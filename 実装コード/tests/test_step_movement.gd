class_name TestStepMovement
extends TestCase

func run_all() -> void:
	test_hero_step_overlap_with_witch_causes_game_over()
	test_burrowed_hero_can_pass_witch_safely()
	test_water_trap_stops_movement_immediately()
	test_girl_step_overlap_with_witch_kills_girl()
	test_special_stop_cells_resolution()
	test_event_and_exit_cells_resolution()

## UT-STEP-01: 主人公が未潜行で魔女のマスへ侵入した際の即時ゲームオーバー判定
func test_hero_step_overlap_with_witch_causes_game_over() -> void:
	var tm = TurnManager.new()
	var board = GridBoard.new()
	for x in range(3):
		var c = CellData.new(Vector2i(x, 0), Enums.CellType.NORMAL)
		board.add_cell(c)
	board.connect_cells(Vector2i(0, 0), Vector2i(1, 0))
	board.connect_cells(Vector2i(1, 0), Vector2i(2, 0))
	
	var hero = CharacterData.new("HERO", "主人公", Vector2i(0, 0))
	var witch = EnemyData.new("WITCH_1", Enums.EnemyType.TRACKING, Vector2i(1, 0))
	
	tm.setup_stage(board, [hero], [witch], "STAGE_TEST")
	
	# 1歩目：(1,0) 魔女のいるマスへ侵入
	var result = tm.step_unit(hero, Vector2i(1, 0), 1)
	assert_eq(result.get("result"), "GAME_OVER", "UT-STEP-01: Result should be GAME_OVER")
	assert_eq(tm.current_phase, Enums.TurnPhase.GAME_OVER, "UT-STEP-01: Current phase should be GAME_OVER")

## UT-STEP-02: 土魔法で潜行中のユニットが魔女のマスを通過した際のやり過ごし検証
func test_burrowed_hero_can_pass_witch_safely() -> void:
	var tm = TurnManager.new()
	var board = GridBoard.new()
	for x in range(3):
		var c = CellData.new(Vector2i(x, 0), Enums.CellType.NORMAL)
		board.add_cell(c)
	board.connect_cells(Vector2i(0, 0), Vector2i(1, 0))
	board.connect_cells(Vector2i(1, 0), Vector2i(2, 0))
	
	var hero = CharacterData.new("HERO", "主人公", Vector2i(0, 0))
	hero.is_burrowed = true # 潜行中
	var witch = EnemyData.new("WITCH_1", Enums.EnemyType.TRACKING, Vector2i(1, 0))
	
	tm.setup_stage(board, [hero], [witch], "STAGE_TEST")
	
	var result = tm.step_unit(hero, Vector2i(1, 0), 1)
	assert_eq(result.get("result"), "CONTINUE", "UT-STEP-02: Result should be CONTINUE due to burrow")
	assert_ne(tm.current_phase, Enums.TurnPhase.GAME_OVER, "UT-STEP-02: Should not be GAME_OVER")

## UT-STEP-03: 水魔術トラップマス侵入時の残歩数破棄・即時ターン終了検証
func test_water_trap_stops_movement_immediately() -> void:
	var tm = TurnManager.new()
	var board = GridBoard.new()
	board.add_cell(CellData.new(Vector2i(0, 0), Enums.CellType.NORMAL))
	board.add_cell(CellData.new(Vector2i(1, 0), Enums.CellType.WATER_TRAP)) # 水トラップ
	board.add_cell(CellData.new(Vector2i(2, 0), Enums.CellType.NORMAL))
	board.connect_cells(Vector2i(0, 0), Vector2i(1, 0))
	board.connect_cells(Vector2i(1, 0), Vector2i(2, 0))
	
	var hero = CharacterData.new("HERO", "主人公", Vector2i(0, 0))
	tm.setup_stage(board, [hero], [], "STAGE_TEST")
	
	# 残り歩数2で (1,0) の水トラップに侵入
	var result = tm.step_unit(hero, Vector2i(1, 0), 2)
	assert_eq(result.get("result"), "WATER_TRAP_STOP", "UT-STEP-03: Result should be WATER_TRAP_STOP")
	assert_eq(hero.current_coord, Vector2i(1, 0), "UT-STEP-03: Current coord should be (1,0)")
	assert_true(hero.has_acted, "UT-STEP-03: Unit should have acted upon hitting water trap")

