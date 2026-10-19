#!/usr/bin/env bash
# Self-check for the "Run Grype (filesystem)" step in general-security-fs.yml
# and general-scan-grype-fs.yml.
#
# Like test-scorecard-token-gate.sh, this extracts the step's `run:` block
# straight from each workflow and exercises it against a stubbed `grype`, so the
# assertions are made against the shipped copy rather than a transcription of it.
# Both workflows embed the same verdict logic (a reusable workflow cannot share a
# bash function with another reusable workflow, and a local `uses: ./...` action
# resolves against the CALLER's checkout, so it cannot be factored out); running
# one battery against both is what keeps the two copies from drifting.
#
# What is worth locking here: grype's exit code alone does not say whether the
# scan ran. The real contract, probed against the pinned v0.114.0 binary:
#
#   exit 0,      SARIF written -> ran; nothing at/above --fail-on
#   exit 2,      SARIF written -> ran; findings at/above --fail-on
#   exit 1,      SARIF EMPTY   -> never completed; stderr has an `ERROR ...` line
#   exit >= 128, SARIF EMPTY   -> killed by signal exit-128, by EITHER of two
#                                 causes the exit code cannot distinguish:
#                                   * a cgroup OOM kill (grype dies, bash and
#                                     the runner agent survive), or
#                                   * an external termination -- a cancelled run,
#                                     a pod deletion, a runner scale-down --
#                                     where everything in the pod is signalled.
#                                 Only the kernel's cgroup oom_kill counter
#                                 separates them, so the step samples it either
#                                 side of the scan and the battery below asserts
#                                 all three outcomes (rose / static / unreadable).
#                                 This matters because the advice differs: the
#                                 first is fixed by a larger runner class, the
#                                 second is made no better by one, and measured
#                                 peak RSS for this pinned binary is ~330 MiB
#                                 against a 1.5Gi smallest tier -- so "it OOMed"
#                                 must be evidenced, never assumed.
#
# A repo with no package manifests is the exit-0 case: grype writes a valid
# 358-byte SARIF with an empty `results` array. So the step must
#   (a) PASS a zero-finding scan and say what it actually examined -- a clean
#       verdict over 0 cataloged packages must not read like a clean verdict
#       over a real dependency tree,
#   (b) FAIL, loudly and without retrying, when no report was written at all --
#       a gate that did not run must never pass,
#   (c) never let grype's error code 1 masquerade as "vulnerabilities found", and
#   (d) attribute a signal kill to the cause the kernel actually witnessed.
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
failures=0
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

fail() {
	echo "FAIL: $*" >&2
	failures=$((failures + 1))
}

# Faithful stub. Writes exactly what the real binary writes in each mode --
# including creating an EMPTY report file on a fatal error, which is what the
# real grype does and what makes `test -s` the load-bearing check.
#
# It honours BOTH output spellings the real binary accepts: `-o sarif=PATH`
# (what the step uses now) and bare `-o sarif` to stdout (what it used before).
# That is deliberate -- it lets this battery be pointed at the pre-fix step to
# confirm the checks below actually fail against it, instead of passing because
# the stub quietly stopped matching.
cat >"$tmp/grype" <<'STUB'
#!/usr/bin/env bash
sarif_path="/dev/stdout"
sbom_path="$(mktemp)"
prev=""
for arg in "$@"; do
	if [[ "$prev" == "-o" ]]; then
		case "$arg" in
		sarif=*) sarif_path="${arg#sarif=}" ;;
		cyclonedx-json=*) sbom_path="${arg#cyclonedx-json=}" ;;
		esac
	fi
	prev="$arg"
done

# Every real invocation emits this benign line first; the kill case is defined by
# there being nothing AFTER it.
echo '[0000]  WARN no explicit name and version provided for directory source, deriving artifact ID from the given path (which is not ideal) from=syft' >&2

