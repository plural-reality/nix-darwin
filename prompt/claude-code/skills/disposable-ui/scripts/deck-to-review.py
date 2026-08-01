#!/usr/bin/env python3
"""deck-to-review — 任意のデッキ/資料HTMLを「⌘/Ctrl+クリックで要素注釈できるレビューページ」に変える。

PDF はフラットで注釈できない。だが元の HTML は semantic(見出し・KPI・カードが実要素)。
その HTML に、disposable-ui の要素アノテーション engine(mountAnnotator)と回収オーバーレイを
**注入**するだけで、誰でも任意の箇所を ⌘/Ctrl+クリックしてコメントできるレビュー面になる。
オーバーレイは fixed/absolute で元のレイアウトを壊さない(du- 名前空間で衝突回避)。

  deck-to-review.py deck.html                    # → deck.review.html
  deck-to-review.py deck.html -o r.html --root .slide-wrapper
  # ローカル配信:   askpage_server.py --html deck.review.html --out ans.json --port 8795
  # 共有(永続):     /api/publish に raw-html で上げてトークンURL(SKILL.md 共有配信 参照)
  # 回答: {schema_version, answers:{annotations:[{n,locator,snippet,comment}], overall}, ui_pattern:"element-annotation"}
"""
from __future__ import annotations
import argparse, sys, pathlib

