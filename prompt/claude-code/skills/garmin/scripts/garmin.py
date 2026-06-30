"""Garmin thin client — token-only, stream-out JSON.

Zero credential knowledge: garminconnect reads the canonical token from the
GARMINTOKENS env var (injected by `sops exec-env`). Each subcommand is a pure
read that emits JSON on stdout. `.fit` is downloaded + parsed server-side here
(garmin-fit-sdk); callers never touch raw binary.

Dispatch is a table lookup (no statement-style branching); an unknown command
or a failed call surfaces as a JSON error + nonzero exit, so a broken pipe
never crashes the agent silently.
"""
import io
import os
import sys
import json
import zipfile
from datetime import date, timedelta
from pathlib import Path

from garminconnect import Garmin

FIT_DIR = Path(os.environ.get("GARMIN_FIT_DIR", "~/HealthData/FitFiles/skill")).expanduser()


def _today() -> str:
    return date.today().isoformat()


def _ndays_ago(n: int) -> str:
    return (date.today() - timedelta(days=n)).isoformat()


def _client() -> Garmin:
    # login() with no arg reads GARMINTOKENS from env (>512 chars => loads()).
    os.environ.get("GARMINTOKENS") or sys.exit(
        json.dumps({"ok": False, "error": "GARMINTOKENS not set — run via the `garmin` wrapper (sops exec-env)"})
    )
    g = Garmin()
    g.login()
    return g


def _activity_summary(a: dict) -> dict:
    return {
        "id": a.get("activityId"),
        "name": a.get("activityName"),
        "type": (a.get("activityType") or {}).get("typeKey"),
        "start": a.get("startTimeLocal"),
        "distance_m": a.get("distance"),
        "duration_s": a.get("duration"),
        "avg_hr": a.get("averageHR"),
        "calories": a.get("calories"),
    }


def _fit(g: Garmin, activity_id: str, *_rest) -> dict:
    raw = g.download_activity(int(activity_id), dl_fmt=Garmin.ActivityDownloadFormat.ORIGINAL)
    FIT_DIR.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(io.BytesIO(raw)) as zf:
        names = [n for n in zf.namelist() if n.lower().endswith(".fit")]
        fit_bytes = zf.read(names[0]) if names else b""
    out = FIT_DIR / f"{activity_id}.fit"
    out.write_bytes(fit_bytes)
    return {"activity_id": activity_id, "fit_path": str(out), "bytes": len(fit_bytes), **_fit_parse(fit_bytes)}


def _fit_parse(fit_bytes: bytes) -> dict:
    from garmin_fit_sdk import Decoder, Stream

    decoder = Decoder(Stream.from_byte_array(bytearray(fit_bytes)))
    messages, errors = decoder.read(convert_datetimes_to_dates=False)
    counts = {k: len(v) for k, v in messages.items()}
    sessions = messages.get("session_mesgs") or []
    return {
        "fit_message_counts": counts,
        "fit_errors": len(errors or []),
        "session": ({
            "sport": sessions[0].get("sport"),
            "total_distance": sessions[0].get("total_distance"),
            "total_elapsed_time": sessions[0].get("total_elapsed_time"),
            "avg_heart_rate": sessions[0].get("avg_heart_rate"),
            "total_ascent": sessions[0].get("total_ascent"),
        } if sessions else None),
    }


def _resp(r) -> dict:
    """Write-response -> json-able summary; tolerates empty/non-JSON bodies (toResult)."""
    parsed = None
    try:
        parsed = r.json()
    except Exception:
        parsed = (getattr(r, "text", "") or "")[:1000] or None
    code = getattr(r, "status_code", None)
    return {"status": code, "ok": 200 <= (code or 0) < 300, "body": parsed}


def _retire(g, gear_pk, *_rest) -> dict:
    """Retire a gear: fetch its full DTO, flip status to retired + set dateEnd, PUT back.

    The lib has no retire endpoint; the web app PUTs the *complete* gear object to
    /gear-service/gear/{gearPk} with gearStatusName=retired (forum-confirmed). We read
    the canonical object first so the round-trip never drops fields.
    """
    profile = (g.connectapi("/userprofile-service/socialProfile") or {}).get("profileId")
    gears = g.connectapi(f"/gear-service/gear/filterGear?userProfilePk={profile}") or []
    target = next((x for x in gears if str(gear_pk) in (str(x.get("gearPk")), str(x.get("uuid")))), None)
    target or sys.exit(json.dumps(
        {"ok": False, "error": f"gear {gear_pk} not found for profile {profile}"}, ensure_ascii=False
    ))
    uuid = target.get("uuid")  # the PUT path keys on uuid, not gearPk (server enforces uuid match)
    body = {**target, "gearStatusName": "retired",
            "dateEnd": target.get("dateEnd") or (_today() + "T00:00:00.0")}
    return _resp(g.client.put("connectapi", f"/gear-service/gear/{uuid}", json=body, api=True))


