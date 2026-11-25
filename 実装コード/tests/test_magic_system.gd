class_name TestMagicSystem
extends TestCase

func run_all() -> void:
	test_fire_magic_defeats_witch()
	test_water_magic_creates_trap()
	test_burrowed_unit_wait_maintains_burrow()
	test_unburrow_on_action()
	test_magic_fails_when_dead()
	test_magic_fails_when_already_acted()
	test_magic_fails_caster_not_found()
	test_fire_magic_fails_no_target()
	test_fire_magic_range_boundary()
	test_earth_magic_burrow_and_stun()
	test_unburrow_on_movement()
	test_water_trap_targets_normal_cells_only()
	test_water_magic_fails_on_special_cell()
	test_water_magic_fails_on_missing_cell()
	test_water_magic_range_boundary()

## UT-MAGIC-N01: 炎魔法による魔女撃破
func test_fire_magic_defeats_witch() -> void:
	var tm = TurnManager.new()
	var board = GridBoard.new()
	for x in range(3):
		board.add_cell(CellData.new(Vector2i(x, 0), Enums.CellType.NORMAL))
		if x > 0:
			board.connect_cells(Vector2i(x - 1, 0), Vector2i(x, 0))
	var fire_girl = CharacterData.new("GIRL_FIRE", "炎の少女", Vector2i(0, 0))
	var witch = EnemyData.new("WITCH", Enums.EnemyType.TRACKING, Vector2i(1, 0))
	tm.setup_stage(board, [fire_girl], [witch], "STAGE_TEST")
	
	var success = tm.execute_magic("GIRL_FIRE", Enums.ElementType.FIRE, Vector2i(1, 0))
	assert_true(success, "UT-MAGIC-N01: 炎魔法が成功すること")
	assert_false(witch.is_alive, "UT-MAGIC-N01: 魔女が撃破されること")
	assert_eq(witch.revive_turn_count, 2, "UT-MAGIC-N01: 復活カウンタが2に設定")
	assert_true(fire_girl.has_acted, "UT-MAGIC-N01: 詠唱者は行動済みとなること")

## UT-MAGIC-N02: 水魔法によるトラップ生成
func test_water_magic_creates_trap() -> void:
	var tm = TurnManager.new()
	var board = GridBoard.new()
	board.add_cell(CellData.new(Vector2i(0, 0), Enums.CellType.NORMAL))
	board.add_cell(CellData.new(Vector2i(1, 0), Enums.CellType.NORMAL))
	board.connect_cells(Vector2i(0, 0), Vector2i(1, 0))
	var water_girl = CharacterData.new("GIRL_WATER", "水の少女", Vector2i(0, 0))
	tm.setup_stage(board, [water_girl], [], "STAGE_TEST")
	
	var success = tm.execute_magic("GIRL_WATER", Enums.ElementType.WATER, Vector2i(1, 0))
	assert_true(success, "UT-MAGIC-N02: 水魔法が成功すること")
	var cell = board.get_cell(Vector2i(1, 0))
	assert_eq(cell.cell_type, Enums.CellType.WATER_TRAP, "UT-MAGIC-N02: 対象マスがWATER_TRAPに変更されること")
	assert_true(water_girl.has_acted, "UT-MAGIC-N02: 詠唱者は行動済みとなること")

## UT-MAGIC-N03: 待機・祈るによる潜行維持
func test_burrowed_unit_wait_maintains_burrow() -> void:
	var tm = TurnManager.new()
	var hero = CharacterData.new("HERO", "主人公", Vector2i(0, 0))
	hero.is_burrowed = true
	tm.characters["HERO"] = hero
	
	tm.execute_wait("HERO")
	assert_true(hero.is_burrowed, "UT-MAGIC-N03: 待機後も潜行状態が維持されること")
	assert_true(hero.has_acted, "UT-MAGIC-N03: 待機後は行動済みとなること")

## UT-MAGIC-N04: 行動時の潜行解除
func test_unburrow_on_action() -> void:
	var tm = TurnManager.new()
	var board = GridBoard.new()
	board.add_cell(CellData.new(Vector2i(0, 0), Enums.CellType.NORMAL))
	board.add_cell(CellData.new(Vector2i(1, 0), Enums.CellType.NORMAL))
	board.connect_cells(Vector2i(0, 0), Vector2i(1, 0))
	var girl = CharacterData.new("GIRL_WATER", "水の少女", Vector2i(0, 0))
	girl.is_burrowed = true # 潜行中
	tm.setup_stage(board, [girl], [], "STAGE_TEST")
	
	tm.execute_magic("GIRL_WATER", Enums.ElementType.WATER, Vector2i(1, 0))
	assert_false(girl.is_burrowed, "UT-MAGIC-N04: 魔法詠唱時に潜行が解除されること")

