import importlib.util
import unittest
from pathlib import Path

MODULE_PATH = Path(__file__).resolve().parents[1] / "audit_road_surfaces.py"
spec = importlib.util.spec_from_file_location("audit_road_surfaces", MODULE_PATH)
audit = importlib.util.module_from_spec(spec)
spec.loader.exec_module(audit)

class RoadAuditTests(unittest.TestCase):
    def test_unpaved_classification(self):
        self.assertEqual(audit.classify({"surface":"gravel"}), "unpaved")
        self.assertEqual(audit.classify({"tracktype":"grade4"}), "unpaved")

    def test_bad_asphalt_classification(self):
        self.assertEqual(audit.classify({"surface":"asphalt","smoothness":"bad"}), "damaged_paved")
        self.assertEqual(audit.classify({"smoothness":"very_bad"}), "damaged_paved")

    def test_unknown_is_not_guessed(self):
        self.assertEqual(audit.classify({}), "surface_unknown")

    def test_bridge_level_is_preserved(self):
        self.assertNotEqual(audit.level({"bridge":"yes","layer":"1"}), audit.level({"bridge":"no","layer":"0"}))

    def test_near_t_junction_is_reported(self):
        features = [
            {"id":"a","properties":{"highway":"residential","osm_id":"a","layer":"0"},
             "geometry":{"type":"LineString","coordinates":[[9.44,0.40],[9.441,0.40]]}},
            {"id":"b","properties":{"highway":"residential","osm_id":"b","layer":"0"},
             "geometry":{"type":"LineString","coordinates":[[9.4405,0.40001],[9.4405,0.4003]]}},
        ]
        result = audit.audit_topology(features)
        self.assertGreaterEqual(result["possible_t_junctions_within_3m"], 1)

if __name__ == "__main__":
    unittest.main()
