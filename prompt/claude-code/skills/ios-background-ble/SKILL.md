---
name: ios-background-ble
description: iOSバックグラウンドでのBLE通信の維持手法。CoreBluetoothのバックグラウンドモード、State Preservation/Restoration、AVAudioSessionによるアプリ生存、iOSバージョン固有の制約とワークアラウンドを含む。バックグラウンドでBLEが止まる問題の診断と修正に使う。
allowed-tools: Read, Edit, Write, Grep, Bash
---

# iOS バックグラウンド BLE 維持スキル

## 3層防御アーキテクチャ

iOS でバックグラウンド BLE 通信を維持するには、単一の手法では不十分。
以下の3層を**すべて実装**して冗長性を確保する。

### 第1層: AVAudioSession（最重要）

**これが最も効果的な単一テクニック。** Apple DTS の公式回答でも「BLE デバイスからの音声ストリーミングアプリはアクティブな AVAudioSession によりバックグラウンドで活性化を維持できる」と確認されている。

```swift
// Info.plist の UIBackgroundModes に "audio" を追加
// <string>audio</string>

class AudioSessionManager {
    static let shared = AudioSessionManager()

    func configure() {
        let session = AVAudioSession.sharedInstance()
        do {
            // .playAndRecord で入出力の両方を確保
            // .allowBluetooth で BLE オーディオルーティングを許可
            // .mixWithOthers で他のアプリの音声と共存
            try session.setCategory(
                .playAndRecord,
                mode: .default,
                options: [.allowBluetooth, .mixWithOthers]
            )
            try session.setActive(true)
        } catch {
            Logger.lifecycle.error("AudioSession setup failed: \(error)")
        }
    }

    // アプリがフォアグラウンドに戻った時に再アクティベート
    func reactivate() {
        try? AVAudioSession.sharedInstance().setActive(true)
    }
}
```

**注意**: AudioSession をアクティブにするだけでは不十分な場合がある。実際に音声を再生または録音している状態（たとえ無音でも）が必要になることがある。その場合、受信した Opus データを AVAudioEngine で無音再生するパターンを検討する。

### 第2層: CoreBluetooth バックグラウンドモード

```swift
// Info.plist の UIBackgroundModes に "bluetooth-central" を追加
// <string>bluetooth-central</string>

// CBCentralManager を専用キューで初期化
private let bleQueue = DispatchQueue(label: "com.reliableomi.ble", qos: .userInitiated)

centralManager = CBCentralManager(
    delegate: self,
    queue: bleQueue,
    options: [
        CBCentralManagerOptionRestoreIdentifierKey: "com.reliableomi.central",
        CBCentralManagerOptionShowPowerAlertKey: true
    ]
)
```

bluetooth-central モードで可能なこと（バックグラウンド時）:
- 接続中デバイスからの Notification 受信 ✅
- 接続中デバイスへの Write ✅
- 切断検出と自動再接続開始 ✅
- スキャン（ただしスロットル・制限あり）⚠️

バックグラウンドでの制約:
- **約10秒の実行ウィンドウ** — BLE イベントでウェイクアップ後、約10秒でタスクを完了する必要がある
- **スキャンのスロットリング** — バックグラウンドスキャンは service UUID 指定必須、結果が遅延する
- **iOS がアプリを終了する可能性** — メモリ圧迫時にいつでも起こりうる

### 第3層: State Preservation & Restoration

iOS がメモリ圧迫でアプリを終了した場合のセーフティネット。
BLE イベント（Notification 到着、切断等）発生時にアプリを再起動してくれる。

```swift
// 復元デリゲート
func centralManager(_ central: CBCentralManager,
                    willRestoreState dict: [String: Any]) {

    Logger.lifecycle.info("State restored")

    // 復元された接続中ペリフェラルを回収
    if let peripherals = dict[CBCentralManagerRestoredStatePeripheralsKey] as? [CBPeripheral] {
        for peripheral in peripherals {
            Logger.bleConnection.info("Restored peripheral: \(peripheral.identifier)")
            peripheral.delegate = self
            self.connectedPeripheral = peripheral

            if peripheral.state == .connected {
                // サービス探索を再開
                peripheral.discoverServices([Self.audioServiceUUID])
            } else {
                // 再接続
                central.connect(peripheral, options: nil)
            }
        }
    }

    // 復元されたスキャン中サービスを回収
    if let services = dict[CBCentralManagerRestoredStateScanServicesKey] as? [CBUUID] {
        Logger.bleConnection.info("Restored scanning for: \(services)")
    }
}
```

**State Restoration が動かないケース**（回避不能）:
- ユーザーがアプリスイッチャーから**強制終了**した場合
- Bluetooth が**システム設定からOFF**にされた場合
- デバイスが**再起動**された場合（ロック解除前）
- これらのケースでは、ユーザーがアプリを手動で再起動するまで復帰しない

## 実装チェックリスト

### Info.plist

```xml
<key>UIBackgroundModes</key>
<array>
    <string>bluetooth-central</string>
    <string>audio</string>
</array>

<key>NSBluetoothAlwaysUsageDescription</key>
<string>Omi デバイスから音声を受信するために Bluetooth を使用します</string>
```

### アプリ起動時

