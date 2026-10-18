class_name CharacterData
extends RefCounted

var character_id: String = ""       ## "HERO", "GIRL_FIRE", etc.
var name: String = ""
var current_coord: Vector2i = Vector2i.ZERO
var initial_coord: Vector2i = Vector2i.ZERO
var is_alive: bool = true
var has_acted: bool = false
var revive_turn_count: int = 0      ## 魔女に殺された後の復活ターン（初期3）
var is_burrowed: bool = false       ## 土魔法の潜行状態
var is_skipped: bool = false        ## 1回休み状態
var available_magics: Array[Enums.ElementType] = []

func _init(p_id: String, p_name: String, p_init_coord: Vector2i) -> void:
    character_id = p_id
    name = p_name
    initial_coord = p_init_coord
    current_coord = p_init_coord
    is_alive = true
    has_acted = false
    revive_turn_count = 0
    is_burrowed = false
    is_skipped = false

func reset_turn_state() -> void:
    if is_skipped:
        is_skipped = false
        has_acted = true  ## 休みにより自動行動済み
    else:
        has_acted = false

func kill() -> void:
    is_alive = false
    is_burrowed = false
    revive_turn_count = 3

func tick_revive() -> bool:
    if not is_alive and revive_turn_count > 0:
        revive_turn_count -= 1
        if revive_turn_count <= 0:
            is_alive = true
            current_coord = initial_coord
            has_acted = false
            return true
    return false
