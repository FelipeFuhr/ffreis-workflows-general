#!/usr/bin/env python3
"""Unit tests for ci_budget.

These build fixture sysfs/procfs trees on disk, so every branch of the
detection logic is exercised without needing a container, a cgroup, or root.
The regression these exist to prevent is specific and was observed in
production: a memory-aware auto-cap that reads the HOST's free memory while
running inside a capped pod, and therefore plans a worker count that cannot
fit. `test_cgroup_limit_wins_over_larger_host` is that case.
"""

import unittest
from pathlib import Path
from tempfile import TemporaryDirectory

import ci_budget as cb

MIB = 1024 * 1024


def write(root: Path, rel: str, text: str) -> None:
    path = root / rel
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text)


def meminfo(root: Path, available_kib: int) -> None:
    write(root, "meminfo", f"MemTotal:       32000000 kB\nMemAvailable:   {available_kib} kB\n")


class TestDetectMemory(unittest.TestCase):
    def test_cgroup_v2_limit(self):
        with TemporaryDirectory() as d:
            sysfs, proc = Path(d) / "sys", Path(d) / "proc"
            write(sysfs, "memory.max", str(3 * 1024 * MIB))
            meminfo(proc, 9_000_000)
            self.assertEqual(cb.detect_memory(str(sysfs), str(proc)), (3072, "cgroup-v2"))

    def test_cgroup_v2_max_keyword_is_not_a_limit(self):
        with TemporaryDirectory() as d:
            sysfs, proc = Path(d) / "sys", Path(d) / "proc"
            write(sysfs, "memory.max", "max")
            meminfo(proc, 8_192_000)  # 8000 MiB
            self.assertEqual(cb.detect_memory(str(sysfs), str(proc)), (8000, "meminfo"))

    def test_cgroup_v1_limit(self):
        with TemporaryDirectory() as d:
            sysfs, proc = Path(d) / "sys", Path(d) / "proc"
            write(sysfs, "memory/memory.limit_in_bytes", str(1536 * MIB))
            meminfo(proc, 9_000_000)
            self.assertEqual(cb.detect_memory(str(sysfs), str(proc)), (1536, "cgroup-v1"))

    def test_cgroup_v1_unlimited_sentinel_ignored(self):
        with TemporaryDirectory() as d:
            sysfs, proc = Path(d) / "sys", Path(d) / "proc"
            write(sysfs, "memory/memory.limit_in_bytes", "9223372036854771712")
            meminfo(proc, 4_096_000)  # 4000 MiB
            self.assertEqual(cb.detect_memory(str(sysfs), str(proc)), (4000, "meminfo"))

    def test_cgroup_limit_wins_over_larger_host(self):
        """THE regression: a 3Gi pod on a node reporting ~9Gi free.

        The old auto-cap read 9051 MiB here and planned three 2.5 GB workers
        into a 3 GiB pod. The budget must be the pod's.
        """
        with TemporaryDirectory() as d:
            sysfs, proc = Path(d) / "sys", Path(d) / "proc"
            write(sysfs, "memory.max", str(3 * 1024 * MIB))
            meminfo(proc, 9_268_224)  # 9051 MiB, the observed host figure
            mib, source = cb.detect_memory(str(sysfs), str(proc))
            self.assertEqual((mib, source), (3072, "cgroup-v2"))

    def test_host_lower_than_cgroup_wins(self):
        """A node under real pressure can offer less than the pod's own cap."""
        with TemporaryDirectory() as d:
            sysfs, proc = Path(d) / "sys", Path(d) / "proc"
            write(sysfs, "memory.max", str(8 * 1024 * MIB))
            meminfo(proc, 1_024_000)  # 1000 MiB
            self.assertEqual(cb.detect_memory(str(sysfs), str(proc)), (1000, "meminfo"))

    def test_nothing_readable(self):
        with TemporaryDirectory() as d:
            self.assertEqual(
                cb.detect_memory(str(Path(d) / "nope"), str(Path(d) / "alsonope")),
                (None, "unknown"),
            )

    def test_malformed_files_do_not_raise(self):
        with TemporaryDirectory() as d:
            sysfs, proc = Path(d) / "sys", Path(d) / "proc"
            write(sysfs, "memory.max", "not-a-number")
            write(proc, "meminfo", "MemAvailable:   banana kB\n")
            self.assertEqual(cb.detect_memory(str(sysfs), str(proc)), (None, "unknown"))


