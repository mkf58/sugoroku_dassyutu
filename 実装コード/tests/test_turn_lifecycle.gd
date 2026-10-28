class_name TestTurnLifecycle
extends TestCase

func run_all() -> void:
	test_turn_advance_and_reselection()
	test_girl_revives_after_three_turns()
	test_witch_revives_after_two_turns()
	test_select_character_fails_when_dead()
	test_select_character_fails_when_acted()
	test_select_character_fails_when_skipped()
	test_select_character_fails_not_found()
	test_revive_exact_turn_boundary()
	test_multiple_allies_sequential_action()
	test_girl_death_during_step_movement()

## UT-TURN-N01: ターン進行と行動リセット
func test_turn_advance_and_reselection() -> void:
	var tm = TurnManager.new()
	var board = GridBoard.new()
	board.add_cell(CellData.new(Vector2i(0, 0), Enums.CellType.NORMAL))
	var hero = CharacterData.new("HERO", "主人公", Vector2i(0, 0))
	hero.has_acted = true
	tm.setup_stage(board, [hero], [], "STAGE_TEST")
	
	tm.end_turn_and_advance()
	assert_eq(tm.current_turn, 2, "UT-TURN-N01: ターン数が2へ増加")
	assert_false(hero.has_acted, "UT-TURN-N01: has_actedがfalseへリセット")
	assert_true(tm.select_character("HERO"), "UT-TURN-N01: 主人公が再選択可能")
	assert_eq(tm.current_phase, Enums.TurnPhase.PLAYER_ACTION_SELECT, "UT-TURN-N01: PLAYER_ACTION_SELECTへ遷移")

## UT-TURN-N02: 少女の3ターン復活
func test_girl_revives_after_three_turns() -> void:
	var tm = TurnManager.new()
	var board = GridBoard.new()
	board.add_cell(CellData.new(Vector2i(0, 0), Enums.CellType.NORMAL))
	var girl = CharacterData.new("GIRL_FIRE", "炎の少女", Vector2i(0, 0))
	girl.kill() # revive_turn_count = 3
	tm.setup_stage(board, [girl], [], "STAGE_TEST")
	
	# 1ターン経過
	tm.end_turn_and_advance()
	assert_false(girl.is_alive, "UT-TURN-N02: 1ターン目は死亡中")
	assert_eq(girl.revive_turn_count, 2, "UT-TURN-N02: カウント2")
	
	# 2ターン経過
	tm.end_turn_and_advance()
	assert_false(girl.is_alive, "UT-TURN-N02: 2ターン目は死亡中")
	assert_eq(girl.revive_turn_count, 1, "UT-TURN-N02: カウント1")
	
	# 3ターン経過
	tm.end_turn_and_advance()
	assert_true(girl.is_alive, "UT-TURN-N02: 3ターン目で復活")
	assert_eq(girl.revive_turn_count, 0, "UT-TURN-N02: カウント0")
	assert_eq(girl.current_coord, Vector2i(0, 0), "UT-TURN-N02: 初期位置復帰")

## UT-TURN-N03: 魔女の2ターン復活
func test_witch_revives_after_two_turns() -> void:
	var tm = TurnManager.new()
	var board = GridBoard.new()
	board.add_cell(CellData.new(Vector2i(0, 0), Enums.CellType.NORMAL))
	var witch = EnemyData.new("WITCH", Enums.EnemyType.TRACKING, Vector2i(0, 0))
	witch.defeat() # is_alive = false, revive_turn_count = 2
	tm.setup_stage(board, [], [witch], "STAGE_TEST")
	
	# 1ターン経過
	tm.end_turn_and_advance()
	assert_false(witch.is_alive, "UT-TURN-N03: 1ターン目は撃破中")
	assert_eq(witch.revive_turn_count, 1, "UT-TURN-N03: カウント1")
	
	# 2ターン経過
	tm.end_turn_and_advance()
	assert_true(witch.is_alive, "UT-TURN-N03: 2ターン目で復活")
	assert_eq(witch.revive_turn_count, 0, "UT-TURN-N03: カウント0")

## UT-TURN-E01: 死亡中ユニットの選択拒否
func test_select_character_fails_when_dead() -> void:
	var tm = TurnManager.new()
	var board = GridBoard.new()
	board.add_cell(CellData.new(Vector2i(0, 0), Enums.CellType.NORMAL))
	var girl = CharacterData.new("GIRL_FIRE", "炎の少女", Vector2i(0, 0))
	girl.is_alive = false
	tm.setup_stage(board, [girl], [], "STAGE_TEST")
	
	assert_false(tm.select_character("GIRL_FIRE"), "UT-TURN-E01: 死亡中のユニットは選択不可")

## UT-TURN-E02: 行動済みユニットの選択拒否
func test_select_character_fails_when_acted() -> void:
	var tm = TurnManager.new()
	var board = GridBoard.new()
	board.add_cell(CellData.new(Vector2i(0, 0), Enums.CellType.NORMAL))
	var hero = CharacterData.new("HERO", "主人公", Vector2i(0, 0))
	hero.has_acted = true
	tm.setup_stage(board, [hero], [], "STAGE_TEST")
	
	assert_false(tm.select_character("HERO"), "UT-TURN-E02: 行動済みのユニットは選択不可")

