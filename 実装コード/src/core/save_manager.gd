class_name SaveManager
extends RefCounted

## セーブスロット（3枠）のファイル入出力を担う静的ユーティリティ。
## テスト時は dir 引数で保存先を差し替える。

const SLOT_COUNT: int = 3
const SAVE_DIR: String = "user://saves"

static func is_valid_slot(slot: int) -> bool:
    return slot >= 1 and slot <= SLOT_COUNT

static func slot_path(slot: int, dir: String = SAVE_DIR) -> String:
    return "%s/slot_%d.json" % [dir, slot]

static func has_slot(slot: int, dir: String = SAVE_DIR) -> bool:
    if not is_valid_slot(slot):
        return false
    return FileAccess.file_exists(slot_path(slot, dir))

static func save_slot(slot: int, data: SaveData, dir: String = SAVE_DIR) -> bool:
    if not is_valid_slot(slot) or data == null:
        DebugLogger.warn("SaveManager.save_slot", "不正なスロットまたはデータ", {"slot": slot})
        return false
    DirAccess.make_dir_recursive_absolute(dir)
    var f = FileAccess.open(slot_path(slot, dir), FileAccess.WRITE)
    if f == null:
        DebugLogger.error("SaveManager.save_slot", "ファイルを開けません: %s" % slot_path(slot, dir))
        return false
    f.store_string(JSON.stringify(data.to_dict(), "  "))
    f.close()
    return true

## 読込。未保存・破損・未対応バージョンはnullを返す。
static func load_slot(slot: int, dir: String = SAVE_DIR) -> SaveData:
    if not has_slot(slot, dir):
        return null
    var f = FileAccess.open(slot_path(slot, dir), FileAccess.READ)
    if f == null:
        return null
    var text = f.get_as_text()
    f.close()
    var parsed = JSON.parse_string(text)
    if not (parsed is Dictionary):
        DebugLogger.warn("SaveManager.load_slot", "セーブデータが破損しています", {"slot": slot})
        return null
    var data = SaveData.from_dict(parsed)
    if data == null:
        return null
    if data.version > SaveData.CURRENT_VERSION:
        DebugLogger.warn("SaveManager.load_slot", "未対応の新しいバージョンです", {"version": data.version})
        return null
    return data

static func delete_slot(slot: int, dir: String = SAVE_DIR) -> bool:
    if not has_slot(slot, dir):
        return false
    return DirAccess.remove_absolute(slot_path(slot, dir)) == OK

## 全スロット分（常にSLOT_COUNT件）。空きスロットはnull。
static func list_slots(dir: String = SAVE_DIR) -> Array:
    var result: Array = []
    for s in range(1, SLOT_COUNT + 1):
        result.append(load_slot(s, dir))
    return result

static func has_any_save(dir: String = SAVE_DIR) -> bool:
    for s in range(1, SLOT_COUNT + 1):
        if has_slot(s, dir):
            return true
    return false

## 最新のセーブ日時を持つスロット番号。なければ0。
static func latest_slot(dir: String = SAVE_DIR) -> int:
    var best := 0
    var best_time := ""
    for s in range(1, SLOT_COUNT + 1):
        var d = load_slot(s, dir)
        if d != null and (best == 0 or d.saved_at > best_time):
            best = s
            best_time = d.saved_at
    return best

## 「はじめから」開始時に自動セーブ先とするスロット。空きの若い番号、全使用なら1。
static func pick_new_game_slot(dir: String = SAVE_DIR) -> int:
    for s in range(1, SLOT_COUNT + 1):
        if not has_slot(s, dir):
            return s
    return 1

## ===== 中断セーブ（一時離席用・1枠・ロードすると消える） =====
const SUSPEND_FILE: String = "suspend.json"

static func suspend_path(dir: String = SAVE_DIR) -> String:
    return "%s/%s" % [dir, SUSPEND_FILE]

static func has_suspend(dir: String = SAVE_DIR) -> bool:
    return FileAccess.file_exists(suspend_path(dir))

## 保存（既存の中断データは上書きされる）
static func save_suspend(data: SuspendData, dir: String = SAVE_DIR) -> bool:
    if data == null:
        return false
    DirAccess.make_dir_recursive_absolute(dir)
    var f = FileAccess.open(suspend_path(dir), FileAccess.WRITE)
    if f == null:
        DebugLogger.error("SaveManager.save_suspend", "ファイルを開けません: %s" % suspend_path(dir))
        return false
    f.store_string(JSON.stringify(data.to_dict(), "  "))
    f.close()
    return true

## 読込のみ（消さない）。未保存・破損・未対応バージョンはnull。
static func load_suspend(dir: String = SAVE_DIR) -> SuspendData:
    if not has_suspend(dir):
        return null
    var f = FileAccess.open(suspend_path(dir), FileAccess.READ)
    if f == null:
        return null
    var text = f.get_as_text()
    f.close()
    var parsed = JSON.parse_string(text)
    if not (parsed is Dictionary):
        DebugLogger.warn("SaveManager.load_suspend", "中断データが破損しています")
        return null
    var data = SuspendData.from_dict(parsed)
    if data == null or data.version > SuspendData.CURRENT_VERSION:
        return null
    return data

static func delete_suspend(dir: String = SAVE_DIR) -> bool:
    if not has_suspend(dir):
        return false
    return DirAccess.remove_absolute(suspend_path(dir)) == OK

## 中断データを読み込み、同時に削除する（ロードすると消える）
static func consume_suspend(dir: String = SAVE_DIR) -> SuspendData:
    var data = load_suspend(dir)
    if data != null:
        delete_suspend(dir)
    return data

## 通常スロットのロード。成功した場合は中断データも消す（どのデータをロードしても消える）。
static func load_slot_and_clear_suspend(slot: int, dir: String = SAVE_DIR) -> SaveData:
    var data = load_slot(slot, dir)
    if data != null:
        delete_suspend(dir)
    return data