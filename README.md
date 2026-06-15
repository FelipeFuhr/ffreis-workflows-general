# ffreis-workflows-general

<!-- ffreis-badges:start -->
[![CI](https://img.shields.io/endpoint?url=https://raw.githubusercontent.com/FelipeFuhr/ffreis-badges/main/badges/ffreis-workflows-general/ci.json)](https://github.com/FelipeFuhr/ffreis-workflows-general/actions) [![Latest version](https://img.shields.io/endpoint?url=https://raw.githubusercontent.com/FelipeFuhr/ffreis-badges/main/badges/ffreis-workflows-general/version.json)](https://github.com/FelipeFuhr/ffreis-workflows-general/releases) [![License](https://img.shields.io/endpoint?url=https://raw.githubusercontent.com/FelipeFuhr/ffreis-badges/main/badges/ffreis-workflows-general/license.json)](https://github.com/FelipeFuhr/ffreis-workflows-general/blob/main/LICENSE)
<!-- ffreis-badges:end -->

Reusable, language-agnostic GitHub Actions workflows.

## Workflows

- `general-actionlint.yml`: validates GitHub Actions workflow syntax with actionlint.
- `general-codeql.yml`: enables CodeQL code scanning (uploads alerts to Code Scanning).
- `general-config-validate.yml`: validates arbitrary YAML (yamllint, relaxed) and JSON (parse) config files so broken config can't land.
- `general-gitleaks.yml`: scans for secrets with gitleaks (optional SARIF upload).
- `general-shellcheck.yml`: lints shell scripts with shellcheck.
