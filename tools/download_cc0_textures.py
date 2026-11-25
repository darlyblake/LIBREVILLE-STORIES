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
HDRI_DESTINATION = ROOT / "assets" / "sky"
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
    "dirty_concrete",
    "concrete_pavement_03",
    "leafy_grass",
    "bark_brown_02",
    "brown_mud_leaves_01",
    "coast_sand_rocks_02",
] 
HDRI_ASSETS = ["the_sky_is_on_fire"]
MAP_ALIASES = {
    "diff": "diff", "diffuse": "diff", "color": "diff", "colour": "diff",
    "albedo": "diff", "basecolor": "diff", "base_color": "diff",
    "nor_gl": "nor_gl", "normal": "nor_gl", "normal_gl": "nor_gl",
    "rough": "rough", "roughness": "rough",
    "ao": "ao", "ambient_occlusion": "ao",
    "metal": "metal", "metalness": "metal",
    "disp": "disp", "displacement": "disp", "height": "disp",
}
MAPS = set(MAP_ALIASES.keys())


def get_json(url: str):
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(request, timeout=45) as response:
        return json.loads(response.read().decode("utf-8"))


def collect_map_files(node, path=()):
    found = []
    if isinstance(node, dict):
        if isinstance(node.get("url"), str):
            raw_map_name = next((part for part in reversed(path) if part in MAPS), None)
            if raw_map_name:
                found.append((MAP_ALIASES[raw_map_name], path, node))
        for key, value in node.items():
            found.extend(collect_map_files(value, path + (str(key).lower(),)))
    elif isinstance(node, list):
        for index, value in enumerate(node):
            found.extend(collect_map_files(value, path + (str(index),)))
    return found


def pick_resolution(files: dict, requested: str):
    all_maps = collect_map_files(files)
    for resolution in dict.fromkeys((requested, "2k", "1k", "4k", "8k")):
        candidates = [entry for entry in all_maps if resolution in entry[1]]
        if candidates:
            selected = {}
            for map_name, path, item in candidates:
                # Prefer JPG where available; otherwise retain the API's original format.
                score = 0 if "jpg" in path else 1 if "png" in path else 2
                previous = selected.get(map_name)
                if previous is None or score < previous[0]:
                    selected[map_name] = (score, item)
            return resolution, {key: value[1] for key, value in selected.items()}
    selected = {}
    for map_name, path, item in all_maps:
        score = 0 if "2k" in path else 1 if "1k" in path else 2
        previous = selected.get(map_name)
        if previous is None or score < previous[0]:
            selected[map_name] = (score, item)
    return ("API fallback", {key: value[1] for key, value in selected.items()}) if selected else (None, {})


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


def collect_hdri_files(node, path=()):
    found = []
    if isinstance(node, dict):
        url = node.get("url")
        if isinstance(url, str):
            extension = Path(urllib.parse.urlparse(url).path).suffix.lower()
            if extension in {".hdr", ".exr"}:
                found.append((path, node, extension))
        for key, value in node.items():
            found.extend(collect_hdri_files(value, path + (str(key).lower(),)))
    elif isinstance(node, list):
        for index, value in enumerate(node):
            found.extend(collect_hdri_files(value, path + (str(index),)))
    return found


def download_hdris(requested_resolution: str):
    try:
        catalogue = get_json("https://api.polyhaven.com/assets?type=hdris")
    except Exception as error:
        print(f"Catalogue HDRI indisponible : {error}")
        return 0
    downloaded = 0
    for slug in HDRI_ASSETS:
        if slug not in catalogue:
            print(f"[HDRI ignorée] Asset absent du catalogue : {slug}")
            continue
        try:
            files = get_json(f"https://api.polyhaven.com/files/{urllib.parse.quote(slug)}")
            candidates = collect_hdri_files(files)
            selected = None
            for resolution in (requested_resolution, "2k", "1k", "4k", "8k", "16k"):
                matching = [item for item in candidates if resolution in item[0]]
                if matching:
                    # Préférer HDR compact pour Godot ; EXR reste un secours.
                    matching.sort(key=lambda item: (0 if item[2] == ".hdr" else 1, len(item[0])))
                    selected = (resolution, matching[0])
                    break
            if selected is None:
                print(f"[HDRI] Aucun fichier HDR/EXR exploitable pour {slug}")
                continue
            resolution, (path, item, extension) = selected
            HDRI_DESTINATION.mkdir(parents=True, exist_ok=True)
            target = HDRI_DESTINATION / f"{slug}_{resolution}{extension}"
            download(item["url"], target)
            metadata = {
                "name": catalogue[slug].get("name", slug),
                "source": f"https://polyhaven.com/a/{slug}",
                "license": "CC0",
                "authors": catalogue[slug].get("authors", {}),
                "resolution_downloaded": resolution,
                "format": extension.lstrip("."),
                "downloaded_at_utc": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
            }
            (HDRI_DESTINATION / f"{slug}_{resolution}.json").write_text(
                json.dumps(metadata, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
            )
            downloaded += 1
        except (urllib.error.URLError, TimeoutError, ValueError, RuntimeError) as error:
            print(f"[HDRI] Erreur {slug}: {error}", file=sys.stderr)
    return downloaded


def main():
    parser = argparse.ArgumentParser(description="Télécharger des matériaux PBR CC0 Poly Haven")
    parser.add_argument("--resolution", choices=("1k", "2k", "4k", "8k"), default="4k")
    args = parser.parse_args()

    print("LIBREVILLE STORIES — bibliothèque de matériaux PBR CC0")
    print("Source : Poly Haven | Licence des assets : CC0")
    print("HDRI côtier CC0 : The Sky Is On Fire")
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
            print("  cartes disponibles : " + ", ".join(sorted(maps.keys())))
            if "diff" not in maps:
                print("  ATTENTION : carte couleur absente de la réponse API, vérifier le format de l'asset")
            print(f"  résolution utilisée : {resolution}")
            folder = DESTINATION / slug
            folder.mkdir(parents=True, exist_ok=True)
            metadata_path = folder / "asset.json"
            resolution_rank = {"1k": 1, "2k": 2, "4k": 3, "8k": 4}
            previous_resolution = ""
            if metadata_path.exists():
                try:
                    previous_resolution = json.loads(metadata_path.read_text(encoding="utf-8")).get("resolution_downloaded", "")
                except (OSError, ValueError):
                    previous_resolution = ""
            if resolution_rank.get(resolution, 0) > resolution_rank.get(previous_resolution, 0):
                for old_file in folder.iterdir():
                    if old_file.is_file() and old_file.name != "asset.json":
                        old_file.unlink()
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
    print("Les textures sont dans assets/textures/pbr/ et les HDRI dans assets/sky/.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
