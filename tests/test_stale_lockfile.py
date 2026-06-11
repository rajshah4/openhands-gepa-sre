"""Unit tests for the stale lockfile scenario (issue #166).

These tests verify that service1 returns HTTP 500 when a stale lockfile is
present and HTTP 200 after the lockfile is removed — without requiring Docker.
"""
from __future__ import annotations

import sys
import tempfile
from pathlib import Path

import pytest

# Make the target_service package importable
TARGET_SERVICE_DIR = Path(__file__).resolve().parents[1] / "target_service"
sys.path.insert(0, str(TARGET_SERVICE_DIR))

import app as service_app  # noqa: E402


@pytest.fixture()
def client(tmp_path, monkeypatch):
    """Flask test client with LOCKFILE redirected to a temp directory."""
    lock = str(tmp_path / "service.lock")
    monkeypatch.setattr(service_app, "LOCKFILE", lock)
    service_app.app.config["TESTING"] = True
    with service_app.app.test_client() as c:
        yield c, lock


def test_service1_returns_500_when_lockfile_present(client):
    """service1 must return 500 while the stale lockfile exists."""
    test_client, lock_path = client
    Path(lock_path).touch()

    response = test_client.get("/service1", headers={"User-Agent": "curl/7.x"})
    assert response.status_code == 500
    data = response.get_json()
    assert data["status"] == "error"
    assert "lockfile" in data["reason"]


def test_service1_returns_200_after_lockfile_removed(client):
    """service1 must return 200 once the stale lockfile has been removed."""
    test_client, lock_path = client
    # Simulate the fix: lockfile never created (or already removed)
    assert not Path(lock_path).exists()

    response = test_client.get("/service1", headers={"User-Agent": "curl/7.x"})
    assert response.status_code == 200
    data = response.get_json()
    assert data["status"] == "ok"


def test_service1_recovers_after_lockfile_deleted(client):
    """service1 recovers from 500 → 200 after the lockfile is deleted."""
    test_client, lock_path = client

    # Step 1: create lockfile → expect 500
    Path(lock_path).touch()
    before = test_client.get("/service1", headers={"User-Agent": "curl/7.x"})
    assert before.status_code == 500

    # Step 2: remove lockfile → expect 200
    Path(lock_path).unlink()
    after = test_client.get("/service1", headers={"User-Agent": "curl/7.x"})
    assert after.status_code == 200
    assert after.get_json()["status"] == "ok"