## UT-MAGIC-E01: 死亡中ユニットの詠唱拒否
func test_magic_fails_when_dead() -> void:
	var tm = TurnManager.new()
	var board = GridBoard.new()
	board.add_cell(CellData.new(Vector2i(0, 0), Enums.CellType.NORMAL))
	var girl = CharacterData.new("GIRL_WATER", "水の少女", Vector2i(0, 0))
	girl.is_alive = false
	tm.setup_stage(board, [girl], [], "STAGE_TEST")
	
	var success = tm.execute_magic("GIRL_WATER", Enums.ElementType.WATER, Vector2i(0, 0))
	assert_false(success, "UT-MAGIC-E01: 死亡中のユニットは詠唱失敗すること")

## UT-MAGIC-E02: 行動済みユニットの詠唱拒否
func test_magic_fails_when_already_acted() -> void:
	var tm = TurnManager.new()
	var board = GridBoard.new()
	board.add_cell(CellData.new(Vector2i(0, 0), Enums.CellType.NORMAL))
	var girl = CharacterData.new("GIRL_WATER", "水の少女", Vector2i(0, 0))
	girl.has_acted = true
	tm.setup_stage(board, [girl], [], "STAGE_TEST")
	
	var success = tm.execute_magic("GIRL_WATER", Enums.ElementType.WATER, Vector2i(0, 0))
	assert_false(success, "UT-MAGIC-E02: 既に行動済みのユニットは詠唱失敗すること")

## UT-MAGIC-E03: 詠唱者不在時の防御
func test_magic_fails_caster_not_found() -> void:
	var tm = TurnManager.new()
	var board = GridBoard.new()
	board.add_cell(CellData.new(Vector2i(0, 0), Enums.CellType.NORMAL))
	tm.setup_stage(board, [], [], "STAGE_TEST")
	
	var success = tm.execute_magic("UNKNOWN_ID", Enums.ElementType.FIRE, Vector2i(0, 0))
	assert_false(success, "UT-MAGIC-E03: 存在しないIDは安全に失敗すること")

## UT-MAGIC-E04: 炎魔法の対象不在時の失敗
func test_fire_magic_fails_no_target() -> void:
	var tm = TurnManager.new()
	var board = GridBoard.new()
	board.add_cell(CellData.new(Vector2i(0, 0), Enums.CellType.NORMAL))
	board.add_cell(CellData.new(Vector2i(1, 0), Enums.CellType.NORMAL))
	board.connect_cells(Vector2i(0, 0), Vector2i(1, 0))
	var fire_girl = CharacterData.new("GIRL_FIRE", "炎の少女", Vector2i(0, 0))
	# 魔女を配置しない
	tm.setup_stage(board, [fire_girl], [], "STAGE_TEST")
	
	var success = tm.execute_magic("GIRL_FIRE", Enums.ElementType.FIRE, Vector2i(1, 0))
	assert_false(success, "UT-MAGIC-E04: 対象座標に魔女がいない場合失敗すること")

## UT-MAGIC-B01: 炎魔法の射程境界
func test_fire_magic_range_boundary() -> void:
	var tm = TurnManager.new()
	var board = GridBoard.new()
	for x in range(5):
		board.add_cell(CellData.new(Vector2i(x, 0), Enums.CellType.NORMAL))
		if x > 0:
			board.connect_cells(Vector2i(x - 1, 0), Vector2i(x, 0))
	var fire_girl = CharacterData.new("GIRL_FIRE", "炎の少女", Vector2i(0, 0))
	var witch_at_2 = EnemyData.new("WITCH_2", Enums.EnemyType.TRACKING, Vector2i(2, 0)) # 距離2（境界内）
	tm.setup_stage(board, [fire_girl], [witch_at_2], "STAGE_TEST")
	
	var success = tm.execute_magic("GIRL_FIRE", Enums.ElementType.FIRE, Vector2i(2, 0))
	assert_true(success, "UT-MAGIC-B01: 射程内（距離2）の魔女は撃破可能")

