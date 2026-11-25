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
	test_revived_witch_captures_girl()
	test_revived_witch_captures_hero_game_over()
	test_revive_capture_decision()
	test_stun_decrements_on_turn_end()
	test_stun_end_captures_unit_on_same_cell()
	test_earth_stun_lasts_two_enemy_turns()

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


## 復活捕縛テスト用の盤面：(0,0)〜(2,0) の一直線
func _make_line_board() -> GridBoard:
	var board = GridBoard.new()
	for x in range(3):
		board.add_cell(CellData.new(Vector2i(x, 0), Enums.CellType.NORMAL))
		if x > 0:
			board.connect_cells(Vector2i(x - 1, 0), Vector2i(x, 0))
	return board

## UT-TURN-N06: 復活した魔女が復活位置にいる少女を捕縛する
func test_revived_witch_captures_girl() -> void:
	var tm = TurnManager.new()
	var hero = CharacterData.new("HERO", "主人公", Vector2i(2, 0))
	var girl = CharacterData.new("GIRL_FIRE", "炎の少女", Vector2i(1, 0))
	girl.current_coord = Vector2i(0, 0) # 魔女の初期位置に停止中
	var witch = EnemyData.new("WITCH_1", Enums.EnemyType.TRACKING, Vector2i(0, 0))
	witch.defeat()
	witch.revive_turn_count = 1 # このターン終了で復活
	tm.setup_stage(_make_line_board(), [hero, girl], [witch], "STAGE_TEST")
	var killed: Array = []
	tm.unit_killed.connect(func(uid): killed.append(uid))

	tm.end_turn_and_advance()
	assert_true(witch.is_alive, "UT-TURN-N06: 魔女が復活する")
	assert_false(girl.is_alive, "UT-TURN-N06: 復活位置の少女が捕縛される")
	assert_eq(girl.revive_turn_count, 3, "UT-TURN-N06: 少女の復活カウントが3")
	assert_eq(killed, ["GIRL_FIRE"], "UT-TURN-N06: unit_killedが少女IDで発行される")
	assert_true(hero.is_alive, "UT-TURN-N06: 別マスの主人公は無事")
	assert_eq(tm.current_phase, Enums.TurnPhase.PLAYER_UNIT_SELECT, "UT-TURN-N06: 少女捕縛ではゲームオーバーにならず次ターンへ")
	assert_eq(tm.current_turn, 2, "UT-TURN-N06: ターン数が進む")

## UT-TURN-N07: 復活した魔女が復活位置にいる主人公を捕縛するとゲームオーバー
func test_revived_witch_captures_hero_game_over() -> void:
	var tm = TurnManager.new()
	var hero = CharacterData.new("HERO", "主人公", Vector2i(2, 0))
	hero.current_coord = Vector2i(0, 0)
	var witch = EnemyData.new("WITCH_1", Enums.EnemyType.TRACKING, Vector2i(0, 0))
	witch.defeat()
	witch.revive_turn_count = 1
	tm.setup_stage(_make_line_board(), [hero], [witch], "STAGE_TEST")
	var reasons: Array = []
	tm.game_over_triggered.connect(func(r): reasons.append(r))

	tm.end_turn_and_advance()
	assert_true(witch.is_alive, "UT-TURN-N07: 魔女が復活する")
	assert_eq(tm.current_phase, Enums.TurnPhase.GAME_OVER, "UT-TURN-N07: ゲームオーバーになる")
	assert_eq(reasons.size(), 1, "UT-TURN-N07: game_over_triggeredが1回発行される")
	assert_eq(tm.current_turn, 1, "UT-TURN-N07: 次のプレイヤーターンを始めない")

