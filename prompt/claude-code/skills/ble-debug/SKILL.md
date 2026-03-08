---
name: ble-debug
description: BLE接続の問題診断とデバッグ。切断、パケットロス、スループット低下、バックグラウンド停止などのBLE問題をlog streamから診断し修正案を提示する。CoreBluetoothのエラーコード、HCI切断理由、接続パラメータの異常を検出できる。
allowed-tools: Bash, Read, Edit, Write, Grep, Glob, mcp__xcodebuildmcp__*, mcp__xcode__*
---

# BLE デバッグスキル

## いつ使うか

- BLE 接続が切れる・不安定
- 音声パケットが欠落する
- バックグラウンドで受信が止まる
- スループットが想定より低い
- デバイスが見つからない・接続できない

## デバッグの手順

### Step 1: ログ取得

```bash
# リアルタイムBLEログ（デバイス接続中）
log stream --device <UDID> \
  --predicate 'subsystem == "com.reliableomi.ble" OR subsystem == "com.apple.bluetooth"' \
  --level debug \
  | tee /tmp/ble-debug-$(date +%Y%m%d-%H%M%S).log

# 過去ログの取得（直近5分）
log show --device <UDID> \
  --predicate 'subsystem == "com.reliableomi.ble"' \
  --last 5m \
  --style compact
```

### Step 2: ログからパターンを特定

以下のパターンを順にチェックする。

#### パターン A: 接続が切れる

ログに `didDisconnectPeripheral` + error が出る場合、error の domain と code を確認:

| CBError Code | 意味 | 対処 |
|-------------|------|------|
| 0 (Unknown) | 不明なエラー | RSSI 確認、距離を近づける |
| 6 (ConnectionTimeout) | 接続タイムアウト | supervision timeout が短すぎる可能性。ファームウェア側の接続パラメータ確認 |
| 7 (PeripheralDisconnected) | デバイス側が切断 | ファームウェアのリセット、バッテリー確認 |
| 14 (PeerRemovedPairingInfo) | ペアリング情報削除 | デバイスを忘れて再ペアリング |
| 15 (EncryptionTimedOut) | 暗号化タイムアウト (iOS 14+) | ボンディング情報のクリア |

#### パターン B: HCI 切断理由（PacketLogger / ファームウェアログ）

| HCI Code | 名前 | 意味 |
|----------|------|------|
| 0x08 | Connection Timeout | supervision timeout 超過。距離・干渉が原因 |
| 0x13 | Remote User Terminated | デバイス側が意図的に切断 |
| 0x16 | Local Host Terminated | iOS側が切断を開始 |
| 0x22 | LL Response Timeout | Link Layer応答なし。重度の干渉 |
| 0x28 | Instant Passed | 接続パラメータ更新の同期失敗 |
| 0x3E | Connection Failed to Establish | 接続確立自体が失敗 |

#### パターン C: パケットロス

3バイトヘッダのシーケンス番号にギャップがある場合:
```
受信: seq=100, seq=101, seq=105  → seq 102-104 が欠落
```

原因の切り分け:
1. **BLE スタックのバッファオーバーフロー** → Notification のキュー深度超過。受信側の処理が遅い
2. **iOS バックグラウンド停止** → `applicationState` が `.background` 時に長い欠落がある
3. **接続断→再接続** → 切断ログと時刻が一致する

#### パターン D: バックグラウンドで止まる

```bash
# アプリ状態遷移を確認
log show --device <UDID> \
  --predicate 'subsystem == "com.reliableomi.ble" AND category == "lifecycle"' \
  --last 30m
```

チェックポイント:
- `UIApplication.shared.applicationState` がログに含まれているか
- `.background` 移行後、何秒で Notification 受信が止まるか
- AVAudioSession がアクティブか（`audio` バックグラウンドモード）
- State Restoration の `willRestoreState` が呼ばれているか

### Step 3: 修正パターン

#### 接続安定化

```swift
// didDisconnectPeripheral で即時再接続（指数バックオフ付き）
func centralManager(_ central: CBCentralManager,
                    didDisconnectPeripheral peripheral: CBPeripheral,
                    error: Error?) {
    let delay = min(pow(2.0, Double(reconnectAttempts)) * 0.5, 30.0)
    reconnectAttempts += 1

    DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
        central.connect(peripheral, options: nil)
        // connect() にタイムアウトはない — iOS が管理する
    }
}
```

#### バックグラウンド維持

```swift
// AVAudioSession でアプリを生存させる
func configureAudioSession() {
    let session = AVAudioSession.sharedInstance()
    try? session.setCategory(.playAndRecord,
                             mode: .default,
                             options: [.allowBluetooth, .mixWithOthers])
    try? session.setActive(true)
}
```

#### State Restoration

```swift
// CBCentralManager 初期化時に restoreIdentifier を設定
centralManager = CBCentralManager(
    delegate: self,
    queue: bleQueue,
    options: [CBCentralManagerOptionRestoreIdentifierKey: "com.reliableomi.central"]
)

// iOS がアプリを再起動した場合の復元
func centralManager(_ central: CBCentralManager,
                    willRestoreState dict: [String: Any]) {
    if let peripherals = dict[CBCentralManagerRestoredStatePeripheralsKey] as? [CBPeripheral] {
        for peripheral in peripherals {
            peripheral.delegate = self
            // 既に接続中なら service discovery を再開
            if peripheral.state == .connected {
                peripheral.discoverServices([audioServiceUUID])
            }
        }
    }
}
```

### Step 4: 検証

修正後、以下の手順で検証:

```bash
# 1. クリーンビルド＋実機デプロイ
xcodebuild -project PAL.xcodeproj -scheme PAL \
  -destination 'platform=iOS,name=YuiのiPhone' \
  -quiet build
xcrun devicectl device install app --device <UDID> build/PAL.app

# 2. ログ監視を開始
log stream --device <UDID> \
  --predicate 'subsystem == "com.reliableomi.ble"' \
  --level debug | tee /tmp/ble-test.log &

# 3. 5分間の安定性テスト
#    - アプリをバックグラウンドに移す
#    - 他のアプリを開く
#    - デバイスを少し離す（3-5m）
#    - 戻ってきてログを確認

# 4. パケットロス率を計算
grep "seq=" /tmp/ble-test.log | awk '{print $NF}' | sort -n | \
  awk 'NR>1{gaps+=$1-prev-1; total++} {prev=$1} END{printf "Loss: %.2f%%\n", gaps*100/total}'
```

## 構造化ログの推奨フォーマット

アプリに以下の OSLog カテゴリを実装すること:

```swift
import os

extension Logger {
    static let bleConnection = Logger(subsystem: "com.reliableomi.ble", category: "connection")
    static let bleAudio = Logger(subsystem: "com.reliableomi.ble", category: "audio")
    static let bleSync = Logger(subsystem: "com.reliableomi.ble", category: "sync")
    static let lifecycle = Logger(subsystem: "com.reliableomi.ble", category: "lifecycle")
}

// 使用例
Logger.bleConnection.info("Connected: \(peripheral.identifier), RSSI: \(rssi)")
Logger.bleConnection.error("Disconnected: error=\(error?.localizedDescription ?? "none")")
Logger.bleAudio.debug("Packet: seq=\(seq), size=\(data.count), appState=\(UIApplication.shared.applicationState.rawValue)")
Logger.bleSync.info("SD sync started: offset=\(offset)")
Logger.lifecycle.info("App state: \(UIApplication.shared.applicationState.rawValue)")
```
