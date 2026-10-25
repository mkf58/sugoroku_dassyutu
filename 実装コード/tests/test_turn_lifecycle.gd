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
