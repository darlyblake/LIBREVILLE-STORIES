#!/usr/bin/env python3
"""Validate the reusable 3D character library and any exported GLB assets.

Pending recipes are allowed to reference GLBs that have not been exported yet.
Once a recipe status is changed to "exported", its GLB must exist and have a
valid GLB 2.0 container header.
"""
from __future__ import annotations

import json
import struct
import sys
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "data" / "characters" / "character_library.json"
ALLOWED_STATUSES = {"recipe_pending_export", "exported", "integrated"}
REQUIRED_TOP_LEVEL = {"schema_version", "project", "generator", "engine", "policy", "performance", "starter_characters"}


class ValidationError(Exception):
    pass


def fail(message: str) -> None:
    raise ValidationError(message)


def validate_glb(path: Path) -> None:
    if not path.is_file():
        fail(f"GLB déclaré comme exporté mais introuvable : {path.relative_to(ROOT)}")
    size = path.stat().st_size
    if size < 20:
        fail(f"GLB trop petit ou tronqué : {path.relative_to(ROOT)} ({size} octets)")
    with path.open("rb") as stream:
        header = stream.read(12)
    magic, version, declared_length = struct.unpack("<4sII", header)
    if magic != b"glTF":
        fail(f"Signature GLB invalide : {path.relative_to(ROOT)}")
    if version != 2:
        fail(f"Version GLB non prise en charge (attendu 2) : {path.relative_to(ROOT)}")
    if declared_length != size:
        fail(
            f"Taille GLB incohérente pour {path.relative_to(ROOT)} : "
            f"en-tête={declared_length}, fichier={size}"
        )


def validate() -> int:
    if not MANIFEST.is_file():
        fail("Manifest introuvable : data/characters/character_library.json")

    try:
        data: dict[str, Any] = json.loads(MANIFEST.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        fail(f"JSON invalide dans le manifest (ligne {exc.lineno}, colonne {exc.colno})")

    missing = REQUIRED_TOP_LEVEL - data.keys()
    if missing:
        fail("Clés obligatoires manquantes : " + ", ".join(sorted(missing)))
    if data["schema_version"] != 1:
        fail(f"schema_version non prise en charge : {data['schema_version']!r}")
    if data["project"] != "LIBREVILLE STORIES":
        fail("Le champ project doit être 'LIBREVILLE STORIES'")

    engine = data["engine"]
    if not isinstance(engine, dict) or engine.get("format") != "glb":
        fail("Le format moteur attendu est GLB")
    if engine.get("version") != "4.3":
        fail("La version Godot du manifest doit rester synchronisée sur 4.3")

    characters = data["starter_characters"]
    if not isinstance(characters, list) or not characters:
        fail("starter_characters doit être une liste non vide")

    seen_ids: set[str] = set()
    pending = 0
    exported = 0
    for index, character in enumerate(characters):
        if not isinstance(character, dict):
            fail(f"starter_characters[{index}] doit être un objet")
        character_id = character.get("id")
        if not isinstance(character_id, str) or not character_id.strip():
            fail(f"starter_characters[{index}] possède un id vide ou invalide")
        if character_id in seen_ids:
            fail(f"Identifiant de personnage dupliqué : {character_id}")
        seen_ids.add(character_id)

        status = character.get("status")
        if status not in ALLOWED_STATUSES:
            fail(f"Statut invalide pour {character_id} : {status!r}")

        output = character.get("output")
        if not isinstance(output, str) or not output.endswith(".glb"):
            fail(f"Chemin GLB invalide pour {character_id}")
        relative = Path(output)
        if relative.is_absolute() or ".." in relative.parts:
            fail(f"Chemin de sortie interdit pour {character_id} : {output}")
        if not output.startswith("assets/characters/"):
            fail(f"Les modèles doivent rester dans assets/characters/ : {output}")

        asset_path = ROOT / relative
        if status in {"exported", "integrated"}:
            validate_glb(asset_path)
            exported += 1
        else:
            pending += 1
            if asset_path.exists():
                # Even a pending asset must not silently be a corrupt placeholder.
                validate_glb(asset_path)

    print(
        "Bibliothèque de personnages valide : "
        f"{len(characters)} recette(s), {exported} GLB exporté(s)/intégré(s), "
        f"{pending} en attente d'export."
    )
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(validate())
    except ValidationError as error:
        print(f"ERREUR — {error}", file=sys.stderr)
        raise SystemExit(1)
