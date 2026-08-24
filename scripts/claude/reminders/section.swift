// section.swift — Apple リマインダーの「セクション」を読み書きする。
//
//   f(spec JSON on stdin) -> result JSON on stdout
//
// なぜ private framework なのか:
//   セクションは iOS 17 / macOS 14 で入ったが、EventKit にも Reminders の AppleScript 辞書にも
//   一切公開されていない(Apple DTS が forums/820848 で「非対応、Feedback を出せ」と公式回答)。
//   一方 macOS 26 の ReminderKit には REMListSection / REMMembership があり、Reminders.app 自身が
//   これで書いている。App Intents(RemindersAppIntents.framework)経由でも同じ事はできるが、
//   そちらは Shortcuts を1本 GUI で作る必要があり、CLI から閉じない。
//
//   ⚠️ private API なので macOS の更新でセレクタが変わりうる。壊れたら
//   `/System/Library/PrivateFrameworks/ReminderKit.framework` を objc runtime で
//   再列挙して直す(この手順は memory reference_apple_reminders_ops に書いた)。
//
// データモデルの肝: リマインダーの「所属セクション」は **リマインダー側の属性ではない**。
//   リスト側が membership マッピング(member=リマインダーUUID, group=セクションUUID)を持つ。
//   REMReminder をいくら探しても section が見つからないのはこのため。
//
// spec:
//   {"op":"list"}
//   {"op":"create","list":"多元タスク","section":"5分でスマホで出来ること"}
//   {"op":"delete","list":"多元タスク","section":"5分でスマホで出来ること"}
//   {"op":"assign","list":"多元タスク","title":"管理人","section":"5分でスマホで出来ること"}
//     title は部分一致。未完了のリマインダーのみを対象にする。
import Foundation

// MARK: - private ReminderKit の最小 surface（セレクタは @objc で固定する）

@objc protocol REMObjectIDP { func uuid() -> UUID }
@objc protocol REMStoreP {
    @objc(enumerateAllListsWithBlock:) func enumerateAllLists(_ block: @convention(block) (AnyObject, UnsafeMutablePointer<ObjCBool>) -> Void)
    @objc(fetchListSectionsWithListObjectID:error:) func fetchListSections(_ oid: AnyObject, _ err: NSErrorPointer) -> [AnyObject]?
}
@objc protocol REMDataViewP {
    @objc(initWithStore:) func initWith(store: AnyObject) -> AnyObject
    @objc(fetchRemindersWithListID:includingSubtasks:includingCompleted:error:)
    func fetchReminders(_ lid: AnyObject, includingSubtasks: Bool, includingCompleted: Bool, _ err: NSErrorPointer) -> [AnyObject]?
}
@objc protocol REMSaveRequestP {
    @objc(initWithStore:) func initWith(store: AnyObject) -> AnyObject
    @objc(updateList:) func updateList(_ list: AnyObject) -> AnyObject?
    @objc(updateListSection:) func updateListSection(_ s: AnyObject) -> AnyObject?
    @objc(addListSectionWithDisplayName:toListSectionContextChangeItem:)
    func addSection(_ name: String, to ctx: AnyObject) -> AnyObject?
    @objc(saveSynchronouslyWithError:) func saveSynchronously(_ err: NSErrorPointer) -> Bool
}
@objc protocol REMListChangeItemP { @objc(sectionsContextChangeItem) func sectionsContext() -> AnyObject? }
@objc protocol REMSectionCtxP {
    @objc(setUnsavedMembershipsOfRemindersInSections:) func setMemberships(_ m: AnyObject)
    @objc(setUnsavedSectionIDsOrdering:) func setOrdering(_ o: [AnyObject])
    @objc(setShouldUpdateSectionsOrdering:) func setShouldUpdateOrdering(_ b: Bool)
}
@objc protocol REMMembershipP {
    @objc(initWithMemberIdentifier:groupIdentifier:isObsolete:modifiedOn:)
    func initWith(_ member: UUID, groupIdentifier: UUID, isObsolete: Bool, modifiedOn: Date) -> AnyObject
}
@objc protocol REMMembershipsP {
    @objc(initWithMemberships:) func initWith(_ list: [AnyObject]) -> AnyObject
}
@objc protocol REMChangeItemIDP { @objc(remObjectID) func remObjectID() -> AnyObject? }
@objc protocol REMSectionChangeItemP { @objc(removeFromList) func removeFromList() }

