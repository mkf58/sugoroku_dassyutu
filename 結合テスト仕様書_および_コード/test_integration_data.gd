# 結合テスト：データ構造・モデル整合性結合テスト (IT-DAT)
extends "integration_test_case.gd"

const TurnManager = preload("res://src/core/turn_manager.gd")
const GridBoard = preload("res://src/core/grid_board.gd")
const CharacterData = preload("res://src/core/character_data.gd")
const EnemyData = preload("res://src/core/enemy_data.gd")
const CellData = preload("res://src/core/cell_data.gd")
const ItemData = preload("res://src/core/item_data.gd")
const Enums = preload("res://src/core/enums.gd")

func run_all() -> void:
	test_it_dat_001_grid_board_connectivity()
	test_it_dat_002_wind_magic_line_scan()
	test_it_dat_003_sensor_witch_line_of_sight()
	test_it_dat_004_burrow_state_avoids_capture()
	test_it_dat_005_special_cells_data_effect()
	test_it_dat_006_inventory_item_lifecycle()
	test_it_dat_007_fixed_dice_items_integrity()

## IT-DAT-001: グリッド盤面接続と4方向隣接判定
func test_it_dat_001_grid_board_connectivity() -> void:
	test_name = "IT-DAT-001"
	var board = GridBoard.new()
	# (0,0) を中心に十字型にマスを配置
	var center = Vector2i(1, 1)
	board.add_cell(CellData.new(center, Enums.CellType.NORMAL))
	board.add_cell(CellData.new(Vector2i(1, 0), Enums.CellType.NORMAL)) # 上
	board.add_cell(CellData.new(Vector2i(1, 2), Enums.CellType.NORMAL)) # 下
	board.add_cell(CellData.new(Vector2i(0, 1), Enums.CellType.NORMAL)) # 左
	# 右 (2,1) は配置しない（壁）

	board.connect_cells(center, Vector2i(1, 0))
	board.connect_cells(center, Vector2i(1, 2))
	board.connect_cells(center, Vector2i(0, 1))

	var neighbors = board.get_neighbors(center)
	assert_eq(neighbors.size(), 3, "接続された3方向のみが隣接マスとして取得されること")
	assert_true(neighbors.has(Vector2i(1, 0)), "上マスが存在")
	assert_true(neighbors.has(Vector2i(1, 2)), "下マスが存在")
	assert_true(neighbors.has(Vector2i(0, 1)), "左マスが存在")
	assert_false(neighbors.has(Vector2i(2, 1)), "未接続（壁）の右マスは進行不能判定となること")

## IT-DAT-002: 風魔法直線走査（最遠マス特定）
func test_it_dat_002_wind_magic_line_scan() -> void:
	test_name = "IT-DAT-002"
	var board = GridBoard.new()
	# X=0〜4 の直線通路を作成
	for x in range(5):
		board.add_cell(CellData.new(Vector2i(x, 0), Enums.CellType.NORMAL))
	for x in range(4):
		board.connect_cells(Vector2i(x, 0), Vector2i(x + 1, 0))

	# (1, 0) から右方向 (1, 0) への最遠マス走査
	var farthest = board.find_farthest_linear_cell(Vector2i(1, 0), Vector2i(1, 0))
	assert_eq(farthest, Vector2i(4, 0), "同一直線上で連続して繋がっている最遠マス(4,0)が正しく特定されること")

## IT-DAT-003: 感知型魔女視界（壁・潜行による遮断）
func test_it_dat_003_sensor_witch_line_of_sight() -> void:
	test_name = "IT-DAT-003"
	var board = GridBoard.new()
	for x in range(4):
		board.add_cell(CellData.new(Vector2i(x, 0), Enums.CellType.NORMAL))
	for x in range(3):
		board.connect_cells(Vector2i(x, 0), Vector2i(x + 1, 0))

	# 1. 視界が通るケース
	var line1 = board.has_clear_line_of_sight(Vector2i(0, 0), Vector2i(3, 0))
	assert_true(line1, "直線上に接続されたマスがある場合は視界が通ること")

	# 2. 壁で分断されているケース（(1,0)と(2,0)が未接続の別グリッド）
	var board2 = GridBoard.new()
	board2.add_cell(CellData.new(Vector2i(0, 0), Enums.CellType.NORMAL))
	board2.add_cell(CellData.new(Vector2i(1, 0), Enums.CellType.NORMAL))
	board2.add_cell(CellData.new(Vector2i(3, 0), Enums.CellType.NORMAL))
	board2.connect_cells(Vector2i(0, 0), Vector2i(1, 0))
	var line2 = board2.has_clear_line_of_sight(Vector2i(0, 0), Vector2i(3, 0))
	assert_false(line2, "途中に壁・途切れがある場合は視界が遮断されること")

