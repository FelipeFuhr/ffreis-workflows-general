#!/usr/bin/env bash
# Self-check for the "Run OSSF Scorecard" step in general-scorecard.yml.
#
# Like test-select-shell-files.sh, this fills the gap left by having no unit-test
# harness: it extracts the step's `run:` block straight from the workflow and
# exercises it against a stubbed `scorecard` binary, so the assertions are made
# against the shipped copy rather than a transcription of it.
#
# What is worth locking here: scorecard aborts a private-repo scan with
# "Resource not accessible by integration" while still EXITING 0 and writing
# nothing to stdout. That combination reads like a workflow `permissions:` bug
# and has repeatedly been diagnosed as one -- it is not; no permissions block
# can grant it, only a PAT can. The step must therefore
#   (a) fail rather than pass an empty SARIF onward, and
#   (b) say specifically that a token is missing, but ONLY when that is
#       actually the cause -- never when a token was supplied, and never on a
#       public repo, where the diagnosis would send people down the wrong path.
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
workflow="$repo_root/.github/workflows/general-scorecard.yml"
failures=0
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

fail() {
	echo "FAIL: $*" >&2
	failures=$((failures + 1))
}

# Extract the step's run: block from the workflow itself -- never a copy.
python3 - "$workflow" "$tmp/step.sh" <<'PY'
import sys, yaml, pathlib
doc = yaml.safe_load(pathlib.Path(sys.argv[1]).read_text())
for step in doc["jobs"]["scorecard"]["steps"]:
    if step.get("name") == "Run OSSF Scorecard":
        pathlib.Path(sys.argv[2]).write_text("#!/usr/bin/env bash\n" + step["run"])
        sys.exit(0)
print("could not find the 'Run OSSF Scorecard' step", file=sys.stderr)
sys.exit(1)
PY

mkdir -p "$tmp/bin"
# Faithful stub. The real tool's failure mode is exit 0 + empty stdout + the
# reason on stderr; a stub that exited non-zero would be laxer than reality and
# would pass even if the step stopped checking the SARIF at all.
cat >"$tmp/bin/scorecard" <<'STUB'
#!/usr/bin/env bash
if [[ "${STUB_MODE}" == "graphql-denied" ]]; then
  echo "Skipping ${SCORECARD_REPO}: run: internal error: ListCommits:error during graphqlHandler.setup: internal error: githubv4.Query: Resource not accessible by integration" >&2
  exit 0
fi
echo '{"version":"2.1.0","runs":[]}'
STUB
chmod +x "$tmp/bin/scorecard"
touch "$tmp/.scorecard-policy.yml"

run_case() {
	local mode=$1 visibility=$2 have_token=$3
	( cd "$tmp" && PATH="$tmp/bin:$PATH" \
		GITHUB_WORKSPACE="$tmp" SCORECARD_REPO="owner/repo" ENABLE_SARIF=1 \
		GITHUB_AUTH_TOKEN=stub STUB_MODE="$mode" \
		REPO_VISIBILITY="$visibility" HAVE_SCORECARD_TOKEN="$have_token" \
		bash "$tmp/step.sh" ) >"$tmp/out" 2>&1
}

TOKEN_HINT="Scorecard needs a token on private repos"

# 1. A healthy scan passes.
if run_case ok private true; then :; else fail "valid SARIF should exit 0"; fi

# 2. Private + no token: must fail, and must name the cause.
if run_case graphql-denied private false; then
	fail "private repo with no token should exit non-zero, not pass an empty SARIF on"
else
	grep -q "$TOKEN_HINT" "$tmp/out" || fail "private+no-token should explain the missing token; got: $(cat "$tmp/out")"
fi

# 3. Private + token supplied: still fails, but the token is NOT the cause, so
#    claiming it would misdirect whoever reads the log.
if run_case graphql-denied private true; then
	fail "a failing scan should exit non-zero even when a token was supplied"
else
	! grep -q "$TOKEN_HINT" "$tmp/out" || fail "must not blame a missing token when one was supplied"
fi

# 4. Public repo: github.token is sufficient there, so the token hint would be
#    wrong regardless of what failed.
if run_case graphql-denied public false; then
	fail "a failing scan on a public repo should exit non-zero"
else
	! grep -q "$TOKEN_HINT" "$tmp/out" || fail "must not blame a missing token on a public repo"
fi

# 5. The step must actually consult the optional secret; a hardcoded
#    github.token is what broke every private repo in the first place.
# shellcheck disable=SC2016  # the ${{ }} is GitHub Actions syntax being matched
# literally in the workflow file; shell expansion here would defeat the check.
grep -q 'GITHUB_AUTH_TOKEN: ${{ secrets.SCORECARD_TOKEN || github.token }}' "$workflow" \
	|| fail "GITHUB_AUTH_TOKEN must prefer secrets.SCORECARD_TOKEN and fall back to github.token"

# 6. An undeclared secret is silently empty, so the passthrough above would be
#    inert without this declaration.
python3 - "$workflow" <<'PY' || exit 1
import sys, yaml, pathlib
doc = yaml.safe_load(pathlib.Path(sys.argv[1]).read_text())
call = (doc.get(True) or doc.get("on"))["workflow_call"]
if "SCORECARD_TOKEN" not in (call.get("secrets") or {}):
    print("FAIL: workflow_call must declare the SCORECARD_TOKEN secret", file=sys.stderr)
    sys.exit(1)
PY

if ((failures > 0)); then
	echo "$failures check(s) failed" >&2
	exit 1
fi
echo "scorecard token-gate checks passed"
