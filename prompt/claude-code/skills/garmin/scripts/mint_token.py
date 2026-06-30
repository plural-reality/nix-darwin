"""One-time Garmin auth → canonical token string.

Run ONCE (interactively, with email+password in env). Produces the single
canonical secret: garminconnect's session-state string (client.dumps()),
written to GARMIN_TOKEN_OUT with 0600 perms. That string becomes GARMINTOKENS
in SOPS; the raw password is never persisted. Verifies by pulling one activity.

The token (not the password) is what every later run uses. garminconnect's
curl_cffi engine impersonates a browser at the TLS layer, which is the fix for
the Cloudflare/429 block that killed the old garth mobile-UA path.
"""
import os
import sys
import json
import stat

from garminconnect import Garmin

EMAIL = os.environ["GARMIN_EMAIL"]
PASSWORD = os.environ["GARMIN_PASSWORD"]
OUT = os.path.expanduser(os.environ["GARMIN_TOKEN_OUT"])


class UnexpectedMFA(Exception):
    pass


def _mfa():
    # This account was verified to have no MFA; if Garmin asks, surface it
    # loudly rather than hanging on a non-interactive input().
    raise UnexpectedMFA()


garmin = Garmin(email=EMAIL, password=PASSWORD, prompt_mfa=_mfa)
needs_mfa, _ = garmin.login()  # no tokenstore → fresh credential login

needs_mfa and sys.exit(json.dumps({"ok": False, "reason": "mfa_required"}))

token = garmin.client.dumps()  # the single canonical secret string

with open(OUT, "w") as fh:
    fh.write(token)
os.chmod(OUT, stat.S_IRUSR | stat.S_IWUSR)  # 0600

probe = garmin.get_activities(0, 1) or []
print(json.dumps({
    "ok": True,
    "token_chars": len(token),
    "token_out": OUT,
    "verify_activity": (probe[0].get("activityName") if probe else None),
}, ensure_ascii=False))