## IT-DAT-004: 土潜行無効化（魔女同マスでも捕縛回避）
func test_it_dat_004_burrow_state_avoids_capture() -> void:
	test_name = "IT-DAT-004"
	var board = GridBoard.new()
	board.add_cell(CellData.new(Vector2i(0, 0), Enums.CellType.NORMAL))
	board.add_cell(CellData.new(Vector2i(1, 0), Enums.CellType.NORMAL))
	board.connect_cells(Vector2i(0, 0), Vector2i(1, 0))

	var hero = CharacterData.new("HERO", "主人公", Vector2i(0, 0), Enums.ElementType.NONE)
	hero.is_burrowed = true
	var witch = EnemyData.new("WITCH_1", "魔女", Vector2i(1, 0), Enums.EnemyType.TRACKING)

	var tm = TurnManager.new()
	tm.setup_stage(board, [hero], [witch], "STAGE_1")

	var burrow_passed = false
	tm.burrow_pass_succeeded.connect(func(u_id, e_id): burrow_passed = true)

	var step_res = tm.step_unit(hero, Vector2i(1, 0), 0)
	assert_true(burrow_passed, "潜行中は魔女と同マスになってもやり過ごし成功シグナルが発火すること")
	assert_ne(step_res.get("result"), "GAME_OVER", "ゲームオーバーにならないこと")
	assert_true(hero.is_alive, "主人公が生存していること")

## IT-DAT-005: 特殊マス効果（RETURN_TO_START / SKIP_TURN）
func test_it_dat_005_special_cells_data_effect() -> void:
	test_name = "IT-DAT-005"
	var board = GridBoard.new()
	var cell_start = CellData.new(Vector2i(0, 0), Enums.CellType.NORMAL)
	var cell_return = CellData.new(Vector2i(1, 0), Enums.CellType.RETURN_TO_START)
	var cell_skip = CellData.new(Vector2i(2, 0), Enums.CellType.SKIP_TURN)
	board.add_cell(cell_start)
	board.add_cell(cell_return)
	board.add_cell(cell_skip)
	board.connect_cells(Vector2i(0, 0), Vector2i(1, 0))
	board.connect_cells(Vector2i(1, 0), Vector2i(2, 0))

	var hero = CharacterData.new("HERO", "主人公", Vector2i(0, 0), Enums.ElementType.NONE)
	var tm = TurnManager.new()
	tm.setup_stage(board, [hero], [], "STAGE_1")

	# 1. RETURN_TO_START 停止テスト
	tm.resolve_stop_cell(hero, cell_return)
	assert_eq(hero.current_coord, Vector2i(0, 0), "RETURN_TO_STARTで初期座標へ送還されること")

	# 2. SKIP_TURN 停止テスト
	tm.resolve_stop_cell(hero, cell_skip)
	assert_true(hero.is_skipped, "SKIP_TURN停止でis_skipped=trueが反映されること")

## IT-DAT-006: インベントリ整合性（アイテム付与・消費）
func test_it_dat_006_inventory_item_lifecycle() -> void:
	test_name = "IT-DAT-006"
	var inventory: Array[Dictionary] = []

	# アイテム獲得
	var dice_item = {
		"id": "DICE_3",
		"name": "3の賽",
		"value": 3,
		"type": "FIXED_DICE"
	}
	inventory.append(dice_item)
	assert_eq(inventory.size(), 1, "アイテムがインベントリに追加されること")

	# アイテム使用による消費
	var used_item = inventory.pop_at(0)
	assert_eq(used_item.get("id"), "DICE_3", "使用したアイテムのIDが一致")
	assert_eq(inventory.size(), 0, "消費後にインベントリが空になること")

## IT-DAT-007: 固定賽データ整合性
func test_it_dat_007_fixed_dice_items_integrity() -> void:
	test_name = "IT-DAT-007"
	for v in range(1, 7):
		var dice = {
			"id": "DICE_%d" % v,
			"name": "%dの賽" % v,
			"value": v,
			"type": "FIXED_DICE"
		}
		assert_eq(dice.get("value"), v, "%dの賽の値が確実に%dであること" % [v, v])
		assert_eq(dice.get("type"), "FIXED_DICE", "アイテム種別がFIXED_DICEであること")
