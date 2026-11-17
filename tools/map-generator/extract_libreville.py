#!/usr/bin/env python3
"""Extrait progressivement les routes et bâtiments OSM de Libreville par petites zones."""
from __future__ import annotations
import argparse, json, time, urllib.error, urllib.parse, urllib.request
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUTPUT = ROOT / "data" / "osm"
CACHE = OUTPUT / ".tiles"
DEFAULT_BBOX = (0.355, 9.400, 0.445, 9.495)  # sud, ouest, nord, est
GRID = 3  # 3 x 3 zones, soit 9 requêtes plus légères
ENDPOINTS = [
    "https://overpass-api.de/api/interpreter",
    "https://overpass.kumi.systems/api/interpreter",
    "https://overpass.private.coffee/api/interpreter",
]
USER_AGENT = "LIBREVILLE-STORIES/0.2 (OpenStreetMap data extraction)"

def request_overpass(query: str, timeout: int) -> dict:
    payload = urllib.parse.urlencode({"data": query}).encode("utf-8")
    errors = []
    for endpoint in ENDPOINTS:
        for attempt in range(2):
            req = urllib.request.Request(endpoint, data=payload, headers={
                "User-Agent": USER_AGENT,
                "Content-Type": "application/x-www-form-urlencoded",
            }, method="POST")
            try:
                with urllib.request.urlopen(req, timeout=timeout + 20) as response:
                    data = json.loads(response.read().decode("utf-8"))
                if "elements" not in data:
                    raise RuntimeError("Réponse Overpass sans champ elements")
                return data
            except Exception as exc:
                errors.append(f"{endpoint} essai {attempt + 1}: {exc}")
                if attempt == 0:
                    time.sleep(4)
    raise RuntimeError("Échec des serveurs Overpass :\n" + "\n".join(errors))

def split_bbox(south, west, north, east, grid):
    lat_step = (north - south) / grid
    lon_step = (east - west) / grid
    for row in range(grid):
        for col in range(grid):
            s = south + row * lat_step
            n = south + (row + 1) * lat_step
            w = west + col * lon_step
            e = west + (col + 1) * lon_step
            yield row, col, s, w, n, e

def feature_for_way(element, kind):
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
    return {
        "type": "Feature", "id": f"way/{element['id']}",
        "properties": {"osm_id": element["id"], "osm_type": "way", **element.get("tags", {})},
        "geometry": geometry,
    }

def make_collection(elements, kind):
    unique = {}
    for element in elements:
        if element.get("type") != "way":
            continue
        tags = element.get("tags", {})
        if (kind == "roads" and "highway" not in tags) or (kind == "buildings" and "building" not in tags):
            continue
        feature = feature_for_way(element, kind)
        if feature:
            unique[element["id"]] = feature
    return {"type": "FeatureCollection", "name": f"libreville_{kind}", "features": list(unique.values())}

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--south", type=float, default=DEFAULT_BBOX[0])
    parser.add_argument("--west", type=float, default=DEFAULT_BBOX[1])
    parser.add_argument("--north", type=float, default=DEFAULT_BBOX[2])
    parser.add_argument("--east", type=float, default=DEFAULT_BBOX[3])
    parser.add_argument("--timeout", type=int, default=90)
    parser.add_argument("--grid", type=int, default=GRID)
    args = parser.parse_args()
    if not (args.south < args.north and args.west < args.east) or not (1 <= args.grid <= 8):
        parser.error("Emprise invalide ou grille comprise entre 1 et 8 requise.")

    OUTPUT.mkdir(parents=True, exist_ok=True)
    CACHE.mkdir(parents=True, exist_ok=True)
    all_elements = {}
    tile_report = []
    tiles = list(split_bbox(args.south, args.west, args.north, args.east, args.grid))
    for index, (row, col, south, west, north, east) in enumerate(tiles, 1):
        cache_file = CACHE / f"tile_{row}_{col}.json"
        if cache_file.exists():
            try:
                data = json.loads(cache_file.read_text(encoding="utf-8"))
                print(f"[{index}/{len(tiles)}] Zone {row+1}-{col+1}: cache réutilisé ({len(data['elements'])} éléments)", flush=True)
            except Exception:
                cache_file.unlink(missing_ok=True)
                data = None
        else:
            data = None
        if data is None:
            bbox = f"{south:.7f},{west:.7f},{north:.7f},{east:.7f}"
            query = (
                f'[out:json][timeout:{args.timeout}];'
                f'(way["highway"]({bbox});way["building"]({bbox}););'
                'out body geom;'
            )
            print(f"[{index}/{len(tiles)}] Extraction zone {row+1}-{col+1}…", flush=True)
            data = request_overpass(query, args.timeout)
            cache_file.write_text(json.dumps(data, separators=(",", ":")), encoding="utf-8")
            time.sleep(2)  # respecte la capacité des serveurs publics
        for element in data["elements"]:
            if element.get("type") == "way":
                all_elements[element["id"]] = element
        tile_report.append({"row": row + 1, "column": col + 1, "elements": len(data["elements"])})
    elements = list(all_elements.values())

    report = {
        "source": "OpenStreetMap contributors", "license": "ODbL 1.0",
        "attribution": "© OpenStreetMap contributors",
        "bbox_south_west_north_east": [args.south, args.west, args.north, args.east],
        "grid": f"{args.grid}x{args.grid}", "tiles": tile_report,
        "extracted_at_utc": datetime.now(timezone.utc).isoformat(), "files": {},
    }
    for name in ("roads", "buildings"):
        collection = make_collection(elements, name)
        path = OUTPUT / f"{name}.geojson"
        path.write_text(json.dumps(collection, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
        key = "highway" if name == "roads" else "building"
        categories = Counter(feature["properties"].get(key, "non_précisé") for feature in collection["features"])
        report["files"][path.name] = {
            "features": len(collection["features"]), "categories": dict(categories),
            "size_bytes": path.stat().st_size,
        }
        print(f"{name}: {len(collection['features'])} objets écrits.", flush=True)

    report_path = OUTPUT / "extraction-report.json"
    report_path.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"Extraction terminée : {report_path}", flush=True)
    print("Attribution à conserver : © OpenStreetMap contributors", flush=True)

if __name__ == "__main__":
    main()