sbom() { # $1 = component count
	local n=$1 comps=""
	for ((i = 0; i < n; i++)); do
		[[ -n "$comps" ]] && comps+=","
		comps+="{\"type\":\"library\",\"name\":\"pkg$i\",\"version\":\"1.0.0\"}"
	done
	echo "{\"bomFormat\":\"CycloneDX\",\"components\":[$comps]}" >"$sbom_path"
}

sarif() { # $1 = result count
	local n=$1 results=""
	for ((i = 0; i < n; i++)); do
		[[ -n "$results" ]] && results+=","
		results+="{\"ruleId\":\"CVE-0000-$i\"}"
	done
	echo "{\"version\":\"2.1.0\",\"runs\":[{\"tool\":{},\"results\":[$results]}]}" >"$sarif_path"
}

case "${STUB_MODE}" in
clean-no-manifests) # YAML-only repo: valid report, zero packages, exit 0
	sarif 0
	sbom 0
	exit 0
	;;
clean-with-packages)
	sarif 0
	sbom 3
	exit 0
	;;
findings)
	sarif 2
	sbom 3
	echo '[0001] ERROR discovered vulnerabilities at or above the severity threshold' >&2
	exit 2
	;;
exec-error) # bad config / unresolvable path: empty report, ERROR on stderr
	: >"$sarif_path"
	: >"$sbom_path"
	echo "[0001] ERROR failed to catalog: unable to get file resolver: invalid exclusion pattern(s)" >&2
	exit 1
	;;
killed-oom) # SIGKILL by the cgroup OOM killer: the kernel bumps oom_kill
	: >"$sarif_path"
	: >"$sbom_path"
	printf 'low 0\nhigh 0\nmax 11\noom 1\noom_kill 1\n' >"${CGROUP_ROOT}/memory.events"
	exit 137
	;;
killed-external) # SIGKILL from OUTSIDE the cgroup (pod deletion, scale-down,
	# cancellation): same 137, same empty report, but oom_kill does NOT move.
	: >"$sarif_path"
	: >"$sbom_path"
	exit 137
	;;
killed) # SIGKILL on a runner that exposes no cgroup oom_kill counter at all
	: >"$sarif_path"
	: >"$sbom_path"
	exit 137
	;;
corrupt) # report written but truncated/garbage
	echo 'not json at all' >"$sarif_path"
	sbom 3
	exit 0
	;;
empty-but-clean-exit) # pathological: no report yet a success code
	: >"$sarif_path"
	: >"$sbom_path"
	exit 0
	;;
unknown-code) # a grype contract change we must not paper over
	sarif 0
	sbom 3
	exit 7
	;;
esac
echo "stub: unhandled STUB_MODE '${STUB_MODE}'" >&2
exit 99
STUB
chmod +x "$tmp/grype"

extract_step() { # $1 = workflow path, $2 = job key, $3 = destination
	python3 - "$1" "$2" "$3" <<'PY'
import pathlib
import sys

import yaml

doc = yaml.safe_load(pathlib.Path(sys.argv[1]).read_text())
for step in doc["jobs"][sys.argv[2]]["steps"]:
    if step.get("name") == "Run Grype (filesystem)":
        if "continue-on-error" in step:
            print("the grype step must not use continue-on-error", file=sys.stderr)
            sys.exit(1)
        pathlib.Path(sys.argv[3]).write_text("#!/usr/bin/env bash\n" + step["run"])
        sys.exit(0)
print("could not find the 'Run Grype (filesystem)' step", file=sys.stderr)
sys.exit(1)
PY
}

# A cgroup-v2 memory controller as the kernel presents it inside a pod, with
# the fleet's smallest tier's ceiling. Rebuilt per case so a mode that bumps
# oom_kill cannot leak into the next assertion.
#
# $1 = destination dir. Pass a path that does NOT exist to model a runner whose
# cgroup files are unreadable -- "unknown", which the step must not round down
# to "no OOM happened".
make_cgroup_fixture() {
	rm -rf "$1"
	mkdir -p "$1"
	printf 'low 0\nhigh 0\nmax 0\noom 0\noom_kill 0\n' >"$1/memory.events"
	printf '1610612736\n' >"$1/memory.max" # 1.5Gi, the `light` tier
}