```swift
func application(_ application: UIApplication,
                 didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

    // 1. AudioSession を最初に設定
    AudioSessionManager.shared.configure()

    // 2. CBCentralManager を初期化（State Restoration 付き）
    BLEManager.shared.initialize()

    // 3. BLE から起動された場合の処理
    if let centralManagerIDs = launchOptions?[.bluetoothCentrals] as? [String] {
        Logger.lifecycle.info("Launched by BLE restoration: \(centralManagerIDs)")
    }

    return true
}
```

### 再接続ロジック

```swift
class BLEManager: NSObject, CBCentralManagerDelegate {
    private var reconnectAttempts = 0
    private var reconnectTimer: Timer?

    func centralManager(_ central: CBCentralManager,
                        didDisconnectPeripheral peripheral: CBPeripheral,
                        error: Error?) {

        Logger.bleConnection.warning(
            "Disconnected: \(peripheral.identifier), error: \(error?.localizedDescription ?? "none"), appState: \(UIApplication.shared.applicationState.rawValue)"
        )

        // 即座に再接続（iOS がタイムアウトなしで管理）
        // 指数バックオフは connect() のリトライ間隔ではなく
        // connect() が失敗した場合のフォールバックスキャンに使う
        central.connect(peripheral, options: nil)
        reconnectAttempts += 1

        // フォールバック: 30秒後にまだ接続できていなければスキャンに切り替え
        reconnectTimer?.invalidate()
        reconnectTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: false) { [weak self] _ in
            if peripheral.state != .connected {
                Logger.bleConnection.info("Connect timeout, falling back to scan")
                central.cancelPeripheralConnection(peripheral)
                central.scanForPeripherals(
                    withServices: [Self.audioServiceUUID],
                    options: nil
                )
            }
        }
    }

    func centralManager(_ central: CBCentralManager,
                        didConnect peripheral: CBPeripheral) {

        Logger.bleConnection.info("Connected: \(peripheral.identifier)")
        reconnectAttempts = 0
        reconnectTimer?.invalidate()

        // Notification 再購読のためにサービス探索を開始
        peripheral.discoverServices([Self.audioServiceUUID])
    }
}
```

## iOS バージョン固有の注意点

| iOS | 問題 | 対処 |
|-----|------|------|
| 16.0 | MTU が 517→247→23 に経時劣化 | iOS 16.1 で修正済み。最低 iOS 17 をターゲットにすれば回避 |
| 16+ | バックグラウンド BLE スキャンが空結果を返すケースあり | service UUID を必ず指定。`allowDuplicates: false` |
| 17+ | `CBCentralManager.connect()` の挙動改善 | 接続パラメータのネゴシエーションが安定 |
| 18+ | 新しい `CBConnectionEvent` API | 接続理由の詳細が取得可能（任意） |

## L2CAP CoC に関する注意

L2CAP Connection-Oriented Channels は iOS 11+ で利用可能だが:
- **バックグラウンドでの信頼性に問題あり**（Apple Developer Forums に複数報告）
- GATT Notification の方がバックグラウンドでの信頼性が高い
- Omi ファームウェアは GATT Notification のみ対応

**結論**: Reliable OMI では GATT Notification を使用する。L2CAP CoC は使わない。

## デバッグ用ログ出力テンプレート

すべての CoreBluetooth デリゲートメソッドにログを入れること:

```swift
// 状態変化
func centralManagerDidUpdateState(_ central: CBCentralManager) {
    Logger.bleConnection.info("Central state: \(central.state.rawValue)")
}

// 接続
func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
    Logger.bleConnection.info("Connected: \(peripheral.identifier), appState=\(UIApplication.shared.applicationState.rawValue)")
}

// 切断
func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
    Logger.bleConnection.warning("Disconnected: \(peripheral.identifier), error=\(String(describing: error)), appState=\(UIApplication.shared.applicationState.rawValue)")
}

// Notification 受信
func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
    if let data = characteristic.value {
        let (seq, frag, _) = parseOmiAudioPacket(data) ?? (0, 0, Data())
        Logger.bleAudio.debug("Packet: seq=\(seq), frag=\(frag), size=\(data.count)")
    }
}

// Notification 有効化
func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
    Logger.bleConnection.info("Notification state: \(characteristic.isNotifying), uuid=\(characteristic.uuid), error=\(String(describing: error))")
}

// RSSI
func peripheral(_ peripheral: CBPeripheral, didReadRSSI RSSI: NSNumber, error: Error?) {
    Logger.bleConnection.debug("RSSI: \(RSSI.intValue) dBm")
}
```

## バックグラウンド維持の検証方法

```bash
# 1. アプリを実機にデプロイ
# 2. ログ監視開始
log stream --device <UDID> \
  --predicate 'subsystem == "com.reliableomi.ble"' \
  --level debug | tee /tmp/bg-test.log

# 3. 以下のシナリオを順にテスト（各2分以上）:
#    a) アプリをバックグラウンドに（ホームボタン/スワイプ）
#    b) 別のアプリを開く（Safari, カメラ等）
#    c) 画面ロック
#    d) 5分以上放置
#    e) 低電力モードをONにして放置

# 4. ログを確認
#    - "Packet: seq=" の連続性を確認（ギャップ = パケットロス）
#    - "Disconnected" の頻度を確認
#    - "State restored" が出ているか確認
#    - appState の推移を確認
```
