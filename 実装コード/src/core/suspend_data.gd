class_name SuspendData
extends RefCounted

## 中断セーブ（一時離席用スナップショット）のデータ型。
## ステージ途中の盤面状態を保存する。ロードすると消える1枠のみ。

const CURRENT_VERSION: int = 1

var version: int = CURRENT_VERSION
var saved_at: String = ""
var stage_id: String = ""
var current_turn: int = 1
var characters: Dictionary = {}       ## id -> {coord, is_alive, has_acted, revive_turn_count, is_burrowed, is_skipped}
var enemies: Dictionary = {}          ## id -> {coord, is_alive, revive_turn_count, stun_turns, patrol_index}
var cell_overrides: Array = []        ## 初期盤面との差分マス [{coord, cell_type, is_consumed}]
var inventory: Array[Dictionary] = []
var visited_event_ids: Array = []
var progress_flags: Dictionary = {}
var clear_flags: Dictionary = {}
var achievement_counters: Dictionary = {}
var active_slot: int = 1              ## オートセーブ先スロット

## TurnManager の現在状態を取り込む。fresh_board は同ステージの初期盤面（差分検出用）。
static func capture(tm: TurnManager, fresh_board: GridBoard) -> SuspendData:
    var s = SuspendData.new()
    s.saved_at = Time.get_datetime_string_from_system(false, true)
    s.stage_id = tm.stage_id
    s.current_turn = tm.current_turn
    for id in tm.characters.keys():
        var c: CharacterData = tm.characters[id]
        s.characters[id] = {
            "coord": [c.current_coord.x, c.current_coord.y],
            "is_alive": c.is_alive,
            "has_acted": c.has_acted,
            "revive_turn_count": c.revive_turn_count,
            "is_burrowed": c.is_burrowed,
            "is_skipped": c.is_skipped,
        }
    for id in tm.enemies.keys():
        var e: EnemyData = tm.enemies[id]
        s.enemies[id] = {
            "coord": [e.current_coord.x, e.current_coord.y],
            "is_alive": e.is_alive,
            "revive_turn_count": e.revive_turn_count,
            "stun_turns": e.stun_turns,
            "patrol_index": e.patrol_index,
        }
    if tm.board != null and fresh_board != null:
        for coord in tm.board.cells.keys():
            var now: CellData = tm.board.cells[coord]
            var base: CellData = fresh_board.get_cell(coord)
            if base == null:
                continue
            if now.cell_type != base.cell_type or now.is_consumed != base.is_consumed:
                s.cell_overrides.append({
                    "coord": [coord.x, coord.y],
                    "cell_type": now.cell_type,
                    "is_consumed": now.is_consumed,
                })
    return s

## 保存した状態を TurnManager へ反映する。不明なID・座標は無視する。
func apply_to(tm: TurnManager) -> bool:
    if tm == null:
        return false
    tm.current_turn = current_turn
    for id in characters.keys():
        if not tm.characters.has(id):
            continue
        var d: Dictionary = characters[id]
        var c: CharacterData = tm.characters[id]
        c.current_coord = Vector2i(int(d["coord"][0]), int(d["coord"][1]))
        c.is_alive = bool(d.get("is_alive", true))
        c.has_acted = bool(d.get("has_acted", false))
        c.revive_turn_count = int(d.get("revive_turn_count", 0))
        c.is_burrowed = bool(d.get("is_burrowed", false))
        c.is_skipped = bool(d.get("is_skipped", false))
    for id in enemies.keys():
        if not tm.enemies.has(id):
            continue
        var d: Dictionary = enemies[id]
        var e: EnemyData = tm.enemies[id]
        e.current_coord = Vector2i(int(d["coord"][0]), int(d["coord"][1]))
        e.is_alive = bool(d.get("is_alive", true))
        e.revive_turn_count = int(d.get("revive_turn_count", 0))
        e.stun_turns = int(d.get("stun_turns", 0))
        e.patrol_index = int(d.get("patrol_index", 0))
    if tm.board != null:
        for o in cell_overrides:
            var cell = tm.board.get_cell(Vector2i(int(o["coord"][0]), int(o["coord"][1])))
            if cell == null:
                continue
            cell.cell_type = int(o["cell_type"]) as Enums.CellType
            cell.is_consumed = bool(o["is_consumed"])
    return true

func to_dict() -> Dictionary:
    return {
        "version": version,
        "saved_at": saved_at,
        "stage_id": stage_id,
        "current_turn": current_turn,
        "characters": characters.duplicate(true),
        "enemies": enemies.duplicate(true),
        "cell_overrides": cell_overrides.duplicate(true),
        "inventory": inventory.duplicate(true),
        "story": {
            "visited_event_ids": visited_event_ids.duplicate(),
            "progress_flags": progress_flags.duplicate(true),
            "clear_flags": clear_flags.duplicate(true),
        },
        "achievements": {"counters": achievement_counters.duplicate(true)},
        "active_slot": active_slot,
    }

static func from_dict(data: Dictionary) -> SuspendData:
    if not data.has("version") or not data.has("stage_id") or not data.has("current_turn") \
            or not data.has("characters") or not data.has("enemies"):
        return null
    if str(data["stage_id"]).is_empty():
        return null
    var s = SuspendData.new()
    s.version = int(data["version"])
    s.saved_at = str(data.get("saved_at", ""))
    s.stage_id = str(data["stage_id"])
    s.current_turn = int(data["current_turn"])
    s.characters = Dictionary(data["characters"]).duplicate(true)
    s.enemies = Dictionary(data["enemies"]).duplicate(true)
    s.cell_overrides = Array(data.get("cell_overrides", [])).duplicate(true)
    var inv: Array[Dictionary] = []
    for item in data.get("inventory", []):
        if item is Dictionary:
            var copy: Dictionary = item.duplicate(true)
            if copy.has("value"):
                copy["value"] = int(copy["value"])
            inv.append(copy)
    s.inventory = inv
    var story: Dictionary = data.get("story", {})
    s.visited_event_ids = Array(story.get("visited_event_ids", [])).duplicate()
    s.progress_flags = Dictionary(story.get("progress_flags", {})).duplicate(true)
    s.clear_flags = Dictionary(story.get("clear_flags", {})).duplicate(true)
    s.achievement_counters = Dictionary(Dictionary(data.get("achievements", {})).get("counters", {})).duplicate(true)
    s.active_slot = int(data.get("active_slot", 1))
    return s

