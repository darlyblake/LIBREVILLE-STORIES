#!/usr/bin/env python3
"""Validate Gabon calendar data, including recurring ranges across New Year."""
import json
import sys
from datetime import date
from pathlib import Path

CALENDAR = Path("data/calendar/gabon_events.json")


def fail(message: str) -> None:
    print(f"ERREUR calendrier: {message}", file=sys.stderr)
    raise SystemExit(1)


def main() -> None:
    if not CALENDAR.is_file():
        fail(f"fichier absent: {CALENDAR}")
    try:
        payload = json.loads(CALENDAR.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        fail(f"JSON illisible: {exc}")

    if not isinstance(payload, dict) or not isinstance(payload.get("events"), list):
        fail("la racine doit contenir un tableau 'events'")

    seen = set()
    for index, event in enumerate(payload["events"]):
        prefix = f"events[{index}]"
        if not isinstance(event, dict):
            fail(f"{prefix} doit être un objet")
        event_id = event.get("id")
        if not isinstance(event_id, str) or not event_id.strip():
            fail(f"{prefix}.id manquant")
        if event_id in seen:
            fail(f"identifiant dupliqué: {event_id}")
        seen.add(event_id)

        for field in ("title", "category", "start_date", "end_date"):
            if not isinstance(event.get(field), str) or not event[field].strip():
                fail(f"{event_id}: champ '{field}' absent ou invalide")

        try:
            start = date.fromisoformat(event["start_date"])
            end = date.fromisoformat(event["end_date"])
        except ValueError as exc:
            fail(f"{event_id}: date ISO invalide ({exc})")

        annual = event.get("annual")
        if not isinstance(annual, bool):
            fail(f"{event_id}: 'annual' doit être booléen")
        if annual:
            if start.year != end.year:
                fail(f"{event_id}: les dates annuelles doivent partager une année de référence")
            # For recurring events, end < start is valid: the range wraps over New Year.
        elif end < start:
            fail(f"{event_id}: end_date précède start_date")

        if not isinstance(event.get("tags", []), list):
            fail(f"{event_id}: 'tags' doit être un tableau")
        if not isinstance(event.get("effects", {}), dict):
            fail(f"{event_id}: 'effects' doit être un objet")

    print(f"Calendrier valide: {len(seen)} événements, identifiants uniques, dates et structures corrects.")


if __name__ == "__main__":
    main()
