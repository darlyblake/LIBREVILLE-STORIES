#!/usr/bin/env python3
"""Produit des métriques planimétriques descriptives pour les objets OSM bridge."""
from __future__ import annotations

import json
import math
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "data" / "osm" / "extended" / "bridges.geojson"
OUTPUT = ROOT / "data" / "osm" / "extended" / "bridge-geometry-report.json"


def iter_positions(value: Any):
    if isinstance(value, list) and len(value) >= 2 and all(
        isinstance(item, (int, float)) for item in value[:2]
    ):
        yield float(value[0]), float(value[1])
    elif isinstance(value, list):
        for child in value:
            yield from iter_positions(child)


def project_ring(ring: list, latitude_origin: float) -> list[tuple[float, float]]:
    lon_scale = 111320.0 * math.cos(math.radians(latitude_origin))
    lat_scale = 110540.0
    return [(lon * lon_scale, lat * lat_scale) for lon, lat in ring]


def polygon_metrics(geometry: dict, latitude_origin: float) -> dict:
    polygons = []
    kind = geometry.get("type")
    coordinates = geometry.get("coordinates", [])
    if kind == "Polygon":
        polygons = [coordinates]
    elif kind == "MultiPolygon":
        polygons = coordinates

    total_area = 0.0
    total_perimeter = 0.0
    all_points: list[tuple[float, float]] = []
    for polygon in polygons:
        if not polygon:
            continue
        rings = [project_ring(ring, latitude_origin) for ring in polygon]
        if not rings or not rings[0]:
            continue
        outer = rings[0]
        signed = 0.0
        perimeter = 0.0
        for index, point in enumerate(outer):
            nxt = outer[(index + 1) % len(outer)]
            signed += point[0] * nxt[1] - nxt[0] * point[1]
            perimeter += math.hypot(nxt[0] - point[0], nxt[1] - point[1])
        area = abs(signed) * 0.5
        for hole in rings[1:]:
            hole_signed = 0.0
            for index, point in enumerate(hole):
                nxt = hole[(index + 1) % len(hole)]
                hole_signed += point[0] * nxt[1] - nxt[0] * point[1]
            area -= abs(hole_signed) * 0.5
            perimeter += sum(
                math.hypot(
                    hole[(i + 1) % len(hole)][0] - point[0],
                    hole[(i + 1) % len(hole)][1] - point[1],
                )
                for i, point in enumerate(hole)
            )
        total_area += max(area, 0.0)
        total_perimeter += perimeter
        all_points.extend(outer)

    if not all_points:
        return {}
    xs = [point[0] for point in all_points]
    ys = [point[1] for point in all_points]
    return {
        "bbox_width_m_approx": round(max(xs) - min(xs), 1),
        "bbox_height_m_approx": round(max(ys) - min(ys), 1),
        "polygon_area_m2_approx": round(total_area, 1),
        "outer_and_inner_perimeter_m_approx": round(total_perimeter, 1),
    }


def main() -> None:
    collection = json.loads(SOURCE.read_text(encoding="utf-8"))
    features = []
    for feature in collection.get("features", []):
        geometry = feature.get("geometry") or {}
        positions = list(iter_positions(geometry.get("coordinates", [])))
        if not positions:
            continue
        latitude_origin = sum(lat for _, lat in positions) / len(positions)
        properties = feature.get("properties", {})
        item = {
            "osm_id": feature.get("id"),
            "name": properties.get("name") or properties.get("bridge:name") or "",
            "bridge": properties.get("bridge", ""),
            "man_made": properties.get("man_made", ""),
            "highway": properties.get("highway", ""),
            "bridge_structure": properties.get("bridge:structure", ""),
            "geometry_type": geometry.get("type", ""),
            "source_tags": {
                key: properties[key]
                for key in ("layer", "lanes", "surface", "oneway")
                if key in properties
            },
        }
        if geometry.get("type") in {"Polygon", "MultiPolygon"}:
            item["planimetric_metrics"] = polygon_metrics(geometry, latitude_origin)
        else:
            item["note"] = (
                "Tracé linéaire OSM : longueur de voie non assimilable à la longueur "
                "du tablier ou des rampes."
            )
        features.append(item)

    report = {
        "source": "© OpenStreetMap contributors",
        "license": "ODbL-1.0",
        "method": (
            "Projection locale équirectangulaire approximative à la latitude de chaque "
            "objet. Les métriques décrivent l'emprise cartographique OSM uniquement."
        ),
        "warning": (
            "Les dimensions d'enveloppe, aires et périmètres ne sont pas des mesures "
            "certifiées de tablier. Aucune hauteur, épaisseur, pile, rampe ou altitude "
            "n'est déduite."
        ),
        "feature_count": len(features),
        "features": features,
    }
    OUTPUT.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    polygon_count = sum("planimetric_metrics" in item for item in features)
    print(f"Rapport géométrique ponts : {len(features)} objets, {polygon_count} polygones.")
    for item in features:
        metrics = item.get("planimetric_metrics")
        if metrics:
            print(
                f"  {item['osm_id']} {item['name']}: "
                f"enveloppe {metrics['bbox_width_m_approx']} x "
                f"{metrics['bbox_height_m_approx']} m ; "
                f"aire cartographique {metrics['polygon_area_m2_approx']} m²"
            )


if __name__ == "__main__":
    main()
