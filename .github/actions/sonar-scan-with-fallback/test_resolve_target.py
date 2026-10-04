#!/usr/bin/env python3
"""Unit tests for resolve_target's routing decision.

Guards two things: a public repo must keep going to sonarcloud.io (the org's
SONAR_TOKEN quota is specific to that path), and anything else (private —
the only other value GitHub ever reports for `repository.visibility`) must
never be sent to sonarcloud.io, since that call always 403s there.
"""

import unittest

import resolve_target as rt


class TestResolveTarget(unittest.TestCase):
    def test_public_targets_sonarcloud(self):
        self.assertEqual(
            rt.resolve("public"),
            {"host_url": "https://sonarcloud.io", "is_local": "false"},
        )

    def test_private_targets_local(self):
        self.assertEqual(
            rt.resolve("private"),
            {"host_url": "http://sonarqube.ci.svc.cluster.local:9000", "is_local": "true"},
        )

    def test_unexpected_value_defaults_to_local_not_sonarcloud(self):
        # Fail closed: an unrecognized value must never fall through to the
        # quota-metered sonarcloud.io path.
        self.assertEqual(rt.resolve("internal")["is_local"], "true")


if __name__ == "__main__":
    unittest.main()
