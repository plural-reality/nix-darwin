// zwift-mode — 家のディスプレイを「Zwiftモード(真ミラー@4K60、無ければ最良の60Hz)」⇄「平常(拡張)」に切り替える単一バイナリ。
//
// 設計(why):
//   表示状態を *状態の関数* として扱う:  layout = (Zwift生存 ∧ 外部接続) ? mirror@bestMode(4K優先) : 拡張
//   命令的トグルではなく、イベント(Zwift の launch/quit、ディスプレイ再構成)を「再評価せよ」という
//   単なる tick として受け、その都度 ground-truth を読んで目標レイアウトを *冪等* に適用する(FRP の scan)。
//   これにより「ランチャー(com.zwift.ZwiftLauncher)とゲーム本体は別プロセス」問題を構造的に吸収する:
//   観測は Zwift 系プロセスの launch/quit を拾うだけ、適用可否は毎回 NSWorkspace から再評価する。
//   平常への復帰は決め打ちでなく「突入前の構成を snapshot → 終了時に replay」する前後対称の変換。
//
// 依存: なし(displayplacer 等は不要)。CoreGraphics でミラー/解像度、NSWorkspace で起動検知。
//
// NSWorkspace の既知の罠(リサーチで確認):
//   ① 通知は NSWorkspace.shared.notificationCenter に来る(NotificationCenter.default ではない)。
//   ② LaunchDaemon では WindowServer に繋がらず動かない → 必ず LaunchAgent(Aqua)。
//   ③ RunLoop を回し続けないとコールバックは一度も発火しない。
//
// CLI: zwift-mode [watch|zwift|restore|reconcile|status]

import AppKit
import CoreGraphics
import Foundation

// MARK: - 設定(Zwiftモードの目標)
let kNull: CGDirectDisplayID = 0
// status 表示用の名目値。実際の選択は pick60 が外部パネルの最良 60Hz モードを動的決定する。
let ZWIFT_W = 3840
let ZWIFT_H = 2160
let ZWIFT_HZ = 60.0

let snapshotURL: URL = {
  let dir = FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent(".claude/.cache/zwift-mode", isDirectory: true)
  try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
  return dir.appendingPathComponent("prev-layout.json")
}()

// 自前の apply 中はディスプレイ再構成コールバックを無視するためのガード(ループ防止)。
var isApplying = false

// MARK: - ディスプレイ列挙(純粋な読み取り)
func onlineDisplays() -> [CGDirectDisplayID] {
  var count: UInt32 = 0
  guard CGGetOnlineDisplayList(0, nil, &count) == .success, count > 0 else { return [] }
  var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
  guard CGGetOnlineDisplayList(count, &ids, &count) == .success else { return [] }
  return Array(ids.prefix(Int(count)))
}

func isBuiltin(_ id: CGDirectDisplayID) -> Bool { CGDisplayIsBuiltin(id) != 0 }

// マスター(ミラー時に内容を出す側)= 内蔵パネル。lid 開きの通常運用ではこれが main。
func internalDisplay() -> CGDirectDisplayID {
  onlineDisplays().first(where: isBuiltin) ?? CGMainDisplayID()
}

func externalDisplays() -> [CGDirectDisplayID] {
  onlineDisplays().filter { !isBuiltin($0) }
}

func currentlyMirrored() -> Bool {
  // どちら向きのミラー(内蔵→外部 / 外部→内蔵)でも検出するため全 online を見る。
  onlineDisplays().contains { CGDisplayMirrorsDisplay($0) != kNull }
}

// MARK: - モード探索
func allModes(_ id: CGDirectDisplayID) -> [CGDisplayMode] {
  // HiDPI/低解像度の複製モードまで含めて 1920x1080 を確実に拾う。
  let opts = [kCGDisplayShowDuplicateLowResolutionModes as String: true] as CFDictionary
  return (CGDisplayCopyAllDisplayModes(id, opts) as? [CGDisplayMode]) ?? []
}

// w×h@hz に最も合うモード。内蔵パネルは refreshRate を 0 と報告するので 0 を 60 相当とみなす。
func mode(_ id: CGDirectDisplayID, w: Int, h: Int, hz: Double) -> CGDisplayMode? {
  let m = allModes(id).filter { $0.width == w && $0.height == h }
  return m.first { abs($0.refreshRate - hz) < 0.5 }
    ?? m.first { $0.refreshRate == 0 }
    ?? m.first
}

func mode(byIOID ioID: Int32, on id: CGDirectDisplayID) -> CGDisplayMode? {
  allModes(id).first { $0.ioDisplayModeID == ioID }
}

// MARK: - snapshot(平常レイアウトの保存・復元)
struct DisplaySnap: Codable { let id: UInt32; let ioModeID: Int32; let x: Int32; let y: Int32 }

func captureSnapshot() -> [DisplaySnap] {
  onlineDisplays().compactMap { id in
    guard let cur = CGDisplayCopyDisplayMode(id) else { return nil }
    let b = CGDisplayBounds(id)
    return DisplaySnap(id: id, ioModeID: cur.ioDisplayModeID, x: Int32(b.origin.x), y: Int32(b.origin.y))
  }
}

