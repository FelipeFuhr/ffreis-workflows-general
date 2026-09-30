# `ci-budget`

Derive a CI job's **real** resource budget from its cgroup, plan work that fits
it, and make an overrun attributable.

## The problem it solves

Heavy CI steps size their own parallelism from `/proc/meminfo`'s
`MemAvailable`. Inside a container that is the **node's** free memory, not the
pod's limit. Our self-hosted runner classes are hard-capped — 1.5Gi light, 3Gi
build/heavy, 5Gi, 8Gi xl — so on a 3Gi pod sitting on a node with ~9Gi free, a
"memory-aware" auto-cap plans three 2.5 GB workers into 3 GB.

That does not fail as a build error. The kernel OOM killer takes whatever it
likes, and because the runner agent shares the pod cgroup with the build, the
agent is a candidate. When it loses, the job dies mid-step with empty step
conclusions and `BlobNotFound` logs — which reads as flaky infrastructure
rather than "you asked for more memory than you have".

That misreading is why callers across the fleet carry thirty-line YAML comments
re-deriving the same lesson by hand, each with its own hard-coded worker count,
instead of a number anybody measured.

## Usage

```yaml
- name: Plan
  id: budget
  uses: FelipeFuhr/ffreis-workflows-general/.github/actions/ci-budget@<sha>
  with:
    per-worker-mib: '2500'   # measured peak RSS of ONE unit of parallel work

- name: Capture the OOM baseline
  id: oom-before
  uses: FelipeFuhr/ffreis-workflows-general/.github/actions/ci-budget@<sha>
  with:
    mode: report

- name: Do the heavy thing
  env:
    WORKERS: ${{ steps.budget.outputs.workers }}
  run: some-tool --jobs "$WORKERS"

- name: Report
  if: always()
  uses: FelipeFuhr/ffreis-workflows-general/.github/actions/ci-budget@<sha>
  with:
    mode: report
    baseline-oom-kills: ${{ steps.oom-before.outputs.oom-kills }}
    fail-on-oom: 'true'
```

## Picking `per-worker-mib`

It is the measured peak RSS of one unit of parallel work, and it is a property
of the **dependency closure**, not of the job. Two reference points from this
fleet's Rust crates:

| crate shape | measured peak | 1.5Gi tier | 3Gi tier |
| --- | --- | --- | --- |
| aws-sdk-heavy (4 SDK crates + `lambda_http`) | ~2500 MiB | no | **no** |
| pure-logic (no SDK) | ~350 MiB | 4 workers | 4 workers |

Get the real number from a `mode: report` step's `peak-mib` on a run with
`workers: 1`, then round up.

The 3Gi/aws-sdk cell is the point of the whole action: `3072 − 768 = 2304`
against a 2500 MiB worker **does not fit at any worker count**. No amount of
tuning `jobs` fixes that — the honest answers are a larger tier or a smaller
per-worker footprint, and the plan says so out loud instead of planning a
number that cannot work.

## What it deliberately does not do

**It decides no policy.** It reports `workers` and `fits`; whether a poor fit is
a warning or a failure belongs to the caller, because the answer differs
between a mutation gate and a plain `cargo test`.

**It never plans 0 workers.** When even one does not fit it returns 1 with
`fits=false`. Zero would mean "skip the work", which turns a resource problem
into a silently-green gate — strictly worse than attempting it and being killed
attributably.

**It never raises on an unfamiliar runner.** Missing or malformed cgroup files
degrade to "I could not measure this" (`memory-source: unknown`, `fits=false`,
one worker), never a crash in the step added to protect the job.

## Detection order

Memory is the **minimum** of every ceiling it can see — cgroup v2
`memory.max`, cgroup v1 `memory.limit_in_bytes` (ignoring the unlimited
sentinel), and `/proc/meminfo` `MemAvailable`. Taking the minimum is correct
under both readings: the cgroup limit is what the OOM killer enforces, but a
node under real pressure can legitimately offer less than a pod's own cap. On a
workstation with no limit set it collapses to the plain host value.

CPUs honour a CFS quota (`cpu.max`, or v1 `cpu.cfs_quota_us`/`cfs_period_us`)
before falling back to `os.cpu_count()`, which reports the node's cores inside
a container for the same reason `MemAvailable` does.

## Tests

```bash
cd .github/actions/ci-budget && python3 -m unittest test_ci_budget -v
```

Fixture-driven — no container, no cgroup, no root required. `ci.yml`'s
`ci-budget` job runs them on every PR.
