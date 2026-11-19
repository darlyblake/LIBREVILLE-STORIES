#!/usr/bin/env python3
"""Télécharge et prépare un DEM SRTM1 (≈30 m) pour toute l'emprise Libreville.

Prérequis : Python 3.10+, GDAL, rasterio, numpy et le paquet Python elevation.
Installation : python -m pip install elevation rasterio numpy
Le paquet elevation utilise les tuiles SRTM publiques et GDAL pour le découpage.
"""
from __future__ import annotations

import json
import math
import shutil
import subprocess
import sys
from pathlib import Path

import numpy as np
import rasterio
from rasterio.enums import Resampling
from rasterio.transform import from_origin
from rasterio.warp import reproject

ROOT = Path(__file__).resolve().parents[2]
REPORT = ROOT / "data/osm/extraction-report.json"
OUT_DIR = ROOT / "data/terrain"
SOURCE_TIF = OUT_DIR / "libreville_srtm1_source.tif"
RAW_FILE = OUT_DIR / "libreville_dem_f32.bin"
META_FILE = OUT_DIR / "libreville_dem.json"

CENTER_LAT = 0.400
CENTER_LON = 9.4475
METERS_PER_DEG_LAT = 111320.0
TARGET_SPACING_M = 30.0


def main() -> int:
    if shutil.which("eio") is None:
        print("Commande eio absente. Installez : python -m pip install elevation", file=sys.stderr)
        return 2
    report = json.loads(REPORT.read_text(encoding="utf-8"))
    south, west, north, east = report["bbox_south_west_north_east"]
    # Petite marge pour éviter les bords sans données après rééchantillonnage.
    margin_lat = TARGET_SPACING_M / METERS_PER_DEG_LAT * 2
    margin_lon = margin_lat / math.cos(math.radians(CENTER_LAT))
    south -= margin_lat
    north += margin_lat
    west -= margin_lon
    east += margin_lon

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    command = [
        "eio", "clip", "-o", str(SOURCE_TIF),
        "--bounds", str(west), str(south), str(east), str(north),
        "--product", "SRTM1",
    ]
    print("Téléchargement/découpage SRTM1 :", " ".join(command))
    subprocess.run(command, check=True)

    lon_step = TARGET_SPACING_M / (METERS_PER_DEG_LAT * math.cos(math.radians(CENTER_LAT)))
    lat_step = TARGET_SPACING_M / METERS_PER_DEG_LAT
    width = math.ceil((east - west) / lon_step)
    height = math.ceil((north - south) / lat_step)
    transform = from_origin(west, north, lon_step, lat_step)
    target = np.full((height, width), np.nan, dtype=np.float32)

    with rasterio.open(SOURCE_TIF) as src:
        reproject(
            source=rasterio.band(src, 1),
            destination=target,
            src_transform=src.transform,
            src_crs=src.crs,
            src_nodata=src.nodata,
            dst_transform=transform,
            dst_crs="EPSG:4326",
            dst_nodata=np.nan,
            resampling=Resampling.bilinear,
        )

    # SRTM ne fournit pas de bathymétrie : les cellules sans donnée (mer) sont
    # ramenées au niveau 0 m. Les trous terrestres résiduels sont interpolés
    # avec le pixel valide le plus proche, afin de ne pas créer de trous mesh.
    valid = np.isfinite(target)
    if not valid.any():
        raise RuntimeError("Le DEM téléchargé ne contient aucune altitude valide.")
    land = target[valid]
    target[~valid] = 0.0
    # Filtre des valeurs aberrantes évidentes, sans exagérer les pentes.
    target = np.clip(target, -5.0, 500.0).astype("<f4", copy=False)

    # Conversion des coordonnées géographiques vers le repère monde Godot.
    x_min = (west - CENTER_LON) * METERS_PER_DEG_LAT * math.cos(math.radians(CENTER_LAT))
    z_min = (CENTER_LAT - north) * METERS_PER_DEG_LAT
    target.tofile(RAW_FILE)
    metadata = {
        "source": "NASA/NGA SRTM 1 arc-second (SRTM1), via elevation",
        "license_note": "Respecter les conditions et l'attribution de la source SRTM utilisée.",
        "source_bbox_south_west_north_east": [south, west, north, east],
        "center_lat": CENTER_LAT,
        "center_lon": CENTER_LON,
        "rows": int(height),
        "columns": int(width),
        "spacing_m": TARGET_SPACING_M,
        "x_min": x_min,
        "z_min": z_min,
        "min_elevation_m": float(np.nanmin(land)),
        "max_elevation_m": float(np.nanmax(land)),
        "valid_source_cells": int(valid.sum()),
        "nodata_cells_set_to_zero": int((~valid).sum()),
        "encoding": "row-major little-endian float32; row 0 = north; columns increase east",
    }
    META_FILE.write_text(json.dumps(metadata, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"DEM prêt : {RAW_FILE}")
    print(f"Grille : {width} × {height} | altitudes sources : {metadata['min_elevation_m']:.1f} à {metadata['max_elevation_m']:.1f} m")
    print(f"Métadonnées : {META_FILE}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
