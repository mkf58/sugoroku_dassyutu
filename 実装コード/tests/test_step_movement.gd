class_name TestStepMovement
extends TestCase

func run_all() -> void:
	test_step_continue_on_normal_cell()
	test_step_arrived_on_normal_cell()
	test_water_trap_stops_movement_immediately()
	test_special_stop_cells_resolution()
	test_event_and_exit_cells_resolution()
	test_step_unit_null_guard()
	test_step_board_null_guard()
	test_consumed_event_cell_not_retriggered()
	test_step_first_step_overlap_with_witch()
	test_step_final_step_on_water_trap()
	test_realtime_enemy_contact_decision()

## UT-STEP-N01: 通常マスの歩行継続
func test_step_continue_on_normal_cell() -> void:
	var tm = TurnManager.new()
	var board = GridBoard.new()
	for x in range(3):
		board.add_cell(CellData.new(Vector2i(x, 0), Enums.CellType.NORMAL))
		if x > 0:
			board.connect_cells(Vector2i(x - 1, 0), Vector2i(x, 0))
	var hero = CharacterData.new("HERO", "主人公", Vector2i(0, 0))
	tm.setup_stage(board, [hero], [], "STAGE_TEST")
	
	var res = tm.step_unit(hero, Vector2i(1, 0), 1)
	assert_eq(res.get("result"), "CONTINUE", "UT-STEP-N01: 残り歩数がある場合はCONTINUE")
	assert_eq(hero.current_coord, Vector2i(1, 0), "UT-STEP-N01: 座標が更新されること")
	assert_false(hero.has_acted, "UT-STEP-N01: 移動継続中は未行動")

## UT-STEP-N02: 通常マスへの最終到着
func test_step_arrived_on_normal_cell() -> void:
	var tm = TurnManager.new()
	var board = GridBoard.new()
	for x in range(3):
		board.add_cell(CellData.new(Vector2i(x, 0), Enums.CellType.NORMAL))
		if x > 0:
			board.connect_cells(Vector2i(x - 1, 0), Vector2i(x, 0))
	var hero = CharacterData.new("HERO", "主人公", Vector2i(1, 0))
	tm.setup_stage(board, [hero], [], "STAGE_TEST")
	
	var res = tm.step_unit(hero, Vector2i(2, 0), 0)
	assert_eq(res.get("result"), "ARRIVED", "UT-STEP-N02: 残り歩数0でARRIVED")
	assert_true(hero.has_acted, "UT-STEP-N02: 到着時は行動済みとなること")

## UT-STEP-N03: 水トラップ即時停止
func test_water_trap_stops_movement_immediately() -> void:
	var tm = TurnManager.new()
	var board = GridBoard.new()
	board.add_cell(CellData.new(Vector2i(0, 0), Enums.CellType.NORMAL))
	board.add_cell(CellData.new(Vector2i(1, 0), Enums.CellType.WATER_TRAP))
	board.connect_cells(Vector2i(0, 0), Vector2i(1, 0))
	
	var hero = CharacterData.new("HERO", "主人公", Vector2i(0, 0))
	tm.setup_stage(board, [hero], [], "STAGE_TEST")
	
	var res = tm.step_unit(hero, Vector2i(1, 0), 2)
	assert_eq(res.get("result"), "WATER_TRAP_STOP", "UT-STEP-N03: 水トラップ進入で即時停止")
	assert_true(hero.has_acted, "UT-STEP-N03: 水トラップ停止で行動済み")

