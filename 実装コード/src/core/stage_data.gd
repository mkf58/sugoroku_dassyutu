class_name StageData
extends RefCounted

## ステージ定義モデルクラス
## 各階層の盤面、初期配置、同行者、次階層の接続を保持する。

var stage_id: String = ""
var stage_name: String = ""
var floor_number: int = 1
var board: GridBoard = null
var hero_coord: Vector2i = Vector2i(1, 3)
var enemies: Array[Dictionary] = []
var companions: Array[Dictionary] = []
var next_stage_id: String = ""
var initial_camera_pos: Vector2 = Vector2(480, 200)
var initial_camera_zoom: Vector2 = Vector2(0.95, 0.95)

func _init(
    p_id: String = "",
    p_name: String = "",
    p_floor: int = 1,
    p_board: GridBoard = null,
    p_hero: Vector2i = Vector2i(1, 3),
    p_enemies: Array[Dictionary] = [],
    p_companions: Array[Dictionary] = [],
    p_next_stage: String = "",
    p_cam_pos: Vector2 = Vector2(480, 200),
    p_cam_zoom: Vector2 = Vector2(0.95, 0.95)
) -> void:
    stage_id = p_id
    stage_name = p_name
    floor_number = p_floor
    board = p_board if p_board else GridBoard.new()
    hero_coord = p_hero
    enemies = p_enemies
    companions = p_companions
    next_stage_id = p_next_stage
    initial_camera_pos = p_cam_pos
    initial_camera_zoom = p_cam_zoom
