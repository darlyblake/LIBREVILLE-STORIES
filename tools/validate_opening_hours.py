#!/usr/bin/env python3
"""Validate the data-driven opening-hours profiles used by WorldClock."""
import json
import sys
from pathlib import Path

PATH = Path("data/calendar/opening_hours.json")


def fail(message: str) -> None:
    print(f"ERREUR horaires: {message}", file=sys.stderr)
    raise SystemExit(1)


def main() -> None:
    try:
        data = json.loads(PATH.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        fail(f"fichier JSON illisible: {exc}")
    profiles = data.get("profiles") if isinstance(data, dict) else None
    if not isinstance(profiles, dict) or not profiles:
        fail("la racine doit contenir un objet 'profiles' non vide")
    for profile_id, profile in profiles.items():
        if not isinstance(profile_id, str) or not isinstance(profile, dict):
            fail("chaque profil doit être un objet avec un identifiant texte")
        if profile.get("always_open") is True:
            continue
        days = profile.get("days")
        if not isinstance(days, dict):
            fail(f"{profile_id}: 'days' doit être un objet")
        for weekday, ranges in days.items():
            if weekday not in {str(i) for i in range(7)}:
                fail(f"{profile_id}: jour invalide '{weekday}' (0=dimanche)")
            if not isinstance(ranges, list):
                fail(f"{profile_id}: les plages du jour {weekday} doivent être une liste")
            for item in ranges:
                if not isinstance(item, list) or len(item) not in (2, 4):
                    fail(f"{profile_id}: plage invalide {item!r}")
                if any(not isinstance(v, int) for v in item):
                    fail(f"{profile_id}: heures/minutes doivent être des entiers")
                if len(item) == 2:
                    start, end = item[0] * 60, item[1] * 60
                else:
                    start, end = item[0] * 60 + item[1], item[2] * 60 + item[3]
                    if not (0 <= item[1] < 60 and 0 <= item[3] < 60):
                        fail(f"{profile_id}: minutes hors limites")
                if not (0 <= start < end <= 1440):
                    fail(f"{profile_id}: plage horaire hors limites ou inversée: {item!r}")
    print(f"Horaires valides: {len(profiles)} profils, jours et plages contrôlés.")


if __name__ == "__main__":
    main()
