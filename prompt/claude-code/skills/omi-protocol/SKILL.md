---
name: omi-protocol
description: Omi（旧Friend）ウェアラブルデバイスのBLEプロトコル仕様。GATT UUID定義、Opusパケットフォーマット、3バイトヘッダの解析、SDカード同期プロトコル、ファームウェアの動作モードを含む。OmiデバイスとのBLE通信コードを書く・デバッグする際に参照する。
allowed-tools: Read, Edit, Write, Grep, Bash
---

# Omi BLE プロトコル仕様

## GATT サービス定義

### 標準サービス

| サービス | UUID | 用途 |
|---------|------|------|
| Battery Service | `0x180F` | バッテリーレベル (0-100, Notify) |
| Device Information | `0x180A` | ファームウェアバージョン等 |

### カスタム Audio Streaming Service

**Service UUID**: `19B10000-E8F2-537E-4F6C-D104768A1214`

| Characteristic | UUID | Property | 説明 |
|---------------|------|----------|------|
| Audio Data | `19B10001-E8F2-537E-4F6C-D104768A1214` | Notify | Opus音声パケット |
| Codec Type | `19B10002-E8F2-537E-4F6C-D104768A1214` | Read | コーデック種別 |
| Speaker | `19B10003-E8F2-537E-4F6C-D104768A1214` | Write | 未使用 |

### SD カードストレージサービス

公式ドキュメントに未記載。ファームウェアの `storage.c` に実装。
UUID は `19B1xxxx-E8F2-537E-4F6C-D104768A1214` ベースファミリの別 Characteristic。

正確な UUID は Omi Flutter アプリの `app/lib/services/devices/omi/omi_connection.dart` を参照すること。

## 音声パケットフォーマット

### エンコーディング

- コーデック: **Opus** (SILK モード, 可変ビットレート)
- サンプルレート: **16 kHz**
- チャネル: **モノラル**
- フレーム長: **160 サンプル = 10ms**
- ビットレート: 約 **16 kbps** (2 KB/s)

### パケット構造

各 BLE Notification は以下の構造:

```
[3バイトヘッダ][Opusペイロード]
```

3バイトヘッダ:
```
Byte 0: パケット番号（下位バイト）
Byte 1: パケット番号（上位バイト）— 全体のシーケンス
Byte 2: フラグメントインデックス — MTU分割時のチャンク番号
```

パケット番号は16ビット（0-65535）で巡回する。

### MTU とフラグメンテーション

- iOS は通常 MTU **247 バイト**をネゴシエート
- Opus フレーム + 3バイトヘッダが MTU に収まる場合、フラグメントインデックス = 0
- 収まらない場合、複数の BLE Notification に分割され、フラグメントインデックスが 0, 1, 2... と増加
- フラグメントインデックス = 0 の Notification が新しい Opus フレームの開始

### パケット解析の Swift 実装パターン

```swift
func parseOmiAudioPacket(_ data: Data) -> (sequenceNumber: UInt16, fragmentIndex: UInt8, opusPayload: Data)? {
    guard data.count >= 4 else { return nil } // 最低4バイト（ヘッダ3 + ペイロード1）

    let seqLow = UInt16(data[0])
    let seqHigh = UInt16(data[1])
    let sequenceNumber = seqLow | (seqHigh << 8)
    let fragmentIndex = data[2]
    let opusPayload = data.subdata(in: 3..<data.count)

    return (sequenceNumber, fragmentIndex, opusPayload)
}
```

## Opus デコードの注意点

PAL プロジェクト (nelcea/PAL) の開発者 Eric Bariaux 氏が文書化した重要な知見:

1. **デコーダインスタンスは録音セッション全体で再利用する**
   - パケットごとに新しいデコーダを作ると深刻な音声歪みが発生する
   - Opus の内部状態（前フレームのコンテキスト）がフレーム間予測に必要

2. **可変ビットレートのため、各パケットを個別の Array<UInt8> として扱う**
   - 複数パケットを Data に結合してはならない
   - 各フレームのサイズが異なるため、境界がわからなくなる

3. **alta/swift-opus パッケージの使い方**
   ```swift
   import Opus

   let decoder = try Opus.Decoder(sampleRate: 16000, channels: 1)

   // パケットごとにデコード（デコーダインスタンスは使い回す）
   let pcmSamples = try decoder.decode(opusPayload)
   ```

## ファームウェアの動作モード

### デュアルモード（BLE接続中 / オフライン）

ファームウェアの `transport.c` 内の `use_storage` フラグが制御:

- **BLE 接続中**: Opus エンコード → GATT Notification で iPhone にリアルタイム送信
- **BLE 切断時**: Opus エンコード → SD カード（FatFS, FAT32）に自動書き込み

切り替えは自動。アプリ側のアクションは不要。

### SD カード同期フロー

1. アプリが再接続を検出
2. ストレージサービスの Characteristic に**書き込みコマンド**を送信
3. ファームウェアが `read_audio_data()` で SD カードから Opus データを読み出し
4. `bt_gatt_notify()` で**チャンク転送**
5. 転送完了時に stop 通知

プロトコルの詳細（コマンドフォーマット等）は:
- ファームウェア: `firmware/omi/src/storage.c` の `storage_write_handler()` と `parse_storage_command()`
- Flutter アプリ: `app/lib/services/devices/omi/omi_connection.dart`

### 既知の問題

- **Issue #2506**: SD カード同期が CV1 デバイスを認識しない問題（パッチ済み、最新ファームウェアで解決）
- **PR #3499**: パケット長エラーとエラー処理の修正
- **PR #3490**: SD カード読み書き時間の最適化
- **バッテリー表示**: 100% → 41% → 63% → -1% と乱高下する既知バグ（ファームウェア側の問題）

## デバイス検出

Omi デバイスは以下の条件でスキャン:

```swift
// Audio Service UUID でフィルタリング
let audioServiceUUID = CBUUID(string: "19B10000-E8F2-537E-4F6C-D104768A1214")
centralManager.scanForPeripherals(
    withServices: [audioServiceUUID],
    options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
)
```

デバイス名は通常 "Omi" または "Friend" で始まる。
