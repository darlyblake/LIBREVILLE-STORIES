#!/usr/bin/env python3
"""Validate life-simulation profiles and crowd/activity parameters."""
import json
from pathlib import Path

path = Path("data/simulation/life_profiles.json")
data = json.loads(path.read_text(encoding="utf-8"))
assert data.get("version") == 1, "Unsupported life profile version"
employment = data.get("employment", {})
leave_days = employment.get("annual_leave_calendar_days")
assert isinstance(leave_days, int) and 1 <= leave_days <= 45, "Annual leave must be 1..45 calendar days"
for job, profile in data.get("job_profiles", {}).items():
    start, end = profile.get("start_hour"), profile.get("end_hour")
    assert isinstance(start, int) and isinstance(end, int), f"{job}: work hours must be integers"
    assert 0 <= start <= 23 and 0 <= end <= 24 and start != end, f"{job}: invalid work-hour range"
nightlife = data.get("nightlife", {})
for key in ("weekday_chance", "weekend_chance", "holiday_chance", "alcohol_per_hour"):
    value = nightlife.get(key)
    assert isinstance(value, (int, float)) and 0.0 <= value <= 1.0, f"nightlife.{key} must be between 0 and 1"
for place, profile in data.get("crowds", {}).items():
    for key in ("weekday_day", "weekend_day", "school_holiday_factor"):
        value = profile.get(key)
        assert isinstance(value, (int, float)) and 0.0 <= value <= 3.0, f"{place}.{key} outside 0..3"
    night_factor = profile.get("night_hours", {}).get("factor", 1.0)
    assert isinstance(night_factor, (int, float)) and 0.0 <= night_factor <= 3.0, f"{place}: invalid night factor"
print(f"Life simulation profiles valid: {len(data.get('job_profiles', {}))} jobs, {len(data.get('crowds', {}))} place types")