func saveSnapshot(_ s: [DisplaySnap]) {
  if let data = try? JSONEncoder().encode(s) { try? data.write(to: snapshotURL) }
}
func loadSnapshot() -> [DisplaySnap]? {
  guard let d = try? Data(contentsOf: snapshotURL) else { return nil }
  return try? JSONDecoder().decode([DisplaySnap].self, from: d)
}
func clearSnapshot() { try? FileManager.default.removeItem(at: snapshotURL) }

// 真ミラー時に外部を 60Hz で走らせるための共通モード選択。外部 4K パネルでは「実ピクセル
// 3840x2160@60」を最優先し、Zwift を真の 4K backing で描かせる(従来は 1440p 上限で軟調だった)。
// 同一ピクセルなら 2x HiDPI(width*2==pixelWidth, UI が大きく可読) > その他 HiDPI > native(等倍・UI 微小)。
// 4K@60 が無いケーブル/TV では 1440p→1080p→実ピクセル面積最大へ綺麗に縮退(4K@30 は選ばない=滑らかさ優先)。
let PREF_PX: [(pw: Int, ph: Int)] = [(3840, 2160), (2560, 1440), (1920, 1080)]
func pick60(_ id: CGDirectDisplayID) -> CGDisplayMode? {
  let m = allModes(id).filter { abs($0.refreshRate - 60) < 0.5 }
  let preferred = PREF_PX.lazy.compactMap { p -> CGDisplayMode? in
    let cands = m.filter { $0.pixelWidth == p.pw && $0.pixelHeight == p.ph }
    return cands.first { $0.width * 2 == $0.pixelWidth }   // 2x HiDPI(UI最大・標準的な綺麗さ)
        ?? cands.first { $0.width < $0.pixelWidth }         // その他 HiDPI
        ?? cands.first                                      // native(等倍)
  }.first
  return preferred ?? m.max { $0.pixelWidth * $0.pixelHeight < $1.pixelWidth * $1.pixelHeight }
}

// MARK: - 適用(唯一の副作用境界)
func elog(_ s: String) { FileHandle.standardError.write(Data((s + "\n").utf8)) }
func ck(_ label: String, _ e: CGError) { elog("  [\(label)] CGError=\(e.rawValue)") }

func applyZwiftMode() {
  let internalID = internalDisplay()
  let exts = externalDisplays()
  guard !exts.isEmpty else { elog("applyZwift: no external → skip"); return }
  guard !currentlyMirrored() else { elog("applyZwift: already mirrored → skip"); return }
  saveSnapshot(captureSnapshot())            // 突入前の平常構成を記憶
  isApplying = true
  defer { isApplying = false }

  // 外部ディスプレイ最適化: 外部を master(フレームバッファの基準)にして native 寄りの 60Hz 高解像度で
  // Zwift を描かせ、内蔵をその縮小ミラーにする。内蔵を master にすると内蔵の小さい枠(1470x956)で描いて
  // 外部に拡大表示＝MacBook 最適化になってしまう(直前の不満点)。要点は「外部を master に」反転すること。
  guard let ext = exts.first else { return }

  // txn1: 外部(master)を 1440p60 へ(無ければ 1080p60 / 最大面積)。
  if let m60 = pick60(ext) {
    var c1: CGDisplayConfigRef?
    if CGBeginDisplayConfiguration(&c1) == .success {
      ck("setmode ext=\(ext) \(m60.width)x\(m60.height)@60 io=\(m60.ioDisplayModeID)",
         CGConfigureDisplayWithDisplayMode(c1, ext, m60, nil))
      ck("complete txn1(ext mode)", CGCompleteDisplayConfiguration(c1, .permanently))
    }
  } else { elog("  外部に 60Hz モードなし") }

  // txn2: 内蔵を外部のミラーにする(内蔵=slave, 外部=master)。framebuffer が外部の解像度になり、
  // Zwift は外部 native で描かれて綺麗・滑らか。内蔵はその縮小表示。
  var c2: CGDisplayConfigRef?
  if CGBeginDisplayConfiguration(&c2) == .success {
    ck("mirror internal=\(internalID)->ext=\(ext)", CGConfigureDisplayMirrorOfDisplay(c2, internalID, ext))
    ck("complete txn2(mirror)", CGCompleteDisplayConfiguration(c2, .permanently))
  } else { elog("  CGBeginDisplayConfiguration txn2 failed") }
}

func restoreNormal() {
  isApplying = true
  defer { isApplying = false }
  var cfg: CGDisplayConfigRef?
  guard CGBeginDisplayConfiguration(&cfg) == .success else { return }
  for d in onlineDisplays() {
    CGConfigureDisplayMirrorOfDisplay(cfg, d, kNull) // どちら向きのミラーでも解除(全 online)
  }
  if let snap = loadSnapshot() { // 保存済みなら厳密復元、無ければ解除のみで macOS が拡張へ整列
    for s in snap {
      let id = CGDirectDisplayID(s.id)
      if let m = mode(byIOID: s.ioModeID, on: id) {
        CGConfigureDisplayWithDisplayMode(cfg, id, m, nil)
      }
      CGConfigureDisplayOrigin(cfg, id, s.x, s.y)
    }
  }
  CGCompleteDisplayConfiguration(cfg, .permanently)
  clearSnapshot()
}

