# ffreis-workflows-general

Reusable, language-agnostic GitHub Actions workflows.

## Workflows

- `general-actionlint.yml`: validates GitHub Actions workflow syntax with actionlint.
- `general-codeql.yml`: enables CodeQL code scanning (uploads alerts to Code Scanning).
- `general-gitleaks.yml`: scans for secrets with gitleaks (optional SARIF upload).
- `general-shellcheck.yml`: lints shell scripts with shellcheck.
