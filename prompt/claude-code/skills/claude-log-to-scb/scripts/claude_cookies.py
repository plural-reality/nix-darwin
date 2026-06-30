"""Decrypt Claude Desktop's cookie jar → claude.ai session cookies.

Claude Desktop (Electron/Chromium) stores cookies AES-128-CBC encrypted in
~/Library/Application Support/Claude/Cookies; the key derives (PBKDF2-HMAC-SHA1,
salt "saltysalt", 1003 iters) from the macOS Keychain password under service
"Claude Safe Storage". Recent Chromium prepends a 32-byte SHA256(domain) to the
plaintext — stripped here. Returns the fresh cf_clearance too (Claude Desktop
refreshes it as you use the app, so re-reading each run keeps Cloudflare happy).

First call triggers a Keychain access prompt — approve "Always Allow" once so
headless/launchd runs work later.
"""
import subprocess
import hashlib
import sqlite3
import os
import shutil
import tempfile

COOKIES = os.path.expanduser("~/Library/Application Support/Claude/Cookies")
KEYCHAIN_SERVICE = "Claude Safe Storage"
WANT = ("sessionKey", "lastActiveOrg", "cf_clearance")


def _key():
    pw = subprocess.run(
        ["security", "find-generic-password", "-w", "-s", KEYCHAIN_SERVICE],
        capture_output=True, text=True,
    ).stdout.strip()
    if not pw:
        raise RuntimeError("Keychain password for 'Claude Safe Storage' not obtained (denied?)")
    return hashlib.pbkdf2_hmac("sha1", pw.encode(), b"saltysalt", 1003, 16)


def _decrypt(enc, key):
    if not enc or enc[:3] != b"v10":
        return None
    p = subprocess.run(
        ["openssl", "enc", "-d", "-aes-128-cbc", "-K", key.hex(), "-iv", "20" * 16, "-nopad"],
        input=enc[3:], capture_output=True,
    )
    pt = p.stdout
    if not pt:
        return None
    pt = pt[:-pt[-1]]                          # PKCS7 padding
    if pt[:1] and not (32 <= pt[0] < 127):     # 32-byte SHA256(domain) prefix (recent Chromium)
        pt = pt[32:]
    return pt.decode("utf-8", "ignore")


def claude_cookies():
    """Return {sessionKey, lastActiveOrg, cf_clearance} for .claude.ai."""
    if not os.path.exists(COOKIES):
        raise RuntimeError(f"Claude Desktop cookie jar not found: {COOKIES}")
    key = _key()
    tmp = tempfile.mkdtemp()
    try:
        db = os.path.join(tmp, "Cookies")
        shutil.copy2(COOKIES, db)  # copy avoids lock contention with a running app
        con = sqlite3.connect(db)
        out = {}
        q = "SELECT name, encrypted_value FROM cookies WHERE host_key LIKE '%claude.ai%' AND name IN (?,?,?)"
        for name, val in con.execute(q, WANT):
            out[name] = _decrypt(val, key)
        con.close()
        if not out.get("sessionKey"):
            raise RuntimeError("sessionKey not found — is Claude Desktop logged in?")
        return out
    finally:
        shutil.rmtree(tmp, ignore_errors=True)
