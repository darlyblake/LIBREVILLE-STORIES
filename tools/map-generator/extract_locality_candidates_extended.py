#!/usr/bin/env python3
"""Extrait des localités OSM candidates sur une emprise élargie sans toucher aux données du jeu."""
from __future__ import annotations

import json
import time
import urllib.parse
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUTPUT = ROOT / "data" / "osm" / "locality_candidates_extended.geojson"
# Emprise de recherche volontairement plus large que le DEM actuel.
# Elle sert à repérer des noms, pas à étendre automatiquement la carte jouable.
BBOX = (0.300, 9.370, 0.500, 9.550)  # sud, ouest, nord, est
CURRENT_DEM_BBOX = (0.354461, 9.399461, 0.445539, 9.495539)
ENDPOINTS = [
    "https://overpass-api.de/api/interpreter",
    "https://overpass.kumi.systems/api/interpreter",
    "https://overpass.private.coffee/api/interpreter",
]
USER_AGENT = "LIBREVILLE-STORIES/0.3 (OpenStreetMap locality candidate extraction)"
PLACE_VALUES = "suburb|neighbourhood|quarter|district|borough|locality|village|hamlet"


def fetch_candidates() -> list[dict]:
    south, west, north, east = BBOX
    bbox = f"{south},{west},{north},{east}"
    query = (
        f'[out:json][timeout:90];'
        f'(node["place"~"^({PLACE_VALUES})$"]({bbox});'
        f'way["place"~"^({PLACE_VALUES})$"]({bbox});'
        f'relation["place"~"^({PLACE_VALUES})$"]({bbox}););'
        "out center tags;"
    )
    payload = urllib.parse.urlencode({"data": query}).encode("utf-8")
    errors = []
    for endpoint in ENDPOINTS:
        for attempt in range(2):
            request = urllib.request.Request(
                endpoint, data=payload,
                headers={"User-Agent": USER_AGENT, "Content-Type": "application/x-www-form-urlencoded"},
                method="POST",
            )
            try:
                with urllib.request.urlopen(request, timeout=120) as response:
                    result = json.loads(response.read().decode("utf-8"))
                elements = result.get("elements")
                if not isinstance(elements, list):
                    raise RuntimeError("Réponse Overpass invalide")
                return elements
            except Exception as exc:
                errors.append(f"{endpoint}: {type(exc).__name__}: {exc}")
                if attempt == 0:
                    time.sleep(3)
    raise RuntimeError("Tous les serveurs Overpass ont échoué :\n" + "\n".join(errors))


def main() -> None:
    from shapely.geometry import Point, mapping

    south, west, north, east = BBOX
    dem_south, dem_west, dem_north, dem_east = CURRENT_DEM_BBOX
    elements = fetch_candidates()
    unique = {}
    for element in elements:
        tags = element.get("tags") or {}
        name = str(tags.get("name", "")).strip()
        place = str(tags.get("place", "")).strip().lower()
        if not name or not place:
            continue
        if element.get("type") == "node":
            lon, lat = element.get("lon"), element.get("lat")
        else:
            center = element.get("center") or {}
            lon, lat = center.get("lon"), center.get("lat")
        if lon is None or lat is None:
            continue
        lon, lat = float(lon), float(lat)
        if not (west <= lon <= east and south <= lat <= north):
            continue
        osm_type = str(element.get("type", ""))
        osm_id = int(element["id"])
        key = f"{osm_type}/{osm_id}"
        unique[key] = {
            "type": "Feature",
            "id": key,
            "properties": {
                "osm_id": osm_id,
                "osm_type": osm_type,
                "name": name,
                "place": place,
                "source": "OpenStreetMap",
                "candidate_status": "à vérifier avant intégration",
                "inside_current_dem": dem_west <= lon <= dem_east and dem_south <= lat <= dem_north,
            },
            "geometry": mapping(Point(lon, lat)),
        }

    collection = {
        "type": "FeatureCollection",
        "name": "libreville_locality_candidates_extended",
        "metadata": {
            "source": "OpenStreetMap contributors",
            "attribution": "© OpenStreetMap contributors",
            "license": "ODbL 1.0",
            "extracted_at_utc": datetime.now(timezone.utc).isoformat(),
            "search_bbox_south_west_north_east": list(BBOX),
            "current_dem_bbox_south_west_north_east": list(CURRENT_DEM_BBOX),
            "warning": "Points candidats uniquement. Cette emprise élargie ne représente pas une limite administrative. Ne pas créer de téléporteur ou de polygone avant vérification de la commune, de l'arrondissement et de l'emprise du terrain.",
        },
        "features": list(unique.values()),
    }
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    temp = OUTPUT.with_suffix(".geojson.tmp")
    temp.write_text(json.dumps(collection, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
    temp.replace(OUTPUT)
    inside = sum(1 for feature in unique.values() if feature["properties"]["inside_current_dem"])
    print(f"Localités candidates : {len(unique)}")
    print(f"Dans le DEM actuel : {inside}")
    print(f"Hors du DEM actuel : {len(unique) - inside}")
    print(f"Fichier créé : {OUTPUT}")


if __name__ == "__main__":
    main()
