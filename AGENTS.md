# Agent Context

**This repo:** `ffreis-workflows-general` — language-agnostic reusable GitHub Actions
workflow library. Covers actionlint, CodeQL, gitleaks, shellcheck, commit-message
linting, and other general-purpose CI concerns. Consumed by every other repo in the fleet.

## Non-obvious rules (read before changing anything)

1. **Every new `general-*.yml` must be exercised in `ci.yml`** against
   `examples/hello/`. `devops-*.yml` workflows (repo-maintenance) are exempt because
   they compose already-verified workflows. One documented exception to the general rule:
   `general-claude-judge.yml` requires live PR context (Code Scanning alerts, PR diff)
   that cannot be reproduced against a static example directory — its YAML syntax is
   covered by the existing `general-actionlint.yml` job. Any future exception must carry
   an explicit rationale in both the workflow file header and this AGENTS.md entry.

   **This rule is currently violated by 11 workflows, and the list is here so the
   violation is visible rather than rediscovered.** `ci.yml` covers 28 of the 40
   `general-*.yml` files. Uncovered, with no rationale on file:
   `general-commit-messages.yml`, `general-dependency-review.yml`,
   `general-kb-sync.yml`, `general-markdownlint.yml`, `general-pr-size.yml`,
   `general-pr-summary.yml`, `general-promote-gate.yml`, `general-sbom.yml`,
   `general-sonarcloud.yml`, `general-typos.yml`,
   `general-workflow-failure-alert.yml` (plus `general-claude-judge.yml`, which
   has the documented exception above). There is room: see rule 10 — the per-run
   ceiling is 50 unique called workflows and `ci.yml` is at 28. Closing a line of
   this list is always a welcome diff; adding one to it is not.

2. **Shell injection prevention is enforced by Semgrep.** Never interpolate
   `${{ inputs.* }}` directly inside `run:` blocks. Always route through an `env:` var.
   CI will block the PR.

3. **Third-party action SHAs are managed by Renovate.** Do not edit them manually.
   GitHub-owned actions (`actions/*`) may use a major version tag. One documented
   exception: an **orphaned SHA** (the pinned commit 404s upstream, e.g. after a
   force-push/tag rewrite) is a broken-CI bug, not a routine bump — fix it by hand,
   verified against `git ls-remote`/the releases API, and note the incident inline.

