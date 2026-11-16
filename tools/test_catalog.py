"""Regression tests for the public catalog and preserved webinar scope."""
import hashlib
import json
import re
import unittest
from unittest.mock import patch

import build_catalog
import check_repo


class CatalogTests(unittest.TestCase):
    def test_all_labs_have_catalog_links(self):
        labs = build_catalog.discover()
        self.assertEqual(len(labs), 37)
        catalog = build_catalog.render()
        for lab in labs:
            self.assertEqual(catalog.count(f"](labs/{lab['folder']}/README.md)"), 1)
        self.assertIn("labs/12-generate-diagrams/README.md", catalog)

    def test_catalog_and_schedule_are_current(self):
        errors = []
        check_repo.check_catalog(errors)
        check_repo.check_schedule(errors)
        self.assertEqual(errors, [])

    def test_missing_diagramming_lab_is_detected(self):
        without_diagrams = [lab for lab in build_catalog.discover() if lab["id"] != "12"]
        with patch.object(check_repo, "discover", return_value=without_diagrams):
            errors = []
            check_repo.check_catalog(errors)
        self.assertIn("Catalog lab IDs differ from the reviewed 37-lab inventory", errors)

    def test_pdf_fixture_is_exactly_the_reviewed_file(self):
        self.assertEqual(len(check_repo.ALLOWED_BINARY), 1)
        for relative, digest in check_repo.ALLOWED_BINARY.items():
            data = (build_catalog.ROOT / relative).read_bytes()
            self.assertEqual(hashlib.sha256(data).hexdigest(), digest)

    def test_slides_preserve_live_order_and_curated_recommendations(self):
        deck = (build_catalog.ROOT / "presentation/index.html").read_text()
        ids = re.findall(r'^  id: "([^"]+)",', deck, re.M)
        self.assertEqual(len(ids), 16)
        self.assertEqual([slide for slide in ids if re.fullmatch(r"lab\d+", slide)],
                         ["lab10", "lab11", "lab41", "lab62"])
        self.assertEqual(ids[-3:], ["other-labs", "other-labs-toolkit", "links"])
        closing = deck.split('id: "links",', 1)[1].split("\n];", 1)[0]
        for number in (21, 61, 71):
            self.assertIn(f"<h3>Lab {number}</h3>", closing)
        self.assertIn("<strong>Lab 12:</strong>", deck)
        metadata = json.loads(re.search(
            r'<script type="application/json" id="snowflake-report-metadata">(.*?)</script>',
            deck, re.S).group(1))
        self.assertTrue({"slide-14", "slide-15"}.issubset(
            {section["id"] for section in metadata["sections"]}))

    def test_public_links_and_privacy(self):
        errors = []
        check_repo.check_links(errors)
        check_repo.check_privacy(errors)
        self.assertEqual(errors, [])


if __name__ == "__main__":
    unittest.main()
