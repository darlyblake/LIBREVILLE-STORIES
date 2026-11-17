#!/usr/bin/env python3
"""Extrait les routes et bâtiments OSM de Libreville par petites zones avec reprise sur erreur."""
from __future__ import annotations

import argparse
import json
import math
import time
import urllib.parse
import urllib.request
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUTPUT = ROOT / "data" / "osm"
CACHE = OUTPUT / ".tiles"
DEFAULT_BBOX = (0.355, 9.400, 0.445, 9.495)  # sud, ouest, nord, est
GRID = 4  # 4 x 4 secteurs indépendants
ENDPOINTS = [
    "https://overpass-api.de/api/interpreter",
    "https://overpass.kumi.systems/api/interpreter",
    "https://overpass.private.coffee/api/interpreter",
]
USER_AGENT = "LIBREVILLE-STORIES/0.3 (OpenStreetMap data extraction)"


def request_overpass(query: str, timeout: int) -> dict:
    payload = urllib.parse.urlencode({"data": query}).encode("utf-8")
    errors = []
    for endpoint_index, endpoint in enumerate(ENDPOINTS):
        for attempt in range(2):
            req = urllib.request.Request(
                endpoint,
                data=payload,
                headers={
                    "User-Agent": USER_AGENT,
                    "Content-Type": "application/x-www-form-urlencoded",
                },
                method="POST",
            )
            try:
                with urllib.request.urlopen(req, timeout=timeout + 15) as response:
                    data = json.loads(response.read().decode("utf-8"))
                if not isinstance(data.get("elements"), list):
                    raise RuntimeError("Réponse Overpass sans liste elements")
                return data
            except Exception as exc:
                errors.append(f"{endpoint} essai {attempt + 1}: {type(exc).__name__}: {exc}")
                if attempt == 0:
                    time.sleep(min(12, 3 * (2 ** attempt) + endpoint_index))
        print(f"Serveur indisponible, passage au suivant : {endpoint}", flush=True)
    raise RuntimeError("Échec de tous les serveurs Overpass pour ce secteur :\n" + "\n".join(errors))


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
    coords = [
        [point["lon"], point["lat"]]
        for point in points
        if "lon" in point and "lat" in point
        and math.isfinite(point["lon"]) and math.isfinite(point["lat"])
    ]
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
        "type": "Feature",
        "id": f"way/{element['id']}",
        "properties": {
            "osm_id": element["id"],
            "osm_type": "way",
            **element.get("tags", {}),
        },
        "geometry": geometry,
    }


def make_collection(elements, kind):
    unique = {}
    for element in elements:
        if element.get("type") != "way":
            continue
        tags = element.get("tags", {})
        if (kind == "roads" and "highway" not in tags) or (
            kind == "buildings" and "building" not in tags
        ):
            continue
        feature = feature_for_way(element, kind)
        if feature:
            unique[element["id"]] = feature
    return {
        "type": "FeatureCollection",
        "name": f"libreville_{kind}",
        "features": list(unique.values()),
    }