# subcommand -> (callable(g, *args) -> json-able). Pure table; no if-chains.
COMMANDS = {
    "recent": lambda g, *a: [_activity_summary(x) for x in (g.get_activities(0, int(a[0]) if a else 10) or [])],
    "last": lambda g, *a: _activity_summary(g.get_last_activity() or {}),
    "activity": lambda g, *a: g.get_activity(int(a[0])),
    "details": lambda g, *a: g.get_activity_details(int(a[0])),
    "splits": lambda g, *a: g.get_activity_splits(int(a[0])),
    "weather": lambda g, *a: g.get_activity_weather(int(a[0])),
    "fit": _fit,
    "sleep": lambda g, *a: g.get_sleep_data(a[0] if a else _today()),
    "stress": lambda g, *a: g.get_stress_data(a[0] if a else _today()),
    "steps": lambda g, *a: g.get_steps_data(a[0] if a else _today()),
    "hrv": lambda g, *a: g.get_hrv_data(a[0] if a else _today()),
    "rhr": lambda g, *a: g.get_rhr_day(a[0] if a else _today()),
    "bodybattery": lambda g, *a: g.get_body_battery(a[0] if a else _ndays_ago(1), a[1] if len(a) > 1 else _today()),
    "stats": lambda g, *a: g.get_stats(a[0] if a else _today()),
    "summary": lambda g, *a: g.get_user_summary(a[0] if a else _today()),
    "readiness": lambda g, *a: g.get_training_readiness(a[0] if a else _today()),
    "status": lambda g, *a: g.get_training_status(a[0] if a else _today()),
    "spo2": lambda g, *a: g.get_spo2_data(a[0] if a else _today()),
    "respiration": lambda g, *a: g.get_respiration_data(a[0] if a else _today()),
    "weight": lambda g, *a: g.get_weigh_ins(a[0] if a else _ndays_ago(30), a[1] if len(a) > 1 else _today()),
    "devices": lambda g, *a: g.get_devices(),
    "profile": lambda g, *a: {"name": g.get_full_name(), "units": g.get_unit_system()},
    "rename": lambda g, *a: (g.set_activity_name(a[0], a[1]), {"renamed": a[0], "title": a[1]})[1],
    "settype": lambda g, *a: _resp(g.set_activity_type(a[0], int(a[1]), a[2], int(a[3]))),
    "gear": lambda g, *a: g.connectapi(f"/gear-service/gear/filterGear?userProfilePk={a[0]}"),
    "link": lambda g, *a: g.add_gear_to_activity(a[0], a[1]),     # (gearUUID, activityId)
    "unlink": lambda g, *a: g.remove_gear_from_activity(a[0], a[1]),
    "post": lambda g, *a: _resp(g.client.post("connectapi", a[0], json=(json.loads(a[1]) if len(a) > 1 and a[1] else None), api=True)),
    "put": lambda g, *a: _resp(g.client.put("connectapi", a[0], json=(json.loads(a[1]) if len(a) > 1 and a[1] else None), api=True)),
    "del": lambda g, *a: _resp(g.client.delete("connectapi", a[0], api=True)),
    "retire": _retire,                                            # gear_pk -> mark retired (read-merge-PUT)
    "raw": lambda g, *a: g.connectapi(a[0]),  # escape hatch: any Connect API GET path
}


def main(argv: list) -> None:
    cmd = argv[0] if argv else "recent"
    handler = COMMANDS.get(cmd)
    handler or sys.exit(json.dumps({
        "ok": False, "error": f"unknown command: {cmd}", "commands": sorted(COMMANDS)
    }, ensure_ascii=False))
    result = handler(_client(), *argv[1:])
    print(json.dumps(result, ensure_ascii=False, default=str))


main(sys.argv[1:])
