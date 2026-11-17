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


def is_point_of_interest(tags):
    """Retient les lieux nommés et catégorisés utiles à l'identification en jeu."""
    keys = ("amenity", "shop", "tourism", "healthcare", "school", "office",
            "public_transport", "leisure", "historic", "emergency", "government",
            "railway", "aeroway", "place", "building", "man_made", "natural",
            "boundary", "sport", "waterway", "landuse")
    return bool(tags.get("name")) and any(key in tags for key in keys)


def environment_kind(tags):
    """Classe les objets naturels/eau/végétation utiles au décor de Libreville."""
    natural = tags.get("natural", "")
    landuse = tags.get("landuse", "")
    leisure = tags.get("leisure", "")
    waterway = tags.get("waterway", "")
    if natural == "coastline":
        return "coastline"
    if waterway or natural in {"river", "stream", "canal"}:
        return "waterway"
    if natural in {"water", "wetland"} or landuse in {"reservoir", "basin"}:
        return "water"
    if natural in {"wood", "scrub", "grassland", "heath", "tree_row"} or landuse in {"forest", "grass", "meadow", "orchard", "vineyard"}:
        return "vegetation"
    if leisure in {"park", "garden", "nature_reserve", "golf_course"} or landuse in {"recreation_ground", "village_green"}:
        return "green_space"
    if natural in {"beach", "sand", "bare_rock"}:
        return "natural_surface"
    return ""


def is_environment_feature(tags):
    return bool(environment_kind(tags))


def _geometry_parts(geometry, accepted_types):
    if geometry.is_empty:
        return
    if geometry.geom_type in accepted_types:
        yield geometry
    elif hasattr(geometry, "geoms"):
        for part in geometry.geoms:
            yield from _geometry_parts(part, accepted_types)


def make_environment_collection(elements, bounds):
    from shapely.geometry import LineString, Polygon, box

    features = []
    south, west, north, east = bounds
    clip = box(west, south, east, north)
    for way in elements:
        tags = way.get("tags", {})
        kind = environment_kind(tags)
        if not kind or way.get("type") != "way":
            continue
        points = way.get("geometry") or []
        coords = [
            (float(point["lon"]), float(point["lat"]))
            for point in points
            if "lon" in point and "lat" in point
            and math.isfinite(float(point["lon"])) and math.isfinite(float(point["lat"]))
        ]
        if len(coords) < 2:
            continue
        is_area = len(coords) >= 4 and coords[0] == coords[-1]
        if kind not in {"waterway", "coastline"} and not is_area:
            continue
        try:
            if is_area:
                shape = Polygon(coords)
                if not shape.is_valid:
                    shape = shape.buffer(0)
                clipped = shape.intersection(clip)
                parts = list(_geometry_parts(clipped, {"Polygon"}))
                for index, part in enumerate(parts):
                    geometry = {"type": "Polygon", "coordinates": [[list(point) for point in part.exterior.coords]]}
                    suffix = "" if len(parts) == 1 else "#part/" + str(index + 1)
                    features.append({
                        "type": "Feature", "id": "way/" + str(way["id"]) + suffix,
                        "properties": {"osm_id": int(way["id"]), "osm_type": "way", "environment_kind": kind, **tags},
                        "geometry": geometry,
                    })
            else:
                clipped = LineString(coords).intersection(clip)
                parts = list(_geometry_parts(clipped, {"LineString"}))
                for index, part in enumerate(parts):
                    if len(part.coords) < 2:
                        continue
                    suffix = "" if len(parts) == 1 else "#part/" + str(index + 1)
                    features.append({
                        "type": "Feature", "id": "way/" + str(way["id"]) + suffix,
                        "properties": {"osm_id": int(way["id"]), "osm_type": "way", "environment_kind": kind, **tags},
                        "geometry": {"type": "LineString", "coordinates": [list(point) for point in part.coords]},
                    })
        except Exception as exc:
            print("Géométrie environnementale ignorée way/" + str(way["id"]) + ": " + str(exc), flush=True)
    return {"type": "FeatureCollection", "name": "libreville_environment", "features": features}

