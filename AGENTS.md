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

2. **Shell injection prevention is enforced by Semgrep.** Never interpolate
   `${{ inputs.* }}` directly inside `run:` blocks. Always route through an `env:` var.
   CI will block the PR.

3. **Third-party action SHAs are managed by Renovate.** Do not edit them manually.
   GitHub-owned actions (`actions/*`) may use a major version tag. One documented
   exception: an **orphaned SHA** (the pinned commit 404s upstream, e.g. after a
   force-push/tag rewrite) is a broken-CI bug, not a routine bump — fix it by hand,
   verified against `git ls-remote`/the releases API, and note the incident inline.

4. **No `secrets: inherit`.** Only explicitly declared secrets are passed to callers.
   Workflows requiring secrets must gate against fork PRs in `self-test.yml`.

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
   exit `>= 128` = killed by signal `exit-128` — the OOM killer takes grype
   (largest RSS in the pod cgroup) while bash survives, so the step sees an
   empty report and *no error text at all*. A repo with **no package manifests
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

10. **`self-test.yml` has no trigger and no caller — it never runs.** It is
    `workflow_call`-only and nothing in this repo invokes it, so any workflow
    whose only "coverage" is a job there has no gate at all
    (`general-scan-grype-fs.yml` is in this position today). Real PR coverage
    comes from `ci.yml`: a job there, or `make test` via its `self-checks` job.
    `ci.yml` also sits near GitHub's per-file reusable-workflow ceiling (it hit
    `startup_failure` at 23 callers once), so prefer extending
    `scripts/test-*.sh` + `make test` over adding another caller job.

## Structure

```
.github/workflows/
  general-*.yml         ← reusable library (what consumers call)
  devops-*.yml          ← repo-maintenance (stale, labeling, scorecard — exempt from self-test)
  ci.yml                ← self-test orchestrator
.github/actions/
  ci-budget/            ← composite action (rule 8): action.yml + ci_budget.py
                          + test_ci_budget.py + README.md
examples/hello/         ← canonical test subject for ci.yml
scripts/select-*.sh,
scripts/test-*.sh        ← standalone mirrors of testable inline `run:` bash + their self-checks (rule 7)
Makefile                ← setup, lint, test, secrets-scan-staged, hooks
```

## Build/test

```bash
make setup               # verify gitleaks + bootstrap lefthook
make lint                # actionlint on all workflows
make test                # repo self-checks (e.g. shell file-selector logic) — no live-Actions run needed
make secrets-scan-staged
```

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