## UT-TURN-E03: 1回休みユニットの選択拒否
func test_select_character_fails_when_skipped() -> void:
	var tm = TurnManager.new()
	var board = GridBoard.new()
	board.add_cell(CellData.new(Vector2i(0, 0), Enums.CellType.NORMAL))
	var hero = CharacterData.new("HERO", "主人公", Vector2i(0, 0))
	hero.is_skipped = true
	tm.setup_stage(board, [hero], [], "STAGE_TEST")
	
	assert_false(tm.select_character("HERO"), "UT-TURN-E03: 1回休みのユニットは選択不可")

## UT-TURN-E04: 未登録キャラクターIDの選択拒否
func test_select_character_fails_not_found() -> void:
	var tm = TurnManager.new()
	var board = GridBoard.new()
	board.add_cell(CellData.new(Vector2i(0, 0), Enums.CellType.NORMAL))
	tm.setup_stage(board, [], [], "STAGE_TEST")
	
	assert_false(tm.select_character("NON_EXISTENT_HERO"), "UT-TURN-E04: 未登録ユニットは選択不可")

## UT-TURN-B01: 復活境界値の検証
func test_revive_exact_turn_boundary() -> void:
	var girl = CharacterData.new("GIRL_1", "少女", Vector2i(0, 0))
	girl.kill() # revive_turn_count = 3
	
	girl.tick_revive() # 3 -> 2
	assert_false(girl.is_alive, "UT-TURN-B01: カウント2では依然死亡")
	girl.tick_revive() # 2 -> 1
	assert_false(girl.is_alive, "UT-TURN-B01: カウント1でも依然死亡")
	girl.tick_revive() # 1 -> 0
	assert_true(girl.is_alive, "UT-TURN-B01: カウント0で即座に復活")

## UT-TURN-N04: 複数味方ユニットの順次行動制御
func test_multiple_allies_sequential_action() -> void:
	var tm = TurnManager.new()
	var board = GridBoard.new()
	board.add_cell(CellData.new(Vector2i(0, 0), Enums.CellType.NORMAL))
	board.add_cell(CellData.new(Vector2i(1, 0), Enums.CellType.NORMAL))
	var hero = CharacterData.new("HERO", "主人公", Vector2i(0, 0))
	var girl = CharacterData.new("GIRL_FIRE", "炎の少女", Vector2i(1, 0))
	tm.setup_stage(board, [hero, girl], [], "STAGE_TEST")

	# 主人公の選択・行動
	assert_true(tm.select_character("HERO"), "UT-TURN-N04: 最初は主人公が選択可能")
	hero.has_acted = true
	assert_false(tm.select_character("HERO"), "UT-TURN-N04: 主人公は行動後選択不可")

	# 少女の選択・行動
	assert_true(tm.select_character("GIRL_FIRE"), "UT-TURN-N04: 主人公行動後、少女が選択可能")
	girl.has_acted = true
	assert_false(tm.select_character("GIRL_FIRE"), "UT-TURN-N04: 少女も行動後選択不可")

	# ターン終了と次ターンのリセット
	tm.end_turn_and_advance()
	assert_false(hero.has_acted, "UT-TURN-N04: ターン経過で主人公行動リセット")
	assert_false(girl.has_acted, "UT-TURN-N04: ターン経過で少女行動リセット")
	assert_true(tm.select_character("HERO"), "UT-TURN-N04: 次ターンで再び主人公選択可能")

## UT-TURN-N05: 少女が魔女マスへ侵入した際の殺害判定（ゲームオーバーにならず少女のみ死亡）
func test_girl_death_during_step_movement() -> void:
	var tm = TurnManager.new()
	var board = GridBoard.new()
	board.add_cell(CellData.new(Vector2i(0, 0), Enums.CellType.NORMAL))
	board.add_cell(CellData.new(Vector2i(1, 0), Enums.CellType.NORMAL))
	board.connect_cells(Vector2i(0, 0), Vector2i(1, 0))
	var hero = CharacterData.new("HERO", "主人公", Vector2i(0, 0))
	var girl = CharacterData.new("GIRL_FIRE", "炎の少女", Vector2i(0, 0))
	var witch = EnemyData.new("WITCH", Enums.EnemyType.TRACKING, Vector2i(1, 0))
	tm.setup_stage(board, [hero, girl], [witch], "STAGE_TEST")

	var step_res = tm.step_unit(girl, Vector2i(1, 0), 0)
	assert_eq(step_res.get("result"), "GIRL_DIED", "UT-TURN-N05: 少女が魔女マスに到達するとGIRL_DIEDを返す")
	assert_false(girl.is_alive, "UT-TURN-N05: 少女の生存フラグがfalseになる")
	assert_eq(girl.revive_turn_count, 3, "UT-TURN-N05: 復活カウントが3にセットされる")
	assert_true(hero.is_alive, "UT-TURN-N05: 主人公は生存のまま")
	assert_ne(tm.current_phase, Enums.TurnPhase.GAME_OVER, "UT-TURN-N05: 少女死亡時はゲームオーバーにならない")

