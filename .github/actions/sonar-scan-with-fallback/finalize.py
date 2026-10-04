#!/usr/bin/env python3
"""Decide the overall outcome of a sonar-scan-with-fallback run.

Pure function, no I/O — takes the outcome of each scan step (GitHub Actions'
`steps.<id>.outcome`, one of "success"/"failure"/"skipped"/"cancelled", or ""
when the step never ran at all because an earlier `if:` excluded it) and
decides:

  * host-used: "sonarcloud" | "local" | "none" — which server, if either,
    actually produced a scan.
  * used-fallback: "true" only when SonarCloud was attempted AND failed AND
    local rescued it. A private repo routing straight to local (SonarCloud
    was never attempted — `is_local` was already "true" before any scan ran)
    is normal, by-design routing, not a fallback, and must NOT trigger the
    once-a-day "SonarCloud isn't the one running" notification — that
    notification exists for the SILENT case where a PR looks green but the
    org-wide LOC quota (or similar outage) quietly took SonarCloud itself
    out of the loop.
  * ok: whether the caller's job should be treated as a successful scan.
    False means neither target produced a scan — the composite step this
    runs in exits non-zero, so the job fails exactly as it would have before
    this fallback existed (no silent masking of a real failure).

dry-run short-circuits to "what the routing WOULD do", without having run
any scan — used only by this repo's own self-test (ci.yml), which has no
real SONAR_TOKEN or cluster to scan against.
"""
from __future__ import annotations

import argparse
import sys


def decide(
    is_local: str,
    primary_outcome: str,
    local_scan_outcome: str,
    dry_run: bool,
) -> dict[str, str]:
    if dry_run:
        return {
            "host-used": "local" if is_local == "true" else "sonarcloud",
            "used-fallback": "false",
            "ok": "true",
        }

    if is_local == "true":
        # By-design private-repo routing: SonarCloud was never attempted.
        ok = local_scan_outcome == "success"
        return {"host-used": "local" if ok else "none", "used-fallback": "false", "ok": str(ok).lower()}

    if primary_outcome == "success":
        return {"host-used": "sonarcloud", "used-fallback": "false", "ok": "true"}

    # SonarCloud was attempted and did not succeed — only now is a local
    # scan "fallback" rather than plain routing.
    if local_scan_outcome == "success":
        return {"host-used": "local", "used-fallback": "true", "ok": "true"}

    return {"host-used": "none", "used-fallback": "false", "ok": "false"}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--is-local", required=True)
    parser.add_argument("--primary-outcome", default="")
    parser.add_argument("--local-scan-outcome", default="")
    parser.add_argument("--dry-run", default="false")
    args = parser.parse_args()

    result = decide(
        is_local=args.is_local,
        primary_outcome=args.primary_outcome,
        local_scan_outcome=args.local_scan_outcome,
        dry_run=args.dry_run == "true",
    )
    for key, value in result.items():
        if key != "ok":
            print(f"{key}={value}")

    if result["ok"] != "true":
        print(
            "::error::sonar-scan-with-fallback: neither SonarCloud nor the "
            "local SonarQube produced a successful scan",
            file=sys.stderr,
        )
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
