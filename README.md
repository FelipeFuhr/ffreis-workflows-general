# ffreis-workflows-general

Reusable, language-agnostic GitHub Actions workflows.

## Workflows

- `general-actionlint.yml`: validates GitHub Actions workflow syntax with actionlint.
- `general-codeql.yml`: enables CodeQL code scanning (uploads alerts to Code Scanning).
- `general-config-validate.yml`: validates arbitrary YAML (yamllint, relaxed) and JSON (parse) config files so broken config can't land.
- `general-gitleaks.yml`: scans for secrets with gitleaks (optional SARIF upload).
- `general-shellcheck.yml`: lints shell scripts with shellcheck.
