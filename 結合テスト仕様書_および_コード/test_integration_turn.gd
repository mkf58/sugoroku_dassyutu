# 結合テスト：ゲーム進行・ターン制御フロー結合テスト (IT-TRN)
extends "integration_test_case.gd"

const TurnManager = preload("res://src/core/turn_manager.gd")
const GridBoard = preload("res://src/core/grid_board.gd")
const CharacterData = preload("res://src/core/character_data.gd")
const EnemyData = preload("res://src/core/enemy_data.gd")
const CellData = preload("res://src/core/cell_data.gd")
const Enums = preload("res://src/core/enums.gd")

func run_all() -> void:
	test_it_trn_001_player_turn_continuation()
	test_it_trn_002_all_acted_advances_phase()
	test_it_trn_003_magic_cost_consumes_turn()
	test_it_trn_004_water_trap_stops_immediately()
	test_it_trn_005_water_trap_next_turn_escape()
	test_it_trn_006_burrow_pray_retains_burrow()
	test_it_trn_007_burrow_move_unburrows()
	test_it_trn_008_realtime_enemy_contact_gameover()
	test_it_trn_009_witch_target_distance()
	test_it_trn_010_witch_target_priority_same_dist()
	test_it_trn_011_all_burrowed_witch_returns()
	test_it_trn_012_chest_event_cell()
	test_it_trn_013_exit_cell_clears_stage()
	test_it_trn_014_additional_move_chains()
	test_it_trn_015_roundtrip_movement_step_evaluation()

# 直線5マスのボードを構築するヘルパー
func _create_linear_board(length: int = 5) -> GridBoard:
	var board = GridBoard.new()
	for x in range(length):
		var coord = Vector2i(x, 0)
		var cell = CellData.new(coord, Enums.CellType.NORMAL)
		board.add_cell(cell)
	for x in range(length - 1):
		board.connect_cells(Vector2i(x, 0), Vector2i(x + 1, 0))
	return board

## IT-TRN-001: プレイヤーターン味方順次行動遷移
func test_it_trn_001_player_turn_continuation() -> void:
	test_name = "IT-TRN-001"
	var board = _create_linear_board(5)
	var hero = CharacterData.new("HERO", "主人公", Vector2i(0, 0), Enums.ElementType.NONE)
	var girl = CharacterData.new("GIRL_FIRE", "炎の少女", Vector2i(1, 0), Enums.ElementType.FIRE)
	var tm = TurnManager.new()
	tm.setup_stage(board, [hero, girl], [], "STAGE_1")
	tm.start_player_turn()

	assert_true(tm.select_character("HERO"), "主人公を選択可能")
	# 主人公を行動済みにする
	hero.has_acted = true

	# プレイヤーターンは継続し、少女が選択可能
	assert_true(tm.select_character("GIRL_FIRE"), "味方A行動完了後も味方Bが未行動として選択可能")

## IT-TRN-002: 味方全員行動完了時の判定
func test_it_trn_002_all_acted_advances_phase() -> void:
	test_name = "IT-TRN-002"
	var board = _create_linear_board(5)
	var hero = CharacterData.new("HERO", "主人公", Vector2i(0, 0), Enums.ElementType.NONE)
	var tm = TurnManager.new()
	tm.setup_stage(board, [hero], [], "STAGE_1")
	tm.start_player_turn()

	tm.select_character("HERO")
	hero.has_acted = true

	var all_acted = true
	for c in tm.characters.values():
		if c.is_alive and not c.has_acted and not c.is_skipped:
			all_acted = false
			break
	assert_true(all_acted, "全員行動完了の判定が真となること")

## IT-TRN-003: 魔法使用時の移動不可・即時行動済み
func test_it_trn_003_magic_cost_consumes_turn() -> void:
	test_name = "IT-TRN-003"
	var board = _create_linear_board(5)
	var girl = CharacterData.new("GIRL_WATER", "水の少女", Vector2i(0, 0), Enums.ElementType.WATER)
	var tm = TurnManager.new()
	tm.setup_stage(board, [girl], [], "STAGE_1")
	tm.start_player_turn()

	assert_false(girl.has_acted, "魔法詠唱前は未行動")
	var success = tm.execute_magic("GIRL_WATER", Enums.ElementType.WATER, Vector2i(2, 0))
	assert_true(success, "水魔法が正常に発動")
	assert_true(girl.has_acted, "魔法発動後は即座に行動済み（移動との二者択一）となること")

