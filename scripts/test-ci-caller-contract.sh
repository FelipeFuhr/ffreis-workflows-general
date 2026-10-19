#!/usr/bin/env bash
# Self-check for ci.yml's contract with every reusable workflow it calls.
#
# Why this exists as its own gate: a broken caller contract produces
# `startup_failure` — zero jobs, no log, and `gh pr checks` reports it as
# perpetual PENDING rather than red. It is the one CI failure mode that is
# invisible from inside CI, so it has to be caught before the push. This repo
# has hit it at least three separate times (#77 a secret referenced by the wrong
# name, #79 a caller-count theory that turned out to be wrong, #82 a missing
# `id-token: write` on the scorecard caller) and each time it was diagnosed only
# after a red-or-pending PR.
#
# `general-workflows-policy.yml` already covers the OTHER startup-failure causes
# (SHA pinning, `secrets: inherit`, `@main` refs, draft gating) and runs as a
# ci.yml job, so none of that is repeated here. What it does NOT look at, and
# what this adds, is whether a caller job and its callee actually agree:
#
#   1. every input a caller passes is DECLARED by the callee
#   2. every input the callee REQUIRES without a default is passed
#   3. the caller's `permissions` is a SUPERSET of the callee's
#   4. every secret the callee requires is passed
#
# Scope is ci.yml's own caller jobs: it holds every reusable-workflow caller in
# this repo that a PR can exercise, and it is the file most often edited. A
# `self-test-<thing>.yml` file that grows its own `uses:` caller job (see
# AGENTS.md rule 10) is picked up automatically: the scan is over every
# live-triggered workflow in this repo, not a hardcoded ci.yml, so a second
# orchestrator cannot quietly escape the contract.
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

python3 - "$repo_root" <<'PY'
import pathlib
import sys

import yaml

root = pathlib.Path(sys.argv[1])
workflows = root / ".github/workflows"

# A caller granting MORE than the callee needs is fine; granting less is the
# startup failure. "absent" and "none" are the same thing to GitHub.
RANK = {"none": 0, "read": 1, "write": 2}
# Triggers that mean "a PR or a push can actually start this".
LIVE = ("pull_request", "pull_request_target", "push", "schedule", "workflow_dispatch")


def rank(value):
	return RANK.get(str(value), 0)


def trigger_block(doc):
	# PyYAML resolves a bare `on:` key to the boolean True, so a workflow has to
	# be looked up under both spellings. Getting this wrong makes every check
	# below silently vacuous, which is the failure mode this file is about.
	return doc.get(True) if True in doc else doc.get("on")


failures = []
checked = 0
orchestrators = []

for path in sorted(workflows.glob("*.yml")):
	doc = yaml.safe_load(path.read_text())
	if not isinstance(doc, dict):
		failures.append(f"{path.name}: does not parse as a mapping")
		continue
	on = trigger_block(doc) or {}
	if not isinstance(on, dict) or not any(t in on for t in LIVE):
		continue  # workflow_call-only: nothing here can start it, see AGENTS.md rule 10
	orchestrators.append(path.name)

	pr = on.get("pull_request") or on.get("pull_request_target") or {}
	if isinstance(pr, dict) and "pull_request" in on:
		if "ready_for_review" not in (pr.get("types") or []):
			failures.append(
				f"{path.name}: on.pull_request.types must include ready_for_review, or a "
				"draft-gated job stays unrun and reports green at promotion"
			)

	for job_id, job in (doc.get("jobs") or {}).items():
		if not isinstance(job, dict):
			continue
		uses = str(job.get("uses") or "")
		if not uses.startswith("./.github/workflows/"):
			continue
		callee_path = root / uses[2:]
		name = f"{path.name}::{job_id} -> {callee_path.name}"
		if not callee_path.is_file():
			failures.append(f"{name}: calls {uses}, which does not exist")
			continue
		callee = yaml.safe_load(callee_path.read_text())
		call = (trigger_block(callee) or {}).get("workflow_call")
		if call is None:
			failures.append(f"{name}: callee has no workflow_call trigger, so it cannot be called")
			continue
		checked += 1

		declared = dict(call.get("inputs") or {})
		passed = dict(job.get("with") or {})

		for key in sorted(set(passed) - set(declared)):
			failures.append(f"{name}: passes undeclared input '{key}' (startup_failure, zero jobs)")
		for key, spec in sorted(declared.items()):
			if spec.get("required") and "default" not in spec and key not in passed:
				failures.append(f"{name}: callee requires input '{key}' and it is not passed")

		# Collapse the callee's per-job grants into the single strongest ask,
		# which is what the caller has to cover.
		needed = {}
		for callee_job in (callee.get("jobs") or {}).values():
			for key, value in (callee_job.get("permissions") or {}).items():
				if rank(value) > rank(needed.get(key)):
					needed[key] = value
		# GitHub's resolution order, which this has to model exactly or it fires
		# on correct callers: a job's own `permissions:` wins; with none, the job
		# inherits the WORKFLOW-level block. `lefthook-complex.yml` is the live
		# example — top-level `contents: read`, no per-job block, and perfectly
		# valid. Treat absent-everywhere as nothing granted: every workflow here
		# declares a top-level block, so there is no case where the repo default
		# would silently apply.
		granted = job.get("permissions")
		if granted is None:
			granted = doc.get("permissions")
		granted = granted or {}
		if not isinstance(granted, dict):
			# `permissions: read-all` / `write-all` are scalars that grant every
			# scope; nothing to check.
			granted = None
		if granted is not None:
			for key, value in sorted(needed.items()):
				if rank(value) > rank(granted.get(key)):
					failures.append(
						f"{name}: callee needs permissions.{key}: {value} but the caller grants "
						f"{granted.get(key, 'nothing')}"
					)

		for key, spec in sorted((call.get("secrets") or {}).items()):
			if spec.get("required") and key not in (job.get("secrets") or {}):
				failures.append(f"{name}: callee requires secret '{key}' and it is not passed")

if not checked:
	# An empty pass is not a pass. If the parse shape or the file layout ever
	# changes, this gate must go red rather than report success over nothing.
	failures.append("found no reusable-workflow caller jobs in any live-triggered workflow")

for line in failures:
	print(f"FAIL: {line}", file=sys.stderr)
if failures:
	print(f"{len(failures)} caller-contract violation(s)", file=sys.stderr)
	sys.exit(1)
print(
	f"caller-contract checks passed ({checked} caller job(s) across "
	f"{len(orchestrators)} live-triggered workflow(s): {', '.join(orchestrators)})"
)
PY