# $1 = step script, $2 = STUB_MODE, $3 = fail-on-vuln,
# $4 = CGROUP_ROOT (optional; default a fresh readable fixture)
run_case() {
	local step=$1 mode=$2 fov=$3 cgroup=${4:-}
	local work="$tmp/work"
	rm -rf "$work"
	mkdir -p "$work"
	: >"$tmp/gh_output"
	if [[ -z "$cgroup" ]]; then
		cgroup="$tmp/cgroup"
		make_cgroup_fixture "$cgroup"
	fi
	# A DB cache the step can size, so the disclosure line is deterministic
	# rather than dependent on whatever is in the dev box's real HOME.
	rm -rf "$tmp/grypedb"
	mkdir -p "$tmp/grypedb/6"
	head -c $((7 * 1024 * 1024)) /dev/zero >"$tmp/grypedb/6/vulnerability.db"
	(
		cd "$work" && PATH="$tmp:$PATH" \
			GITHUB_OUTPUT="$tmp/gh_output" GITHUB_WORKSPACE="$work" \
			SCAN_PATH="." SEVERITY="high" FAIL_ON_VULN="$fov" \
			STUB_MODE="$mode" CGROUP_ROOT="$cgroup" \
			GRYPE_DB_CACHE_DIR="$tmp/grypedb" \
			bash "$step"
	) >"$tmp/out" 2>&1
}

out_has() { grep -qF "$1" "$tmp/out"; }

