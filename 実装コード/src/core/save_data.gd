class_name SaveData
extends RefCounted

## セーブデータ型。ステージクリア時に保存する最小限の状態のみを保持する。
## 座標・生死・ターン数などのステージ内状態は次ステージ開始時に初期化されるため保存しない。

const CURRENT_VERSION: int = 1

var version: int = CURRENT_VERSION
var saved_at: String = ""                 ## セーブ日時（表示用）
var next_stage_id: String = ""            ## 再開するステージID
var cleared_stage_name: String = ""       ## 直前にクリアしたステージ名（表示用）
var inventory: Array[Dictionary] = []     ## 所持アイテム
var visited_event_ids: Array = []         ## 踏んだイベントマスのID
var progress_flags: Dictionary = {}       ## ストーリー進行フラグ（仮置き）
var clear_flags: Dictionary = {}          ## クリアフラグ（仮置き）
var achievement_counters: Dictionary = {} ## 実績用カウンタ（枠のみ確保）

func to_dict() -> Dictionary:
    return {
        "version": version,
        "saved_at": saved_at,
        "next_stage_id": next_stage_id,
        "cleared_stage_name": cleared_stage_name,
        "inventory": inventory.duplicate(true),
        "story": {
            "visited_event_ids": visited_event_ids.duplicate(),
            "progress_flags": progress_flags.duplicate(true),
            "clear_flags": clear_flags.duplicate(true),
        },
        "achievements": {
            "counters": achievement_counters.duplicate(true),
        },
    }

## 辞書から復元する。必須キー欠落などの不正データはnullを返す。
static func from_dict(data: Dictionary) -> SaveData:
    if not data.has("version") or not data.has("next_stage_id"):
        return null
    var d = SaveData.new()
    d.version = int(data["version"])
    d.saved_at = str(data.get("saved_at", ""))
    d.next_stage_id = str(data["next_stage_id"])
    d.cleared_stage_name = str(data.get("cleared_stage_name", ""))
    var inv: Array[Dictionary] = []
    for item in data.get("inventory", []):
        if item is Dictionary:
            var copy: Dictionary = item.duplicate(true)
            # JSON経由で数値がfloat化するため、値はintへ戻す
            if copy.has("value"):
                copy["value"] = int(copy["value"])
            inv.append(copy)
    d.inventory = inv
    var story: Dictionary = data.get("story", {})
    d.visited_event_ids = Array(story.get("visited_event_ids", [])).duplicate()
    d.progress_flags = Dictionary(story.get("progress_flags", {})).duplicate(true)
    d.clear_flags = Dictionary(story.get("clear_flags", {})).duplicate(true)
    var ach: Dictionary = data.get("achievements", {})
    d.achievement_counters = Dictionary(ach.get("counters", {})).duplicate(true)
    return d

## 「はじめから」用：ステージ1開始状態の初期セーブデータ
static func new_game(first_stage_id: String) -> SaveData:
    var d = SaveData.new()
    d.saved_at = Time.get_datetime_string_from_system(false, true)
    d.next_stage_id = first_stage_id
    d.cleared_stage_name = ""
    d.inventory = initial_inventory()
    return d

## ゲーム開始時の所持品（1の賽）
static func initial_inventory() -> Array[Dictionary]:
    var inv: Array[Dictionary] = []
    inv.append({
        "id": "DICE_1_INIT",
        "name": "1の賽",
        "desc": "出目が必ず【1】になる固定ダイス",
        "value": 1,
        "type": "FIXED_DICE",
        "icon_text": "🎲",
    })
    return inv

## まだ1ステージもクリアしていない開始前セーブか
func is_initial() -> bool:
    return cleared_stage_name.is_empty()