class TestDetectCpus(unittest.TestCase):
    def test_v2_quota(self):
        with TemporaryDirectory() as d:
            sysfs = Path(d) / "sys"
            write(sysfs, "cpu.max", "200000 100000")
            self.assertEqual(cb.detect_cpus(str(sysfs)), (2, "cgroup-v2"))

    def test_v2_max_falls_back_to_host(self):
        with TemporaryDirectory() as d:
            sysfs = Path(d) / "sys"
            write(sysfs, "cpu.max", "max 100000")
            cpus, source = cb.detect_cpus(str(sysfs))
            self.assertEqual(source, "host")
            self.assertGreaterEqual(cpus, 1)

    def test_v1_quota(self):
        with TemporaryDirectory() as d:
            sysfs = Path(d) / "sys"
            write(sysfs, "cpu/cpu.cfs_quota_us", "400000")
            write(sysfs, "cpu/cpu.cfs_period_us", "100000")
            self.assertEqual(cb.detect_cpus(str(sysfs)), (4, "cgroup-v1"))

    def test_fractional_quota_rounds_up_to_one(self):
        with TemporaryDirectory() as d:
            sysfs = Path(d) / "sys"
            write(sysfs, "cpu.max", "50000 100000")  # half a CPU
            self.assertEqual(cb.detect_cpus(str(sysfs)), (1, "cgroup-v2"))


class TestPlanWorkers(unittest.TestCase):
    def limits(self, mib, cpus=16, source="cgroup-v2"):
        return cb.Limits(memory_mib=mib, memory_source=source, cpus=cpus, cpu_source="host")

    def test_heavy_tier_does_not_fit_an_aws_sdk_crate(self):
        """3 GiB tier, 768 MiB reserved, 2500 MiB/worker: does NOT fit — by 196 MiB.

        This is the measured markforge case and the answer is genuinely "no":
        3072 - 768 = 2304 usable against a 2500 MiB worker. No worker count
        makes that fit, which is why every attempt to tune `jobs` on this tier
        OOM'd. The honest outcomes are a larger tier or a smaller per-worker
        footprint, and the plan says so instead of planning a number that
        cannot work.
        """
        plan = cb.plan_workers(self.limits(3072), per_worker_mib=2500, reserve_mib=768, max_workers=4)
        self.assertFalse(plan.fits)
        self.assertEqual(plan.workers, 1)
        self.assertEqual(plan.shortfall_mib, 196)

    def test_five_gi_tier_fits_one_aws_sdk_worker(self):
        """The same crate on the 5Gi tier: fits, single worker."""
        plan = cb.plan_workers(self.limits(5120), per_worker_mib=2500, reserve_mib=768, max_workers=4)
        self.assertTrue(plan.fits)
        self.assertEqual(plan.workers, 1)

    def test_old_host_based_reading_would_have_planned_three(self):
        """Documents the bug: same knobs, host figure, three workers."""
        plan = cb.plan_workers(self.limits(9051, source="meminfo"), per_worker_mib=2500,
                               reserve_mib=768, max_workers=4)
        self.assertEqual(plan.workers, 3)

    def test_light_tier_cannot_fit_a_heavy_crate(self):
        """1.5 GiB tier, 2500 MiB per worker: does not fit, and says so."""
        plan = cb.plan_workers(self.limits(1536), per_worker_mib=2500, reserve_mib=768, max_workers=4)
        self.assertFalse(plan.fits)
        self.assertEqual(plan.workers, 1, "must still attempt 1, never 0 — 0 would skip the gate")
        self.assertGreater(plan.shortfall_mib, 0)
        self.assertIn("short by", plan.reason)

    def test_light_tier_fits_a_light_crate(self):
        """The flowgraph/evidence-core case: small closure, 1.5 GiB is plenty."""
        plan = cb.plan_workers(self.limits(1536, cpus=8), per_worker_mib=350, reserve_mib=512, max_workers=4)
        self.assertTrue(plan.fits)
        self.assertEqual(plan.workers, 2)

    def test_cpu_bound_when_memory_is_plentiful(self):
        plan = cb.plan_workers(self.limits(64000, cpus=4), per_worker_mib=500, reserve_mib=512, max_workers=8)
        self.assertEqual(plan.workers, 2)
        self.assertIn("cpu-bound", plan.reason)

    def test_max_workers_ceiling_applies(self):
        plan = cb.plan_workers(self.limits(64000, cpus=64), per_worker_mib=500, reserve_mib=512, max_workers=4)
        self.assertEqual(plan.workers, 4)

    def test_unmeasurable_budget_is_conservative_and_flagged(self):
        plan = cb.plan_workers(self.limits(None), per_worker_mib=2500, reserve_mib=768, max_workers=4)
        self.assertEqual(plan.workers, 1)
        self.assertFalse(plan.fits)


