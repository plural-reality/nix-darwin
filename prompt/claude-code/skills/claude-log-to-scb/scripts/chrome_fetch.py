#!/usr/bin/env python3
"""claude-log-to-scb — PATH B acquisition: same-origin GET inside the user's
REAL, logged-in Chrome (NOT Playwright's bundled Chromium — per CLAUDE.md).

Why this beats every headless variant for ChatGPT:
  - The XHR runs INSIDE a real chatgpt.com tab, so Cloudflare sees a genuine
    browser (real TLS/JA3, real cf_clearance cookie) and the request passes.
  - Auth is the page's own: we read accessToken from /api/auth/session (cookie-
    authed) and Bearer it to backend-api. No cookie/token is ever extracted from
    the browser — nothing leaves the page context. This is the exact pattern the
    200k-user chatgpt-exporter extension uses; it does not trip OpenAI's
    out-of-browser-token BAN heuristic.
  - The READ endpoints (GET conversations / conversation) carry no PoW/Turnstile
    gate (those are POST-only), so a bare authed GET is all that's needed.

One-time enablement (mirrors claude-log-to-scb's Keychain "Always Allow"):
  Chrome menu ▸ View ▸ Developer ▸ "Allow JavaScript from Apple Events".
  After that this is fully scriptable / launchd-able.

API: chrome_get(path) -> parsed JSON dict.  CLI: chrome_fetch.py <path>
"""
import sys
import json
import time
import subprocess

ORIGIN_HINTS = ("chatgpt.com", "chat.openai.com")

# One execute-javascript call: read the page's accessToken (cookie-authed), then
# Bearer it to `path`. Synchronous XHR so the value is returned in one round-trip.
# Same-origin relative URLs → the browser supplies cookies + cf_clearance.
_JS = (
    "(function(){try{"
    "function tk(f){if(!f&&window.__cgTok)return window.__cgTok;"
    "var s=new XMLHttpRequest();s.open('GET','/api/auth/session',false);"
    "s.setRequestHeader('Accept','application/json');s.send(null);"
    "var t='';try{t=(JSON.parse(s.responseText)||{}).accessToken||'';}catch(e){}"
    "window.__cgTok=t;return t;}"
    "function go(tok){var x=new XMLHttpRequest();x.open('GET',%PATH%,false);"
    "if(tok){x.setRequestHeader('Authorization','Bearer '+tok);}"
    "x.setRequestHeader('Accept','application/json');x.send(null);return x;}"
    "var tok=tk(false),x=go(tok);"
    "if(x.status===401){tok=tk(true);x=go(tok);}"  # token expired mid-run → refresh once
    "return JSON.stringify({status:x.status,body:x.responseText,"
    "hasTok:tok.length>0,origin:location.origin});"
    "}catch(e){return JSON.stringify({status:-1,error:String(e)});}})()"
)

_TOGGLE_HELP = (
    "Chrome の 'Allow JavaScript from Apple Events' が無効です。\n"
    "  Chrome メニュー ▸ 表示(View) ▸ デベロッパ(Developer) ▸ "
    "'Apple Events からの JavaScript を許可' をオンにして再実行してください。\n"
    "  (claude-log-to-scb の Keychain『常に許可』と同じ一度きりの操作)"
)


def _osa(script, timeout=180):
    return subprocess.run(["osascript", "-e", script],
                          capture_output=True, text=True, timeout=timeout)


def _find_tab():
    """(window_idx, tab_idx) of a logged-in ChatGPT tab, or None."""
    r = _osa(
        'tell application "Google Chrome"\n'
        ' set wi to 0\n repeat with w in windows\n  set wi to wi+1\n  set ti to 0\n'
        '  repeat with t in tabs of w\n   set ti to ti+1\n'
        '   if (URL of t) contains "chatgpt.com" or (URL of t) contains "chat.openai.com" then\n'
        '    return (wi as text) & " " & (ti as text)\n   end if\n  end repeat\n'
        ' end repeat\n return ""\nend tell'
    )
    out = r.stdout.strip()
    if not out:
        return None
    w, t = out.split()
    return int(w), int(t)


def ensure_tab(open_if_missing=True):
    tab = _find_tab()
    if tab or not open_if_missing:
        return tab
    _osa('tell application "Google Chrome"\n'
         ' if (count of windows)=0 then make new window\n'
         ' tell window 1 to make new tab with properties {URL:"https://chatgpt.com/"}\n'
         'end tell')
    for _ in range(40):
        time.sleep(1.0)
        tab = _find_tab()
        if tab:
            time.sleep(2.0)  # let the SPA hydrate so /api/auth/session is live
            return tab
    raise RuntimeError("no chatgpt.com tab and could not open one")


def chrome_get(path, tab=None):
    """Same-origin authed GET via the real Chrome tab. Returns parsed JSON.

    Finds the ChatGPT tab and runs the JS in ONE AppleScript, referencing the
    tab object directly — positional `window N` / `tab N` indices drift with
    z-order between calls, so we never pass them across the osascript boundary.
    """
    js = _JS.replace("%PATH%", json.dumps(path))           # JS string literal
    js_as = js.replace("\\", "\\\\").replace('"', '\\"')   # AppleScript escape
    # try-guard the volatile accesses: windows/tabs can close mid-scan (z-order
    # churns while the blocking XHR runs), which otherwise throws "Invalid index".
    script = (
        'tell application "Google Chrome"\n'
        ' set tgt to missing value\n'
        ' repeat with w in windows\n'
        '  try\n'
        '   repeat with t in (tabs of w)\n'
        '    set u to ""\n'
        '    try\n     set u to (URL of t)\n    end try\n'
        '    if u contains "chatgpt.com" or u contains "chat.openai.com" then\n'
        '     set tgt to t\n     exit repeat\n'
        '    end if\n'
        '   end repeat\n'
        '  end try\n'
        '  if tgt is not missing value then exit repeat\n'
        ' end repeat\n'
        ' if tgt is missing value then return "NO_TAB"\n'
        f' return (execute tgt javascript "{js_as}")\n'
        'end tell'
    )
    r = _osa(script)
    if r.returncode != 0:
        err = r.stderr.strip()
        if "Executing JavaScript through AppleScript is turned off" in err:
            raise RuntimeError(_TOGGLE_HELP)
        if "not allowed assistive access" in err:
            raise RuntimeError("osascript needs Accessibility, or open a chatgpt.com tab manually.")
        raise RuntimeError("osascript: " + err)
    out = r.stdout.strip()
    if out == "NO_TAB" or not out:
        raise RuntimeError("ログイン済み chatgpt.com タブが見つからない(タブを開いて再実行)")
    obj = json.loads(out)
    if obj.get("error"):
        raise RuntimeError("page JS: " + obj["error"])
    if obj.get("status") != 200:
        raise RuntimeError(
            f"HTTP {obj.get('status')} (session={obj.get('sessionStatus')}, "
            f"bearer={obj.get('hasTok')}) — logged in on {obj.get('origin')}? "
            f"body={(obj.get('body') or '')[:160]}")
    return json.loads(obj["body"])


def main(argv):
    if not argv:
        sys.exit("usage: chrome_fetch.py <backend-api-path>")
    print(json.dumps(chrome_get(argv[0]), ensure_ascii=False))


if __name__ == "__main__":
    main(sys.argv[1:])