## UT-TURN-D01: デシジョンテーブル：魔女復活時の捕縛判定
func test_revive_capture_decision() -> void:
	# Case 1: 復活位置にいるが潜行中 -> やり過ごし
	var tm1 = TurnManager.new()
	var girl1 = CharacterData.new("GIRL_EARTH", "土の少女", Vector2i(1, 0))
	girl1.current_coord = Vector2i(0, 0)
	girl1.is_burrowed = true
	var w1 = EnemyData.new("WITCH_1", Enums.EnemyType.TRACKING, Vector2i(0, 0))
	w1.defeat()
	w1.revive_turn_count = 1
	tm1.setup_stage(_make_line_board(), [girl1], [w1], "STAGE_TEST")
	var passed: Array = []
	tm1.burrow_pass_succeeded.connect(func(uid, eid): passed.append([uid, eid]))
	tm1.end_turn_and_advance()
	assert_true(w1.is_alive, "UT-TURN-D01: Case1 魔女は復活")
	assert_true(girl1.is_alive, "UT-TURN-D01: Case1 潜行中の少女は捕縛されない")
	assert_eq(passed, [["GIRL_EARTH", "WITCH_1"]], "UT-TURN-D01: Case1 やり過ごしシグナルが発行される")

	# Case 2: 復活位置以外にいる -> 捕縛されない
	var tm2 = TurnManager.new()
	var girl2 = CharacterData.new("GIRL_FIRE", "炎の少女", Vector2i(1, 0))
	var w2 = EnemyData.new("WITCH_1", Enums.EnemyType.TRACKING, Vector2i(0, 0))
	w2.defeat()
	w2.revive_turn_count = 1
	tm2.setup_stage(_make_line_board(), [girl2], [w2], "STAGE_TEST")
	tm2.end_turn_and_advance()
	assert_true(w2.is_alive, "UT-TURN-D01: Case2 魔女は復活")
	assert_true(girl2.is_alive, "UT-TURN-D01: Case2 別マスの少女は無事")

	# Case 3: 復活位置にいるが、まだ復活しない（カウント2→1） -> 捕縛されない
	var tm3 = TurnManager.new()
	var girl3 = CharacterData.new("GIRL_FIRE", "炎の少女", Vector2i(1, 0))
	girl3.current_coord = Vector2i(0, 0)
	var w3 = EnemyData.new("WITCH_1", Enums.EnemyType.TRACKING, Vector2i(0, 0))
	w3.defeat() # カウント2
	tm3.setup_stage(_make_line_board(), [girl3], [w3], "STAGE_TEST")
	tm3.end_turn_and_advance()
	assert_false(w3.is_alive, "UT-TURN-D01: Case3 魔女はまだ復活しない")
	assert_true(girl3.is_alive, "UT-TURN-D01: Case3 復活前なので少女は無事")

	# Case 4: もともと生存中の魔女と同じマスにいる（復活ではない） -> ターン終了処理では捕縛しない
	var tm4 = TurnManager.new()
	var girl4 = CharacterData.new("GIRL_FIRE", "炎の少女", Vector2i(0, 0))
	var w4 = EnemyData.new("WITCH_1", Enums.EnemyType.TRACKING, Vector2i(0, 0))
	tm4.setup_stage(_make_line_board(), [girl4], [w4], "STAGE_TEST")
	tm4.end_turn_and_advance()
	assert_true(girl4.is_alive, "UT-TURN-D01: Case4 復活でない魔女はターン終了時に捕縛しない")

## UT-TURN-N08: スタンはターン終了で1減り、魔女は次のターンから行動できる
func test_stun_decrements_on_turn_end() -> void:
	var tm = TurnManager.new()
	var hero = CharacterData.new("HERO", "主人公", Vector2i(2, 0))
	var witch = EnemyData.new("WITCH_1", Enums.EnemyType.TRACKING, Vector2i(0, 0))
	witch.stun_turns = 1
	tm.setup_stage(_make_line_board(), [hero], [witch], "STAGE_TEST")
	tm.end_turn_and_advance()
	assert_eq(witch.stun_turns, 0, "UT-TURN-N08: ターン終了でスタンが0になる")
	tm.end_turn_and_advance()
	assert_eq(witch.stun_turns, 0, "UT-TURN-N08: 0より小さくならない")

