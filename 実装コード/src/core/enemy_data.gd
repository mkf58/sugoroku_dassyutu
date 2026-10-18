class_name EnemyData
extends RefCounted

var enemy_id: String = ""
var enemy_type: Enums.EnemyType = Enums.EnemyType.TRACKING
var current_coord: Vector2i = Vector2i.ZERO
var initial_coord: Vector2i = Vector2i.ZERO
var is_alive: bool = true
var revive_turn_count: int = 0      ## 炎魔法で撃破された後の復活カウンタ（2ターン）
var patrol_coords: Array[Vector2i] = []
var patrol_index: int = 0
var stun_turns: int = 0             ## 土魔法による行動不能ターン（1ターン）

func _init(p_id: String, p_type: Enums.EnemyType, p_coord: Vector2i) -> void:
    enemy_id = p_id
    enemy_type = p_type
    initial_coord = p_coord
    current_coord = p_coord
    is_alive = true
    revive_turn_count = 0
    stun_turns = 0

func defeat() -> void:
    is_alive = false
    revive_turn_count = 2

func tick_revive() -> bool:
    if not is_alive and revive_turn_count > 0:
        revive_turn_count -= 1
        if revive_turn_count <= 0:
            is_alive = true
            current_coord = initial_coord
            return true
    return false
