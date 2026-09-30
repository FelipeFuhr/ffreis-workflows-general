#!/usr/bin/env python3
"""ci_budget — derive a CI job's REAL resource budget, then hold work to it.

WHY THIS EXISTS
---------------
Heavy CI steps in this fleet (mutation testing above all, but also `test`,
`build` and `coverage` on dependency-heavy crates) size their own parallelism
from `/proc/meminfo`'s `MemAvailable`. Inside a container that number is the
NODE's free memory, not the pod's limit. The self-hosted runner classes are
hard-capped (`resources_limits_memory`: 1.5Gi light, 3Gi build/heavy, 5Gi,
8Gi xl), so on a 3Gi pod sitting on a node with 9Gi free, a "memory-aware"
auto-cap picks three workers at ~2.5 GB peak each and asks for 7.5 GB inside
3 GB. The result is not a build error: the kernel OOM killer takes whatever it
likes, and because the GitHub runner agent shares the pod cgroup with the
build, the agent itself is a candidate. When it loses, the job dies mid-step
with empty step conclusions and `BlobNotFound` logs — which reads as flaky
infrastructure rather than "you asked for more memory than you have".

That misreading is expensive: it is why callers across this fleet carry
thirty-line YAML comments re-deriving the same lesson by hand, each with its
own hard-coded worker count, instead of a number anybody measured.

This module fixes the input, not the folklore. It reads the budget from the
cgroup when there is one and falls back to the host only when there is not,
takes the MINIMUM of everything it can see, and reports what it found. After
the run it reads back the observed peak and the kernel's own OOM-kill counter,
so an overrun is reported as an overrun.

DESIGN NOTES
------------
* `sysfs_root` / `proc_root` are injectable so the detection logic is testable
  from fixture directories. Nothing here needs a container to be exercised.
* Detection NEVER raises on a missing or malformed file — a runner we have not
  seen before must degrade to "I could not measure this", not crash the job it
  was added to protect.
* This module decides nothing about policy. It reports `workers` and `fits`;
  whether a poor fit is a warning or a failure belongs to the caller, because
  that answer differs between a mutation gate and a plain `cargo test`.
"""

from __future__ import annotations

import argparse
import os
import sys
from dataclasses import dataclass, asdict
from pathlib import Path

MIB = 1024 * 1024

# cgroup v1 writes a sentinel rather than an "unlimited" keyword. The exact
# value is PAGE_SIZE-dependent (it is LONG_MAX rounded down to a page
# multiple), so treat anything implausibly large as "no limit" instead of
# comparing against one magic constant.
_V1_UNLIMITED_FLOOR = 1 << 62


def _read(path: Path) -> str | None:
    """Read a sysfs/procfs file, returning None for anything unreadable.

    Missing files are the common case (cgroup v1 on a v2 host and vice versa);
    PermissionError and OSError show up on hardened or unusual runners. None of
    those should be fatal to the caller.
    """
    try:
        return path.read_text().strip()
    except (OSError, ValueError):
        return None


@dataclass(frozen=True)
class Limits:
    """What we were able to observe about this machine's real ceiling."""

    memory_mib: int | None
    memory_source: str
    cpus: int
    cpu_source: str


