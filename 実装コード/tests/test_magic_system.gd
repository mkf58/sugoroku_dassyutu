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