# 注入する自己完結オーバーレイ(du- 名前空間・元CSSと衝突しない・collect は transport 非依存)
OVERLAY = r"""
<div id="du-anno-layer"></div>
<div id="du-bar" data-open="1">
  <div id="du-head"><span>フィードバック <b id="du-cnt">0</b></span><button id="du-toggle" title="開閉">–</button></div>
  <div id="du-body">
    <div id="du-hint">気になる箇所を <b>⌘/Ctrl＋クリック</b> → その要素にコメント</div>
    <div id="du-list"></div>
    <textarea id="du-overall" placeholder="全体コメント（任意）"></textarea>
    <button id="du-send">送信</button>
    <button id="du-copy">回答をコピー</button>
    <div id="du-status"></div>
    <div id="du-done">回収しました。ターミナルに戻ると続きます。</div>
    <textarea id="du-paste" readonly></textarea>
  </div>
</div>
<style>
  #du-anno-layer{position:absolute;inset:0;pointer-events:none;z-index:2147483000;}
  .du-pin{position:absolute;width:22px;height:22px;margin:-11px 0 0 -11px;border-radius:50% 50% 50% 2px;background:#FF6B4A;color:#fff;font:700 12px "SF Mono",Menlo,monospace;display:flex;align-items:center;justify-content:center;box-shadow:0 2px 8px rgba(0,0,0,.4);pointer-events:auto;cursor:pointer;z-index:2147483001;}
  .du-hl{outline:2px solid #FF6B4A!important;outline-offset:2px;background:rgba(255,107,74,.08)!important;}
  .du-pop{position:absolute;z-index:2147483002;width:264px;background:#fff;color:#111;border:1px solid #d0d0d0;border-radius:10px;box-shadow:0 12px 34px rgba(0,0,0,.3);padding:11px;pointer-events:auto;font:13px/1.5 "Helvetica Neue",Arial,sans-serif;}
  .du-pop .du-loc{font-size:10.5px;color:#8a8a8a;margin-bottom:6px;line-height:1.4;}
  .du-pop textarea{width:100%;min-height:64px;border:1px solid #d6d6d6;border-radius:7px;padding:7px 9px;font:inherit;font-size:12.5px;resize:vertical;box-sizing:border-box;}
  .du-pop .du-row{display:flex;gap:8px;justify-content:flex-end;margin-top:8px;}
  .du-pop button{font:inherit;font-size:12px;border-radius:6px;padding:6px 12px;cursor:pointer;border:1px solid #d0d0d0;background:#fff;}
  .du-pop button.du-pri{background:#00E599;border-color:#00E599;color:#000;font-weight:600;}
  #du-bar{position:fixed;right:18px;bottom:18px;width:300px;z-index:2147483005;background:#1C2127;color:#fff;border:1px solid #383E47;border-radius:14px;box-shadow:0 12px 34px rgba(0,0,0,.5);font:13px/1.5 "Helvetica Neue",Arial,"Hiragino Kaku Gothic ProN",sans-serif;}
  #du-head{display:flex;justify-content:space-between;align-items:center;padding:12px 14px;font-weight:600;}
  #du-head b{color:#00E599;font-family:"SF Mono",Menlo,monospace;}
  #du-toggle{background:transparent;border:1px solid #383E47;color:#D4D9DF;width:24px;height:24px;border-radius:6px;cursor:pointer;font-size:14px;line-height:1;}
  #du-body{padding:0 14px 14px;}
  #du-bar[data-open="0"] #du-body{display:none;}
  #du-hint{font-size:11.5px;color:#D4D9DF;margin-bottom:10px;}
  #du-list{display:flex;flex-direction:column;gap:8px;max-height:40vh;overflow:auto;margin-bottom:10px;}
  .du-li{display:flex;gap:9px;background:#252A31;border:1px solid #383E47;border-radius:8px;padding:9px 10px;font-size:12px;cursor:pointer;}
  .du-li .du-n{flex:none;width:20px;height:20px;border-radius:50% 50% 50% 2px;background:#FF6B4A;color:#fff;font:700 11px "SF Mono",Menlo,monospace;display:flex;align-items:center;justify-content:center;}
  .du-li .du-lc{color:#D4D9DF;font-size:10px;display:block;margin-bottom:2px;}
  .du-li .du-del{margin-left:auto;color:#8b929b;flex:none;}
  #du-list:empty::after{content:"⌘/Ctrl+クリックで注釈";color:#8b929b;font-size:11.5px;}
  #du-overall{width:100%;min-height:52px;border:1px solid #383E47;border-radius:6px;background:#252A31;color:#fff;padding:8px 10px;font:inherit;font-size:12.5px;resize:vertical;box-sizing:border-box;}
  #du-send{width:100%;margin-top:9px;background:#00E599;color:#000;border:0;padding:10px;font-size:13.5px;font-weight:650;border-radius:6px;cursor:pointer;}
  #du-copy{width:100%;margin-top:7px;background:transparent;border:1px solid #383E47;color:#D4D9DF;padding:8px;font-size:12px;border-radius:6px;cursor:pointer;}
  #du-status{font-size:11px;color:#D4D9DF;margin-top:7px;text-align:center;}
  #du-done{display:none;font-size:12px;color:#00E599;text-align:center;margin-top:8px;}
  #du-paste{display:none;width:100%;margin-top:7px;min-height:70px;font-size:11px;box-sizing:border-box;}
</style>
<script>
(() => {
  "use strict";
  const $ = (id) => document.getElementById(id);
  const ROOT_SEL = "__ROOT__";
  const collect = ({ answers, uiPattern }) => {
    const payload = { schema_version: "1.0", collected_at: new Date().toISOString(), answers, ...(uiPattern ? { ui_pattern: uiPattern } : {}) };
    const text = JSON.stringify(payload, null, 2);
    const submitUrl = (window.__COLLECT__ && window.__COLLECT__.submitUrl) || "/submit";
    const asPrompt = "以下は disposable-ui(要素アノテーション)の回答です。JSON を回収して反映してください:\n\n```json\n" + text + "\n```";
    const clip = () => navigator.clipboard.writeText(asPrompt).then(() => ({ ok: true, via: "clipboard" }), () => ({ ok: false, via: "clipboard", text: asPrompt }));
    return fetch(submitUrl, { method: "POST", headers: { "Content-Type": "application/json" }, body: text }).then((r) => (r.ok ? { ok: true, via: "post" } : clip()), () => clip());
  };
  const layer = $("du-anno-layer"), list = $("du-list");
  let annos = [], seq = 0, pop = null;
  const locate = (el) => {
    const doc = el.closest("[data-doc]");
    let h = "", n = el;
    while (n && n !== doc && n !== document.body) {
      let p = n.previousElementSibling;
      while (p) { if (/^H[1-6]$/.test(p.tagName)) { h = p.textContent.trim(); break; } p = p.previousElementSibling; }
      if (h) break; n = n.parentElement;
    }
    const name = doc ? doc.getAttribute("data-doc") : "";
    const snippet = (el.textContent || "").trim().replace(/\s+/g, " ").slice(0, 40);
    return { path: [name, h].filter(Boolean).join(" › "), snippet, tag: el.tagName.toLowerCase() };
  };
  const place = (a) => { const r = a.el.getBoundingClientRect(); a.pin.style.left = (r.left + scrollX + 2) + "px"; a.pin.style.top = (r.top + scrollY + 2) + "px"; };
  const closeP = () => { if (pop) { pop.remove(); pop = null; } };
  const render = () => {
    $("du-cnt").textContent = annos.length;
    list.replaceChildren(...annos.map((a) => {
      const li = document.createElement("div"); li.className = "du-li";
      li.innerHTML = '<span class="du-n">' + a.n + '</span><span style="min-width:0"><span class="du-lc">' + a.loc.path + (a.loc.snippet ? ' › 「' + a.loc.snippet + '」' : '') + '</span><span class="du-cm"></span></span><span class="du-del">✕</span>';
      li.querySelector(".du-cm").textContent = a.comment;
      li.onclick = (e) => { if (e.target.classList.contains("du-del")) { rm(a.n); return; } a.el.scrollIntoView({ block: "center", behavior: "smooth" }); };
      return li;
    }));
  };
  const rm = (n) => { const a = annos.find((x) => x.n === n); if (!a) return; a.pin.remove(); a.el.classList.remove("du-hl"); annos = annos.filter((x) => x.n !== n); render(); };
  const add = (el, x, y) => {
    closeP(); const loc = locate(el);
    pop = document.createElement("div"); pop.className = "du-pop";
    pop.style.left = Math.min(x, scrollX + innerWidth - 284) + "px"; pop.style.top = (y + 8) + "px";
    pop.innerHTML = '<div class="du-loc">' + loc.path + (loc.snippet ? ' › 「' + loc.snippet + '」' : '') + '</div><textarea placeholder="この箇所へのコメント…"></textarea><div class="du-row"><button data-x>取消</button><button class="du-pri" data-ok>追加</button></div>';
    layer.appendChild(pop); const ta = pop.querySelector("textarea"); ta.focus();
    pop.querySelector("[data-x]").onclick = closeP;
    const save = () => { const c = ta.value.trim(); if (!c) { closeP(); return; } seq++; const n = seq; const pin = document.createElement("div"); pin.className = "du-pin"; pin.textContent = n; layer.appendChild(pin); el.classList.add("du-hl"); const a = { n, el, comment: c, loc, pin }; annos.push(a); place(a); render(); closeP(); };
    pop.querySelector("[data-ok]").onclick = save; ta.onkeydown = (e) => { if ((e.metaKey || e.ctrlKey) && e.key === "Enter") save(); };
  };
  document.addEventListener("click", (e) => {
    if (!(e.metaKey || e.ctrlKey)) return;
    if (e.target.closest("#du-bar") || e.target.closest(".du-pop")) return;
    const el = e.target.closest(`${ROOT_SEL} *`) || e.target.closest(ROOT_SEL);
    if (!el) return;
    e.preventDefault(); e.stopPropagation(); add(el, e.pageX, e.pageY);
  }, true);
  addEventListener("scroll", () => annos.forEach(place), { passive: true });
  addEventListener("resize", () => annos.forEach(place));
  $("du-toggle").onclick = () => { const b = $("du-bar"); b.dataset.open = b.dataset.open === "1" ? "0" : "1"; $("du-toggle").textContent = b.dataset.open === "1" ? "–" : "+"; };
  const showDone = (res) => {
    $("du-send").style.display = "none"; $("du-copy").style.display = "none"; $("du-overall").style.display = "none"; $("du-hint").style.display = "none";
    $("du-done").style.display = "block"; $("du-status").textContent = "";
    if (res.via === "clipboard") { $("du-done").textContent = res.ok ? "クリップボードにコピーしました。貼り戻してください。" : "コピー失敗。下の枠を全選択して貼ってください。"; if (!res.ok) { const b = $("du-paste"); b.style.display = "block"; b.value = res.text; b.select(); } }
  };
  const submit = () => {
    const annotations = annos.map((a) => ({ n: a.n, locator: a.loc.path, snippet: a.loc.snippet, comment: a.comment }));
    const overall = $("du-overall").value.trim();
    if (!annotations.length && !overall) { $("du-status").textContent = "⌘/Ctrl+クリックでコメントを付けてください"; return; }
    $("du-status").textContent = "送信中…";
    collect({ answers: { annotations, overall }, uiPattern: "element-annotation" }).then(showDone);
  };
  $("du-send").onclick = submit; $("du-copy").onclick = submit;
})();
</script>
"""