## UT-MAGIC-D01: デシジョンテーブル：土魔法の効果分岐
func test_earth_magic_burrow_and_stun() -> void:
	var tm = TurnManager.new()
	var board = GridBoard.new()
	for x in range(3):
		board.add_cell(CellData.new(Vector2i(x, 0), Enums.CellType.NORMAL))
		if x > 0:
			board.connect_cells(Vector2i(x - 1, 0), Vector2i(x, 0))
	var earth_girl = CharacterData.new("GIRL_EARTH", "土の少女", Vector2i(0, 0))
	var witch = EnemyData.new("WITCH", Enums.EnemyType.TRACKING, Vector2i(2, 0))
	tm.setup_stage(board, [earth_girl], [witch], "STAGE_TEST")
	
	# Case 1: 空きマス対象 -> 自身潜行
	var res1 = tm.execute_magic("GIRL_EARTH", Enums.ElementType.EARTH, Vector2i(1, 0))
	assert_true(res1, "UT-MAGIC-D01: 空きマス詠唱成功")
	assert_true(earth_girl.is_burrowed, "UT-MAGIC-D01: 自身が潜行状態になること")
	assert_eq(witch.stun_turns, 0, "UT-MAGIC-D01: 魔女はスタンしない")
	
	# Case 2: 魔女対象 -> 魔女スタン
	earth_girl.has_acted = false
	var res2 = tm.execute_magic("GIRL_EARTH", Enums.ElementType.EARTH, Vector2i(2, 0))
	assert_true(res2, "UT-MAGIC-D01: 魔女対象詠唱成功")
	assert_eq(witch.stun_turns, 1, "UT-MAGIC-D01: 魔女が1ターンスタンすること")

## UT-MAGIC-N05: 移動完了による潜行解除
func test_unburrow_on_movement() -> void:
	var tm = TurnManager.new()
	var board = GridBoard.new()
	board.add_cell(CellData.new(Vector2i(0, 0), Enums.CellType.NORMAL))
	board.add_cell(CellData.new(Vector2i(1, 0), Enums.CellType.NORMAL))
	board.connect_cells(Vector2i(0, 0), Vector2i(1, 0))
	var hero = CharacterData.new("HERO", "主人公", Vector2i(0, 0))
	hero.is_burrowed = true # 潜行中
	tm.setup_stage(board, [hero], [], "STAGE_TEST")
	
	# 残り歩数0で到着
	var res = tm.step_unit(hero, Vector2i(1, 0), 0)
	assert_eq(res.get("result"), "ARRIVED", "UT-MAGIC-N05: 到着すること")
	assert_false(hero.is_burrowed, "UT-MAGIC-N05: 移動完了により潜行解除されること")

## 水魔術テスト用の盤面：(0,0)〜(4,0) の一直線
func _make_water_board(types: Array) -> GridBoard:
	var board = GridBoard.new()
	for x in range(types.size()):
		board.add_cell(CellData.new(Vector2i(x, 0), types[x]))
		if x > 0:
			board.connect_cells(Vector2i(x - 1, 0), Vector2i(x, 0))
	return board

## UT-MAGIC-N06: 水魔術の設置可能マスはNORMALのみ（足元・ユニットのいるマスも可）
func test_water_trap_targets_normal_cells_only() -> void:
	var tm = TurnManager.new()
	var board = _make_water_board([
		Enums.CellType.NORMAL, Enums.CellType.EXIT, Enums.CellType.EVENT, Enums.CellType.ADDITIONAL_MOVE,
		Enums.CellType.RETURN_TO_START, Enums.CellType.SKIP_TURN, Enums.CellType.ROLL_AGAIN,
		Enums.CellType.WATER_TRAP, Enums.CellType.NORMAL
	])
	var girl = CharacterData.new("GIRL_WATER", "水の少女", Vector2i(0, 0))
	var witch = EnemyData.new("WITCH_1", Enums.EnemyType.TRACKING, Vector2i(8, 0))
	tm.setup_stage(board, [girl], [witch], "STAGE_TEST")

	var targets = tm.get_water_trap_targets("GIRL_WATER")
	assert_eq(targets.size(), 2, "UT-MAGIC-N06: 設置可能マスはNORMALの2マスのみ")
	assert_true(targets.has(Vector2i(0, 0)), "UT-MAGIC-N06: 詠唱者の足元に設置可能")
	assert_true(targets.has(Vector2i(8, 0)), "UT-MAGIC-N06: 魔女のいるNORMALマスに設置可能")
	assert_true(tm.can_place_water_trap("GIRL_WATER", Vector2i(8, 0)), "UT-MAGIC-N06: can_place_water_trapもtrue")

	var ok = tm.execute_magic("GIRL_WATER", Enums.ElementType.WATER, Vector2i(8, 0))
	assert_true(ok, "UT-MAGIC-N06: 指定したNORMALマスへの設置に成功")
	assert_eq(board.get_cell(Vector2i(8, 0)).cell_type, Enums.CellType.WATER_TRAP, "UT-MAGIC-N06: 指定マスがWATER_TRAPになる")
	assert_eq(board.get_cell(Vector2i(0, 0)).cell_type, Enums.CellType.NORMAL, "UT-MAGIC-N06: 足元は変化しない")

