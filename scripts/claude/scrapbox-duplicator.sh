#!/bin/sh
# scrapbox-duplicator.sh — tkgshn-private の [public.icon] ページだけを公開 project tkgshn へ転送する。
#
# 旧構成は GitHub Actions (tkgshn/Scrapbox-Duplicator, Deno) だった。しかし Scrapbox の connect.sid は
# 5週間程度で失効し、静的 secret として置く限り定期的に死ぬ。実際 2026-06-22 以降は全 run が
# NotLoggedInError で失敗し、さらに 2026-07-14 に repo 無活動で cron 自体が disabled_inactivity になり、
# 約7週間にわたり転送が止まっていた。SID を「ログイン済み Chrome セッションの関数」として実行時に
# 再生成できるのはローカル Mac だけなので、実行主体をここへ移し GitHub 側は廃止した。
# これにより source of truth は「Chrome のログインセッション」1つになり、失効も cron 停止も起きない。
#
#   sync = export(source) |> filter([public.icon] ∧ ¬[private.icon]) |> chunk |> import(dest)
#
# 純粋な pipeline として書く: 入力は Scrapbox の状態のみ、作業領域は mktemp -d で実行後に消える。
# import は content-idempotent(source 側の created/updated を持ち込むので、内容が同じなら公開側の
# タイムスタンプは動かない)ため、差分を持たず毎回全件転送してよい。
#
# 使い方:
#   scrapbox-duplicator.sh            転送を実行(launchd から日次)
#   scrapbox-duplicator.sh --check    到達性と SID の有効性だけ確認(export/import しない)
#   scrapbox-duplicator.sh --dry-run  export + filter まで実行し件数を出す(import しない)
set -eu

SOURCE="${SCB_DUP_SOURCE:-tkgshn-private}"   # 転送元(private)
DEST="${SCB_DUP_DEST:-tkgshn}"               # 転送先(public)
# ponytail: 全 7800 件を1リクエストで投げると 36MB になり Scrapbox 側が 413 を返す。200件ずつに割る。
# 上限は経験値。将来 413 が出るようなら SCB_DUP_CHUNK を下げる。
CHUNK="${SCB_DUP_CHUNK:-200}"

CACHE="$HOME/.claude/.cache/scrapbox-duplicator"
mkdir -p "$CACHE"
LOG="$CACHE/run.log"
LOCK="$CACHE/.lock"

# launchd の最小 PATH では nix の curl/jq/python3 が見えないので明示注入。
export PATH="/run/current-system/sw/bin:/etc/profiles/per-user/${USER}/bin:${HOME}/.local/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:${PATH:-}"
export LANG=ja_JP.UTF-8 LC_ALL=ja_JP.UTF-8

ts() { date '+%F %T'; }
log() { echo "$(ts) $*" >> "$LOG"; }

MODE="${1:-run}"

# ---- SID: ログイン済み Chrome から実行時に再生成。失敗時のみ settings.local.json にフォールバック ----
resolve_sid() {
  if FRESH=$("$HOME/.claude/scripts/scrapbox-sid-refresh.sh" 2>>"$LOG"); then
    printf '%s' "$FRESH"
    return 0
  fi
  log "SID refresh failed; fall back to settings.local.json"
  [ -f "$HOME/.claude/settings.local.json" ] || return 1
  jq -r '.env.SCRAPBOX_SID // empty' "$HOME/.claude/settings.local.json" 2>/dev/null
}

# guest 落ちしたまま走ると export が NotLoggedInError で落ちるだけなので、先に判定して静かに降りる。
assert_logged_in() {
  ME=$(curl -s --max-time 10 -H "Cookie: connect.sid=${SID}" https://scrapbox.io/api/users/me 2>/dev/null || true)
  case "$ME" in
    *'"isGuest":true'*|'') return 1 ;;
  esac
  echo "$ME" | jq -e '.name' >/dev/null 2>&1
}

SID=$(resolve_sid || true)
[ -n "${SID:-}" ] || { log "no SID available; abort"; exit 0; }

if [ "$MODE" = "--check" ]; then
  echo "curl:   $(command -v curl || echo MISSING)"
  echo "jq:     $(command -v jq || echo MISSING)"
  echo "sid:    ${#SID} chars"
  if assert_logged_in; then
    echo "login:  OK ($(echo "$ME" | jq -r .name))"
  else
    echo "login:  GUEST/INVALID"
    exit 1
  fi
  echo "source: $SOURCE  $(curl -s -o /dev/null -w '%{http_code}' -H "Cookie: connect.sid=$SID" "https://scrapbox.io/api/projects/$SOURCE")"
  echo "dest:   $DEST  $(curl -s -o /dev/null -w '%{http_code}' -H "Cookie: connect.sid=$SID" "https://scrapbox.io/api/projects/$DEST")"
  exit 0
