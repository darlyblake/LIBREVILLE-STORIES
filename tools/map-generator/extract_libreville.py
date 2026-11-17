#!/usr/bin/env python3
"""Extrait les routes et bâtiments OSM de la zone de travail de Libreville."""
from __future__ import annotations
import argparse, json, time, urllib.error, urllib.parse, urllib.request
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUTPUT = ROOT / "data" / "osm"
DEFAULT_BBOX = (0.355, 9.400, 0.445, 9.495)  # sud, ouest, nord, est
ENDPOINTS = [
    "https://overpass-api.de/api/interpreter",
    "https://overpass.kumi.systems/api/interpreter",
    "https://overpass.private.coffee/api/interpreter",
]
USER_AGENT = "LIBREVILLE-STORIES/0.1 (OpenStreetMap data extraction)"

def request_overpass(query: str, timeout: int = 180) -> dict:
    payload = urllib.parse.urlencode({"data": query}).encode("utf-8")
    errors = []
    for endpoint in ENDPOINTS:
        for attempt in range(2):
            req = urllib.request.Request(endpoint, data=payload, headers={
                "User-Agent": USER_AGENT,
                "Content-Type": "application/x-www-form-urlencoded",
            }, method="POST")
            try:
                with urllib.request.urlopen(req, timeout=timeout + 30) as response:
                    result = json.loads(response.read().decode("utf-8"))
                if "elements" not in result:
                    raise RuntimeError("Réponse Overpass sans champ elements")
                return result
            except (OSError, urllib.error.URLError, TimeoutError,
                    json.JSONDecodeError, RuntimeError) as exc:
                errors.append(f"{endpoint} (essai {attempt + 1}) : {exc}")
                if attempt == 0:
                    time.sleep(3)
    raise RuntimeError("Tous les serveurs Overpass ont échoué.\n" + "\n".join(errors))

def feature_for_way(element: dict, kind: str):
    points = element.get("geometry") or []
    coords = [[p["lon"], p["lat"]] for p in points if "lon" in p and "lat" in p]
    if len(coords) < 2:
        return None
    if kind == "buildings":
        if len(coords) < 4:
            return None
        if coords[0] != coords[-1]:
            coords.append(coords[0])
        geometry = {"type": "Polygon", "coordinates": [coords]}
    else:
        geometry = {"type": "LineString", "coordinates": coords}
    return {"type": "Feature", "id": f"way/{element['id']}",
            "properties": {"osm_id": element["id"], "osm_type": "way",
                           **element.get("tags", {})},
            "geometry": geometry}

def to_collection(elements: list, kind: str) -> dict:
    features = []
    for element in elements:
        if element.get("type") != "way":
            continue
        tags = element.get("tags", {})
        if kind == "roads" and "highway" not in tags:
            continue
        if kind == "buildings" and "building" not in tags:
            continue
        feature = feature_for_way(element, kind)
        if feature:
            features.append(feature)
    return {"type": "FeatureCollection", "name": f"libreville_{kind}",
            "features": features}

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--south", type=float, default=DEFAULT_BBOX[0])
    parser.add_argument("--west", type=float, default=DEFAULT_BBOX[1])
    parser.add_argument("--north", type=float, default=DEFAULT_BBOX[2])
    parser.add_argument("--east", type=float, default=DEFAULT_BBOX[3])
    parser.add_argument("--timeout", type=int, default=180)
    args = parser.parse_args()
    if not (args.south < args.north and args.west < args.east):
        parser.error("La bbox doit respecter sud < nord et ouest < est.")
    bbox = f"{args.south},{args.west},{args.north},{args.east}"
    OUTPUT.mkdir(parents=True, exist_ok=True)
    report = {
        "source": "OpenStreetMap contributors", "license": "ODbL 1.0",
        "attribution": "© OpenStreetMap contributors",
        "bbox_south_west_north_east": [args.south, args.west, args.north, args.east],
        "extracted_at_utc": datetime.now(timezone.utc).isoformat(), "files": {},
    }
    jobs = {
        "roads": f'[out:json][timeout:{args.timeout}];way["highway"]({bbox});out body geom;',
        "buildings": f'[out:json][timeout:{args.timeout}];way["building"]({bbox});out body geom;',
    }
    for name, query in jobs.items():
        print(f"Extraction {name} depuis OpenStreetMap…", flush=True)
        osm = request_overpass(query, args.timeout)
        collection = to_collection(osm["elements"], name)
        path = OUTPUT / f"{name}.geojson"
        path.write_text(json.dumps(collection, ensure_ascii=False,
                                   separators=(",", ":")), encoding="utf-8")
        categories = Counter()
        for feature in collection["features"]:
            tags = feature["properties"]
            categories[tags.get("highway" if name == "roads" else "building",
                                "non_précisé")] += 1
        report["files"][path.name] = {
            "features": len(collection["features"]),
            "osm_elements_received": len(osm["elements"]),
            "categories": dict(categories), "size_bytes": path.stat().st_size,
        }
        print(f"  {len(collection['features'])} objets écrits dans {path}", flush=True)
    report_path = OUTPUT / "extraction-report.json"
    report_path.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"Terminé. Rapport : {report_path}")
    print("Attribution à conserver : © OpenStreetMap contributors")

if __name__ == "__main__":
    main()

# Pipeline cloud GitHub Actions : extraction déclenchée sur les mises à jour de cet outil.
