"""One-time Garmin auth → canonical token string.

Run only through `garmin auth` (interactive; env overrides are supported).
Produces the single
canonical secret: garminconnect's session-state string (client.dumps()),
written to GARMIN_TOKEN_OUT with 0600 perms. The boundary persists that string
into the host-local token store; the raw password is never persisted.
Verifies by pulling one activity.

The password is never persisted. The token is written to a 0600 ephemeral file
and the wrapper renames it into the host-local store. garminconnect's
curl_cffi engine impersonates a browser at the TLS layer, which is the fix for
the Cloudflare/429 block that killed the old garth mobile-UA path.
"""
import getpass
import os
import sys
import json
import stat

from garminconnect import Garmin

EMAIL = os.environ.get("GARMIN_EMAIL") or input("Garmin email: ").strip()
PASSWORD = os.environ.get("GARMIN_PASSWORD") or getpass.getpass(
    "Garmin password (入力内容は表示されません): "
)
OUT = os.path.expanduser(os.environ["GARMIN_TOKEN_OUT"])


def _mfa():
    return input("Garmin MFA code: ").strip()


garmin = Garmin(email=EMAIL, password=PASSWORD, prompt_mfa=_mfa)
needs_mfa, _ = garmin.login()  # no tokenstore → fresh credential login

needs_mfa and sys.exit(json.dumps({"ok": False, "reason": "mfa_required"}))

probe = garmin.get_activities(0, 1) or []
token = garmin.client.dumps()  # capture state after the authenticated probe

with open(OUT, "w") as fh:
    fh.write(token)
os.chmod(OUT, stat.S_IRUSR | stat.S_IWUSR)  # 0600

print(json.dumps({
    "ok": True,
    "token_chars": len(token),
    "token_out": OUT,
    "verify_activity": (probe[0].get("activityName") if probe else None),
}, ensure_ascii=False))