def make_poi_collection(nodes, elements):
    features = []
    for node in nodes.values():
        tags = node.get("tags", {})
        if not is_point_of_interest(tags):
            continue
        lon, lat = float(node["lon"]), float(node["lat"])
        if not (math.isfinite(lon) and math.isfinite(lat)):
            continue
        features.append({
            "type": "Feature", "id": f"node/{node['id']}",
            "properties": {"osm_id": node["id"], "osm_type": "node", **tags},
            "geometry": {"type": "Point", "coordinates": [lon, lat]},
        })
    for way in elements:
        tags = way.get("tags", {})
        if not is_point_of_interest(tags):
            continue
        points = way.get("geometry") or []
        if len(points) < 2:
            continue
        # Centroïde des sommets pour positionner l'étiquette du lieu.
        lon = sum(float(point["lon"]) for point in points) / len(points)
        lat = sum(float(point["lat"]) for point in points) / len(points)
        if not (math.isfinite(lon) and math.isfinite(lat)):
            continue
        features.append({
            "type": "Feature", "id": f"way/{way['id']}",
            "properties": {"osm_id": way["id"], "osm_type": "way", **tags},
            "geometry": {"type": "Point", "coordinates": [lon, lat]},
        })
    return {"type": "FeatureCollection", "name": "libreville_pois", "features": features}


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



