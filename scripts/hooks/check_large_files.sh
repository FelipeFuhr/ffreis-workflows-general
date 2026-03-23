#!/usr/bin/env bash
set -euo pipefail

max_bytes="${MAX_BYTES:-1048576}" # 1 MiB

while IFS= read -r -d '' file; do
  size="$(wc -c <"$file" | tr -d ' ')"
  if [[ "$size" -gt "$max_bytes" ]]; then
    echo "ERROR: large file detected: $file ($size bytes > $max_bytes bytes)"
    exit 1
  fi
done < <(find . -type f -not -path './.git/*' -print0)