// MARK: - 述語と統合(reconcile = 純粋な判断 → 冪等適用)
func isZwiftRunning() -> Bool {
  NSWorkspace.shared.runningApplications.contains { app in
    let n = (app.localizedName ?? "").lowercased()
    let b = (app.bundleIdentifier ?? "").lowercased()
    let isZwift = b.hasPrefix("com.zwift") || n.hasPrefix("zwift")
    return isZwift && n != "zwift-mode" && b != "com.tkgshn.zwift-mode" // 自分自身は除外
  }
}

func reconcile() {
  guard !isApplying else { return }
  let want = isZwiftRunning() && !externalDisplays().isEmpty
  let now = currentlyMirrored()
  guard want != now else { return } // 既に望む状態 → no-op
  if want { applyZwiftMode() } else { restoreNormal() }
}

// MARK: - 監視(イベント源)
func cgCallback(_ display: CGDirectDisplayID,
                _ flags: CGDisplayChangeSummaryFlags,
                _ userInfo: UnsafeMutableRawPointer?) {
  guard !isApplying else { return }
  reconcile() // 外部の抜き差し等でも目標状態を保つ
}

func watch() {
  let nc = NSWorkspace.shared.notificationCenter // ★ default ではない
  let onAppEvent: (Notification) -> Void = { note in
    guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
    let n = (app.localizedName ?? "").lowercased()
    let b = (app.bundleIdentifier ?? "").lowercased()
    guard b.hasPrefix("com.zwift") || n.hasPrefix("zwift") else { return }
    reconcile()
  }
  nc.addObserver(forName: NSWorkspace.didLaunchApplicationNotification,
                 object: nil, queue: .main, using: onAppEvent)
  nc.addObserver(forName: NSWorkspace.didTerminateApplicationNotification,
                 object: nil, queue: .main, using: onAppEvent)
  CGDisplayRegisterReconfigurationCallback(cgCallback, nil)
  reconcile()           // 起動直後の整合(login 時に既に Zwift が動いている等)
  RunLoop.main.run()    // ★ 回し続ける
}

// MARK: - 観測(非破壊)
func describeMode(_ id: CGDirectDisplayID) -> String {
  guard let m = CGDisplayCopyDisplayMode(id) else { return "?" }
  return "\(m.width)x\(m.height)@\(String(format: "%.0f", m.refreshRate))Hz"
}

func printModes() {
  for id in onlineDisplays() {
    let tag = isBuiltin(id) ? "internal" : "external"
    print("\(tag) id=\(id) available modes (w x h @ hz | pixels | ioID):")
    let ms = allModes(id)
      .map { (w: $0.width, h: $0.height, hz: $0.refreshRate, pw: $0.pixelWidth, ph: $0.pixelHeight, io: $0.ioDisplayModeID) }
      .sorted { ($0.w, $0.h, $0.hz) > ($1.w, $1.h, $1.hz) }
    for m in ms {
      print("    \(m.w)x\(m.h)@\(String(format: "%.0f", m.hz))Hz  px=\(m.pw)x\(m.ph) io=\(m.io)")
    }
  }
}

func printStatus() {
  let internalID = internalDisplay()
  let want = isZwiftRunning() && !externalDisplays().isEmpty
  let now = currentlyMirrored()
  print("zwift-mode status")
  print("  zwift running : \(isZwiftRunning())")
  print("  external count: \(externalDisplays().count)")
  print("  current layout: \(now ? "ZWIFT (mirror)" : "normal (extended)")")
  print("  displays:")
  for id in onlineDisplays() {
    let tag = isBuiltin(id) ? "internal" : "external"
    let main = id == internalID ? " [builtin]" : ""
    let mirrors = CGDisplayMirrorsDisplay(id)
    let mir = mirrors != kNull ? " mirrors=\(mirrors)" : ""
    let o = CGDisplayBounds(id).origin
    print("    \(tag)\(main) id=\(id) \(describeMode(id)) origin=(\(Int(o.x)),\(Int(o.y)))\(mir)")
  }
  print("  reconcile would: \(want == now ? "no-op" : (want ? "apply ZWIFT mirror@\(ZWIFT_W)x\(ZWIFT_H)/\(Int(ZWIFT_HZ))" : "restore normal"))")
}

// MARK: - エントリ
let cmd = CommandLine.arguments.dropFirst().first ?? "status"
switch cmd {
case "watch": watch()
case "zwift", "apply": applyZwiftMode()
case "restore", "normal": restoreNormal()
case "reconcile": reconcile()
case "modes": printModes()
case "status": printStatus()
default:
  FileHandle.standardError.write(Data("usage: zwift-mode [watch|zwift|restore|reconcile|status]\n".utf8))
  exit(2)
}
