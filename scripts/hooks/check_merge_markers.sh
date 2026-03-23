#!/usr/bin/env bash
set -euo pipefail

if rg -n --hidden --glob '!.git/**' '^(<{7}|={7}|>{7})' . >/dev/null; then
  echo "ERROR: merge conflict markers found"
  rg -n --hidden --glob '!.git/**' '^(<{7}|={7}|>{7})' .
  exit 1
fi

