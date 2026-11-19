#!/usr/bin/env python3
"""Construit un DEM SRTM1 étendu, sans écraser le terrain actuel du jeu.

Emprise de travail régionale (non administrative) : 0.300–0.500 N,
9.370–9.550 E. Le fichier binaire est compatible avec world_map.gd :
float32 little-endian, ligne 0 au nord, colonnes vers l'est.
"""
from __future__ import annotations

import gzip
import json
import math
import tempfile
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

import numpy as np
import rasterio
from rasterio.transform import from_origin
from rasterio.warp import Resampling, reproject

ROOT = Path(__file__).resolve().parents[2]
SOUTH, WEST, NORTH, EAST = 0.300, 9.370, 0.500, 9.550
CENTER_LAT, CENTER_LON = 0.400, 9.4475
SPACING_M = 30.0
TILE_URL = "https://elevation-tiles-prod.s3.amazonaws.com/skadi/N00/N00E009.hgt.gz"
NODATA = -32768.0


def download_tile(destination: Path) -> None:
    request = urllib.request.Request(
        TILE_URL,
        headers={"User-Agent": "LIBREVILLE-STORIES terrain builder/1.0"},
    )
    with urllib.request.urlopen(request, timeout=180) as response:
        compressed = response.read()
    with gzip.open(__import__("io").BytesIO(compressed), "rb") as source:
        raw = source.read()
    expected = 3601 * 3601 * 2
    if len(raw) != expected:
        raise RuntimeError(f"Tuile SRTM inattendue : {len(raw)} octets, {expected} attendus")
    destination.write_bytes(raw)


def main() -> None:
    # 30 m environ, dans le même repère local que le monde Godot.
    lat_step = SPACING_M / 111320.0
    lon_step = SPACING_M / (111320.0 * math.cos(math.radians(CENTER_LAT)))
    columns = math.ceil((EAST - WEST) / lon_step)
    rows = math.ceil((NORTH - SOUTH) / lat_step)
    transform = from_origin(WEST, NORTH, lon_step, lat_step)

    with tempfile.TemporaryDirectory(prefix="libreville-dem-") as temp:
        hgt_path = Path(temp) / "N00E009.hgt"
        print("Téléchargement de la tuile SRTM1 N00E009…", flush=True)
        download_tile(hgt_path)
        with rasterio.open(hgt_path, driver="SRTM") as source:
            destination = np.full((rows, columns), NODATA, dtype=np.float32)
            reproject(
                source=rasterio.band(source, 1),
                destination=destination,
                src_transform=source.transform,
                src_crs=source.crs,
                src_nodata=source.nodata if source.nodata is not None else NODATA,
                dst_transform=transform,
                dst_crs="EPSG:4326",
                dst_nodata=NODATA,
                resampling=Resampling.bilinear,
                num_threads=2,
            )

    valid = np.isfinite(destination) & (destination != NODATA)
    valid_count = int(valid.sum())
    if valid_count < int(rows * columns * 0.95):
        raise RuntimeError(
            f"Couverture SRTM insuffisante : {valid_count}/{rows * columns} cellules valides"
        )
    nodata_count = int((~valid).sum())
    destination[~valid] = 0.0
    destination = np.asarray(destination, dtype="<f4", order="C")

    x_min = (WEST - CENTER_LON) * 111320.0 * math.cos(math.radians(CENTER_LAT))
    z_min = (CENTER_LAT - NORTH) * 111320.0
    actual_east = WEST + columns * lon_step
    actual_south = NORTH - rows * lat_step

    binary_path = ROOT / "libreville_dem_extended_f32.bin"
    meta_path = ROOT / "libreville_dem_extended.json"
    destination.tofile(binary_path)
    metadata = {
        "source": "NASA/NGA SRTM 1 arc-second (SRTM1), AWS elevation-tiles-prod mirror",
        "source_tile": "N00E009.hgt",
        "source_url": TILE_URL,
        "license_note": "Données d'altitude SRTM ; conserver l'attribution NASA/NGA et vérifier les conditions de redistribution.",
        "region_note": "Emprise régionale de travail pour le jeu, pas une limite administrative officielle de Libreville.",
        "requested_bbox_south_west_north_east": [SOUTH, WEST, NORTH, EAST],
        "actual_bbox_south_west_north_east": [actual_south, WEST, NORTH, actual_east],
        "center_lat": CENTER_LAT,
        "center_lon": CENTER_LON,
        "rows": rows,
        "columns": columns,
        "spacing_m": SPACING_M,
        "x_min": x_min,
        "z_min": z_min,
        "min_elevation_m": float(destination.min()),
        "max_elevation_m": float(destination.max()),
        "valid_source_cells": valid_count,
        "nodata_cells_set_to_zero": nodata_count,
        "encoding": "row-major little-endian float32; row 0 = north; columns increase east",
        "generated_at_utc": datetime.now(timezone.utc).isoformat(),
        "binary_file": binary_path.name,
    }
    meta_path.write_text(json.dumps(metadata, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    expected_bytes = rows * columns * 4
    if binary_path.stat().st_size != expected_bytes:
        raise RuntimeError("La taille du binaire généré ne correspond pas aux dimensions.")
    print(f"DEM étendu créé : {columns} x {rows} cellules, {expected_bytes:,} octets")
    print(f"Altitude : {metadata['min_elevation_m']:.1f} à {metadata['max_elevation_m']:.1f} m")
    print(f"Fichiers : {binary_path.name}, {meta_path.name}")


if __name__ == "__main__":
    main()