class TestPeakAndOom(unittest.TestCase):
    def test_peak_v2(self):
        with TemporaryDirectory() as d:
            sysfs = Path(d) / "sys"
            write(sysfs, "memory.peak", str(2600 * MIB))
            self.assertEqual(cb.read_peak(str(sysfs)), 2600)

    def test_peak_v1(self):
        with TemporaryDirectory() as d:
            sysfs = Path(d) / "sys"
            write(sysfs, "memory/memory.max_usage_in_bytes", str(1200 * MIB))
            self.assertEqual(cb.read_peak(str(sysfs)), 1200)

    def test_peak_absent(self):
        with TemporaryDirectory() as d:
            self.assertIsNone(cb.read_peak(str(Path(d) / "nope")))

    def test_oom_kill_counter(self):
        with TemporaryDirectory() as d:
            sysfs = Path(d) / "sys"
            write(sysfs, "memory.events", "low 0\nhigh 0\nmax 12\noom 3\noom_kill 2\n")
            self.assertEqual(cb.read_oom_kills(str(sysfs)), 2)

    def test_oom_distinguished_from_oom_kill(self):
        """`oom` alone can be survivable; only `oom_kill` means a process died."""
        with TemporaryDirectory() as d:
            sysfs = Path(d) / "sys"
            write(sysfs, "memory.events", "oom 5\noom_kill 0\n")
            self.assertEqual(cb.read_oom_kills(str(sysfs)), 0)


class TestUtilisation(unittest.TestCase):
    """The fit assertion — "does this work still fit its tier, with margin".

    The regression these prevent is not an OOM. It is the quarter BEFORE the
    OOM, when a dependency bump takes a job from 50% to 95% of its pod and
    nothing says anything, so the eventual kill arrives with no history and
    reads as flaky infrastructure.
    """

    def test_basic_ratio(self):
        self.assertEqual(cb.utilisation_pct(1554, 3072), 51)

    def test_at_the_ceiling(self):
        self.assertEqual(cb.utilisation_pct(3072, 3072), 100)

    def test_the_measured_heavy_tier_case(self):
        """2541 MiB measured under a cgroup mirroring the heavy pod."""
        self.assertEqual(cb.utilisation_pct(2541, 3072), 83)

    def test_unknown_peak_is_unknown_not_zero(self):
        """Critical: must be None, never 0.

        0 would read as "0% utilised — comfortably fits", which is the exact
        inversion of the truth ("we could not measure this at all").
        """
        self.assertIsNone(cb.utilisation_pct(None, 3072))

    def test_unknown_budget_is_unknown(self):
        self.assertIsNone(cb.utilisation_pct(1554, None))

    def test_zero_budget_does_not_divide_by_zero(self):
        self.assertIsNone(cb.utilisation_pct(1554, 0))


if __name__ == "__main__":
    unittest.main(verbosity=2)