fi

# ---- 多重起動防止。export API は回数制限があるので重ねて叩かない ----
if [ -e "$LOCK" ]; then
  log "locked, skip"
  exit 0
fi
WORK=$(mktemp -d "${TMPDIR:-/tmp}/scb-dup.XXXXXX")
trap 'rm -f "$LOCK"; rm -rf "$WORK"' EXIT INT TERM
: > "$LOCK"

assert_logged_in || { log "guest/invalid SID; abort (Chrome未ログイン/ロック?)"; exit 0; }

log "start ${SOURCE} -> ${DEST} (mode=${MODE})"

# ---- 1. export ----
CODE=$(curl -sS --max-time 600 -H "Cookie: connect.sid=${SID}" \
  "https://scrapbox.io/api/page-data/export/${SOURCE}.json?metadata=true" \
  -o "$WORK/export.json" -w '%{http_code}') || { log "export request failed"; exit 1; }
[ "$CODE" = "200" ] || { log "export http=$CODE: $(head -c 300 "$WORK/export.json")"; exit 1; }
TOTAL=$(jq '.pages | length' "$WORK/export.json")

# ---- 2. filter + chunk ----
# index.ts と同じ判定: [private.icon] があれば除外、無くて [public.icon] があれば転送。
# 両方無いページは転送しない(旧 SHOULD_DUPLICATE_BY_DEFAULT=False 相当・実測で確認済)。
jq -c --argjson n "$CHUNK" '
  [ .pages[]
    | select(([.lines[].text] | any(index("[private.icon]"))) | not)
    | select( [.lines[].text] | any(index("[public.icon]")) )
  ] as $p
  | range(0; ($p | length); $n) as $i
  | {pages: $p[$i:$i+$n]}
' "$WORK/export.json" | split -l 1 -a 3 - "$WORK/chunk."
MATCHED=$(cat "$WORK"/chunk.* 2>/dev/null | jq -s '[.[].pages | length] | add // 0')
CHUNKS=$(ls "$WORK"/chunk.* 2>/dev/null | wc -l | tr -d ' ')
log "exported ${TOTAL} pages, matched ${MATCHED} pages, ${CHUNKS} chunk(s)"

if [ "$MODE" = "--dry-run" ]; then
  echo "source=${SOURCE} total=${TOTAL} matched=${MATCHED} chunks=${CHUNKS} dest=${DEST} (dry-run: 転送していない)"
  log "dry-run done"
  exit 0
fi
[ "${MATCHED:-0}" -gt 0 ] || { log "no page to import; done"; exit 0; }

# ---- 3. import ----
# Scrapbox は書込 API に Origin 検査を掛けており、付けないと CSRF token の有無に関わらず
# 403 CrossOriginWriteNotAllowedError になる。逆に Origin さえ合っていれば X-CSRF-TOKEN は不要
# (旧 Deno 実装が使っていた /api/users/me の csrfToken フィールドは既に API から消えている)。
FAILED=0
I=0
for f in "$WORK"/chunk.*; do
  I=$((I + 1))
  CODE=$(curl -sS --max-time 300 -X POST \
    -H "Cookie: connect.sid=${SID}" \
    -H "Origin: https://scrapbox.io" \
    -H "Referer: https://scrapbox.io/${DEST}" \
    -H "Accept: application/json, text/plain, */*" \
    -F "import-file=@${f};type=application/octet-stream" \
    -F "name=undefined" \
    "https://scrapbox.io/api/page-data/import/${DEST}.json" \
    -o "$WORK/res.json" -w '%{http_code}') || CODE=000
  if [ "$CODE" = "200" ]; then
    log "  [${I}/${CHUNKS}] ok: $(jq -r '.message // "?"' "$WORK/res.json" 2>/dev/null)"
  else
    FAILED=$((FAILED + 1))
    log "  [${I}/${CHUNKS}] http=${CODE}: $(head -c 300 "$WORK/res.json")"
  fi
done

if [ "$FAILED" -gt 0 ]; then
  log "done with ${FAILED}/${CHUNKS} failed chunk(s)"
  exit 1
fi
log "done: ${MATCHED} pages imported into ${DEST}"
