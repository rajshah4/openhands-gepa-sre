"""Tests for the adoptable pet catalog.

Regression coverage for KAN-21: a pending pet (Nova) must never appear in the
available/adoptable catalog. The log clue PENDING_PET_VISIBLE indicated that
non-available pets were leaking into the customer-facing list.
"""

from __future__ import annotations

import unittest

from target_service.app import ADOPTED, AVAILABLE, PENDING, PETS, app, available_pets


class AvailablePetsTests(unittest.TestCase):
    def test_only_available_pets_are_visible(self) -> None:
        visible = available_pets()
        for pet in visible:
            self.assertEqual(pet["status"], AVAILABLE)

    def test_pending_pet_nova_is_excluded(self) -> None:
        visible = available_pets()
        names = {p["name"] for p in visible}
        self.assertNotIn("Nova", names)
        # Sanity check: Nova exists in the source data and is pending.
        nova = next(p for p in PETS if p["name"] == "Nova")
        self.assertEqual(nova["status"], PENDING)

    def test_adopted_pet_is_excluded(self) -> None:
        visible = available_pets()
        names = {p["name"] for p in visible}
        self.assertNotIn("Bella", names)

    def test_available_pets_are_present(self) -> None:
        visible = available_pets()
        names = {p["name"] for p in visible}
        self.assertIn("Luna", names)
        self.assertIn("Milo", names)
        self.assertIn("Charlie", names)

    def test_no_pending_or_adopted_status_leaks(self) -> None:
        # Guard against any future pet being added with a non-available status
        # and silently appearing in the catalog.
        for pet in available_pets():
            self.assertNotIn(pet["status"], (PENDING, ADOPTED))


class PetsEndpointTests(unittest.TestCase):
    def setUp(self) -> None:
        app.config["TESTING"] = True
        self.client = app.test_client()

    def test_api_pets_excludes_nova(self) -> None:
        resp = self.client.get("/api/pets", headers={"Accept": "application/json"})
        self.assertEqual(resp.status_code, 200)
        body = resp.get_json()
        names = {p["name"] for p in body["pets"]}
        self.assertNotIn("Nova", names)
        self.assertNotIn("Bella", names)
        # count must match the visible list, not the full roster
        self.assertEqual(body["count"], len(available_pets()))

    def test_pets_html_excludes_nova(self) -> None:
        resp = self.client.get("/pets", headers={"Accept": "text/html"})
        self.assertEqual(resp.status_code, 200)
        self.assertNotIn("Nova", resp.get_data(as_text=True))
        self.assertNotIn("Bella", resp.get_data(as_text=True))
        self.assertIn("Luna", resp.get_data(as_text=True))


if __name__ == "__main__":
    unittest.main()