# Shared battery: every assertion below must hold for BOTH workflows. The only
# intended difference is who decides on findings -- the bundle defers to its
# aggregate step, the standalone honours fail-on-vuln itself -- so findings are
# asserted separately per workflow afterwards.
check_common() { # $1 = label, $2 = step script
	local label=$1 step=$2

	# 1. A manifest-free repo PASSES, and says that nothing was there to scan.
	#    This is the whole defect: it used to error, retry 3x, and get evicted.
	if run_case "$step" clean-no-manifests false; then
		out_has "no package manifests found" ||
			fail "$label: a zero-package scan should name that explicitly; got: $(cat "$tmp/out")"
		grep -q '^packages=0$' "$tmp/gh_output" ||
			fail "$label: should report packages=0; got: $(cat "$tmp/gh_output")"
	else
		fail "$label: a zero-package scan must PASS (grype ran fine and found nothing); got: $(cat "$tmp/out")"
	fi

	# 2. A clean scan over a real tree PASSES and reports what it examined, so a
	#    green gate is distinguishable from a gate that checked nothing.
	if run_case "$step" clean-with-packages false; then
		out_has "3 package(s) cataloged" ||
			fail "$label: a clean scan should report the package count; got: $(cat "$tmp/out")"
		out_has "no package manifests found" &&
			fail "$label: must not claim 'no manifests' when 3 packages were cataloged"
	else
		fail "$label: a clean scan over 3 packages must PASS; got: $(cat "$tmp/out")"
	fi

	# 3. No report at all => the scan did NOT run => must fail, never pass.
	if run_case "$step" exec-error false; then
		fail "$label: a scanner that wrote no report must FAIL, not pass as zero findings"
	else
		out_has "failed to run (exit 1)" ||
			fail "$label: an execution failure should say so; got: $(cat "$tmp/out")"
		out_has "invalid exclusion pattern" ||
			fail "$label: should surface grype's own ERROR line; got: $(cat "$tmp/out")"
		grep -qiE 'vulnerability|vulnerabilities' "$tmp/out" &&
			fail "$label: an execution error must not be reported as a vulnerability verdict"
	fi

	# 4a. A genuine cgroup OOM kill: the kernel's oom_kill counter rose. THIS is
	#     the capacity case, and the only one where a larger runner is the fix,
	#     so the message must name both the evidence and the exact label to move
	#     to -- "a larger runner class" with no label is advice nobody can action.
	if run_case "$step" killed-oom false; then
		fail "$label: an OOM-killed scanner must FAIL -- the scan did not run"
	else
		out_has "killed by signal 9" ||
			fail "$label: should name the signal; got: $(cat "$tmp/out")"
		out_has "oom_kill counter rose" ||
			fail "$label: should cite the kernel counter as the evidence; got: $(cat "$tmp/out")"
		out_has "heavy" ||
			fail "$label: an OOM should name the runner label to move to; got: $(cat "$tmp/out")"
	fi

	# 4b. Same signal, same empty report, but the counter did NOT move: the
	#     scanner was killed from outside its own memory limit. Recommending a
	#     bigger runner here is wrong -- it spends fleet capacity on a queue or
	#     lifecycle problem and leaves the real cause unexamined.
	if run_case "$step" killed-external false; then
		fail "$label: an externally killed scanner must FAIL -- the scan did not run"
	else
		out_has "killed by signal 9" ||
			fail "$label: should name the signal; got: $(cat "$tmp/out")"
		out_has "did NOT move" ||
			fail "$label: should say the OOM counter stayed put; got: $(cat "$tmp/out")"
		out_has "will NOT fix this" ||
			fail "$label: should say a bigger runner is not the fix; got: $(cat "$tmp/out")"
		grep -qF "local\",\"heavy" "$tmp/out" &&
			fail "$label: must not recommend a larger runner class for a non-OOM kill"
	fi

	# 4c. A runner that exposes no cgroup counter at all: the step must say the
	#     two causes are indistinguishable rather than pick the flattering one.
	#     An absent fixture is "unknown", and unknown must not read as "no OOM".
	if run_case "$step" killed false "$tmp/no-such-cgroup"; then
		fail "$label: a killed scanner must FAIL even when the cause is unknowable"
	else
		out_has "killed by signal 9" ||
			fail "$label: should name the signal; got: $(cat "$tmp/out")"
		out_has "cannot be told apart" ||
			fail "$label: should admit the cause is undetermined; got: $(cat "$tmp/out")"
		grep -qF "local\",\"heavy" "$tmp/out" &&
			fail "$label: must not recommend a larger runner class on an unevidenced kill"
	fi

	# 5. A report that is not valid JSON is a failed scan, not zero findings.
	if run_case "$step" corrupt false; then
		fail "$label: a report that is not valid JSON must FAIL"
	else
		out_has "not valid JSON" ||
			fail "$label: should name the parse failure; got: $(cat "$tmp/out")"
	fi

	# 6. Success code with no report is still a gate that did not run.
	if run_case "$step" empty-but-clean-exit false; then
		fail "$label: no report must fail even when grype exits 0"
	fi

	# 7. An exit code outside grype's documented set must not be silently
	#    treated as clean just because a report happens to exist.
	if run_case "$step" unknown-code false; then
		fail "$label: an undocumented grype exit code must not pass silently"
	else
		out_has "neither 'clean' (0) nor 'findings' (2)" ||
			fail "$label: should name the unexpected exit code; got: $(cat "$tmp/out")"
	fi

	# 8. The retry loop is gone. Retrying could not fix any case above (all are
	#    deterministic or fatal); it only kept a dying job on the runner, which
	#    is what turned a diagnosable failure into "received a shutdown signal".
	grep -qE 'max_attempts|retrying after backoff' "$step" &&
		fail "$label: the deterministic-failure retry loop must not come back"
	grep -qE '^[[:space:]]*sleep ' "$step" &&
		fail "$label: no backoff sleep belongs in this step"

	# 9. The step states the size of the vulnerability DB it matched against.
	#    A ~3 GiB DB re-fetched per job is where a multi-minute "scan" of a
	#    sub-megabyte tree actually goes, and the fleet cannot reason about that
	#    from a log that only reports findings. Disclosure, not scope reduction:
	#    assertions 1-2 above still require the full package census.
	if run_case "$step" clean-with-packages false; then
		out_has "MiB vulnerability DB" ||
			fail "$label: should state the DB size it matched against; got: $(cat "$tmp/out")"
		out_has "7 MiB vulnerability DB" ||
			fail "$label: the DB size must be measured, not hardcoded; got: $(cat "$tmp/out")"
	else
		fail "$label: a clean scan over 3 packages must PASS; got: $(cat "$tmp/out")"
	fi
	return 0
}

