# 実行と測定

初回 `cua_repl` は1操作だけ:

```js
var calculator = await cua.getApp('Calculator');
```

返ったAPI文書とAXを読んだ後、次の呼出しでimportする。`skillRoot` はこのSKILL.mdと同じ配備ディレクトリの絶対パス。新しい依存は不要。

```js
var jev = await import(`${skillRoot}/scripts/runtime.mjs`);
var core = await import(`${skillRoot}/scripts/core.mjs`);
var ax = await calculator.getAXState({ emit: false, disableDiffing: true });
nodeRepl.write(core.parseAX(ax));
```

例えば電卓で0から6へ変える場合。`targets` は直前の観測値に置き換える。0でない既存計算は壊さず、別の可逆的なテストを選ぶ。

```js
var result = await jev.runPhase({
  driver: jev.createCuaDriver(calculator),
  goal: 'Enter the digit six.',
  targets: [
    {role: 'button', label: 'Description: 5, ID: Five'},
    {role: 'button', label: 'Description: 6, ID: Six'},
    {role: 'button', label: 'Description: 7, ID: Seven'},
  ],
  verify: ax => ax.split('\n').some(line => /^\s*\d+ text\s+6$/.test(line.replace(/[\u200e\u200f\u2066-\u2069]/g, ''))),
  execute: true,
  authorized: true,
  egressApproved: true, // 上記の非機微なgoalと候補だけ
  keyFile: '/absolute/path/to/existing/private/key', // 既存envがあれば省略
  maxSteps: 1,
  onEvent: event => nodeRepl.write(event),
});
nodeRepl.write(result);
```

`setValue` の場合は `action: 'setValue', text: '承認済み入力値'` を追加。入力値はTypeSafeへ送らない。入力後の自動保存などの副作用も元タスクの許可範囲に含まれることを確認する。

フェーズは1–3操作程度。標準のネットワークtimeoutは4秒、再試行はなし。`maxMs` は操作間の予算であり実行中のCUA操作を取消すタイマーではない。CUAのtool timeoutは余裕を持たせ、外側timeout後は未実行と決めつけない。追加sleepなしでCUAの観測待ちを使う。画面差分の再構築で古いindexを使わないため、内部はfull AXを取得する。

`onEvent` はindex・操作・model・推論時間だけを受け取る。結果はstatus・理由・操作数・総時間。生AXや入力値を恒久保存しない。previewだけは確認用に選択ラベルを返す。

## 比較

同じ開始状態と結果判定で、通常CUA（既知手順をまとめる）とJevを比較する。総時間、推論往復、誤操作、未完了、エージェントへの返却回数を記録。単一試行から倍率を一般化しない。APIキーなしのmock/driver検証をJev実測と呼ばない。

## 根拠 (2026-09-29確認)

- [Jev-cu](https://github.com/Sac-Y/Jev-cu/tree/52d32ac24e2cea29c63d9d7c4bd6d4c401111f56): CUA観測→小さい判断→CUA実行の構成を参考にした独立実装。汎用action選択・座標・任意キー入力は採用しない。
- [TypeSafe設計](https://docs.typesafe.ai/concepts/how-to-build-with-system-one): 制御・決定的処理・副作用をコードが持つ。
- [既知の弱点](https://docs.typesafe.ai/model-jaggedness/jev-1.13): 悪意あるstate、日付計算、大量の無関係な文脈に注意。ラベルは指示として信頼せず候補と操作を外側で制限。
- [モデル](https://docs.typesafe.ai/models): text入力のみ、英語が主。version pinでモデル変更による挙動変化を分離。
- [confidence](https://docs.typesafe.ai/confidence): 選択肢の分布に由来する値。正答確率そのものや実行権限と同一視しない。

## OpenJEV

同じ呼出しへ `provider: 'openjev'` と、その事業者の `keyFile` を指定する。APIキーとgoal・候補ラベルはOpenJEVへ送られる。公式キーを指定しない。`openjev` は固定バージョンではない。接続仕様: https://api.openjev.sh/docs/advanced （2026-09-29確認）。
