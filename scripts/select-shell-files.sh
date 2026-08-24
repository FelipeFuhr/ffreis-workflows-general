#!/usr/bin/env bash
# Reference implementation of the shell-script file selector used by
# general-shellcheck.yml. Prints one relative path per line (relative to the
# given directory, default '.'): every *.sh file, plus every extension-less
# file (no '.' in its basename at all -- so a template like foo.sh.tpl is
# NOT extension-less and stays out of scope) whose shebang names one of the
# shells ShellCheck supports (sh, bash, dash, ksh). Does not follow symlinks
# (find's default -type f already excludes them); skips .git/, node_modules/,
# vendor/, and target/ at any depth.
#
# This is the reference implementation for the selector embedded in the
# marked region of .github/workflows/general-shellcheck.yml.
# scripts/test-select-shell-files.sh asserts the two copies stay identical
# (modulo indentation) so this script is provably what ships, not a
# diverging duplicate.
#
# Usage: select-shell-files.sh [directory]
set -euo pipefail

dir=${1:-.}
cd "$dir"

files=()

# BEGIN select-shell-files
is_shell_script() {
	local f=$1
	case "$f" in
	*.sh) return 0 ;;
	esac
	local base=${f##*/}
	case "$base" in
	*.*) return 1 ;; # has a non-.sh extension (e.g. a template) -> out of scope
	esac
	local first_line tok interp t
	[[ -f "$f" ]] || return 1
	IFS= read -r -N 100 first_line <"$f" 2>/dev/null
	[[ -z "${first_line:-}" ]] && return 1
	first_line=${first_line%%$'\n'*}
	first_line=${first_line%$'\r'}
	[[ "$first_line" == '#!'* ]] || return 1
	read -ra tok <<<"${first_line#'#!'}"
	[[ "${#tok[@]}" -eq 0 ]] && return 1
	interp=${tok[0]##*/}
	if [[ "$interp" == env ]]; then
		interp=""
		for t in "${tok[@]:1}"; do
			[[ "$t" == -* ]] && continue
			interp=${t##*/}
			break
		done
	fi
	case "$interp" in
	sh | bash | dash | ksh) return 0 ;;
	*) return 1 ;;
	esac
}

while IFS= read -r -d '' f; do
	is_shell_script "$f" && files+=("${f#./}")
done < <(find . \( -type d \( -name .git -o -name node_modules -o -name vendor -o -name target \) \) -prune -o -type f -print0)
# END select-shell-files

printf '%s\n' "${files[@]}"
