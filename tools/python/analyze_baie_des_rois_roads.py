#!/usr/bin/env python3
"""Extract OSM road/sidewalk geometry around the Baie des Rois kiosk rows.

Run from the repository root:
    python tools/python/analyze_baie_des_rois_roads.py

The report is diagnostic only: it does not modify game geometry.
"""
from __future__ import annotations

import json
import math
from pathlib import Path
from typing import Iterable

ROOT = Path(__file__).resolve().parents[2]
INPUT = ROOT / "data/osm/roads.geojson"
OUTPUT = ROOT / "data/analysis/baie_des_rois_roads_report.json"

CENTER_LAT = 0.400
CENTER_LON = 9.4475
METERS_PER_DEG = 111320.0
ROW_A = ((-1833.4264482147119, -437.00614973078456),
         (-1934.1358903731473, -428.4267799582003))
ROW_B = ((-1834.8129615841162, -428.34698673045466),
         (-1934.1358903731473 + 0.7222, -428.4267799582003 + 8.4795))
# Bounding box in game-world metres, with a 45 m inspection margin.
BOUNDS = (-1980.0, -485.0, -1770.0, -365.0)


def geo_to_world(coord: list[float]) -> tuple[float, float]:
    lon, lat = float(coord[0]), float(coord[1])
    x = (lon - CENTER_LON) * METERS_PER_DEG * math.cos(math.radians(CENTER_LAT))
    z = -(lat - CENTER_LAT) * METERS_PER_DEG
    return x, z


def road_width(kind: str, props: dict) -> float:
    raw = str(props.get("width", "")).strip().lower().replace(",", ".")
    try:
        if raw.endswith("ft"):
            value = float(raw[:-2].strip()) * 0.3048
        elif raw.endswith("m"):
            value = float(raw[:-1].strip())
        else:
            value = float(raw)
        if 1.5 <= value <= 40:
            return value
    except (ValueError, TypeError):
        pass
    try:
        lanes = int(props.get("lanes", 0))
    except (ValueError, TypeError):
        lanes = 0
    if 1 <= lanes <= 8:
        return max(3.5, min(28.0, lanes * 3.4 + 1.2))
    return {
        "motorway": 16.0, "trunk": 16.0, "primary": 12.5,
        "secondary": 9.0, "tertiary": 7.0,
        "residential": 5.5, "unclassified": 5.5,
        "service": 3.6, "footway": 1.8, "path": 1.8,
        "steps": 1.8, "cycleway": 1.8,
    }.get(kind, 5.0)


def sidewalk_mode(props: dict, kind: str) -> str:
    general = str(props.get("sidewalk", "")).lower()
    left = str(props.get("sidewalk:left", "")).lower()
    right = str(props.get("sidewalk:right", "")).lower()
    if general in ("no", "none", "separate"):
        return "none"
    if left == "no":
        return "right" if right in ("yes", "both") else "none"
    if right == "no":
        return "left" if left in ("yes", "both") else "none"
    if left in ("yes", "both") and right in ("yes", "both"):
        return "both"
    if left in ("yes", "both"):
        return "left"
    if right in ("yes", "both"):
        return "right"
    if general in ("yes", "both"):
        return "both"
    return "both" if kind in (
        "trunk", "primary", "secondary", "tertiary", "residential"
    ) else "none"


def point_segment_distance(p, a, b) -> float:
    dx, dz = b[0] - a[0], b[1] - a[1]
    denom = dx * dx + dz * dz
    if denom < 1e-9:
        return math.hypot(p[0] - a[0], p[1] - a[1])
    t = max(0.0, min(1.0, ((p[0]-a[0])*dx + (p[1]-a[1])*dz) / denom))
    q = (a[0] + t*dx, a[1] + t*dz)
    return math.hypot(p[0]-q[0], p[1]-q[1])