## UT-MAGIC-E05: 特殊マス（EXIT・イベント・+2・戻る・休み・もう1回・設置済み水罠）への設置拒否
func test_water_magic_fails_on_special_cell() -> void:
	var specials = [
		Enums.CellType.EXIT, Enums.CellType.EVENT, Enums.CellType.ADDITIONAL_MOVE,
		Enums.CellType.RETURN_TO_START, Enums.CellType.SKIP_TURN, Enums.CellType.ROLL_AGAIN,
		Enums.CellType.WATER_TRAP
	]
	for t in specials:
		var tm = TurnManager.new()
		var board = _make_water_board([Enums.CellType.NORMAL, t])
		var girl = CharacterData.new("GIRL_WATER", "水の少女", Vector2i(0, 0))
		tm.setup_stage(board, [girl], [], "STAGE_TEST")
		assert_false(tm.can_place_water_trap("GIRL_WATER", Vector2i(1, 0)), "UT-MAGIC-E05: 特殊マス(type=%d)は設置不可" % t)
		var ok = tm.execute_magic("GIRL_WATER", Enums.ElementType.WATER, Vector2i(1, 0))
		assert_false(ok, "UT-MAGIC-E05: 特殊マス(type=%d)への詠唱は失敗" % t)
		assert_eq(board.get_cell(Vector2i(1, 0)).cell_type, t, "UT-MAGIC-E05: 特殊マス(type=%d)の種別は変わらない" % t)
		assert_false(girl.has_acted, "UT-MAGIC-E05: 失敗時は行動済みにならない(type=%d)" % t)

## UT-MAGIC-E06: 盤面に存在しない座標への設置拒否
func test_water_magic_fails_on_missing_cell() -> void:
	var tm = TurnManager.new()
	var board = _make_water_board([Enums.CellType.NORMAL, Enums.CellType.NORMAL])
	var girl = CharacterData.new("GIRL_WATER", "水の少女", Vector2i(0, 0))
	tm.setup_stage(board, [girl], [], "STAGE_TEST")
	assert_false(tm.can_place_water_trap("GIRL_WATER", Vector2i(5, 5)), "UT-MAGIC-E06: 存在しない座標は設置不可")
	assert_false(tm.execute_magic("GIRL_WATER", Enums.ElementType.WATER, Vector2i(5, 5)), "UT-MAGIC-E06: 存在しない座標への詠唱は失敗")
	assert_false(girl.has_acted, "UT-MAGIC-E06: 失敗時は行動済みにならない")
	assert_false(tm.can_place_water_trap("UNKNOWN_ID", Vector2i(1, 0)), "UT-MAGIC-E06: 存在しない詠唱者は設置不可")
	assert_eq(tm.get_water_trap_targets("UNKNOWN_ID").size(), 0, "UT-MAGIC-E06: 存在しない詠唱者の設置可能マスは空")

## UT-MAGIC-B02: 水魔術の射程境界（射程2：距離2は可・距離3は不可／-1は全範囲）
func test_water_magic_range_boundary() -> void:
	var tm = TurnManager.new()
	var board = _make_water_board([Enums.CellType.NORMAL, Enums.CellType.NORMAL, Enums.CellType.NORMAL, Enums.CellType.NORMAL, Enums.CellType.NORMAL])
	var girl = CharacterData.new("GIRL_WATER", "水の少女", Vector2i(0, 0))
	tm.setup_stage(board, [girl], [], "STAGE_TEST")

	assert_eq(TurnManager.WATER_TRAP_RANGE, -1, "UT-MAGIC-B02: 既定の射程は全範囲(-1)")
	assert_true(tm.can_place_water_trap("GIRL_WATER", Vector2i(4, 0)), "UT-MAGIC-B02: 全範囲なら距離4も設置可")

	tm.water_trap_range = 2
	assert_true(tm.can_place_water_trap("GIRL_WATER", Vector2i(2, 0)), "UT-MAGIC-B02: 射程2で距離2は設置可")
	assert_false(tm.can_place_water_trap("GIRL_WATER", Vector2i(3, 0)), "UT-MAGIC-B02: 射程2で距離3は設置不可")
	assert_eq(tm.get_water_trap_targets("GIRL_WATER").size(), 3, "UT-MAGIC-B02: 射程2の設置可能マスは距離0〜2の3マス")
	assert_false(tm.execute_magic("GIRL_WATER", Enums.ElementType.WATER, Vector2i(3, 0)), "UT-MAGIC-B02: 射程外への詠唱は失敗")
	assert_true(tm.execute_magic("GIRL_WATER", Enums.ElementType.WATER, Vector2i(2, 0)), "UT-MAGIC-B02: 射程内への詠唱は成功")
