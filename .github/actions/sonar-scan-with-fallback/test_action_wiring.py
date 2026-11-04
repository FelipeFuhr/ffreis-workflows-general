#!/usr/bin/env python3
"""Structural tests for action.yml's token wiring.

WHY THESE ARE STRUCTURAL AND NOT UNIT TESTS
-------------------------------------------
Which token the local scan presents is decided by a GitHub Actions
expression, not by Python, so there is no function to call. It is still worth
locking, because getting it wrong is SILENT in exactly the way that cost a
real outage: `resolve_target` correctly sends every private repo to the
self-hosted server, the step then presented the SonarCloud SONAR_TOKEN, and
the scanner answered

    HTTP 401 Unauthorized. Please check the property sonar.token
    or the environment variable SONAR_TOKEN.

which reads as a bad secret rather than as "wrong server entirely". Every
private repo's sonar gate was permanently red with correct routing and a
valid token (measured 2026-11-04, ffreis-urbs-infra PR #10).

test_resolve_target.py already guards the routing half. This guards the
credential half, which is the part that has no other test.
"""

import pathlib
import unittest

import yaml

ACTION = pathlib.Path(__file__).with_name("action.yml")
LOCAL_SCAN = "SonarQube scan (local)"
WARN_STEP = "Warn when the local scan has no dedicated token"
LOCAL_HOST = "http://sonarqube.ci.svc.cluster.local:9000"


def load_steps():
    with ACTION.open(encoding="utf-8") as handle:
        return yaml.safe_load(handle)


class TestLocalTokenWiring(unittest.TestCase):
    def setUp(self):
        self.action = load_steps()
        self.steps = self.action["runs"]["steps"]
        self.by_name = {s.get("name"): s for s in self.steps}

    def test_local_token_input_is_optional(self):
        # Optional is the whole backward-compatibility story: a caller that
        # upgrades this action without setting the new input must behave
        # exactly as before, not fail to start.
        spec = self.action["inputs"]["local-sonar-token"]
        self.assertFalse(spec.get("required", False))
        self.assertEqual(spec.get("default"), "")

    def test_local_scan_prefers_the_local_token_and_falls_back(self):
        step = self.by_name[LOCAL_SCAN]
        token_expr = step["env"]["SONAR_TOKEN"]
        # Both halves asserted: preferring the local token is the fix, and
        # keeping the fallback is what stops the upgrade breaking anyone.
        self.assertIn("inputs.local-sonar-token", token_expr)
        self.assertIn("inputs.sonar-token", token_expr)
        self.assertIn("!= ''", token_expr)

    def test_the_cloud_scan_still_uses_the_cloud_token_only(self):
        # The converse mistake would be just as bad and is not otherwise
        # caught: sending a self-hosted token to sonarcloud.io.
        step = self.by_name["SonarCloud scan"]
        self.assertEqual(step["env"]["SONAR_TOKEN"], "${{ inputs.sonar-token }}")

    def test_local_scan_still_targets_the_in_cluster_service(self):
        self.assertEqual(self.by_name[LOCAL_SCAN]["env"]["SONAR_HOST_URL"], LOCAL_HOST)

    def test_the_warning_precedes_the_local_scan(self):
        # Ordering is the point: a warning emitted after the scan is read
        # only by someone already debugging the failure, which is precisely
        # who did not need it.
        names = [s.get("name") for s in self.steps]
        self.assertLess(names.index(WARN_STEP), names.index(LOCAL_SCAN))

    def test_the_warning_fires_only_when_the_token_is_missing(self):
        condition = self.by_name[WARN_STEP]["if"]
        self.assertIn("inputs.local-sonar-token == ''", condition)
        # And only when a local scan is actually about to happen — warning on
        # every public-repo run would train people to ignore it.
        self.assertIn("steps.scale-local.outcome == 'success'", condition)

    def test_the_warning_names_the_fix_not_just_the_symptom(self):
        body = self.by_name[WARN_STEP]["run"]
        self.assertIn("::warning", body)
        self.assertIn("local-sonar-token", body)
        self.assertIn("401", body)


if __name__ == "__main__":
    unittest.main()