// MARK: - 小道具（全部式・状態を持たない）

func die(_ msg: String) -> Never {
    let d = try! JSONSerialization.data(withJSONObject: ["ok": false, "error": msg], options: [.sortedKeys])
    FileHandle.standardOutput.write(d); FileHandle.standardOutput.write(Data("\n".utf8)); exit(1)
}
func emit(_ o: [String: Any]) -> Never {
    let d = (try? JSONSerialization.data(withJSONObject: o.merging(["ok": true]) { a, _ in a }, options: [.sortedKeys, .prettyPrinted]))
        ?? Data(#"{"ok":false,"error":"encode"}"#.utf8)
    FileHandle.standardOutput.write(d); FileHandle.standardOutput.write(Data("\n".utf8)); exit(0)
}
/// title は NSAttributedString で返ることがある（plain String 決め打ちは落ちる）
func plain(_ v: Any?) -> String? {
    (v as? NSAttributedString)?.string ?? (v as? String)
}
/// KVC は key が無いと NSUnknownKeyException を投げる（section は name でなく displayName）
func kv(_ o: AnyObject, _ key: String) -> String? {
    guard o.responds(to: NSSelectorFromString(key)) else { return nil }
    return plain(o.value(forKey: key))
}
func newInstance(_ className: String) -> AnyObject? {
    guard let cls = NSClassFromString(className) as AnyObject? else { return nil }
    return cls.perform(NSSelectorFromString("alloc"))?.takeRetainedValue()
}
func objectID(_ o: AnyObject) -> AnyObject? {
    for sel in ["objectID", "remObjectID"] where o.responds(to: NSSelectorFromString(sel)) {
        if let r = o.perform(NSSelectorFromString(sel))?.takeUnretainedValue() { return r }
    }
    return nil
}
func uuidOf(_ o: AnyObject) -> UUID? {
    objectID(o).flatMap { unsafeBitCast($0, to: REMObjectIDP.self).uuid() }
}

// MARK: - 本体

guard dlopen("/System/Library/PrivateFrameworks/ReminderKit.framework/ReminderKit", RTLD_LAZY) != nil
else { die("ReminderKit を dlopen できない（macOS 更新でパスが変わった可能性）") }

let raw = FileHandle.standardInput.readDataToEndOfFile()
let spec = (try? JSONSerialization.jsonObject(with: raw.isEmpty ? Data("{}".utf8) : raw)) as? [String: Any] ?? [:]
let op = spec["op"] as? String ?? "list"

guard let storeObj = newInstance("REMStore"),
      let store = storeObj.perform(NSSelectorFromString("init"))?.takeRetainedValue()
else { die("REMStore を初期化できない") }
let storeP = unsafeBitCast(store, to: REMStoreP.self)

var lists: [AnyObject] = []
storeP.enumerateAllLists { l, _ in lists.append(l) }

func sectionsOf(_ list: AnyObject) -> [AnyObject] {
    guard let oid = objectID(list) else { return [] }
    var err: NSError?
    return storeP.fetchListSections(oid, &err) ?? []
}
func sectionName(_ s: AnyObject) -> String { kv(s, "displayName") ?? kv(s, "name") ?? "(?)" }

if op == "list" {
    emit(["lists": lists.map { l in
        ["list": kv(l, "name") ?? "(?)",
         "sections": sectionsOf(l).map { s in
             ["name": sectionName(s), "uuid": uuidOf(s)?.uuidString ?? ""] }]
    }])
}

guard let listName = spec["list"] as? String, let secName = spec["section"] as? String
else { die("list と section は必須（op=list 以外）") }
guard let list = lists.first(where: { kv($0, "name") == listName })
else { die("リストが見つからない: \(listName)") }

guard let saveObj = newInstance("REMSaveRequest") else { die("REMSaveRequest なし") }
let save = unsafeBitCast(saveObj, to: REMSaveRequestP.self).initWith(store: store)
let saveP = unsafeBitCast(save, to: REMSaveRequestP.self)
guard let listChange = saveP.updateList(list),
      let ctxObj = unsafeBitCast(listChange, to: REMListChangeItemP.self).sectionsContext()
else { die("セクション context を取得できない") }
let ctx = unsafeBitCast(ctxObj, to: REMSectionCtxP.self)

switch op {
case "create":
    if sectionsOf(list).contains(where: { sectionName($0) == secName }) {
        emit(["created": false, "reason": "already exists", "list": listName, "section": secName])
    }
    guard let sec = saveP.addSection(secName, to: ctxObj),
          let sid = unsafeBitCast(sec, to: REMChangeItemIDP.self).remObjectID()
    else { die("セクションを作成できない") }
    // 既存セクションの並びを保ったまま末尾に足す（順序を落とすと UI で並びが壊れる）
    ctx.setOrdering(sectionsOf(list).compactMap { objectID($0) } + [sid])
    ctx.setShouldUpdateOrdering(true)
    var err: NSError?
    guard saveP.saveSynchronously(&err) else { die(err?.localizedDescription ?? "save 失敗") }
    emit(["created": true, "list": listName, "section": secName])

case "assign":
    guard let needle = spec["title"] as? String else { die("title は必須") }
    guard let section = sectionsOf(list).first(where: { sectionName($0) == secName }),
          let gid = uuidOf(section)
    else { die("セクションが見つからない: \(secName)") }
    guard let dvObj = newInstance("REMRemindersDataView") else { die("REMRemindersDataView なし") }
    let dv = unsafeBitCast(dvObj, to: REMDataViewP.self).initWith(store: store)
    var err: NSError?
    let rems = unsafeBitCast(dv, to: REMDataViewP.self)
        .fetchReminders(objectID(list)!, includingSubtasks: true, includingCompleted: false, &err) ?? []
    guard let reminder = rems.first(where: { (kv($0, "title") ?? "").contains(needle) }),
          let mid = uuidOf(reminder)
    else { die("リマインダーが見つからない: \(needle)") }
    guard let memObj = newInstance("REMMembership"), let memsObj = newInstance("REMMemberships")
    else { die("REMMembership なし") }
    let membership = unsafeBitCast(memObj, to: REMMembershipP.self)
        .initWith(mid, groupIdentifier: gid, isObsolete: false, modifiedOn: Date())
    ctx.setMemberships(unsafeBitCast(memsObj, to: REMMembershipsP.self).initWith([membership]))
    guard saveP.saveSynchronously(&err) else { die(err?.localizedDescription ?? "save 失敗") }
    emit(["assigned": kv(reminder, "title") ?? "", "list": listName, "section": secName])

case "delete":
    guard let section = sectionsOf(list).first(where: { sectionName($0) == secName })
    else { emit(["deleted": false, "reason": "not found", "list": listName, "section": secName]) }
    guard let change = saveP.updateListSection(section) else { die("セクション change item を作れない") }
    unsafeBitCast(change, to: REMSectionChangeItemP.self).removeFromList()
    var derr: NSError?
    guard saveP.saveSynchronously(&derr) else { die(derr?.localizedDescription ?? "save 失敗") }
    emit(["deleted": true, "list": listName, "section": secName])

default:
    die("unknown op: \(op)（list | create | assign | delete）")
}
