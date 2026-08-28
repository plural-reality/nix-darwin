# e-Tax読取専用broker

## 目的

Safariの短命なログイン状態やPasswords AutoFillのuser-presenceへ依存せず、e-Taxの適格請求書発行事業者通知を毎日無人で確認する。

## 単一境界

`ETaxWatchBridge.app`だけが、専用Keychain項目とe-Tax公式受付システムへ触れる。Nixは署名済みアプリのコードと固定コマンドclientを配布し、資格情報の値を保持しない。

```text
etax-watch watch
  -> 固定署名ETaxWatchBridge.app
  -> broker専用Keychain項目
  -> uketsuke.e-tax.nta.go.jp
  -> 件数・未読件数・日付・fingerprintだけのJSON
```

## コマンド

- `etax-watch status`: broker登録有無だけを返す。Keychain値を読まない。
- `etax-watch enroll`: 本人が一度だけnative secure fieldへ入力し、brokerが専用Keychain項目へ直接保存する。
- `etax-watch watch`: 毎回新規接続し、受付システムの公式XML `XU00SB40` の通知一覧を読み取る。

任意URL、Cookie、汎用HTTP proxy、通知本文取得、受付番号の出力、申告・送信・支払・設定変更のコマンドは実装しない。

## 秘密値の契約

- 利用者識別番号とパスワードはCLI引数、環境変数、stdin、stdout、stderr、状態ファイル、Nix storeを通らない。
- Keychain項目は `AfterFirstUnlockThisDeviceOnly` とし、固定bundle IDと署名identityを保つ。
- enrollment UIは `NSSecureTextField` を使い、保存後の確認は新規broker processの `status` と公式画面の非秘密メタデータで行う。

## 取得の契約

接続先はHTTPSの次の2 hostだけに固定する。

- `login.e-tax.nta.go.jp`
- `uketsuke.e-tax.nta.go.jp`

受付システムの汎用法人対応入口 `loginCtl` から、公式XMLの画面IDとhandoffをたどる。確定申告書等作成コーナー用の `loginCtlKakutei` は使わない。想定外host、画面ID、XML構造、2 MB超の応答、通信timeout、認証拒否ではfail closedにする。他の監視sourceは独立して続行する。

## 配置と更新

個人downstreamがbundle IDをbindingし、`build.sh`を実行する。生成物は次へcontent-addressedに置き、`current` symlinkだけを原子的に切り替える。

```text
$HOME/Library/Application Support/ETaxWatchBridge/generations/<hash>/ETaxWatchBridge.app
```

秘密値はgenerationへ含めない。通常運用では、最初にad-hoc署名したimmutable generationを更新せず使い続ける。これにより追加の証明書信頼操作を増やさず、毎日の実行は同じcode requirementでKeychain項目を再利用する。brokerコードを更新する時だけ、別generationへの明示移行と再登録を行う。Home Manager適用だけでは`current`を自動で切り替えない。

## 完了証拠

1. Nix checkでparser・host allowlist・秘密値非投影を検証する。
2. `codesign --verify --deep --strict` とdesignated requirementを再読込する。
3. enrollment後に別processの `status` が `登録済み` を返す。
4. `watch` が `screen: XU00SB40` と最小summaryを返す。
5. `daily-watch run` がe-Tax失敗時も他sourceを続行し、e-Tax結果を独立したtyped outcomeで返す。