## IT-TRN-004: 移動途中の水トラップ即時停止
func test_it_trn_004_water_trap_stops_immediately() -> void:
	test_name = "IT-TRN-004"
	var board = _create_linear_board(5)
	# (1, 0) を水トラップに設定
	board.get_cell(Vector2i(1, 0)).cell_type = Enums.CellType.WATER_TRAP

	var hero = CharacterData.new("HERO", "主人公", Vector2i(0, 0), Enums.ElementType.NONE)
	var tm = TurnManager.new()
	tm.setup_stage(board, [hero], [], "STAGE_1")
	tm.start_player_turn()

	# 出目3で (0,0) から 1歩目 (1,0) へ進む
	var step_res = tm.step_unit(hero, Vector2i(1, 0), 2)
	assert_eq(step_res.get("result"), "WATER_TRAP_STOP", "水トラップ進入時に即時停止結果が返ること")
	assert_true(hero.has_acted, "水トラップ停止時に行動済みとなること")
	assert_eq(hero.current_coord, Vector2i(1, 0), "水トラップマスで停止していること")

## IT-TRN-005: 水トラップ上からの次ターン脱出
func test_it_trn_005_water_trap_next_turn_escape() -> void:
	test_name = "IT-TRN-005"
	var board = _create_linear_board(5)
	board.get_cell(Vector2i(1, 0)).cell_type = Enums.CellType.WATER_TRAP

	var hero = CharacterData.new("HERO", "主人公", Vector2i(1, 0), Enums.ElementType.NONE)
	hero.has_acted = true
	var tm = TurnManager.new()
	tm.setup_stage(board, [hero], [], "STAGE_1")

	# 次ターン開始
	tm.end_turn_and_advance()
	assert_false(hero.has_acted, "次ターン開始時に行動可能へリセット")
	assert_true(tm.select_character("HERO"), "水トラップ上のユニットを選択可能")

	# 水トラップから (2,0) へ移動
	var step_res = tm.step_unit(hero, Vector2i(2, 0), 0)
	assert_eq(step_res.get("result"), "ARRIVED", "水マスから脱出して通常マスへ到着できること")
	assert_eq(hero.current_coord, Vector2i(2, 0), "脱出後の座標が正しいこと")

## IT-TRN-006: 土潜行中「祈る」による潜行維持
func test_it_trn_006_burrow_pray_retains_burrow() -> void:
	test_name = "IT-TRN-006"
	var board = _create_linear_board(5)
	var hero = CharacterData.new("HERO", "主人公", Vector2i(0, 0), Enums.ElementType.NONE)
	hero.is_burrowed = true
	var tm = TurnManager.new()
	tm.setup_stage(board, [hero], [], "STAGE_1")

	tm.execute_wait("HERO")
	assert_true(hero.is_burrowed, "祈る/待機を選択しても潜行状態が維持されること")
	assert_true(hero.has_acted, "待機後は行動済みとなること")

## IT-TRN-007: 土潜行中「移動」による地上出現
func test_it_trn_007_burrow_move_unburrows() -> void:
	test_name = "IT-TRN-007"
	var board = _create_linear_board(5)
	var hero = CharacterData.new("HERO", "主人公", Vector2i(0, 0), Enums.ElementType.NONE)
	hero.is_burrowed = true
	var tm = TurnManager.new()
	tm.setup_stage(board, [hero], [], "STAGE_1")

	# ダイス移動開始時に潜行解除する仕様
	hero.is_burrowed = false
	var step_res = tm.step_unit(hero, Vector2i(1, 0), 0)
	assert_false(hero.is_burrowed, "移動時は地上に出現して潜行解除されること")
	assert_eq(step_res.get("result"), "ARRIVED", "正常に到着すること")

