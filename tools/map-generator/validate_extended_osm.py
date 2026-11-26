#!/usr/bin/env python3
"""Valide la qualité géométrique des couches OSM étendues."""
from __future__ import annotations

import json
from collections import Counter
from pathlib import Path

from shapely.geometry import shape

ROOT = Path(__file__).resolve().parents[2]
DATA_DIR = ROOT / "data" / "osm" / "extended"
WEST, SOUTH, EAST, NORTH = 9.370, 0.300, 9.550, 0.500
TOLERANCE = 0.00002
OPTIONAL_FILES = {"bridges.geojson"}

ALLOWED_TYPES = {
    "roads.geojson": {"LineString", "MultiLineString"},
    "bridges.geojson": {"LineString", "MultiLineString", "Polygon", "MultiPolygon"},
    "buildings.geojson": {"Polygon", "MultiPolygon"},
    "environment.geojson": {
        "LineString", "MultiLineString", "Polygon", "MultiPolygon"
    },
    "localities.geojson": {"Point"},
    "neighbourhoods.geojson": {"Polygon", "MultiPolygon"},
    "pois.geojson": {
        "Point", "MultiPoint", "LineString", "MultiLineString",
        "Polygon", "MultiPolygon"
    },
}


def main() -> None:
    failures: list[str] = []
    for filename, allowed in ALLOWED_TYPES.items():
        path = DATA_DIR / filename
        if not path.is_file():
            if filename in OPTIONAL_FILES:
                print(f"{filename}: absent (sera créé à la prochaine extraction OSM)")
                continue
            failures.append(f"{filename}: fichier absent")
            continue

        collection = json.loads(path.read_text(encoding="utf-8"))
        if collection.get("type") != "FeatureCollection":
            failures.append(f"{filename}: FeatureCollection invalide")
            continue

        type_counts: Counter[str] = Counter()
        invalid = empty = outside = missing = wrong_type = 0
        examples: list[str] = []

        for feature in collection.get("features", []):
            raw_geometry = feature.get("geometry")
            if not raw_geometry:
                missing += 1
                continue
            try:
                geometry = shape(raw_geometry)
            except Exception as exc:
                invalid += 1
                if len(examples) < 5:
                    examples.append(f"lecture: {exc}")
                continue

            type_counts[geometry.geom_type] += 1
            if geometry.is_empty:
                empty += 1
                continue
            if geometry.geom_type not in allowed:
                wrong_type += 1
            if not geometry.is_valid:
                invalid += 1
                if len(examples) < 5:
                    examples.append(
                        f"{feature.get('id', '?')}: {geometry.geom_type}"
                    )

            min_x, min_y, max_x, max_y = geometry.bounds
            if (
                min_x < WEST - TOLERANCE
                or min_y < SOUTH - TOLERANCE
                or max_x > EAST + TOLERANCE
                or max_y > NORTH + TOLERANCE
            ):
                outside += 1
                if len(examples) < 5:
                    examples.append(
                        f"{feature.get('id', '?')}: hors emprise {geometry.bounds}"
                    )

        count = len(collection.get("features", []))
        print(
            f"{filename}: {count} objets | géométries={dict(type_counts)} "
            f"| invalides={invalid} | vides={empty} | hors emprise={outside} "
            f"| sans géométrie={missing} | types inattendus={wrong_type}"
        )
        if examples:
            for example in examples:
                print(f"  Exemple: {example}")

        if invalid or empty or outside or missing or wrong_type:
            failures.append(filename)

    if failures:
        raise SystemExit("Validation géométrique échouée : " + ", ".join(failures))
    print("Validation géométrique terminée : toutes les couches sont cohérentes.")


if __name__ == "__main__":
    main()
