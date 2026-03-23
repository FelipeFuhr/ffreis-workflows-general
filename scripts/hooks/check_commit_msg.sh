#!/usr/bin/env bash
set -euo pipefail

msg_file="${1:-}"
if [[ -z "$msg_file" || ! -f "$msg_file" ]]; then
  echo "ERROR: commit message file not provided"
  exit 1
fi

msg="$(cat "$msg_file")"

# Very small conventional-commit guard to keep public repos tidy.
if ! printf '%s' "$msg" | rg -q '^(feat|fix|docs|chore|refactor|test|ci|build)(\\([a-z0-9_-]+\\))?: '; then
  echo "ERROR: commit message must follow Conventional Commits."
  echo "Example: feat(cli): add dry-run flag"
  exit 1
fi

