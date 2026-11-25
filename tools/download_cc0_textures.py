#!/usr/bin/env python3
"""Télécharge des matériaux PBR CC0 Poly Haven pour LIBREVILLE STORIES.

Usage:
  python3 tools/download_cc0_textures.py
  python3 tools/download_cc0_textures.py --resolution 4k

Les fichiers sont conservés dans assets/textures/pbr/<asset_id>/.
Le script n'envoie rien sur un serveur : il télécharge les fichiers originaux
depuis l'API officielle Poly Haven et conserve les métadonnées d'auteur.
"""
from __future__ import annotations

import argparse
import json
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DESTINATION = ROOT / "assets" / "textures" / "pbr"
USER_AGENT = "LibrevilleStoriesAssetPipeline/1.0 (CC0 game materials)"
ASSETS = [
    "asphalt_02",
    "concrete_floor_01",
    "white_plaster_02",
    "red_bricks_04",
    "corrugated_iron_03",
    "rusty_metal_02",
    "rough_wood",
    "coast_sand_01",
    "sand_02",
    "gravel_01",
    "dirt",
    "grass",
]
MAPS = {"diff", "nor_gl", "rough", "ao", "metal", "disp"}


def get_json(url: str):
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(request, timeout=45) as response:
        return json.loads(response.read().decode("utf-8"))


def find_maps(node, path=()):
    found = {}
    if isinstance(node, dict):
        if isinstance(node.get("url"), str):
            map_name = next((part for part in reversed(path) if part in MAPS), None)
            if map_name:
                found[map_name] = node
        for key, value in node.items():
            found.update(find_maps(value, path + (str(key).lower(),)))
    elif isinstance(node, list):
        for index, value in enumerate(node):
            found.update(find_maps(value, path + (str(index),)))
    return found


def pick_resolution(files: dict, requested: str):
    for resolution in (requested, "2k", "1k", "4k", "8k"):
        if resolution in files:
            maps = find_maps(files[resolution])
            if maps:
                return resolution, maps
    maps = find_maps(files)
    return ("API fallback", maps) if maps else (None, {})


def download(url: str, destination: Path):
    destination.parent.mkdir(parents=True, exist_ok=True)
    if destination.exists() and destination.stat().st_size > 1024:
        print(f"  déjà présent : {destination.name}")
        return
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(request, timeout=120) as response:
        data = response.read()
    if len(data) < 1024:
        raise RuntimeError(f"Fichier trop petit : {url}")
    destination.write_bytes(data)
    print(f"  téléchargé : {destination.name} ({len(data) // 1024} Ko)")


def main():
    parser = argparse.ArgumentParser(description="Télécharger des matériaux PBR CC0 Poly Haven")
    parser.add_argument("--resolution", choices=("1k", "2k", "4k", "8k"), default="2k")
    args = parser.parse_args()

    print("LIBREVILLE STORIES — bibliothèque de matériaux PBR CC0")
    print("Source : Poly Haven | Licence des assets : CC0")
    print(f"Résolution demandée : {args.resolution}")
    DESTINATION.mkdir(parents=True, exist_ok=True)

    try:
        catalogue = get_json("https://api.polyhaven.com/assets?type=textures")
    except Exception as error:
        print(f"Impossible de joindre l'API Poly Haven : {error}", file=sys.stderr)
        return 2

    available = set(catalogue.keys())
    downloaded = 0
    missing = []
    for slug in ASSETS:
        if slug not in available:
            missing.append(slug)
            print(f"[ignoré] Asset absent du catalogue actuel : {slug}")
            continue
        print(f"[{slug}]")
        try:
            files = get_json(f"https://api.polyhaven.com/files/{urllib.parse.quote(slug)}")
            resolution, maps = pick_resolution(files, args.resolution)
            if not maps:
                print("  aucune carte PBR exploitable dans la réponse API")
                continue
            print(f"  résolution utilisée : {resolution}")
            folder = DESTINATION / slug
            folder.mkdir(parents=True, exist_ok=True)
            saved = 0
            for map_name in sorted(MAPS):
                item = maps.get(map_name)
                if not item or not item.get("url"):
                    continue
                url = item["url"]
                extension = Path(urllib.parse.urlparse(url).path).suffix or ".jpg"
                target = folder / f"{slug}_{map_name}{extension}"
                download(url, target)
                saved += 1
            metadata = {
                "name": catalogue[slug].get("name", slug),
                "source": f"https://polyhaven.com/a/{slug}",
                "license": "CC0",
                "authors": catalogue[slug].get("authors", {}),
                "resolution_requested": args.resolution,
                "resolution_downloaded": resolution,
                "downloaded_at_utc": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
            }
            (folder / "asset.json").write_text(json.dumps(metadata, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
            downloaded += saved
        except (urllib.error.URLError, TimeoutError, ValueError, RuntimeError) as error:
            print(f"  ERREUR : {error}", file=sys.stderr)

    print(f"\nCartes téléchargées : {downloaded}")
    if missing:
        print("Assets non trouvés (ils seront simplement ignorés) : " + ", ".join(missing))
    print("Les textures sont dans assets/textures/pbr/.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