def segment_distance(a, b, c, d) -> float:
    # Minimum of endpoint-to-segment distances; zero if segments intersect.
    def orient(p, q, r):
        return (q[0]-p[0])*(r[1]-p[1]) - (q[1]-p[1])*(r[0]-p[0])
    o1, o2, o3, o4 = orient(a,b,c), orient(a,b,d), orient(c,d,a), orient(c,d,b)
    if o1 * o2 <= 0 and o3 * o4 <= 0:
        return 0.0
    return min(point_segment_distance(a,c,d), point_segment_distance(b,c,d),
               point_segment_distance(c,a,b), point_segment_distance(d,a,b))


def lines_from_geometry(geometry: dict) -> list[list]:
    kind = geometry.get("type")
    if kind == "LineString":
        return [geometry.get("coordinates", [])]
    if kind == "MultiLineString":
        return geometry.get("coordinates", [])
    return []


def main() -> None:
    if not INPUT.exists():
        raise SystemExit(f"Fichier introuvable : {INPUT}")
    data = json.loads(INPUT.read_text(encoding="utf-8"))
    row_segments = [ROW_A, ROW_B]
    found = []
    for feature in data.get("features", []):
        props = feature.get("properties", {})
        kind = str(props.get("highway", ""))
        if not kind:
            continue
        all_lines = lines_from_geometry(feature.get("geometry", {}))
        closest = float("inf")
        closest_row = None
        closest_world = None
        clipped_lines = []
        for line in all_lines:
            world = [geo_to_world(c) for c in line]
            local = [p for p in world if BOUNDS[0] <= p[0] <= BOUNDS[2]
                     and BOUNDS[1] <= p[1] <= BOUNDS[3]]
            # Keep a whole line if it has any point in the local inspection area.
            if local:
                clipped_lines.append([[round(x, 2), round(z, 2)] for x, z in world])
            for i in range(len(world)-1):
                for row_index, row in enumerate(row_segments):
                    distance = segment_distance(world[i], world[i+1], *row)
                    if distance < closest:
                        closest, closest_row = distance, row_index + 1
                        closest_world = world[i] if point_segment_distance(world[i], *row) <= point_segment_distance(world[i+1], *row) else world[i+1]
        if closest <= 65.0 and clipped_lines:
            width = road_width(kind, props)
            sw = sidewalk_mode(props, kind)
            found.append({
                "osm_id": feature.get("id", ""),
                "name": props.get("name", ""),
                "highway": kind,
                "surface": props.get("surface", ""),
                "width_m_used_by_game": width,
                "sidewalk_mode_used_by_game": sw,
                "sidewalk_width_m_each_side": 1.55 if sw != "none" else 0,
                "curb_width_m_each_side": 0.22 if sw != "none" else 0,
                "nearest_kiosk_row": closest_row,
                "distance_centerline_to_row_m": round(closest, 2),
                "nearest_road_vertex_world_xz": [round(closest_world[0], 2), round(closest_world[1], 2)] if closest_world else None,
                "world_lines_xz": clipped_lines,
            })
    found.sort(key=lambda item: item["distance_centerline_to_row_m"])
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    report = {
        "source": str(INPUT.relative_to(ROOT)),
        "coordinate_conversion": "same constants and X/Z convention as game/scripts/world_map.gd",
        "warning": "OSM centre lines and game-sidewalk widths are estimates, not a surveyed curb edge.",
        "rows": {"A": [[round(x,2),round(z,2)] for x,z in ROW_A],
                 "B": [[round(x,2),round(z,2)] for x,z in ROW_B]},
        "road_features_within_65m_of_kiosk_rows": found,
    }
    OUTPUT.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"Routes proches des kiosques : {len(found)}")
    print(f"Rapport complet : {OUTPUT}")
    for item in found[:20]:
        label = item["name"] or item["osm_id"]
        print(
            f"- {label} | {item['highway']} | rangée {item['nearest_kiosk_row']} "
            f"| axe à {item['distance_centerline_to_row_m']:.2f} m "
            f"| largeur jeu {item['width_m_used_by_game']:.1f} m "
            f"| trottoir {item['sidewalk_mode_used_by_game']}"
        )
    if not found:
        print("Aucun axe OSM proche trouvé dans la zone analysée.")


if __name__ == "__main__":
    main()
