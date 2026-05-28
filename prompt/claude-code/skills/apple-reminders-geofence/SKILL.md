---
name: apple-reminders-geofence
description: >
  Use this skill when creating, updating, or auditing Apple Reminders location alarms,
  geofence reminders, EventKit reminders, or Japanese リマインダー/ジオフェンス tasks on macOS.
  It covers venue verification, radius choice, duplicate-safe replacement, and read-back validation.
---

# Apple Reminders Geofence

## Pattern

Implement a stream-to-EventKit adapter: accept a declarative JSON reminder spec on stdin, write only at the macOS Reminders boundary, and emit a JSON verification summary on stdout.

Use this skill when the user wants reminders that fire near physical places: bank windows, offices, stations, stores, municipal offices, travel errands, or "近くに行った時に通知".

## Workflow

1. Verify the actionable destination before writing.
   - Prefer official pages for branch addresses, opening hours, and whether a location is a staffed counter or ATM-only.
   - For errands requiring staff, do not geofence ATM-only or vague neighborhood points as the primary target.
   - If a place can change, browse current official sources before claiming it is open or staffed.

2. Model reminders by action, not by map labels.
   - Primary reminder: the best actionable venue, with the user's strongest eligibility signal in notes, such as "口座あり".
   - Fallback reminder: only when it is a genuinely distinct venue cluster.
   - Put nearby alternatives in notes when they are within the same walking cluster; do not create noisy duplicate geofences.

3. Choose radius from the action boundary.
   - 150-250m: exact building or small venue.
   - 300-550m: walkable cluster or "notify when I am close enough to detour".
   - Avoid large city-neighborhood radii unless the user explicitly wants a broad nudge.

4. Write duplicate-safely.
   - Add a stable marker in notes.
   - Replace incomplete reminders containing the marker before creating new ones.
   - Preserve completed reminders unless the user explicitly asks to remove history.

5. Read back after writing.
   - Confirm title, calendar/list, radius, coordinates, and `proximity=enter`.
   - Report what changed and any uncertainty in the source data.

## Script

Use the bundled EventKit adapter:

```bash
swift ~/.codex/skills/apple-reminders-geofence/scripts/geofence_reminders.swift < spec.json
```

The same script works from the canonical repo path before projection:

```bash
swift prompt/claude-code/skills/apple-reminders-geofence/scripts/geofence_reminders.swift < spec.json
```

Input schema:

```json
{
  "marker": "[stable-marker]",
  "calendarTitle": null,
  "replaceIncompleteMatchingMarker": true,
  "items": [
    {
      "title": "SMBC京都支店/四条支店: 1万円札を窓口で交換",
      "notes": "第一候補。口座あり。平日9:00-15:00目安。",
      "locationTitle": "SMBC京都支店/四条支店（京都三井ビル）",
      "latitude": 35.0040466,
      "longitude": 135.760041,
      "radiusMeters": 520,
      "priority": 1,
      "proximity": "enter"
    }
  ]
}
```

`priority` follows Apple Reminders values: `1` high, `5` medium, `9` low, `0` none.

## Practical Notes

- Apple Reminders location alarms cannot reliably encode business-hour conditions. Put hours in notes instead.
- The script uses the default Reminders calendar unless `calendarTitle` names an existing list.
- Location coordinates are part of the contract. If geocoding is approximate, say that and choose a radius that matches the uncertainty.
- Treat account names, addresses, and errands as user-private context. Do not put sensitive identifiers in reusable examples.
