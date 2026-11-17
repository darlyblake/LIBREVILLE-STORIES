#!/usr/bin/env python3
"""Tests hors-ligne de l'assemblage des frontières OSM multipolygones."""
import sys
import unittest
from pathlib import Path

from shapely.geometry import shape

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "map-generator"))
import extract_libreville as extractor


class NeighbourhoodRelationTests(unittest.TestCase):
    BOUNDS = (0.0, 0.0, 1.0, 1.0)

    @staticmethod
    def member(way_id, role, ring):
        return {
            "type": "way",
            "ref": way_id,
            "role": role,
            "geometry": [{"lon": lon, "lat": lat} for lon, lat in ring],
        }

    def test_relation_rebuilds_outer_and_inner_rings(self):
        outer = [(0.1, 0.1), (0.9, 0.1), (0.9, 0.9), (0.1, 0.9), (0.1, 0.1)]
        inner = [(0.4, 0.4), (0.6, 0.4), (0.6, 0.6), (0.4, 0.6), (0.4, 0.4)]
        relation = {
            "type": "relation",
            "id": 7001,
            "tags": {"name": "Quartier test", "place": "neighbourhood", "type": "multipolygon"},
            "members": [
                self.member(11, "outer", outer),
                self.member(12, "inner", inner),
            ],
        }

        result = extractor.make_neighbourhood_collection([], self.BOUNDS, [relation])
        self.assertEqual(len(result["features"]), 1)
        feature = result["features"][0]
        self.assertEqual(feature["id"], "relation/7001")
        self.assertEqual(feature["properties"]["name"], "Quartier test")
        self.assertEqual(feature["properties"]["osm_type"], "relation")
        polygon = shape(feature["geometry"])
        self.assertEqual(len(polygon.interiors), 1)
        self.assertAlmostEqual(polygon.area, 0.60, places=6)

    def test_relation_is_clipped_to_map_bounds(self):
        outer = [(-0.2, 0.2), (0.5, 0.2), (0.5, 0.8), (-0.2, 0.8), (-0.2, 0.2)]
        relation = {
            "type": "relation",
            "id": 7002,
            "tags": {"name": "Quartier bordure", "boundary": "administrative"},
            "members": [self.member(21, "outer", outer)],
        }
        result = extractor.make_neighbourhood_collection([], self.BOUNDS, [relation])
        self.assertEqual(len(result["features"]), 1)
        polygon = shape(result["features"][0]["geometry"])
        self.assertAlmostEqual(polygon.bounds[0], 0.0, places=7)
        self.assertAlmostEqual(polygon.bounds[2], 0.5, places=7)

    def test_unnamed_relation_is_not_published(self):
        ring = [(0.1, 0.1), (0.9, 0.1), (0.9, 0.9), (0.1, 0.9), (0.1, 0.1)]
        relation = {
            "type": "relation",
            "id": 7003,
            "tags": {"place": "neighbourhood"},
            "members": [self.member(31, "outer", ring)],
        }
        result = extractor.make_neighbourhood_collection([], self.BOUNDS, [relation])
        self.assertEqual(result["features"], [])


if __name__ == "__main__":
    unittest.main(verbosity=2)
