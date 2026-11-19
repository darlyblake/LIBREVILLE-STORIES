#!/usr/bin/env python3
"""Extraction OSM régionale isolée : ne remplace jamais data/osm/*.geojson."""
from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TOOLS = Path(__file__).resolve().parent
sys.path.insert(0, str(TOOLS))

import extract_libreville as extractor  # noqa: E402

extractor.OUTPUT = ROOT / "data" / "osm" / "extended"
extractor.CACHE = extractor.OUTPUT / ".tiles"

if __name__ == "__main__":
    extractor.main()
