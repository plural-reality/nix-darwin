---
name: plural-reality-knowledge
description: >
  多元現実の会社知識を調べるとき、会社Cosenseとplural-reality配下のGit正本から
  provenance付きevidenceを横断取得する。トリガー: 「多元現実では」「会社の過去判断」
  「社内資料」「既存実装・方針を横断して調べて」。
---

# Plural Reality Knowledge

## 境界

- `cosense-evidence` は読み取り専用のretrieval境界であり、回答生成器ではない。
- 対象sourceはHome Managerの明示allowlistが正本。skill内でpathやprojectを追加しない。
- 個人Cosense、私信、Gmail、Beeper、Calendarを会社検索へ混ぜない。
- 結果の `complete: false` は「mirrorで確認できた候補」であり、0件を正本上の不在と断定しない。
- Git evidenceはtracked `HEAD` の内容。working treeの未コミット変更を現在の正本として扱わない。

## 取得

query specをstdinから渡し、stdoutのNDJSONだけをevidenceとして読む。

```bash
printf '%s\n' '{"query":"検索語","limit":20}' | cosense-evidence
```

`cosense-evidence` が存在しない、source failure、古い `observedAt`、空結果はそれぞれ区別する。失敗を0件へ縮退させない。

## 回答

1. 質問の固有語を保った狭いqueryから始める。
2. 各hitの `sourceUri`、`sourceVersion`、`locator`、`observedAt` を確認する。
3. 必要な場合だけcanonical sourceを直接再読込する。
4. 回答では主張の近くにsource URIとlocatorを付ける。
5. 現在状態や完了を問う質問では、evidence検索だけで確定せず、正本またはlive serviceをreadbackする。

検索品質が不足しても、その場で別のknowledge storeやembedding indexを作らない。実質問のfailure caseとして記録し、retrieval評価で再現してから構造を拡張する。
