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
            "tags": {"name": "Quartier bordure", "boundary": "administrative", "admin_level": "10"},
            "members": [self.member(21, "outer", outer)],
        }
        result = extractor.make_neighbourhood_collection([], self.BOUNDS, [relation])
        self.assertEqual(len(result["features"]), 1)
        polygon = shape(result["features"][0]["geometry"])
        self.assertAlmostEqual(polygon.bounds[0], 0.0, places=7)
        self.assertAlmostEqual(polygon.bounds[2], 0.5, places=7)

    def test_relation_assembles_separate_outer_member_ways(self):
        # Les frontières OSM sont souvent découpées en plusieurs ways.
        segments = [
            self.member(41, "outer", [(0.1, 0.1), (0.9, 0.1), (0.9, 0.9)]),
            self.member(42, "outer", [(0.9, 0.9), (0.1, 0.9), (0.1, 0.1)]),
        ]
        relation = {
            "type": "relation",
            "id": 7004,
            "tags": {"name": "Quartier en segments", "place": "suburb", "type": "multipolygon"},
            "members": segments,
        }

        result = extractor.make_neighbourhood_collection([], self.BOUNDS, [relation])
        self.assertEqual(len(result["features"]), 1)
        polygon = shape(result["features"][0]["geometry"])
        self.assertAlmostEqual(polygon.area, 0.64, places=6)
        self.assertTrue(polygon.is_valid)

    def test_country_and_province_boundaries_are_not_neighbourhoods(self):
        ring = [(0.1, 0.1), (0.9, 0.1), (0.9, 0.9), (0.1, 0.9), (0.1, 0.1)]
        relations = [
            {
                "type": "relation", "id": 8001,
                "tags": {"name": "Gabon", "boundary": "administrative", "admin_level": "2"},
                "members": [self.member(51, "outer", ring)],
            },
            {
                "type": "relation", "id": 8002,
                "tags": {"name": "Estuaire", "boundary": "administrative", "admin_level": "4"},
                "members": [self.member(52, "outer", ring)],
            },
            {
                "type": "relation", "id": 8003,
                "tags": {"name": "Libreville", "boundary": "administrative", "admin_level": "6"},
                "members": [self.member(53, "outer", ring)],
            },
            {
                "type": "relation", "id": 8004,
                "tags": {"name": "Arrondissement", "boundary": "administrative", "admin_level": "9"},
                "members": [self.member(54, "outer", ring)],
            },
        ]
        result = extractor.make_neighbourhood_collection([], self.BOUNDS, relations)
        self.assertEqual(result["features"], [])

    def test_local_administrative_level_10_is_kept(self):
        ring = [(0.1, 0.1), (0.9, 0.1), (0.9, 0.9), (0.1, 0.9), (0.1, 0.1)]
        relation = {
            "type": "relation", "id": 8005,
            "tags": {"name": "Quartier local", "boundary": "administrative", "admin_level": "10"},
            "members": [self.member(55, "outer", ring)],
        }
        result = extractor.make_neighbourhood_collection([], self.BOUNDS, [relation])
        self.assertEqual([f["properties"]["name"] for f in result["features"]], ["Quartier local"])

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


    def test_named_place_nodes_are_exported_as_label_points(self):
        nodes = {
            101: {"id": 101, "lon": 0.25, "lat": 0.35,
                  "tags": {"name": "Nzeng-Ayong", "place": "suburb"}},
            102: {"id": 102, "lon": 1.25, "lat": 0.35,
                  "tags": {"name": "Hors emprise", "place": "suburb"}},
            103: {"id": 103, "lon": 0.45, "lat": 0.45,
                  "tags": {"name": "Commerce", "shop": "supermarket"}},
        }
        result = extractor.make_locality_collection(nodes, [], self.BOUNDS)
        self.assertEqual(len(result["features"]), 1)
        feature = result["features"][0]
        self.assertEqual(feature["id"], "node/101")
        self.assertEqual(feature["properties"]["name"], "Nzeng-Ayong")
        self.assertEqual(feature["geometry"]["type"], "Point")

    def test_named_place_way_is_labelled_without_fabricated_boundary(self):
        ways = [{
            "type": "way", "id": 202,
            "tags": {"name": "Akébé", "place": "neighbourhood"},
            "geometry": [
                {"lon": 0.2, "lat": 0.2}, {"lon": 0.8, "lat": 0.2},
                {"lon": 0.8, "lat": 0.8}, {"lon": 0.2, "lat": 0.8},
                {"lon": 0.2, "lat": 0.2},
            ],
        }]
        result = extractor.make_locality_collection({}, ways, self.BOUNDS)
        self.assertEqual(len(result["features"]), 1)
        self.assertEqual(result["features"][0]["geometry"]["type"], "Point")
        self.assertEqual(result["features"][0]["properties"]["source"],
                         "OpenStreetMap place way (label point)")


if __name__ == "__main__":
    unittest.main(verbosity=2)
