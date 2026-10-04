#!/usr/bin/env python3
"""Build the JSON payload for the fleet's monitor Lambda's `ci_notify` mode.

A separate script (rather than `python3 -c '...'` built from shell string
interpolation in action.yml) so the repo/run-url values — which come from
GitHub Actions context, not user input, but are still free text — go through
`json.dumps` rather than hand-built string concatenation, and so this has
its own unit test instead of being untestable inline YAML.
"""
from __future__ import annotations

import argparse
import json


def build(repo: str, run_url: str, host_used: str) -> dict[str, str]:
    return {
        "mode": "ci_notify",
        "detail": f"{repo} fell back to the local SonarQube server (host={host_used}): {run_url}",
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo", required=True)
    parser.add_argument("--run-url", required=True)
    parser.add_argument("--host-used", required=True)
    args = parser.parse_args()
    print(json.dumps(build(args.repo, args.run_url, args.host_used)))


if __name__ == "__main__":
    main()