bundle="$repo_root/.github/workflows/general-security-fs.yml"
standalone="$repo_root/.github/workflows/general-scan-grype-fs.yml"

extract_step "$bundle" security-fs "$tmp/bundle-step.sh" || exit 1
extract_step "$standalone" grype "$tmp/standalone-step.sh" || exit 1

check_common "security-fs bundle" "$tmp/bundle-step.sh"
check_common "scan-grype-fs" "$tmp/standalone-step.sh"

# --- findings: the two workflows own this decision differently ---------------

# Bundle: the step records the verdict and the aggregate step decides, so the
# step itself must stay green even with findings.
if run_case "$tmp/bundle-step.sh" findings false; then
	grep -q '^exit-code=2$' "$tmp/gh_output" ||
		fail "bundle: must publish exit-code=2 for the aggregate step; got: $(cat "$tmp/gh_output")"
	grep -q '^findings=2$' "$tmp/gh_output" ||
		fail "bundle: must publish the findings count; got: $(cat "$tmp/gh_output")"
else
	fail "bundle: the grype step must not fail on findings -- its aggregate step decides"
fi

# Standalone: honours fail-on-vuln itself, in both directions.
if run_case "$tmp/standalone-step.sh" findings false; then
	out_has "fail-on-vuln=false" ||
		fail "standalone: should say why findings did not fail the job; got: $(cat "$tmp/out")"
else
	fail "standalone: findings with fail-on-vuln=false must not fail the job"
fi
if run_case "$tmp/standalone-step.sh" findings true; then
	fail "standalone: findings with fail-on-vuln=true must fail the job"
else
	out_has "Grype found 2 vulnerability finding(s)" ||
		fail "standalone: should name the finding count when failing; got: $(cat "$tmp/out")"
fi

# --- caller contract ---------------------------------------------------------
# ~90 repos pin this library by SHA. An input added without a default, or a
# callee permission the caller does not already grant, is a startup failure with
# zero jobs and no log -- so assert the fix introduced neither.
python3 - "$bundle" "$standalone" <<'PY' || exit 1
import pathlib
import sys

import yaml

for path in sys.argv[1:]:
    doc = yaml.safe_load(pathlib.Path(path).read_text())
    call = (doc.get(True) or doc.get("on"))["workflow_call"]
    for name, spec in (call.get("inputs") or {}).items():
        if spec.get("required") or "default" not in spec:
            print(
                f"FAIL: {path}: input '{name}' must be optional with a default; "
                "a required input breaks every already-pinned caller at startup",
                file=sys.stderr,
            )
            sys.exit(1)
    for job in doc["jobs"].values():
        extra = set(job.get("permissions") or {}) - {
            "contents",
            "actions",
            "security-events",
        }
        if extra:
            print(
                f"FAIL: {path}: job requests permissions {sorted(extra)} that "
                "existing callers do not grant",
                file=sys.stderr,
            )
            sys.exit(1)
PY

if ((failures > 0)); then
	echo "$failures check(s) failed" >&2
	exit 1
fi
echo "grype scan-verdict checks passed"
