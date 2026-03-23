#!/usr/bin/env bash
set -euo pipefail

while IFS= read -r -d '' file; do
  if file --mime "$file" | rg -q 'charset=binary'; then
    echo "ERROR: binary file detected: $file"
    exit 1
  fi
done < <(find . -type f -not -path './.git/*' -print0)