def extract_from_geofabrik_pbf(south, west, north, east):
    """Repli fiable sur l'extrait PBF national Geofabrik si Overpass est indisponible."""
    try:
        import osmium
    except ImportError as exc:
        raise RuntimeError("Le module Python 'osmium' est requis pour le repli Geofabrik.") from exc

    pbf_path = OUTPUT / "gabon-latest.osm.pbf"
    if not pbf_path.exists() or pbf_path.stat().st_size < 1_000_000:
        temp_path = pbf_path.with_suffix(".pbf.part")
        url = "https://download.geofabrik.de/africa/gabon-latest.osm.pbf"
        print("Téléchargement du PBF Gabon depuis Geofabrik…", flush=True)
        request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
        with urllib.request.urlopen(request, timeout=180) as response, temp_path.open("wb") as output:
            while True:
                chunk = response.read(1024 * 1024)
                if not chunk:
                    break
                output.write(chunk)
        if temp_path.stat().st_size < 1_000_000:
            raise RuntimeError("Fichier PBF Geofabrik incomplet ou trop petit.")
        temp_path.replace(pbf_path)

    class LibrevilleHandler(osmium.SimpleHandler):
        def __init__(self):
            super().__init__()
            self.elements = []
            self.nodes = {}

        def node(self, node):
            tags = dict(node.tags)
            if not node.location.valid() or not is_point_of_interest(tags):
                return
            self.nodes[int(node.id)] = {
                "id": int(node.id), "lon": float(node.lon), "lat": float(node.lat),
                "tags": tags,
            }

        def way(self, way):
            tags = dict(way.tags)
            if "highway" not in tags and "building" not in tags and not is_point_of_interest(tags) and not is_environment_feature(tags):
                return
            geometry = []
            min_lon = min_lat = float("inf")
            max_lon = max_lat = float("-inf")
            for node in way.nodes:
                if not node.location.valid():
                    continue
                lon, lat = float(node.lon), float(node.lat)
                geometry.append({"lon": lon, "lat": lat})
                min_lon, max_lon = min(min_lon, lon), max(max_lon, lon)
                min_lat, max_lat = min(min_lat, lat), max(max_lat, lat)

            # Garder aussi les voies qui traversent l'emprise sans sommet dedans.
            intersects_bbox = (
                len(geometry) >= 2
                and max_lon >= west and min_lon <= east
                and max_lat >= south and min_lat <= north
            )
            if intersects_bbox:
                self.elements.append({
                    "type": "way", "id": int(way.id),
                    "tags": tags, "geometry": geometry,
                    "_bounds": [min_lat, min_lon, max_lat, max_lon],
                })

    handler = LibrevilleHandler()
    print("Lecture et découpage local du PBF sur l'emprise de Libreville…", flush=True)
    handler.apply_file(str(pbf_path), locations=True)
    print(f"Repli Geofabrik : {len(handler.elements)} voies et bâtiments candidats.", flush=True)
    return handler.elements, handler.nodes

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
    all_nodes = {}
    tile_report = []
    tiles = list(split_bbox(args.south, args.west, args.north, args.east, args.grid))

    used_geofabrik_fallback = False
    try:
        for index, (row, col, south, west, north, east) in enumerate(tiles, 1):
            cache_file = CACHE / f"grid{args.grid}_v5_tile_{row}_{col}.json"
            data = load_cached_tile(cache_file)
            from_cache = data is not None
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
                    f'(way["highway"]({bbox});way["building"]({bbox});'
                    f'node["name"]({bbox});node["amenity"]({bbox});'
                    f'node["shop"]({bbox});node["tourism"]({bbox});'
                    f'node["healthcare"]({bbox});node["leisure"]({bbox});'
                    f'node["public_transport"]({bbox});node["historic"]({bbox});'
                    f'node["emergency"]({bbox});'
                    f'way["amenity"]({bbox});way["shop"]({bbox});'
                    f'way["tourism"]({bbox});way["healthcare"]({bbox});'
                    f'way["leisure"]({bbox});way["historic"]({bbox});'
                    f'way["public_transport"]({bbox});way["office"]({bbox});'
                    f'way["emergency"]({bbox});way["place"]({bbox});way["railway"]({bbox});way["aeroway"]({bbox});way["government"]({bbox});way["man_made"]({bbox});way["natural"]({bbox});way["boundary"]({bbox});way["sport"]({bbox});way["waterway"]({bbox});way["landuse"]({bbox}););'
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
                elif element.get("type") == "node":
                    all_nodes[element["id"]] = element
            tile_report.append({
                "row": row + 1,
                "column": col + 1,
                "elements": len(data["elements"]),
                "from_cache": from_cache,
            })
    
    
    except Exception as extraction_error:
        print(f"Overpass indisponible ({extraction_error}). Bascule vers Geofabrik PBF.", flush=True)
        used_geofabrik_fallback = True
        elements_from_pbf, nodes_from_pbf = extract_from_geofabrik_pbf(
            args.south, args.west, args.north, args.east
        )
        all_elements = {element["id"]: element for element in elements_from_pbf}
        all_nodes = nodes_from_pbf
        tile_report = []
        for row, col, tile_south, tile_west, tile_north, tile_east in tiles:
            tile_count = sum(
                1 for element in elements_from_pbf
                if (bounds := element.get("_bounds")) is not None
                and bounds[2] >= tile_south and bounds[0] <= tile_north
                and bounds[3] >= tile_west and bounds[1] <= tile_east
            )
            tile_report.append({
                "row": row + 1, "column": col + 1,
                "elements": tile_count, "from_cache": False,
                "source": "Geofabrik Gabon PBF (intersection géographique)",
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
        "source_mode": "Geofabrik Gabon PBF (fallback)" if used_geofabrik_fallback else "Overpass API",
        "tiles": tile_report,
        "extracted_at_utc": datetime.now(timezone.utc).isoformat(),
        "files": {},
    }

    generated = {}
    generated["environment.geojson"] = make_environment_collection(elements, (args.south, args.west, args.north, args.east))
    report["files"]["environment.geojson"] = {
        "features": len(generated["environment.geojson"]["features"]),
        "categories": dict(Counter(
            feature["properties"].get("environment_kind", "other")
            for feature in generated["environment.geojson"]["features"]
        )),
    }
    generated["pois.geojson"] = make_poi_collection(all_nodes, elements)
    report["files"]["pois.geojson"] = {
        "features": len(generated["pois.geojson"]["features"]),
        "categories": dict(Counter(
            feature["properties"].get("amenity")
            or feature["properties"].get("shop")
            or feature["properties"].get("tourism")
            or feature["properties"].get("healthcare")
            or feature["properties"].get("leisure")
            or "other"
            for feature in generated["pois.geojson"]["features"]
        )),
    }
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
    print(f"Lieux identifiables : {report['files']['pois.geojson']['features']}", flush=True)
    print("Attribution à conserver : © OpenStreetMap contributors", flush=True)


if __name__ == "__main__":
    main()
