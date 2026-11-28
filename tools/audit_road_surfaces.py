#!/usr/bin/env python3
"""Audit OSM road surface and smoothness tags for LIBREVILLE STORIES.

This is a conservative data audit: missing OSM tags are reported as unknown,
never guessed to be asphalt or dirt. It writes a JSON report and prints a
compact summary. Uses only the Python standard library.
"""
from __future__ import annotations

import json
import math
from collections import Counter, defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
INPUT = ROOT / "data/osm/extended/roads.geojson"
OUTPUT = ROOT / "data/analysis/road_surface_audit.json"
LATITUDE_REFERENCE = 0.400
METERS_PER_DEGREE = 111320.0
UNPAVED = {"unpaved", "ground", "dirt", "earth", "compacted", "gravel",
           "fine_gravel", "pebblestone", "sand", "mud", "grass", "woodchips"}
POOR_SMOOTHNESS = {"bad", "very_bad", "horrible", "very_horrible", "impassable"}
PAVED = {"asphalt", "paved", "concrete", "concrete:lanes", "concrete:plates",
         "paving_stones", "sett", "cobblestone", "paved_stones"}


def lines(geometry: dict) -> list[list]:
    kind = geometry.get("type")
    if kind == "LineString":
        return [geometry.get("coordinates", [])]
    if kind == "MultiLineString":
        return geometry.get("coordinates", [])
    return []


def length_m(geometry: dict) -> float:
    total = 0.0
    cos_lat = math.cos(math.radians(LATITUDE_REFERENCE))
    for line in lines(geometry):
        for a, b in zip(line, line[1:]):
            dx = (float(b[0]) - float(a[0])) * METERS_PER_DEGREE * cos_lat
            dz = (float(b[1]) - float(a[1])) * METERS_PER_DEGREE
            total += math.hypot(dx, dz)
    return total


def classify(props: dict) -> str:
    surface = str(props.get("surface", "")).strip().lower()
    smoothness = str(props.get("smoothness", "")).strip().lower()
    tracktype = str(props.get("tracktype", "")).strip().lower()
    if surface in UNPAVED or tracktype in {"grade2", "grade3", "grade4", "grade5"}:
        return "unpaved"
    if surface in PAVED and smoothness in POOR_SMOOTHNESS:
        return "damaged_paved"
    if smoothness in POOR_SMOOTHNESS:
        return "poor_smoothness_tagged"
    if surface in PAVED:
        return "paved_tagged"
    if surface:
        return "other_surface_tagged"
    return "surface_unknown"


def main() -> int:
    if not INPUT.exists():
        raise SystemExit(f"OSM roads file missing: {INPUT}")
    data = json.loads(INPUT.read_text(encoding="utf-8"))
    counts: Counter[str] = Counter()
    lengths: defaultdict[str, float] = defaultdict(float)
    highway_counts: defaultdict[str, Counter[str]] = defaultdict(Counter)
    examples: defaultdict[str, list] = defaultdict(list)
    features = data.get("features", [])
    for feature in features:
        props = feature.get("properties") or {}
        if not props.get("highway"):
            continue
        category = classify(props)
        road_length = length_m(feature.get("geometry") or {})
        counts[category] += 1
        lengths[category] += road_length
        highway = str(props.get("highway", "unknown"))
        highway_counts[category][highway] += 1
        if category in {"unpaved", "damaged_paved", "poor_smoothness_tagged"} and len(examples[category]) < 250:
            examples[category].append({
                "osm_id": feature.get("id", props.get("osm_id", "")),
                "name": props.get("name", ""),
                "highway": highway,
                "surface": props.get("surface", ""),
                "smoothness": props.get("smoothness", ""),
                "tracktype": props.get("tracktype", ""),
                "estimated_length_m": round(road_length, 1),
            })
    report = {
        "source": str(INPUT.relative_to(ROOT)),
        "method": "OSM tags only; approximate length from geographic coordinates",
        "warning": "OSM surface/smoothness coverage can be incomplete; unknown is not assumed paved or damaged.",
        "feature_count": sum(counts.values()),
        "categories": {
            key: {
                "features": counts[key],
                "estimated_total_length_km": round(lengths[key] / 1000.0, 2),
                "highway_types": dict(highway_counts[key].most_common()),
            } for key in sorted(counts)
        },
        "examples": dict(examples),
    }
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"OSM roads audited: {report['feature_count']} features")
    for key, item in report["categories"].items():
        print(f"- {key}: {item['features']} features, ~{item['estimated_total_length_km']} km")
    print(f"Detailed report: {OUTPUT}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