def load_cached_tile(cache_file):
    if not cache_file.exists():
        return None
    try:
        data = json.loads(cache_file.read_text(encoding="utf-8"))
        if isinstance(data.get("elements"), list):
            return data
    except (OSError, json.JSONDecodeError, AttributeError):
        pass
    cache_file.unlink(missing_ok=True)
    return None


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--south", type=float, default=DEFAULT_BBOX[0])
    parser.add_argument("--west", type=float, default=DEFAULT_BBOX[1])
    parser.add_argument("--north", type=float, default=DEFAULT_BBOX[2])
    parser.add_argument("--east", type=float, default=DEFAULT_BBOX[3])
    parser.add_argument("--timeout", type=int, default=45)
    parser.add_argument("--grid", type=int, default=GRID)
    args = parser.parse_args()

    if not (args.south < args.north and args.west < args.east):
        parser.error("Emprise géographique invalide.")
    if not (1 <= args.grid <= 8):
        parser.error("La grille doit être comprise entre 1 et 8.")
    if args.timeout < 10:
        parser.error("Le délai Overpass doit être d'au moins 10 secondes.")

    OUTPUT.mkdir(parents=True, exist_ok=True)
    CACHE.mkdir(parents=True, exist_ok=True)
    all_elements = {}
    tile_report = []
    tiles = list(split_bbox(args.south, args.west, args.north, args.east, args.grid))

    for index, (row, col, south, west, north, east) in enumerate(tiles, 1):
        cache_file = CACHE / f"grid{args.grid}_tile_{row}_{col}.json"
        data = load_cached_tile(cache_file)
        if data is not None:
            print(
                f"[{index}/{len(tiles)}] Secteur {row + 1}-{col + 1} : "
                f"cache réutilisé ({len(data['elements'])} éléments)",
                flush=True,
            )
        else:
            bbox = f"{south:.7f},{west:.7f},{north:.7f},{east:.7f}"
            query = (
                f"[out:json][timeout:{args.timeout}];"
                f'(way["highway"]({bbox});way["building"]({bbox}););'
                "out body geom;"
            )
            print(f"[{index}/{len(tiles)}] Extraction secteur {row + 1}-{col + 1}…", flush=True)
            data = request_overpass(query, args.timeout)
            temp_cache = cache_file.with_suffix(".json.tmp")
            temp_cache.write_text(
                json.dumps(data, separators=(",", ":")), encoding="utf-8"
            )
            temp_cache.replace(cache_file)
            time.sleep(2)  # limite la pression sur les serveurs publics

        for element in data["elements"]:
            if element.get("type") == "way":
                all_elements[element["id"]] = element
        tile_report.append({
            "row": row + 1,
            "column": col + 1,
            "elements": len(data["elements"]),
            "from_cache": load_cached_tile(cache_file) is not None,
        })

    elements = list(all_elements.values())
    report = {
        "source": "OpenStreetMap contributors",
        "license": "ODbL 1.0",
        "attribution": "© OpenStreetMap contributors",
        "bbox_south_west_north_east": [
            args.south, args.west, args.north, args.east
        ],
        "grid": f"{args.grid}x{args.grid}",
        "tiles": tile_report,
        "extracted_at_utc": datetime.now(timezone.utc).isoformat(),
        "files": {},
    }

    generated = {}
    for name in ("roads", "buildings"):
        collection = make_collection(elements, name)
        key = "highway" if name == "roads" else "building"
        categories = Counter(
            feature["properties"].get(key, "non_précisé")
            for feature in collection["features"]
        )
        generated[f"{name}.geojson"] = collection
        report["files"][f"{name}.geojson"] = {
            "features": len(collection["features"]),
            "categories": dict(categories),
        }

    if len(generated["roads.geojson"]["features"]) < 1000:
        raise RuntimeError("Extraction incomplète : moins de 1 000 voies.")
    if len(generated["buildings.geojson"]["features"]) < 10000:
        raise RuntimeError("Extraction incomplète : moins de 10 000 bâtiments.")

    # Écriture atomique : une extraction interrompue ne remplace pas la carte validée.
    for filename, collection in generated.items():
        path = OUTPUT / filename
        temp_path = path.with_suffix(path.suffix + ".tmp")
        temp_path.write_text(
            json.dumps(collection, ensure_ascii=False, separators=(",", ":")),
            encoding="utf-8",
        )
        temp_path.replace(path)
        report["files"][filename]["size_bytes"] = path.stat().st_size

    report_path = OUTPUT / "extraction-report.json"
    temp_report = report_path.with_suffix(".json.tmp")
    temp_report.write_text(
        json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8"
    )
    temp_report.replace(report_path)

    print(f"Extraction terminée : {len(tile_report)} secteurs traités.", flush=True)
    print(f"Routes : {report['files']['roads.geojson']['features']}", flush=True)
    print(f"Bâtiments : {report['files']['buildings.geojson']['features']}", flush=True)
    print("Attribution à conserver : © OpenStreetMap contributors", flush=True)


if __name__ == "__main__":
    main()