## UT-STEP-04: 少女が魔女と同マス接触した際の殺害と復活カウンタ設定
func test_girl_step_overlap_with_witch_kills_girl() -> void:
	var tm = TurnManager.new()
	var board = GridBoard.new()
	for x in range(3):
		board.add_cell(CellData.new(Vector2i(x, 0), Enums.CellType.NORMAL))
		if x > 0:
			board.connect_cells(Vector2i(x - 1, 0), Vector2i(x, 0))
			
	var girl = CharacterData.new("GIRL_FIRE", "炎の少女", Vector2i(0, 0), Enums.ElementType.FIRE)
	var witch = EnemyData.new("WITCH_1", Enums.EnemyType.TRACKING, Vector2i(1, 0))
	tm.setup_stage(board, [girl], [witch], "STAGE_TEST")
	
	var result = tm.step_unit(girl, Vector2i(1, 0), 1)
	assert_eq(result.get("result"), "GIRL_DIED", "UT-STEP-04: Result should be GIRL_DIED")
	assert_false(girl.is_alive, "UT-STEP-04: Girl should be dead")
	assert_eq(girl.revive_turn_count, 3, "UT-STEP-04: Revive counter should be set to 3")

## UT-STEP-05: 特殊停止マス（ADDITIONAL_MOVE / ROLL_AGAIN / RETURN_TO_START / SKIP_TURN）の効果検証
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
	assert_eq(granted_steps, 2, "UT-STEP-05: Additional move of 2 steps should be granted")
	assert_false(hero.has_acted, "UT-STEP-05: has_acted should be reset for additional move")
	
	# 2. ROLL_AGAIN
	var cell_roll = CellData.new(Vector2i(2, 0), Enums.CellType.ROLL_AGAIN)
	hero.has_acted = true
	var roll_again_called = false
	tm.roll_again_granted.connect(func(u_id): roll_again_called = true)
	tm.resolve_stop_cell(hero, cell_roll)
	assert_true(roll_again_called, "UT-STEP-05: roll_again_granted should be emitted")
	assert_false(hero.has_acted, "UT-STEP-05: has_acted should be reset for roll again")
	
	# 3. RETURN_TO_START
	var cell_return = CellData.new(Vector2i(5, 0), Enums.CellType.RETURN_TO_START)
	hero.current_coord = Vector2i(5, 0)
	hero.initial_coord = Vector2i(0, 0)
	tm.resolve_stop_cell(hero, cell_return)
	assert_eq(hero.current_coord, Vector2i(0, 0), "UT-STEP-05: Hero should be returned to initial coord (0,0)")
	
	# 4. SKIP_TURN
	var cell_skip = CellData.new(Vector2i(3, 0), Enums.CellType.SKIP_TURN)
	hero.is_skipped = false
	tm.resolve_stop_cell(hero, cell_skip)
	assert_true(hero.is_skipped, "UT-STEP-05: Hero is_skipped should be set to true")

## UT-STEP-06: EVENTマスおよびEXITマス停止の検証
func test_event_and_exit_cells_resolution() -> void:
	var tm = TurnManager.new()
	tm.stage_id = "STAGE_TEST"
	var hero = CharacterData.new("HERO", "主人公", Vector2i(0, 0))
	
	# 1. EVENTマス（宝箱等）
	var cell_event = CellData.new(Vector2i(1, 0), Enums.CellType.EVENT)
	cell_event.event_id = "CHEST_TEST"
	var event_triggered = false
	tm.cell_event_triggered.connect(func(cell): event_triggered = true)
	tm.resolve_stop_cell(hero, cell_event)
	assert_true(event_triggered, "UT-STEP-06: cell_event_triggered signal should be emitted")
	assert_true(cell_event.is_consumed, "UT-STEP-06: Event cell should be consumed")
	
	# 2. EXITマス
	var cell_exit = CellData.new(Vector2i(2, 0), Enums.CellType.EXIT)
	var stage_cleared = false
	tm.stage_cleared.connect(func(s_id): stage_cleared = true)
	tm.resolve_stop_cell(hero, cell_exit)
	assert_true(stage_cleared, "UT-STEP-06: stage_cleared signal should be emitted")
	assert_eq(tm.current_phase, Enums.TurnPhase.STAGE_CLEAR, "UT-STEP-06: Phase should transition to STAGE_CLEAR")