## UT-STEP-N04: 特殊停止マス効果の適用
func test_special_stop_cells_resolution() -> void:
	var tm = TurnManager.new()
	var hero = CharacterData.new("HERO", "主人公", Vector2i(0, 0))
	
	# 1. ADDITIONAL_MOVE
	var cell_add = CellData.new(Vector2i(1, 0), Enums.CellType.ADDITIONAL_MOVE)
	cell_add.event_params = {"steps": 2}
	hero.has_acted = true
	var granted_steps = 0
	tm.additional_move_granted.connect(func(u_id, s): granted_steps = s)
	tm.resolve_stop_cell(hero, cell_add)
	assert_eq(granted_steps, 2, "UT-STEP-N04: 追加移動2歩付与")
	assert_false(hero.has_acted, "UT-STEP-N04: 追加移動で行動可能復帰")
	
	# 2. ROLL_AGAIN
	var cell_roll = CellData.new(Vector2i(2, 0), Enums.CellType.ROLL_AGAIN)
	hero.has_acted = true
	var roll_again_called = false
	tm.roll_again_granted.connect(func(u_id): roll_again_called = true)
	tm.resolve_stop_cell(hero, cell_roll)
	assert_true(roll_again_called, "UT-STEP-N04: 再ロールシグナル発火")
	assert_false(hero.has_acted, "UT-STEP-N04: 再ロールで行動可能復帰")
	
	# 3. RETURN_TO_START
	var cell_return = CellData.new(Vector2i(5, 0), Enums.CellType.RETURN_TO_START)
	hero.current_coord = Vector2i(5, 0)
	hero.initial_coord = Vector2i(0, 0)
	tm.resolve_stop_cell(hero, cell_return)
	assert_eq(hero.current_coord, Vector2i(0, 0), "UT-STEP-N04: 初期位置送還")
	
	# 4. SKIP_TURN
	var cell_skip = CellData.new(Vector2i(3, 0), Enums.CellType.SKIP_TURN)
	hero.is_skipped = false
	tm.resolve_stop_cell(hero, cell_skip)
	assert_true(hero.is_skipped, "UT-STEP-N04: 1回休み反映")

## UT-STEP-N05: EVENTマスおよびEXITマス停止
func test_event_and_exit_cells_resolution() -> void:
	var tm = TurnManager.new()
	tm.stage_id = "STAGE_TEST"
	var hero = CharacterData.new("HERO", "主人公", Vector2i(0, 0))
	
	# 1. EVENTマス
	var cell_event = CellData.new(Vector2i(1, 0), Enums.CellType.EVENT)
	cell_event.event_id = "CHEST_TEST"
	var event_triggered = false
	tm.cell_event_triggered.connect(func(cell): event_triggered = true)
	tm.resolve_stop_cell(hero, cell_event)
	assert_true(event_triggered, "UT-STEP-N05: イベント発火")
	assert_true(cell_event.is_consumed, "UT-STEP-N05: イベント消費済み更新")
	
	# 2. EXITマス
	var cell_exit = CellData.new(Vector2i(2, 0), Enums.CellType.EXIT)
	var stage_cleared = false
	tm.stage_cleared.connect(func(s_id): stage_cleared = true)
	tm.resolve_stop_cell(hero, cell_exit)
	assert_true(stage_cleared, "UT-STEP-N05: クリアシグナル発火")
	assert_eq(tm.current_phase, Enums.TurnPhase.STAGE_CLEAR, "UT-STEP-N05: STAGE_CLEAR遷移")

## UT-STEP-E01: nullユニット移動の防御
func test_step_unit_null_guard() -> void:
	var tm = TurnManager.new()
	var res = tm.step_unit(null, Vector2i(1, 0), 0)
	assert_eq(res.get("result"), "ERROR", "UT-STEP-E01: unitがnullの場合安全にERROR返却")

## UT-STEP-E02: 未設定盤面での移動防御
func test_step_board_null_guard() -> void:
	var tm = TurnManager.new()
	var hero = CharacterData.new("HERO", "主人公", Vector2i(0, 0))
	# boardを渡さずnullのまま
	var res = tm.step_unit(hero, Vector2i(1, 0), 0)
	assert_eq(res.get("result"), "ERROR", "UT-STEP-E02: boardがnullの場合安全にERROR返却")

## UT-STEP-E03: 消費済みEVENTマスの再停止
func test_consumed_event_cell_not_retriggered() -> void:
	var tm = TurnManager.new()
	var hero = CharacterData.new("HERO", "主人公", Vector2i(0, 0))
	var cell_event = CellData.new(Vector2i(1, 0), Enums.CellType.EVENT)
	cell_event.is_consumed = true
	var trigger_count = 0
	tm.cell_event_triggered.connect(func(c): trigger_count += 1)
	tm.resolve_stop_cell(hero, cell_event)
	assert_eq(trigger_count, 0, "UT-STEP-E03: 消費済みマスではイベント再発火しないこと")

## UT-STEP-B01: 1歩目（初手）での接触判定
func test_step_first_step_overlap_with_witch() -> void:
	var tm = TurnManager.new()
	var board = GridBoard.new()
	for x in range(3):
		board.add_cell(CellData.new(Vector2i(x, 0), Enums.CellType.NORMAL))
		if x > 0:
			board.connect_cells(Vector2i(x - 1, 0), Vector2i(x, 0))
	var hero = CharacterData.new("HERO", "主人公", Vector2i(0, 0))
	var witch = EnemyData.new("WITCH_1", Enums.EnemyType.TRACKING, Vector2i(1, 0))
	tm.setup_stage(board, [hero], [witch], "STAGE_TEST")
	
	# 出目2の1歩目で即座に魔女と接触
	var res = tm.step_unit(hero, Vector2i(1, 0), 1)
	assert_eq(res.get("result"), "GAME_OVER", "UT-STEP-B01: 初手接触で即座にGAME_OVER")

