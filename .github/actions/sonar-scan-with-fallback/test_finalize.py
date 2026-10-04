#!/usr/bin/env python3
"""Unit tests for finalize's outcome decision.

The case this exists to get right: `used-fallback` must distinguish
"SonarCloud failed and local rescued it" (notify-worthy — a silent-looking
green PR that actually skipped the org's default scanner) from "this is a
private repo, SonarCloud was never attempted" (normal, silent, not
notify-worthy — the same routing tf-sonar.yml has always done).
"""

import unittest

import finalize as fz


class TestFinalize(unittest.TestCase):
    def test_public_success_is_not_a_fallback(self):
        r = fz.decide(is_local="false", primary_outcome="success", local_scan_outcome="", dry_run=False)
        self.assertEqual(r, {"host-used": "sonarcloud", "used-fallback": "false", "ok": "true"})

    def test_public_failure_rescued_locally_is_a_fallback(self):
        r = fz.decide(is_local="false", primary_outcome="failure", local_scan_outcome="success", dry_run=False)
        self.assertEqual(r, {"host-used": "local", "used-fallback": "true", "ok": "true"})

    def test_public_failure_with_no_local_rescue_fails_closed(self):
        r = fz.decide(is_local="false", primary_outcome="failure", local_scan_outcome="failure", dry_run=False)
        self.assertEqual(r, {"host-used": "none", "used-fallback": "false", "ok": "false"})

    def test_private_routing_is_not_a_fallback_even_though_its_local(self):
        r = fz.decide(is_local="true", primary_outcome="", local_scan_outcome="success", dry_run=False)
        self.assertEqual(r, {"host-used": "local", "used-fallback": "false", "ok": "true"})

    def test_private_scan_failure_fails_closed(self):
        r = fz.decide(is_local="true", primary_outcome="", local_scan_outcome="failure", dry_run=False)
        self.assertEqual(r, {"host-used": "none", "used-fallback": "false", "ok": "false"})

    def test_dry_run_never_reports_a_fallback_regardless_of_routing(self):
        self.assertEqual(
            fz.decide(is_local="true", primary_outcome="", local_scan_outcome="", dry_run=True)["used-fallback"],
            "false",
        )
        self.assertEqual(
            fz.decide(is_local="false", primary_outcome="", local_scan_outcome="", dry_run=True)["host-used"],
            "sonarcloud",
        )

    def test_main_exits_nonzero_when_not_ok(self):
        import io
        import sys
        from unittest.mock import patch

        argv = ["finalize.py", "--is-local", "false", "--primary-outcome", "failure", "--local-scan-outcome", "failure"]
        with patch.object(sys, "argv", argv), patch("sys.stderr", new=io.StringIO()):
            self.assertEqual(fz.main(), 1)

    def test_main_exits_zero_when_ok(self):
        import sys
        from unittest.mock import patch

        argv = ["finalize.py", "--is-local", "false", "--primary-outcome", "success"]
        with patch.object(sys, "argv", argv):
            self.assertEqual(fz.main(), 0)


if __name__ == "__main__":
    unittest.main()
