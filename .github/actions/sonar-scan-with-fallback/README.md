# `sonar-scan-with-fallback`

Run a SonarCloud scan with automatic fallback to the fleet's self-hosted
SonarQube when SonarCloud itself can't do the scan.

## The problem it solves

SonarCloud's free tier only analyzes PUBLIC repos — a private repo 403s
regardless of token validity — so private repos need to route to a different
server entirely. Separately, the org-wide SonarCloud plan has an LOC-analysis
ceiling shared across every public project; once it's hit, **every** public
repo's scan starts failing with no code-side cause. Before this action
existed, that failure just failed the check — loudly for whoever happened to
push next, but with no record of which repos it hit or how often, and no way
to still get a scan.

This action keeps a scan happening either way:

* **Private repos** route straight to the fleet's self-hosted SonarQube
  (`ffreis-home-infra`'s scale-to-zero `sonarqube` role, `ci` namespace) —
  unchanged behavior, just centralized (previously only
  `ffreis-workflows-terraform`'s `tf-sonar.yml` had this; now every language
  shares one copy).
* **Public repos** try SonarCloud first. If that attempt fails for any
  reason, the same local server scales up and takes the scan instead of the
  check just going red.
* Only the second case — SonarCloud attempted and failed — counts as a
  **fallback** (`used-fallback: 'true'`). A private repo's normal routing is
  not a fallback; it never touches SonarCloud at all, same as before.

## Usage

```yaml
- name: Build Sonar extra args
  id: sonar-args
  # ... existing per-language project-key/organization resolution, unchanged ...

- name: Sonar scan
  id: sonar
  uses: FelipeFuhr/ffreis-workflows-general/.github/actions/sonar-scan-with-fallback@<sha>
  with:
    project-base-dir: ${{ inputs.working-directory }}
    project-key: ${{ steps.sonar-args.outputs.project_key }}
    organization: ${{ steps.sonar-args.outputs.organization }}
    sonar-token: ${{ secrets.SONAR_TOKEN }}
    extra-sonar-args: >
      -Dsonar.go.coverage.reportPaths=coverage.out
      -Dsonar.sources=.
    notify-role-to-assume: ${{ secrets.CI_NOTIFY_ROLE_ARN }}
```

`extra-sonar-args` is whatever language-specific `-Dsonar.*` flags the
reusable workflow already built (coverage paths, `sonar.sources`/`sonar.tests`,
exclusions, language version). `project-key`/`organization` resolution is
**not** touched by this action — each language keeps its own existing logic
for that (sonar-project.properties > repo var > input > computed default).
Getting a SonarCloud project key wrong creates a brand-new project and loses
analysis history, so this action deliberately stays out of that decision.

## Notification

If `notify-role-to-assume` is set and a fallback actually happened, this
action assumes that role and invokes the fleet's `ffreis-monitor-evaluator-prod`
Lambda (`mode: "ci_notify"`), which rate-limits to **one email fleet-wide per
day** via its existing DynamoDB dedup table — so ten repos hitting the same
LOC-quota outage in one day produce one email, not ten. Leave the input empty
to disable notification entirely (no AWS call is made) — useful while rolling
this out to a repo whose `CI_NOTIFY_ROLE_ARN` secret isn't wired yet.

A notification failure (role not assumable, Lambda down, etc.) never fails
the calling job — see the `continue-on-error: true` on both AWS-facing steps.

## Testing

```bash
cd .github/actions/sonar-scan-with-fallback
python3 -m unittest discover -p 'test_*.py' -v
```

`ci.yml`'s `sonar-scan-fallback` job also invokes the action itself with
`dry-run: 'true'` against `examples/hello/` — the only thing that proves
`action.yml`'s input/output wiring actually works, same reasoning as
`ci-budget`. Dry-run skips every network and cluster call (no real
`SONAR_TOKEN` or self-hosted runner is available in this repo's own public
CI), so it only exercises the routing decision, not a real scan.
