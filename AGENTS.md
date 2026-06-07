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
   GitHub-owned actions (`actions/*`) may use a major version tag.

4. **No `secrets: inherit`.** Only explicitly declared secrets are passed to callers.
   Workflows requiring secrets must gate against fork PRs in `self-test.yml`.

5. **Concurrency is caller-controlled.** Never add `concurrency:` blocks to reusable
   workflows — callers set their own strategy.

6. **Fork PR gating pattern:**
   ```yaml
   if: github.event_name != 'pull_request' || github.event.pull_request.head.repo.fork == false
   ```

## Structure

```
.github/workflows/
  general-*.yml   ← reusable library (what consumers call)
  devops-*.yml    ← repo-maintenance (stale, labeling, scorecard — exempt from self-test)
  ci.yml          ← self-test orchestrator
examples/hello/   ← canonical test subject for ci.yml
Makefile          ← setup, lint, secrets-scan-staged, hooks
```

## Build/test

```bash
make setup              # verify gitleaks + bootstrap lefthook
make lint               # actionlint on all workflows
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
