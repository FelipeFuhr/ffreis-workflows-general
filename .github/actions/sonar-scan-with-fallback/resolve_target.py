#!/usr/bin/env python3
"""Decide which SonarQube server a scan should target, before any scan runs.

Pure function, no I/O: SonarCloud's free tier only analyzes PUBLIC repos (a
private repo gets a 403 regardless of token validity), so a private repo
routes straight to the fleet's self-hosted SonarQube rather than attempting
sonarcloud.io at all. This mirrors tf-sonar.yml's pre-existing routing,
pulled out so every language's reusable workflow shares one copy instead of
re-deriving it.

CLI wrapper writes `$GITHUB_OUTPUT`-format `key=value` lines to stdout.
"""
from __future__ import annotations

import argparse

LOCAL_HOST_URL = "http://sonarqube.ci.svc.cluster.local:9000"
SONARCLOUD_HOST_URL = "https://sonarcloud.io"


def resolve(visibility: str) -> dict[str, str]:
    if visibility == "public":
        return {"host_url": SONARCLOUD_HOST_URL, "is_local": "false"}
    return {"host_url": LOCAL_HOST_URL, "is_local": "true"}


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--visibility", required=True)
    args = parser.parse_args()
    for key, value in resolve(args.visibility).items():
        print(f"{key}={value}")


if __name__ == "__main__":
    main()