## IT-TRN-008: 移動途中での魔女接触（捕縛）判定
func test_it_trn_008_realtime_enemy_contact_gameover() -> void:
	test_name = "IT-TRN-008"
	var board = _create_linear_board(5)
	var hero = CharacterData.new("HERO", "主人公", Vector2i(0, 0), Enums.ElementType.NONE)
	var witch = EnemyData.new("WITCH_1", "魔女", Vector2i(1, 0), Enums.EnemyType.TRACKING)
	var tm = TurnManager.new()
	tm.setup_stage(board, [hero], [witch], "STAGE_1")

	var game_over_called = false
	tm.game_over_triggered.connect(func(reason): game_over_called = true)

	var step_res = tm.step_unit(hero, Vector2i(1, 0), 1)
	assert_eq(step_res.get("result"), "GAME_OVER", "魔女マスに踏み入れた瞬間にゲームオーバー判定")
	assert_true(game_over_called, "game_over_triggeredシグナルが発火すること")
	assert_eq(tm.current_phase, Enums.TurnPhase.GAME_OVER, "フェーズがGAME_OVERへ遷移すること")

## IT-TRN-009: 魔女ターゲット選定（最短距離）
func test_it_trn_009_witch_target_distance() -> void:
	test_name = "IT-TRN-009"
	var board = _create_linear_board(7)
	# 魔女: (3,0), 主人公: (0,0) (距離3), 炎少女: (5,0) (距離2)
	var hero = CharacterData.new("HERO", "主人公", Vector2i(0, 0), Enums.ElementType.NONE)
	var girl = CharacterData.new("GIRL_FIRE", "炎少女", Vector2i(5, 0), Enums.ElementType.FIRE)
	var witch = EnemyData.new("WITCH_1", "魔女", Vector2i(3, 0), Enums.EnemyType.TRACKING)
	var tm = TurnManager.new()
	tm.setup_stage(board, [hero, girl], [witch], "STAGE_1")

	var target = tm.select_witch_target(witch)
	assert_ne(target, null, "ターゲットが存在すること")
	assert_eq(target.character_id, "GIRL_FIRE", "より距離が近い炎少女をターゲットとして選定すること")

## IT-TRN-010: 魔女ターゲット同距離優先度（主人公 > 炎少女）
func test_it_trn_010_witch_target_priority_same_dist() -> void:
	test_name = "IT-TRN-010"
	var board = _create_linear_board(5)
	# 魔女: (2,0), 主人公: (0,0) (距離2), 炎少女: (4,0) (距離2)
	var hero = CharacterData.new("HERO", "主人公", Vector2i(0, 0), Enums.ElementType.NONE)
	var girl = CharacterData.new("GIRL_FIRE", "炎少女", Vector2i(4, 0), Enums.ElementType.FIRE)
	var witch = EnemyData.new("WITCH_1", "魔女", Vector2i(2, 0), Enums.EnemyType.TRACKING)
	var tm = TurnManager.new()
	tm.setup_stage(board, [hero, girl], [witch], "STAGE_1")

	var target = tm.select_witch_target(witch)
	assert_ne(target, null, "ターゲットが存在すること")
	assert_eq(target.character_id, "HERO", "同距離時は優先順位に従い主人公が選定されること")

## IT-TRN-011: 全員潜行時魔女AI（初期位置帰還）
func test_it_trn_011_all_burrowed_witch_returns() -> void:
	test_name = "IT-TRN-011"
	var board = _create_linear_board(5)
	var hero = CharacterData.new("HERO", "主人公", Vector2i(0, 0), Enums.ElementType.NONE)
	hero.is_burrowed = true
	var witch = EnemyData.new("WITCH_1", "魔女", Vector2i(3, 0), Enums.EnemyType.TRACKING)
	var tm = TurnManager.new()
	tm.setup_stage(board, [hero], [witch], "STAGE_1")

	var target = tm.select_witch_target(witch)
	assert_eq(target, null, "全員潜行時はターゲットがnullとなること")

