"""Unit tests for stale lockfile scenario (service1 / /service1 endpoint)."""
from __future__ import annotations

import os
import sys
import unittest
from pathlib import Path

# Allow importing target_service.app without a Docker container
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "target_service"))

import app as service_app  # noqa: E402

LOCKFILE = service_app.LOCKFILE


class StaleLockfileUnitTests(unittest.TestCase):
    def setUp(self) -> None:
        """Use Flask test client; ensure lockfile is absent before each test."""
        self.client = service_app.app.test_client()
        self._remove_lockfile()

    def tearDown(self) -> None:
        self._remove_lockfile()

    # ------------------------------------------------------------------
    # helpers
    # ------------------------------------------------------------------

    def _remove_lockfile(self) -> None:
        try:
            os.remove(LOCKFILE)
        except FileNotFoundError:
            pass

    def _create_lockfile(self) -> None:
        Path(LOCKFILE).touch()

    # ------------------------------------------------------------------
    # tests
    # ------------------------------------------------------------------

    def test_service1_returns_200_when_no_lockfile(self) -> None:
        """Without a lockfile, /service1 must be healthy (HTTP 200)."""
        resp = self.client.get("/service1", headers={"Accept": "application/json"})
        self.assertEqual(resp.status_code, 200)
        data = resp.get_json()
        self.assertEqual(data["status"], "ok")

    def test_service1_returns_500_when_lockfile_present(self) -> None:
        """With a stale lockfile, /service1 must return HTTP 500."""
        self._create_lockfile()
        resp = self.client.get("/service1", headers={"Accept": "application/json"})
        self.assertEqual(resp.status_code, 500)
        data = resp.get_json()
        self.assertEqual(data["status"], "error")
        self.assertIn("stale lockfile", data["reason"])

    def test_service1_recovers_after_lockfile_removal(self) -> None:
        """After removing the lockfile, /service1 must recover to HTTP 200."""
        self._create_lockfile()
        broken = self.client.get("/service1", headers={"Accept": "application/json"})
        self.assertEqual(broken.status_code, 500)

        self._remove_lockfile()

        fixed = self.client.get("/service1", headers={"Accept": "application/json"})
        self.assertEqual(fixed.status_code, 200)
        data = fixed.get_json()
        self.assertEqual(data["status"], "ok")


if __name__ == "__main__":
    unittest.main()