## UT-TURN-N09: スタンが解けた瞬間、同じマスにいる地上のキャラを捕縛する（潜行中はやり過ごし）
func test_stun_end_captures_unit_on_same_cell() -> void:
	var tm = TurnManager.new()
	var hero = CharacterData.new("HERO", "主人公", Vector2i(2, 0))
	var girl = CharacterData.new("GIRL_FIRE", "炎の少女", Vector2i(0, 0))
	var earth = CharacterData.new("GIRL_EARTH", "土の少女", Vector2i(1, 0))
	earth.is_burrowed = true
	var w1 = EnemyData.new("WITCH_1", Enums.EnemyType.TRACKING, Vector2i(0, 0))
	w1.stun_turns = 1
	var w2 = EnemyData.new("WITCH_2", Enums.EnemyType.TRACKING, Vector2i(1, 0))
	w2.stun_turns = 1
	tm.setup_stage(_make_line_board(), [hero, girl, earth], [w1, w2], "STAGE_TEST")
	tm.end_turn_and_advance()
	assert_false(girl.is_alive, "UT-TURN-N09: スタンが解けた魔女と同じマスの少女は捕縛される")
	assert_true(earth.is_alive, "UT-TURN-N09: 潜行中の少女はやり過ごす")
	assert_eq(tm.current_phase, Enums.TurnPhase.PLAYER_UNIT_SELECT, "UT-TURN-N09: 少女の捕縛では次ターンへ進む")

	var tm2 = TurnManager.new()
	var hero2 = CharacterData.new("HERO", "主人公", Vector2i(0, 0))
	var w3 = EnemyData.new("WITCH_1", Enums.EnemyType.TRACKING, Vector2i(0, 0))
	w3.stun_turns = 1
	tm2.setup_stage(_make_line_board(), [hero2], [w3], "STAGE_TEST")
	tm2.end_turn_and_advance()
	assert_eq(tm2.current_phase, Enums.TurnPhase.GAME_OVER, "UT-TURN-N09: スタンが解けた魔女と同じマスの主人公はゲームオーバー")

	# スタンがまだ残る（2→1）なら捕縛しない
	var tm3 = TurnManager.new()
	var girl3 = CharacterData.new("GIRL_FIRE", "炎の少女", Vector2i(0, 0))
	var w4 = EnemyData.new("WITCH_1", Enums.EnemyType.TRACKING, Vector2i(0, 0))
	w4.stun_turns = 2
	tm3.setup_stage(_make_line_board(), [girl3], [w4], "STAGE_TEST")
	tm3.end_turn_and_advance()
	assert_true(girl3.is_alive, "UT-TURN-N09: スタンが残っている間は捕縛しない")

## UT-TURN-N10: 土魔術のスタンは魔女ターン2回分続き、その間のプレイヤーターンも無害
func test_earth_stun_lasts_two_enemy_turns() -> void:
	var tm = TurnManager.new()
	var earth_girl = CharacterData.new("GIRL_EARTH", "土の少女", Vector2i(2, 0))
	var witch = EnemyData.new("WITCH_1", Enums.EnemyType.TRACKING, Vector2i(0, 0))
	tm.setup_stage(_make_line_board(), [earth_girl], [witch], "STAGE_TEST")

	assert_true(tm.execute_earth("GIRL_EARTH", "WITCH_1"), "UT-TURN-N10: スタン成功")
	assert_eq(witch.stun_turns, TurnManager.EARTH_STUN_TURNS, "UT-TURN-N10: スタンは2")
	assert_false(witch.is_dangerous(), "UT-TURN-N10: 詠唱したターン（1回目の魔女ターン前）は無害")
	tm.end_turn_and_advance()
	assert_eq(witch.stun_turns, 1, "UT-TURN-N10: 1回目のターン終了で1")
	assert_false(witch.is_dangerous(), "UT-TURN-N10: 次のプレイヤーターンも無害（2回目の魔女ターンも休み）")
	tm.end_turn_and_advance()
	assert_eq(witch.stun_turns, 0, "UT-TURN-N10: 2回目のターン終了で解除")
	assert_true(witch.is_dangerous(), "UT-TURN-N10: 解除後は捕縛判定あり")