4. **No `secrets: inherit`.** Only explicitly declared secrets are passed to callers.
   Workflows requiring secrets must gate against fork PRs in `ci.yml` (see the
   `website-dispatch` job's `head.repo.fork == false` guard for the pattern).

5. **Concurrency is caller-controlled.** Never add `concurrency:` blocks to reusable
   workflows — callers set their own strategy.

6. **Fork PR gating pattern:**
   ```yaml
   if: github.event_name != 'pull_request' || github.event.pull_request.head.repo.fork == false
   ```

7. **Non-trivial inline `run:` bash worth testing outside a live Actions run gets
   a mirrored copy in `scripts/`, guarded by a drift test.** A reusable workflow's
   `run:` steps only ever see the *caller's* checkout — `uses:` never gives you
   this repo's own files at runtime, so logic can't be `source`d from a committed
   script the way a normal single-repo project would. Instead: write the logic
   once as a standalone `scripts/<name>.sh` (locally runnable, testable, and
   reusable for fleet-wide blast-radius audits), wrap the actual logic in
   `# BEGIN <name>` / `# END <name>` marker comments, paste an identical copy
   between the same markers inside the workflow's `run: |` block, and add a
   `scripts/test-<name>.sh` self-check (wired into `make test`) that diffs the
   two marked regions (indentation-stripped, since the YAML copy is nested
   inside a block scalar) so they can't silently diverge. See
   `scripts/select-shell-files.sh` / `scripts/test-select-shell-files.sh` for the
   reference instance (`general-shellcheck.yml`'s file selector).

8. **Capability that must run inside someone else's job is a composite action in
   `.github/actions/<name>/`, not a reusable workflow.** This is the escape hatch
   from rule 7's constraint: a reusable workflow's `run:` only sees the caller's
   checkout, but an *action* is downloaded with its own files, and
   `${{ github.action_path }}` points at them. So an action can ship a real
   script with real unit tests instead of a pasted-and-drift-tested copy. A
   reusable workflow also cannot be invoked as a step, which rules it out
   whenever the capability has to run *between* a caller's own steps.
   `ci-budget` is the first instance and the reason the directory exists.
   Rule 1's self-test obligation applies unchanged: `ci.yml`'s `ci-budget` job
   runs the unit tests **and** invokes the action, because nothing else proves
   `action.yml` wires up. Consumers pin a full SHA exactly as for workflows —
   `uses: FelipeFuhr/ffreis-workflows-general/.github/actions/<name>@<sha>` —
   and because this repo is public that needs no token.

9. **A scanner's exit code does not say whether it ran.** grype v0.114.0:
   exit `0` = ran, nothing at/above `--fail-on`; exit `2` = ran, findings;
   exit `1` = never completed (empty report, `ERROR ...` on stderr);
   exit `>= 128` = killed by signal `exit-128` while bash survives, so the step
   sees an empty report and *no error text at all*. That signal has **two**
   causes the exit code cannot separate — a cgroup OOM kill, or an external
   termination (cancelled run, pod deletion, runner scale-down) — and the step
   must evidence which from the kernel's `oom_kill` counter rather than guess;
   see rule 11, which also carries the measured footprint that makes the OOM
   reading the *less* likely one. A repo with **no package manifests
   is the exit-0 case**: grype writes a valid 358-byte SARIF with
   `"results": []`. Never conflate those four, and never retry any of them —
   all are deterministic or fatal, and retrying only keeps a dying job on the
   runner until it is evicted ("received a shutdown signal"). Log the **package
   count** beside the finding count: a zero-finding verdict over zero cataloged
   packages is not the same claim as one over a real dependency tree.
   This verdict step is duplicated in `general-security-fs.yml` and
   `general-scan-grype-fs.yml` because rule 7's constraint leaves no way to
   share it; `scripts/test-grype-scan-verdict.sh` runs one assertion battery
   against **both**, extracting each step straight from the shipped YAML
   (the `test-scorecard-token-gate.sh` pattern — preferred over rule 7's
   mirror-and-diff when there is no need for a standalone script, since there
   is then no second copy that can drift).

10. **`ci.yml` is the ONLY workflow here with a live trigger, so it is the only
    place coverage can live.** Everything else is `workflow_call`-only
    (`general-*`), `disabled_manually` at the GitHub level (`devops-automation`,
    `devops-security` — check `gh workflow list`, the file's own `on:` block
    does not tell you), or `push`-on-tag (`release`). A job in a workflow you
    cannot trigger is not coverage. `self-test.yml` was deleted for exactly
    this: `workflow_call`-only with no caller anywhere in the fleet, it last ran
    2026-05-08 and had become a drifted duplicate of two thirds of `ci.yml`.
    Real coverage = a job in `ci.yml`, or a `scripts/test-*.sh` reached by
    `make test` via its `self-checks` job.

    **The "20 reusable workflows per file" ceiling is folklore — the real number
    is 50.** GitHub raised the limits in November 2025: 20 → **50 unique called
    workflows per run** (nested trees included) and 4 → **10 nesting levels**.
    The per-run job ceiling (**256**) is the other real one. `ci.yml` itself is
    the proof: it ran green at 25 unique callers / 31 jobs before this file was
    updated, which 20 would have forbidden. It is now at 28 unique / 34 jobs,
    nesting depth 2. So do **not** refuse to add a caller job on caller-count
    grounds, and do not trust the "was 23 → `startup_failure`" story in #79 —
    #82 later found the actual residual cause, a missing `id-token: write` on
    the scorecard caller. `startup_failure` in this repo has come from an
    undeclared input, an abbreviated SHA, a caller `permissions` block that is
    not a superset of the callee's, and a secret referenced by the wrong name —
    diagnose it, never assume the caller count.

11. **A 137 exit does not mean "OOM", and grype is not a memory hog.** Measured
    against the pinned v0.114.0 binary the workflows install: peak RSS **188 MiB**
    with a warm DB, **330 MiB** cold (download + import included). Its
    vulnerability DB is one **~3.1 GiB** SQLite file re-fetched whenever stale,
    staged through ~183 MiB of `TMPDIR` — so on a small repo the step is ~90%
    DB fetch (a *successful* bundle run over a 664 KiB tree spent 4m28s of its
    5m13s in grype). A cold scan plus a 700 MiB co-resident process survives a
    `MemoryMax=1500M`, swap-off cgroup. **`scan-history: true` is not a memory
    driver**: it only changes `fetch-depth`, and grype's catalog is driven by
    package manifests, not object count.
    Both grype steps therefore sample the kernel's own `oom_kill` counter either
    side of the scan and branch on it — *rose* = a real cgroup OOM, name the
    runner label to move to; *static* = killed from outside the cgroup (cancelled
    run, pod deletion, scale-down) and a bigger runner fixes nothing;
    *unreadable* = say the two cannot be told apart. Never round "unknown" down
    to "no OOM". The self-hosted tiers, from
    `platform/ffreis-home-infra/ansible/roles/gha_runner/defaults/main.yml`:
    `[self-hosted, local]` = **1.5Gi** (the default, max 3 replicas, preferred
    onto the 8 GB k3s control-plane box), `+heavy` = 3Gi (max 3, persistent),
    `+large` = 5Gi (max 1, ephemeral), `+xl` = 8Gi (max 1, burst-node only).
    Swap is off fleet-wide. Do not change a `runner:` default — ~650 callers
    share these pools and `heavy` has three lanes total.

## Structure

```
.github/workflows/
  general-*.yml         ← reusable library (what consumers call)
  devops-*.yml          ← repo-maintenance (stale, labeling, scorecard — exempt from self-test)
  ci.yml                ← THE self-test orchestrator; the only live-triggered
                          workflow here, so the only place coverage can live
.github/actions/
  ci-budget/            ← composite action (rule 8): action.yml + ci_budget.py
                          + test_ci_budget.py + README.md
examples/hello/         ← canonical test subject for ci.yml
scripts/select-*.sh,
scripts/test-*.sh        ← mirrors of testable inline `run:` bash + their
                           self-checks (rule 7), plus checks that extract a
                           step or read the workflow graph from the shipped
                           YAML (test-grype-scan-verdict.sh,
                           test-ci-caller-contract.sh)
Makefile                ← setup, lint, test, secrets-scan-staged, hooks
```

## Build/test

```bash
make setup               # verify gitleaks + bootstrap lefthook
make lint                # actionlint on all workflows
make test                # repo self-checks — no live-Actions run needed
make secrets-scan-staged
```

`make test` is reached in CI by `ci.yml`'s `self-checks` job, so it is a real
gate and not just a pre-push convenience. It currently covers the shell-file
selector, the scorecard token gate, both grype verdict steps, the `ci.yml`
caller contract, and the two composite actions' unit tests.

**The caller contract is the one failure mode CI cannot report.** An undeclared
input, a required input not passed, a caller `permissions` block that is not a
superset of the callee's, or a missing required secret all produce
`startup_failure`: zero jobs, no log, and `gh pr checks` shows it as perpetual
PENDING rather than red. `scripts/test-ci-caller-contract.sh` checks all four
before the push; use `quality-kit/scripts/check-ci.sh`, never `gh pr checks`
raw, to read what did run.

## Cross-repo role

Consumed by all `devops/ffreis-workflows-*` repos and indirectly by every repo
in the workspace. Callers pin to a full commit SHA; Renovate manages updates.

## Public repo — private-repo hygiene

This is a **public** GitHub repository. When writing commit messages, PR titles,
PR descriptions, or any other user-visible text, **never name private repos** —
website content, inventory, infra, Lambda, or data repos that are not publicly
listed. Use generic terms instead: "the fleet inventory", "a private consumer",
"internal infra", "private data repo", etc.
## Keeping this file current

- **If you discover a fact not reflected here:** add it before finishing your task.
- **If something here is wrong or outdated:** correct it in the same commit as the code change.
- **If you rename a file, command, or concept referenced here:** update the reference.