def detect_memory(sysfs_root: str = "/sys/fs/cgroup", proc_root: str = "/proc") -> tuple[int | None, str]:
    """Return (budget_mib, source) — the smallest real memory ceiling we can see.

    Order matters, but the MINIMUM matters more. A pod has both a cgroup limit
    and a host `MemAvailable`; the cgroup limit is the one the OOM killer
    enforces against this process, but the host figure can legitimately be
    LOWER when the node is itself under pressure and the pod is over-provisioned
    against it. Taking the minimum is correct under both readings, and collapses
    to the plain host value on a workstation with no limit set.
    """
    sysfs, proc = Path(sysfs_root), Path(proc_root)
    candidates: list[tuple[int, str]] = []

    # cgroup v2 (unified). "max" means no limit was set on this cgroup.
    raw = _read(sysfs / "memory.max")
    if raw and raw != "max":
        try:
            candidates.append((int(raw) // MIB, "cgroup-v2"))
        except ValueError:
            pass

    # cgroup v1.
    raw = _read(sysfs / "memory" / "memory.limit_in_bytes")
    if raw:
        try:
            value = int(raw)
            if value < _V1_UNLIMITED_FLOOR:
                candidates.append((value // MIB, "cgroup-v1"))
        except ValueError:
            pass

    # Host. MemAvailable (not MemFree) is the right figure: it accounts for
    # reclaimable page cache, which is what a compile job can actually take.
    meminfo = _read(proc / "meminfo")
    if meminfo:
        for line in meminfo.splitlines():
            if line.startswith("MemAvailable:"):
                parts = line.split()
                if len(parts) >= 2 and parts[1].isdigit():
                    candidates.append((int(parts[1]) // 1024, "meminfo"))
                break

    if not candidates:
        return None, "unknown"
    return min(candidates, key=lambda c: c[0])


def detect_cpus(sysfs_root: str = "/sys/fs/cgroup") -> tuple[int, str]:
    """Return (cpus, source), honouring a CFS quota when one is set.

    `os.cpu_count()` reports the node's cores inside a container, which
    overstates a quota-limited pod exactly the way MemAvailable overstates its
    memory. A fractional quota rounds UP to 1: a 0.5-CPU pod still runs, just
    slowly, and returning 0 here would propagate a nonsense worker count.
    """
    sysfs = Path(sysfs_root)

    raw = _read(sysfs / "cpu.max")  # v2: "<quota|max> <period>"
    if raw:
        parts = raw.split()
        if len(parts) == 2 and parts[0] != "max":
            try:
                quota, period = int(parts[0]), int(parts[1])
                if quota > 0 and period > 0:
                    return max(1, quota // period), "cgroup-v2"
            except ValueError:
                pass

    quota_raw = _read(sysfs / "cpu" / "cpu.cfs_quota_us")  # v1; -1 == unlimited
    period_raw = _read(sysfs / "cpu" / "cpu.cfs_period_us")
    if quota_raw and period_raw:
        try:
            quota, period = int(quota_raw), int(period_raw)
            if quota > 0 and period > 0:
                return max(1, quota // period), "cgroup-v1"
        except ValueError:
            pass

    return max(1, os.cpu_count() or 1), "host"


def detect_limits(sysfs_root: str = "/sys/fs/cgroup", proc_root: str = "/proc") -> Limits:
    mem, mem_src = detect_memory(sysfs_root, proc_root)
    cpus, cpu_src = detect_cpus(sysfs_root)
    return Limits(memory_mib=mem, memory_source=mem_src, cpus=cpus, cpu_source=cpu_src)


@dataclass(frozen=True)
class Plan:
    workers: int
    fits: bool
    shortfall_mib: int
    usable_mib: int | None
    limits: Limits
    reason: str


def plan_workers(
    limits: Limits,
    per_worker_mib: int,
    reserve_mib: int,
    max_workers: int,
    cpu_divisor: int = 2,
) -> Plan:
    """Decide how many parallel workers this budget actually supports.

    `reserve_mib` is carved off the top for everything that is NOT a worker:
    the runner agent, the shell, the test harness's own allocations. On a
    shared-cgroup runner this reserve is what keeps the OOM killer away from
    the agent, which is the difference between an attributable failure and a
    run that looks like flaky infrastructure.

    `cpu_divisor` halves the core count by default because each mutation worker
    spawns its own compiler, which is itself parallel; letting workers own every
    core oversubscribes the box without shortening the wall clock.

    When even ONE worker does not fit we still return 1 rather than 0, and set
    `fits=False` with the shortfall. Returning 0 would mean "do nothing", which
    silently skips the gate — strictly worse than attempting the work and being
    killed attributably. The caller decides whether a poor fit warns or fails.
    """
    if limits.memory_mib is None:
        # Nothing measurable. Be conservative: one worker, and say why.
        return Plan(
            workers=1, fits=False, shortfall_mib=0, usable_mib=None, limits=limits,
            reason="no memory limit could be read (no cgroup, no /proc/meminfo) — assuming 1 worker",
        )

    usable = limits.memory_mib - reserve_mib
    by_mem = usable // per_worker_mib if per_worker_mib > 0 else max_workers
    by_cpu = max(1, limits.cpus // max(1, cpu_divisor))
    workers = min(by_mem, by_cpu, max_workers)

    if workers < 1:
        shortfall = per_worker_mib - usable
        return Plan(
            workers=1, fits=False, shortfall_mib=max(0, shortfall), usable_mib=usable, limits=limits,
            reason=(
                f"budget {limits.memory_mib} MiB (via {limits.memory_source}) minus {reserve_mib} MiB "
                f"reserved leaves {usable} MiB, below the {per_worker_mib} MiB one worker needs "
                f"— short by {max(0, shortfall)} MiB"
            ),
        )

    binding = "memory" if by_mem <= by_cpu and by_mem <= max_workers else (
        "cpu" if by_cpu <= max_workers else "max-workers ceiling"
    )
    return Plan(
        workers=workers, fits=True, shortfall_mib=0, usable_mib=usable, limits=limits,
        reason=(
            f"{workers} worker(s); {binding}-bound "
            f"(budget {limits.memory_mib} MiB via {limits.memory_source}, "
            f"{usable} MiB usable / {per_worker_mib} MiB per worker = {by_mem}; "
            f"{limits.cpus} cpu via {limits.cpu_source} / {cpu_divisor} = {by_cpu}; ceiling {max_workers})"
        ),
    )


def read_peak(sysfs_root: str = "/sys/fs/cgroup") -> int | None:
    """Observed peak memory in MiB, if the kernel exposes it.

    `memory.peak` landed in cgroup v2 in Linux 5.19; v1's equivalent is
    `memory.max_usage_in_bytes`. Neither is guaranteed, hence None.
    """
    sysfs = Path(sysfs_root)
    for rel in ("memory.peak", "memory/memory.max_usage_in_bytes"):
        raw = _read(sysfs / rel)
        if raw:
            try:
                return int(raw) // MIB
            except ValueError:
                continue
    return None


def read_oom_kills(sysfs_root: str = "/sys/fs/cgroup") -> int | None:
    """How many times the kernel OOM-killed something in this cgroup.

    This is THE signal that turns "the runner lost communication with the
    server" into an attributable message. `oom_kill` counts processes the OOM
    killer actually reaped; `oom` counts times the cgroup hit its limit, which
    can be survivable. We want the former.
    """
    sysfs = Path(sysfs_root)
    for rel in ("memory.events", "memory/memory.oom_control"):
        raw = _read(sysfs / rel)
        if not raw:
            continue
        for line in raw.splitlines():
            parts = line.split()
            if len(parts) == 2 and parts[0] == "oom_kill" and parts[1].isdigit():
                return int(parts[1])
    return None


# --------------------------------------------------------------------------
# GitHub Actions plumbing
# --------------------------------------------------------------------------

def _emit(pairs: dict[str, object], stream_env: str) -> None:
    """Append key=value lines to a GitHub Actions file, if we are in one."""
    path = os.environ.get(stream_env)
    if not path:
        return
    with open(path, "a", encoding="utf-8") as fh:
        for key, value in pairs.items():
            fh.write(f"{key}={value}\n")


def _summary(markdown: str) -> None:
    path = os.environ.get("GITHUB_STEP_SUMMARY")
    if not path:
        return
    with open(path, "a", encoding="utf-8") as fh:
        fh.write(markdown + "\n")


def cmd_plan(args: argparse.Namespace) -> int:
    limits = detect_limits(args.sysfs_root, args.proc_root)
    plan = plan_workers(
        limits,
        per_worker_mib=args.per_worker_mib,
        reserve_mib=args.reserve_mib,
        max_workers=args.max_workers,
        cpu_divisor=args.cpu_divisor,
    )

    print(f"ci-budget: {plan.reason}")
    if not plan.fits:
        # A warning, not an error: this command reports, the caller enforces.
        print(f"::warning title=CI budget::{plan.reason}")

    _emit(
        {
            "workers": plan.workers,
            "fits": str(plan.fits).lower(),
            "shortfall-mib": plan.shortfall_mib,
            "memory-mib": limits.memory_mib if limits.memory_mib is not None else "",
            "memory-source": limits.memory_source,
            "usable-mib": plan.usable_mib if plan.usable_mib is not None else "",
            "cpus": limits.cpus,
            "reason": plan.reason,
        },
        "GITHUB_OUTPUT",
    )
    _summary(
        "### CI budget\n\n"
        f"| budget | source | usable | per worker | cpus | workers | fits |\n"
        f"| --- | --- | --- | --- | --- | --- | --- |\n"
        f"| {limits.memory_mib} MiB | {limits.memory_source} | {plan.usable_mib} MiB "
        f"| {args.per_worker_mib} MiB | {limits.cpus} | **{plan.workers}** | {plan.fits} |\n"
    )
    return 0


def cmd_report(args: argparse.Namespace) -> int:
    peak = read_peak(args.sysfs_root)
    kills = read_oom_kills(args.sysfs_root)
    limits = detect_limits(args.sysfs_root, args.proc_root)

    peak_txt = f"{peak} MiB" if peak is not None else "unavailable"
    print(f"ci-budget: peak {peak_txt}, oom_kill count {kills if kills is not None else 'unavailable'}")

    _emit(
        {
            "peak-mib": peak if peak is not None else "",
            "oom-kills": kills if kills is not None else "",
        },
        "GITHUB_OUTPUT",
    )
    _summary(
        f"\n**Observed peak:** {peak_txt}"
        f" (budget {limits.memory_mib} MiB via {limits.memory_source});"
        f" OOM kills: {kills if kills is not None else 'unavailable'}\n"
    )

    if kills and kills > args.baseline_oom_kills:
        new = kills - args.baseline_oom_kills
        msg = (
            f"the kernel OOM-killed {new} process(es) in this job's cgroup "
            f"(budget {limits.memory_mib} MiB via {limits.memory_source}, peak {peak_txt}). "
            "This is a RESOURCE failure, not a flaky runner and not a test failure: "
            "lower the worker count, raise the runner tier, or narrow the work."
        )
        print(f"::error title=Job exceeded its memory budget::{msg}")
        if args.fail_on_oom:
            return 1
    return 0


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="ci_budget", description=__doc__)
    parser.add_argument("--sysfs-root", default="/sys/fs/cgroup")
    parser.add_argument("--proc-root", default="/proc")
    sub = parser.add_subparsers(dest="command", required=True)

    p = sub.add_parser("plan", help="compute a worker count that fits the real budget")
    p.add_argument("--per-worker-mib", type=int, required=True)
    p.add_argument("--reserve-mib", type=int, default=768)
    p.add_argument("--max-workers", type=int, default=4)
    p.add_argument("--cpu-divisor", type=int, default=2)
    p.set_defaults(func=cmd_plan)

    r = sub.add_parser("report", help="report observed peak and OOM kills after a run")
    r.add_argument("--baseline-oom-kills", type=int, default=0)
    r.add_argument("--fail-on-oom", action="store_true")
    r.set_defaults(func=cmd_report)

    args = parser.parse_args(argv)
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
