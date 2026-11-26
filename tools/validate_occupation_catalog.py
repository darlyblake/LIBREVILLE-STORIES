#!/usr/bin/env python3
"""Validate the Libreville occupation and social-profile catalogue."""
import json
from pathlib import Path

path = Path("data/population/occupation_and_social_profiles.json")
data = json.loads(path.read_text(encoding="utf-8"))
assert data.get("version") == 1
sectors = data.get("sectors", [])
assert sectors, "At least one occupation sector is required"
sector_ids = [sector.get("id") for sector in sectors]
assert len(sector_ids) == len(set(sector_ids)), "Duplicate sector id"
occupations = []
for sector in sectors:
    assert sector.get("label"), "Sector label missing"
    entries = sector.get("occupations", [])
    assert entries, f"Empty sector: {sector.get('id')}"
    occupations.extend(entries)
assert len(occupations) == len(set(occupations)), "Duplicate occupation"
social_ids = [profile.get("id") for profile in data.get("social_profiles", [])]
assert len(social_ids) == len(set(social_ids)), "Duplicate social profile id"
for profile in data.get("social_profiles", []):
    assert profile.get("label") and profile.get("description")
    assert profile.get("behaviors"), f"Missing behaviors for {profile.get('id')}"
print(f"Occupation catalogue valid: {len(sectors)} sectors, {len(occupations)} occupations, {len(social_ids)} social profiles")
