from pathlib import Path
import unittest


class ZoneFieldContractTest(unittest.TestCase):
    def test_processing_sketch_uses_zone_field_names(self):
        sketch = (Path(__file__).parents[1] / "processing" / "FreqZone" / "FreqZone.pde").read_text()
        self.assertNotIn("bt.fLo", sketch)
        self.assertNotIn("bt.fHi", sketch)
        self.assertIn("bt.loHz", sketch)
        self.assertIn("bt.hiHz", sketch)


if __name__ == "__main__":
    unittest.main()
