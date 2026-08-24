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

## Structure

```
.github/workflows/
  general-*.yml         ← reusable library (what consumers call)
  devops-*.yml          ← repo-maintenance (stale, labeling, scorecard — exempt from self-test)
  ci.yml                ← self-test orchestrator
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
