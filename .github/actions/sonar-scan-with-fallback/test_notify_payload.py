#!/usr/bin/env python3
import unittest

import notify_payload as np_


class TestNotifyPayload(unittest.TestCase):
    def test_shape(self):
        payload = np_.build("FelipeFuhr/ffreis-job-arbiter", "https://x/runs/1", "local")
        self.assertEqual(payload["mode"], "ci_notify")
        self.assertIn("FelipeFuhr/ffreis-job-arbiter", payload["detail"])
        self.assertIn("https://x/runs/1", payload["detail"])


if __name__ == "__main__":
    unittest.main()