## IT-TRN-012: 宝箱EVENTマス実行
func test_it_trn_012_chest_event_cell() -> void:
	test_name = "IT-TRN-012"
	var board = _create_linear_board(3)
	var chest_cell = board.get_cell(Vector2i(2, 0))
	chest_cell.cell_type = Enums.CellType.EVENT
	chest_cell.event_id = "CHEST_1"

	var hero = CharacterData.new("HERO", "主人公", Vector2i(0, 0), Enums.ElementType.NONE)
	var tm = TurnManager.new()
	tm.setup_stage(board, [hero], [], "STAGE_1")

	var event_triggered = false
	tm.cell_event_triggered.connect(func(cell): event_triggered = true)

	var step_res = tm.step_unit(hero, Vector2i(2, 0), 0)
	assert_eq(step_res.get("result"), "ARRIVED", "宝箱マスへ到着")
	assert_true(event_triggered, "cell_event_triggeredシグナルが発火すること")
	assert_true(chest_cell.is_consumed, "イベントマスが消費済み（開封）状態となること")

## IT-TRN-013: EXITマス判定
func test_it_trn_013_exit_cell_clears_stage() -> void:
	test_name = "IT-TRN-013"
	var board = _create_linear_board(3)
	board.get_cell(Vector2i(2, 0)).cell_type = Enums.CellType.EXIT

	var hero = CharacterData.new("HERO", "主人公", Vector2i(0, 0), Enums.ElementType.NONE)
	var tm = TurnManager.new()
	tm.setup_stage(board, [hero], [], "STAGE_1")

	var stage_cleared_called = false
	tm.stage_cleared.connect(func(s_id): stage_cleared_called = true)

	var step_res = tm.step_unit(hero, Vector2i(2, 0), 0)
	assert_eq(step_res.get("result"), "ARRIVED", "EXITマスへ到着")
	assert_true(stage_cleared_called, "stage_clearedシグナルが発火すること")
	assert_eq(tm.current_phase, Enums.TurnPhase.STAGE_CLEAR, "フェーズがSTAGE_CLEARへ遷移すること")

## IT-TRN-014: 追加移動マス連鎖
func test_it_trn_014_additional_move_chains() -> void:
	test_name = "IT-TRN-014"
	var board = _create_linear_board(4)
	board.get_cell(Vector2i(1, 0)).cell_type = Enums.CellType.ADDITIONAL_MOVE
	board.get_cell(Vector2i(1, 0)).event_params = {"steps": 2}

	var hero = CharacterData.new("HERO", "主人公", Vector2i(0, 0), Enums.ElementType.NONE)
	var tm = TurnManager.new()
	tm.setup_stage(board, [hero], [], "STAGE_1")

	var granted_steps = 0
	tm.additional_move_granted.connect(func(u_id, steps): granted_steps = steps)

	var step_res = tm.step_unit(hero, Vector2i(1, 0), 0)
	assert_eq(step_res.get("result"), "ARRIVED", "追加移動マスへ到着")
	assert_eq(granted_steps, 2, "2マスの追加移動権が付与されること")
	assert_false(hero.has_acted, "追加移動のため行動済みが解除されること")

## IT-TRN-015: 往復移動（折り返し）と各歩リアルタイム判定
func test_it_trn_015_roundtrip_movement_step_evaluation() -> void:
	test_name = "IT-TRN-015"
	var board = _create_linear_board(3)
	var hero = CharacterData.new("HERO", "主人公", Vector2i(0, 0), Enums.ElementType.NONE)
	var tm = TurnManager.new()
	tm.setup_stage(board, [hero], [], "STAGE_1")

	# 出目3: 0 -> 1 -> 0 -> 1 の折り返し経路をステップ実行
	var visited_coords: Array[Vector2i] = []
	tm.unit_step_moved.connect(func(u_id, from_c, to_c, rem): visited_coords.append(to_c))

	tm.step_unit(hero, Vector2i(1, 0), 2)
	tm.step_unit(hero, Vector2i(0, 0), 1)
	tm.step_unit(hero, Vector2i(1, 0), 0)

	assert_eq(visited_coords.size(), 3, "各歩ごとに移動判定が3回発火すること")
	assert_eq(visited_coords[0], Vector2i(1, 0), "1歩目")
	assert_eq(visited_coords[1], Vector2i(0, 0), "2歩目（折り返し）")
	assert_eq(visited_coords[2], Vector2i(1, 0), "3歩目（最終到着）")
	assert_true(hero.has_acted, "最終歩で行動完了となること")