def inject(src: str, root_sel: str) -> str:
    block = OVERLAY.replace("__ROOT__", root_sel)
    return src.replace("</body>", block + "\n</body>", 1) if "</body>" in src else src + block


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("html", nargs="?", help="入力デッキ/資料HTML")
    ap.add_argument("-o", "--out", help="出力(既定=入力名.review.html)")
    ap.add_argument("--root", default="body", help="注釈対象のルートセレクタ(既定 body=どこでも)。デッキなら .slide-wrapper 等")
    ap.add_argument("--selftest", action="store_true")
    a = ap.parse_args()
    if a.selftest:
        h = inject("<html><body><h2>x</h2><p>y</p></body></html>", ".slide-wrapper")
        assert "du-anno-layer" in h and "element-annotation" in h and 'ROOT_SEL = ".slide-wrapper"' in h and "__ROOT__" not in h, "inject failed"
        assert "</body>" in h and h.index("du-bar") < h.rindex("</body>"), "block placed before </body>"
        print("selftest: OK"); return 0
    if not a.html:
        ap.error("入力HTMLを指定してください")
    out = a.out or str(pathlib.Path(a.html).with_suffix(".review.html"))
    src = pathlib.Path(a.html).read_text(encoding="utf-8")
    pathlib.Path(out).write_text(inject(src, a.root), encoding="utf-8")
    print(out)
    return 0


if __name__ == "__main__":
    sys.exit(main())
