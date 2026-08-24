#!/usr/bin/env bash
# Self-check for scripts/select-shell-files.sh (the reference implementation
# of the shell-script selector embedded in general-shellcheck.yml).
#
# This repo has no unit-test harness of its own (its "tests" are the
# self-test workflows exercised against examples/hello/ in ci.yml, which only
# run on GitHub). This script fills that gap for logic that's worth testing
# without a live Actions run, and is wired into `make test`.
#
# Asserts two things:
#   1. Against a synthetic fixture tree, the selector picks up *.sh files,
#      picks up extension-less files with a recognized shell shebang
#      (including the `env -S` form), and correctly skips: files with no
#      shebang, non-shell shebangs (python, zsh), non-.sh-extensioned files
#      (e.g. Terraform/Ansible *.sh.tpl / *.j2 templates -- those aren't
#      "extension-less", they're out of scope), symlinks, and anything under
#      .git/, node_modules/, vendor/, or target/.
#   2. The selector block embedded in general-shellcheck.yml has not drifted
#      from this script's copy (compared with indentation stripped, since
#      the workflow copy is nested inside a YAML block scalar).
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
selector="$repo_root/scripts/select-shell-files.sh"
workflow="$repo_root/.github/workflows/general-shellcheck.yml"
failures=0

fail() {
	echo "FAIL: $*" >&2
	failures=$((failures + 1))
}

build_fixture() {
	local fixture_dir=$1
	mkdir -p "$fixture_dir"/{node_modules,vendor,target,.git,subdir/node_modules,realdir}
	echo 'echo hi' >"$fixture_dir/a.sh"
	printf '#!/bin/bash\necho hi\n' >"$fixture_dir/extensionless-bash"
	printf '#!/usr/bin/env bash\necho hi\n' >"$fixture_dir/extensionless-env-bash"
	printf '#!/usr/bin/env -S bash -euo pipefail\necho hi\n' >"$fixture_dir/extensionless-env-S-bash"
	printf '#!/bin/sh\necho hi\n' >"$fixture_dir/extensionless-sh"
	printf '#!/usr/bin/env python3\nprint("hi")\n' >"$fixture_dir/extensionless-python"
	printf 'no shebang here\n' >"$fixture_dir/extensionless-plain"
	printf '#!/usr/bin/env zsh\necho hi\n' >"$fixture_dir/extensionless-zsh"
	printf '#!/bin/bash\necho templated\n' >"$fixture_dir/template.sh.tpl"
	printf '#!/usr/bin/env bash\necho hi\n' >"$fixture_dir/template.j2"
	: >"$fixture_dir/node_modules/pkg.sh"
	: >"$fixture_dir/vendor/lib.sh"
	: >"$fixture_dir/target/build.sh"
	: >"$fixture_dir/.git/hook.sh"
	: >"$fixture_dir/subdir/node_modules/nested.sh"
	echo 'echo real' >"$fixture_dir/realdir/real.sh"
	ln -s realdir/real.sh "$fixture_dir/symlink-to-sh"
}

assert_selection() {
	local fixture_dir got want
	fixture_dir=$(mktemp -d)
	trap 'rm -rf "$fixture_dir"' RETURN
	build_fixture "$fixture_dir"

	got=$(bash "$selector" "$fixture_dir" | sort)
	want=$(printf '%s\n' \
		a.sh \
		extensionless-bash \
		extensionless-env-bash \
		extensionless-env-S-bash \
		extensionless-sh \
		realdir/real.sh | sort)

	if [[ "$got" != "$want" ]]; then
		fail "selection mismatch"
		diff <(echo "$want") <(echo "$got") >&2 || true
	else
		echo "PASS: selector picks up *.sh + extension-less shebang scripts, skips the rest"
	fi
}

assert_drift_free() {
	local from_script from_workflow
	from_script=$(sed -n '/# BEGIN select-shell-files/,/# END select-shell-files/p' "$selector" | sed 's/^[[:space:]]*//')
	from_workflow=$(sed -n '/# BEGIN select-shell-files/,/# END select-shell-files/p' "$workflow" | sed 's/^[[:space:]]*//')

	if [[ -z "$from_script" || -z "$from_workflow" ]]; then
		fail "could not find select-shell-files markers in one of the two files"
		return
	fi

	if [[ "$from_script" != "$from_workflow" ]]; then
		fail "general-shellcheck.yml's embedded selector has drifted from scripts/select-shell-files.sh"
		diff <(echo "$from_script") <(echo "$from_workflow") >&2 || true
	else
		echo "PASS: general-shellcheck.yml's embedded selector matches scripts/select-shell-files.sh"
	fi
}

assert_selection
assert_drift_free

if [[ "$failures" -gt 0 ]]; then
	echo "$failures check(s) failed" >&2
	exit 1
fi
echo "All checks passed."
