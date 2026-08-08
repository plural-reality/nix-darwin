# Output contract

## Evidence bundle

```json
{
  "sourceImage": {"sha256": "...", "capturedAt": "..."},
  "derivedImage": {"sha256": "...", "transformation": "perspective-crop"},
  "ocr": [{"field": "name", "value": "...", "confidence": 0.0}],
  "identityCandidates": [],
  "sourceOutcomes": [],
  "eventCandidates": [],
  "conversationPages": [],
  "scrapboxPreview": {},
  "commit": {"status": "not_requested"}
}
```

## Source outcome

各sourceは成功件数だけでなく取得状態を返す。

```text
collected | no_record | temporarily_unavailable | auth_required | unsupported
```

`temporarily_unavailable` や `auth_required` を `no_record` に変換しない。

## Identity candidate

```text
exact_page | alias_page | bracket_mention | plain_text_mention | no_record
```

各候補はproject、exact title、matched fields、contradictionsを持つ。同名だけではmergeしない。

## Event candidate

```text
high | medium | low | unresolved
```

候補はevent title、time range、supporting evidence、contradictions、source outcomesを持つ。撮影日時だけの候補を`high`にしない。

## Conversation page

独立会話ページがある場合は次を保持する。

```json
{
  "project": "plural-reality",
  "title": "2026/8/2 井添優子さんとの会話",
  "url": "https://scrapbox.io/...",
  "readback": "verified",
  "backlinks": ["井添 優子", "デジタル民主主義サミット2026"]
}
```

人物ページは推測titleではなく、`readback: verified` のexact titleだけをlinkする。

## Commit state

```text
not_requested -> previewed -> approved -> uploaded -> written -> verified
```

途中状態を完了扱いしない。GyazoとScrapboxの片方だけ成功した場合は、その事実を保持して再実行時の重複upload/writeを避ける。

## Weekly photo scan state

```json
{
  "snapshotVersion": 1,
  "previousSnapshot": "sha256:...",
  "currentSnapshot": "sha256:...",
  "newAssetIds": [],
  "candidateAssetIds": [],
  "sourceOutcome": "collected",
  "reviewBundle": "..."
}
```

差分keyはPhotoKitの安定asset IDとする。`creationDate >= lastRun` だけで差分を作らない。iCloud同期で古い撮影日のassetが後着するためである。snapshotはasset IDと判定に必要な最小metadataだけをmode `0600` で保持し、写真本体を永続複製しない。