## UT-STEP-B02: 最終歩での水トラップ進入
func test_step_final_step_on_water_trap() -> void:
	var tm = TurnManager.new()
	var board = GridBoard.new()
	board.add_cell(CellData.new(Vector2i(0, 0), Enums.CellType.NORMAL))
	board.add_cell(CellData.new(Vector2i(1, 0), Enums.CellType.WATER_TRAP))
	board.connect_cells(Vector2i(0, 0), Vector2i(1, 0))
	var hero = CharacterData.new("HERO", "主人公", Vector2i(0, 0))
	tm.setup_stage(board, [hero], [], "STAGE_TEST")
	
	# 残り0歩（最終歩）で水トラップマスへ進入
	var res = tm.step_unit(hero, Vector2i(1, 0), 0)
	assert_eq(res.get("result"), "WATER_TRAP_STOP", "UT-STEP-B02: 最終歩でも水トラップ停止が優先されること")

## UT-STEP-D01: デシジョンテーブル：リアルタイム接触判定
func test_realtime_enemy_contact_decision() -> void:
	var board = GridBoard.new()
	for x in range(3):
		board.add_cell(CellData.new(Vector2i(x, 0), Enums.CellType.NORMAL))
		if x > 0:
			board.connect_cells(Vector2i(x - 1, 0), Vector2i(x, 0))
			
	# Case 1: 主人公・地上 -> GAME_OVER
	var tm1 = TurnManager.new()
	var hero1 = CharacterData.new("HERO", "主人公", Vector2i(0, 0))
	var witch1 = EnemyData.new("WITCH_1", Enums.EnemyType.TRACKING, Vector2i(1, 0))
	tm1.setup_stage(board, [hero1], [witch1], "S1")
	var res1 = tm1.step_unit(hero1, Vector2i(1, 0), 1)
	assert_eq(res1.get("result"), "GAME_OVER", "UT-STEP-D01: 主人公・地上は即時ゲームオーバー")

	# Case 2: 主人公・潜行 -> やり過ごし成功
	var tm2 = TurnManager.new()
	var hero2 = CharacterData.new("HERO", "主人公", Vector2i(0, 0))
	hero2.is_burrowed = true
	var witch2 = EnemyData.new("WITCH_2", Enums.EnemyType.TRACKING, Vector2i(1, 0))
	tm2.setup_stage(board, [hero2], [witch2], "S2")
	var res2 = tm2.step_unit(hero2, Vector2i(1, 0), 1)
	assert_eq(res2.get("result"), "CONTINUE", "UT-STEP-D01: 主人公・潜行はやり過ごし成功")

	# Case 3: 少女・地上 -> GIRL_DIED
	var tm3 = TurnManager.new()
	var girl3 = CharacterData.new("GIRL_FIRE", "炎少女", Vector2i(0, 0))
	var witch3 = EnemyData.new("WITCH_3", Enums.EnemyType.TRACKING, Vector2i(1, 0))
	tm3.setup_stage(board, [girl3], [witch3], "S3")
	var res3 = tm3.step_unit(girl3, Vector2i(1, 0), 1)
	assert_eq(res3.get("result"), "GIRL_DIED", "UT-STEP-D01: 少女・地上は殺害判定")
	assert_false(girl3.is_alive, "UT-STEP-D01: 少女死亡")
	assert_eq(girl3.revive_turn_count, 3, "UT-STEP-D01: 復活カウンタ3")

	# Case 4: 少女・潜行 -> やり過ごし成功
	var tm4 = TurnManager.new()
	var girl4 = CharacterData.new("GIRL_FIRE", "炎少女", Vector2i(0, 0))
	girl4.is_burrowed = true
	var witch4 = EnemyData.new("WITCH_4", Enums.EnemyType.TRACKING, Vector2i(1, 0))
	tm4.setup_stage(board, [girl4], [witch4], "S4")
	var res4 = tm4.step_unit(girl4, Vector2i(1, 0), 1)
	assert_eq(res4.get("result"), "CONTINUE", "UT-STEP-D01: 少女・潜行はやり過ごし成功")
