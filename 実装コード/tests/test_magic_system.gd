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
	test_wind_blows_unit_to_farthest_cell()
	test_wind_hero_hits_witch_game_over()
	test_wind_collision_decision()
	test_wind_ignores_cell_effects()
	test_wind_invalid_targets()
	test_wind_range_boundary()
	test_earth_invalid_targets()
	test_earth_range_boundary()
	test_stunned_witch_is_harmless()
	test_earth_cannot_stun_consecutively()

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
	var hero = CharacterData.new("HERO", "主人公", Vector2i(1, 0))
	var witch = EnemyData.new("WITCH", Enums.EnemyType.TRACKING, Vector2i(2, 0))
	tm.setup_stage(board, [hero, earth_girl], [witch], "STAGE_TEST")

	# Case 1: 自分自身を対象 -> 自身潜行
	var res1 = tm.execute_earth("GIRL_EARTH", "GIRL_EARTH")
	assert_true(res1, "UT-MAGIC-D01: 自分自身への詠唱成功")
	assert_true(earth_girl.is_burrowed, "UT-MAGIC-D01: 自身が潜行状態になること")
	assert_false(hero.is_burrowed, "UT-MAGIC-D01: 他の味方は潜行しない")
	assert_eq(witch.stun_turns, 0, "UT-MAGIC-D01: 魔女はスタンしない")
	assert_true(earth_girl.has_acted, "UT-MAGIC-D01: 詠唱者は行動済み")

	# Case 2: 味方を対象 -> 味方が潜行、潜行中だった詠唱者は地上に出る
	earth_girl.has_acted = false
	var res2 = tm.execute_earth("GIRL_EARTH", "HERO")
	assert_true(res2, "UT-MAGIC-D01: 味方への詠唱成功")
	assert_true(hero.is_burrowed, "UT-MAGIC-D01: 味方が潜行状態になること")
	assert_false(earth_girl.is_burrowed, "UT-MAGIC-D01: 自分以外が対象なら詠唱者は潜行解除")
	assert_eq(witch.stun_turns, 0, "UT-MAGIC-D01: 魔女はスタンしない")

	# Case 3: 魔女を対象 -> 魔女スタン
	earth_girl.has_acted = false
	var res3 = tm.execute_earth("GIRL_EARTH", "WITCH")
	assert_true(res3, "UT-MAGIC-D01: 魔女への詠唱成功")
	assert_eq(witch.stun_turns, 2, "UT-MAGIC-D01: 魔女が2回休みのスタンになること")
	assert_false(earth_girl.is_burrowed, "UT-MAGIC-D01: 魔女が対象なら詠唱者は潜行しない")

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

## 風魔術テスト用の盤面：(0,0)〜(n-1,0) の一直線（すべてNORMAL）
func _make_wind_line(n: int) -> GridBoard:
	var types: Array = []
	for i in range(n):
		types.append(Enums.CellType.NORMAL)
	return _make_water_board(types)

## UT-MAGIC-N07: 風魔術で指定ユニットを指定方向の最遠マスへ吹き飛ばす（自分自身も対象可）
func test_wind_blows_unit_to_farthest_cell() -> void:
	var tm = TurnManager.new()
	var board = _make_wind_line(5)
	# (2,0) から下に1マスだけ伸びる枝：右方向の通路とは別
	board.add_cell(CellData.new(Vector2i(2, 1), Enums.CellType.NORMAL))
	board.connect_cells(Vector2i(2, 0), Vector2i(2, 1))
	var wind_girl = CharacterData.new("GIRL_WIND", "風の少女", Vector2i(0, 0))
	var hero = CharacterData.new("HERO", "主人公", Vector2i(1, 0))
	tm.setup_stage(board, [hero, wind_girl], [], "STAGE_TEST")

	var targets = tm.get_wind_targets("GIRL_WIND")
	assert_true(targets.has("HERO"), "UT-MAGIC-N07: 主人公を対象にできる")
	assert_true(targets.has("GIRL_WIND"), "UT-MAGIC-N07: 詠唱者自身を対象にできる")
	var dirs = tm.get_wind_directions("HERO")
	assert_true(dirs.has(Vector2i.RIGHT), "UT-MAGIC-N07: 右に飛ばせる")
	assert_false(dirs.has(Vector2i.LEFT), "UT-MAGIC-N07: 左は詠唱者のいる(0,0)しかなく着地できないため選べない")
	assert_false(dirs.has(Vector2i.UP), "UT-MAGIC-N07: 通路のない上には飛ばせない")

	var res = tm.execute_wind("GIRL_WIND", "HERO", Vector2i.RIGHT)
	assert_eq(res.get("result"), "BLOWN", "UT-MAGIC-N07: 吹き飛ばし成功")
	assert_eq(hero.current_coord, Vector2i(4, 0), "UT-MAGIC-N07: 枝道に曲がらず最遠マス(4,0)まで飛ぶ")
	assert_eq(res.get("path"), [Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0), Vector2i(4, 0)], "UT-MAGIC-N07: 経路は出発点から着地点まで")
	assert_true(wind_girl.has_acted, "UT-MAGIC-N07: 詠唱者は行動済み")
	assert_true(hero.is_alive, "UT-MAGIC-N07: 主人公は無事")

	# 自分自身を吹き飛ばす（潜行中でも詠唱で地上に出るため対象にできる）
	var tm2 = TurnManager.new()
	var girl2 = CharacterData.new("GIRL_WIND", "風の少女", Vector2i(0, 0))
	girl2.is_burrowed = true
	tm2.setup_stage(_make_wind_line(4), [girl2], [], "STAGE_TEST")
	assert_true(tm2.get_wind_targets("GIRL_WIND").has("GIRL_WIND"), "UT-MAGIC-N07: 潜行中の詠唱者自身は対象にできる")
	var res2 = tm2.execute_wind("GIRL_WIND", "GIRL_WIND", Vector2i.RIGHT)
	assert_eq(res2.get("result"), "BLOWN", "UT-MAGIC-N07: 自分自身の吹き飛ばし成功")
	assert_eq(girl2.current_coord, Vector2i(3, 0), "UT-MAGIC-N07: 自分が最遠マスへ移動")
	assert_false(girl2.is_burrowed, "UT-MAGIC-N07: 詠唱で潜行解除")

## UT-MAGIC-N08: 主人公を吹き飛ばして魔女にぶつかるとゲームオーバー
func test_wind_hero_hits_witch_game_over() -> void:
	var tm = TurnManager.new()
	var wind_girl = CharacterData.new("GIRL_WIND", "風の少女", Vector2i(0, 0))
	var hero = CharacterData.new("HERO", "主人公", Vector2i(1, 0))
	var witch = EnemyData.new("WITCH_1", Enums.EnemyType.TRACKING, Vector2i(3, 0))
	tm.setup_stage(_make_wind_line(5), [hero, wind_girl], [witch], "STAGE_TEST")
	var reasons: Array = []
	tm.game_over_triggered.connect(func(r): reasons.append(r))

	var res = tm.execute_wind("GIRL_WIND", "HERO", Vector2i.RIGHT)
	assert_eq(res.get("result"), "GAME_OVER", "UT-MAGIC-N08: 戻り値GAME_OVER")
	assert_eq(hero.current_coord, Vector2i(3, 0), "UT-MAGIC-N08: 魔女のマスで止まる")
	assert_eq(tm.current_phase, Enums.TurnPhase.GAME_OVER, "UT-MAGIC-N08: ゲームオーバーへ遷移")
	assert_eq(reasons.size(), 1, "UT-MAGIC-N08: game_over_triggeredが1回発行される")

## UT-MAGIC-D02: デシジョンテーブル：風魔術の進路・着地の衝突判定
func test_wind_collision_decision() -> void:
	# Case 1: 少女を飛ばして進路上の魔女にぶつかる -> 魔女のマスで止まり捕縛
	var tm1 = TurnManager.new()
	var caster1 = CharacterData.new("GIRL_WIND", "風の少女", Vector2i(0, 0))
	var fire1 = CharacterData.new("GIRL_FIRE", "炎の少女", Vector2i(1, 0))
	var w1 = EnemyData.new("WITCH_1", Enums.EnemyType.TRACKING, Vector2i(3, 0))
	tm1.setup_stage(_make_wind_line(5), [caster1, fire1], [w1], "STAGE_TEST")
	var killed: Array = []
	tm1.unit_killed.connect(func(uid): killed.append(uid))
	var r1 = tm1.execute_wind("GIRL_WIND", "GIRL_FIRE", Vector2i.RIGHT)
	assert_eq(r1.get("result"), "GIRL_DIED", "UT-MAGIC-D02: Case1 戻り値GIRL_DIED")
	assert_eq(fire1.current_coord, Vector2i(3, 0), "UT-MAGIC-D02: Case1 魔女のマスで止まる")
	assert_false(fire1.is_alive, "UT-MAGIC-D02: Case1 少女が捕縛される")
	assert_eq(killed, ["GIRL_FIRE"], "UT-MAGIC-D02: Case1 unit_killedが発行される")
	assert_ne(tm1.current_phase, Enums.TurnPhase.GAME_OVER, "UT-MAGIC-D02: Case1 ゲームオーバーにはならない")

	# Case 2: 魔女を飛ばして進路上のキャラとすれ違う -> すり抜け、誰も捕まらない
	var tm2 = TurnManager.new()
	var caster2 = CharacterData.new("GIRL_WIND", "風の少女", Vector2i(0, 0))
	var hero2 = CharacterData.new("HERO", "主人公", Vector2i(3, 0))
	var w2 = EnemyData.new("WITCH_1", Enums.EnemyType.TRACKING, Vector2i(1, 0))
	tm2.setup_stage(_make_wind_line(5), [hero2, caster2], [w2], "STAGE_TEST")
	var r2 = tm2.execute_wind("GIRL_WIND", "WITCH_1", Vector2i.RIGHT)
	assert_eq(r2.get("result"), "BLOWN", "UT-MAGIC-D02: Case2 戻り値BLOWN")
	assert_eq(w2.current_coord, Vector2i(4, 0), "UT-MAGIC-D02: Case2 魔女はキャラをすり抜けて最遠マスへ")
	assert_true(hero2.is_alive, "UT-MAGIC-D02: Case2 すれ違った主人公は捕まらない")
	assert_ne(tm2.current_phase, Enums.TurnPhase.GAME_OVER, "UT-MAGIC-D02: Case2 ゲームオーバーにならない")

	# Case 3: キャラを飛ばして進路上の味方とすれ違う -> すり抜け
	var tm3 = TurnManager.new()
	var caster3 = CharacterData.new("GIRL_WIND", "風の少女", Vector2i(2, 0))
	var hero3 = CharacterData.new("HERO", "主人公", Vector2i(0, 0))
	tm3.setup_stage(_make_wind_line(5), [hero3, caster3], [], "STAGE_TEST")
	var r3 = tm3.execute_wind("GIRL_WIND", "HERO", Vector2i.RIGHT)
	assert_eq(r3.get("result"), "BLOWN", "UT-MAGIC-D02: Case3 戻り値BLOWN")
	assert_eq(hero3.current_coord, Vector2i(4, 0), "UT-MAGIC-D02: Case3 味方をすり抜けて最遠マスへ")

	# Case 4: 着地マスに別のユニットがいる -> 空いているマスまで手前に戻る
	var tm4 = TurnManager.new()
	var caster4 = CharacterData.new("GIRL_WIND", "風の少女", Vector2i(4, 0))
	var hero4 = CharacterData.new("HERO", "主人公", Vector2i(0, 0))
	var w4 = EnemyData.new("WITCH_1", Enums.EnemyType.TRACKING, Vector2i(1, 0))
	var w4b = EnemyData.new("WITCH_2", Enums.EnemyType.TRACKING, Vector2i(3, 0))
	tm4.setup_stage(_make_wind_line(5), [hero4, caster4], [w4, w4b], "STAGE_TEST")
	var r4 = tm4.execute_wind("GIRL_WIND", "WITCH_1", Vector2i.RIGHT)
	assert_eq(r4.get("result"), "BLOWN", "UT-MAGIC-D02: Case4 戻り値BLOWN")
	assert_eq(w4.current_coord, Vector2i(2, 0), "UT-MAGIC-D02: Case4 (4,0)詠唱者・(3,0)魔女を避けて(2,0)に着地")
	assert_eq(r4.get("path"), [Vector2i(1, 0), Vector2i(2, 0)], "UT-MAGIC-D02: Case4 経路は着地点まで")

	# Case 5: 手前に戻ると出発点になる方向は選べない
	var tm5 = TurnManager.new()
	var caster5 = CharacterData.new("GIRL_WIND", "風の少女", Vector2i(2, 0))
	var hero5 = CharacterData.new("HERO", "主人公", Vector2i(1, 0))
	tm5.setup_stage(_make_wind_line(3), [hero5, caster5], [], "STAGE_TEST")
	assert_false(tm5.get_wind_directions("HERO").has(Vector2i.RIGHT), "UT-MAGIC-D02: Case5 着地点が埋まり動けない方向は選べない")
	assert_true(tm5.get_wind_directions("HERO").has(Vector2i.LEFT), "UT-MAGIC-D02: Case5 反対方向は選べる")

## UT-MAGIC-N09: 風魔術では途中の水罠も着地マスの効果も発動しない
func test_wind_ignores_cell_effects() -> void:
	var tm = TurnManager.new()
	var board = _make_water_board([Enums.CellType.NORMAL, Enums.CellType.NORMAL, Enums.CellType.WATER_TRAP, Enums.CellType.EXIT])
	var wind_girl = CharacterData.new("GIRL_WIND", "風の少女", Vector2i(0, 0))
	var hero = CharacterData.new("HERO", "主人公", Vector2i(1, 0))
	tm.setup_stage(board, [hero, wind_girl], [], "STAGE_TEST")
	var cleared: Array = []
	tm.stage_cleared.connect(func(sid): cleared.append(sid))
	var res = tm.execute_wind("GIRL_WIND", "HERO", Vector2i.RIGHT)
	assert_eq(res.get("result"), "BLOWN", "UT-MAGIC-N09: 戻り値BLOWN")
	assert_eq(hero.current_coord, Vector2i(3, 0), "UT-MAGIC-N09: 水罠を素通りしてEXITまで飛ぶ")
	assert_eq(cleared.size(), 0, "UT-MAGIC-N09: EXITに着地してもクリアにならない")
	assert_ne(tm.current_phase, Enums.TurnPhase.STAGE_CLEAR, "UT-MAGIC-N09: フェーズはSTAGE_CLEARにならない")

	var tm2 = TurnManager.new()
	var board2 = _make_water_board([Enums.CellType.NORMAL, Enums.CellType.NORMAL, Enums.CellType.EVENT])
	var girl2 = CharacterData.new("GIRL_WIND", "風の少女", Vector2i(0, 0))
	var hero2 = CharacterData.new("HERO", "主人公", Vector2i(1, 0))
	tm2.setup_stage(board2, [hero2, girl2], [], "STAGE_TEST")
	tm2.execute_wind("GIRL_WIND", "HERO", Vector2i.RIGHT)
	assert_eq(hero2.current_coord, Vector2i(2, 0), "UT-MAGIC-N09: イベントマスに着地")
	assert_false(board2.get_cell(Vector2i(2, 0)).is_consumed, "UT-MAGIC-N09: イベントは発動しない（未消費のまま）")

## UT-MAGIC-E07: 風魔術の不正な対象・方向の拒否
func test_wind_invalid_targets() -> void:
	var tm = TurnManager.new()
	var wind_girl = CharacterData.new("GIRL_WIND", "風の少女", Vector2i(0, 0))
	var earth = CharacterData.new("GIRL_EARTH", "土の少女", Vector2i(1, 0))
	earth.is_burrowed = true
	var fire = CharacterData.new("GIRL_FIRE", "炎の少女", Vector2i(2, 0))
	fire.kill()
	var witch = EnemyData.new("WITCH_1", Enums.EnemyType.TRACKING, Vector2i(3, 0))
	witch.defeat()
	tm.setup_stage(_make_wind_line(5), [wind_girl, earth, fire], [witch], "STAGE_TEST")

	var targets = tm.get_wind_targets("GIRL_WIND")
	assert_false(targets.has("GIRL_EARTH"), "UT-MAGIC-E07: 潜行中のユニットは対象外")
	assert_false(targets.has("GIRL_FIRE"), "UT-MAGIC-E07: 死亡中のユニットは対象外")
	assert_false(targets.has("WITCH_1"), "UT-MAGIC-E07: 撃破中の魔女は対象外")
	assert_eq(tm.execute_wind("GIRL_WIND", "GIRL_EARTH", Vector2i.RIGHT).get("result"), "ERROR", "UT-MAGIC-E07: 潜行中ユニットへの詠唱は失敗")
	assert_eq(tm.execute_wind("GIRL_WIND", "GIRL_FIRE", Vector2i.RIGHT).get("result"), "ERROR", "UT-MAGIC-E07: 死亡中ユニットへの詠唱は失敗")
	assert_eq(tm.execute_wind("GIRL_WIND", "UNKNOWN", Vector2i.RIGHT).get("result"), "ERROR", "UT-MAGIC-E07: 存在しない対象への詠唱は失敗")
	assert_eq(tm.execute_wind("UNKNOWN", "GIRL_WIND", Vector2i.RIGHT).get("result"), "ERROR", "UT-MAGIC-E07: 存在しない詠唱者は失敗")
	assert_eq(tm.execute_wind("GIRL_WIND", "GIRL_WIND", Vector2i.LEFT).get("result"), "ERROR", "UT-MAGIC-E07: 1マスも動けない方向は失敗")
	assert_eq(tm.execute_wind("GIRL_WIND", "GIRL_WIND", Vector2i(1, 1)).get("result"), "ERROR", "UT-MAGIC-E07: 上下左右以外の方向は失敗")
	assert_false(wind_girl.has_acted, "UT-MAGIC-E07: 失敗時は行動済みにならない")
	assert_eq(wind_girl.current_coord, Vector2i(0, 0), "UT-MAGIC-E07: 失敗時は移動しない")

	wind_girl.has_acted = true
	assert_eq(tm.execute_wind("GIRL_WIND", "GIRL_WIND", Vector2i.RIGHT).get("result"), "ERROR", "UT-MAGIC-E07: 行動済みの詠唱者は失敗")
	wind_girl.has_acted = false
	assert_false(tm.execute_magic("GIRL_WIND", Enums.ElementType.WIND, Vector2i(0, 0)), "UT-MAGIC-E07: execute_magicでの風魔術は受け付けない（execute_windを使う）")
	assert_false(wind_girl.has_acted, "UT-MAGIC-E07: execute_magicで風を指定しても行動済みにならない")

## UT-MAGIC-B03: 風魔術の射程境界（射程2：距離2は対象可・距離3は不可／-1は全範囲）
func test_wind_range_boundary() -> void:
	var tm = TurnManager.new()
	var wind_girl = CharacterData.new("GIRL_WIND", "風の少女", Vector2i(0, 0))
	var w2 = EnemyData.new("WITCH_1", Enums.EnemyType.TRACKING, Vector2i(2, 0))
	var w3 = EnemyData.new("WITCH_2", Enums.EnemyType.TRACKING, Vector2i(3, 0))
	tm.setup_stage(_make_wind_line(6), [wind_girl], [w2, w3], "STAGE_TEST")

	assert_eq(TurnManager.WIND_RANGE, -1, "UT-MAGIC-B03: 既定の射程は全範囲(-1)")
	assert_true(tm.get_wind_targets("GIRL_WIND").has("WITCH_2"), "UT-MAGIC-B03: 全範囲なら距離3も対象可")

	tm.wind_range = 2
	var targets = tm.get_wind_targets("GIRL_WIND")
	assert_true(targets.has("WITCH_1"), "UT-MAGIC-B03: 射程2で距離2は対象可")
	assert_false(targets.has("WITCH_2"), "UT-MAGIC-B03: 射程2で距離3は対象外")
	assert_eq(tm.execute_wind("GIRL_WIND", "WITCH_2", Vector2i.RIGHT).get("result"), "ERROR", "UT-MAGIC-B03: 射程外への詠唱は失敗")
	assert_eq(tm.execute_wind("GIRL_WIND", "WITCH_1", Vector2i.RIGHT).get("result"), "BLOWN", "UT-MAGIC-B03: 射程内への詠唱は成功")

## UT-MAGIC-E08: 土魔術の不正な対象の拒否
func test_earth_invalid_targets() -> void:
	var tm = TurnManager.new()
	var earth_girl = CharacterData.new("GIRL_EARTH", "土の少女", Vector2i(0, 0))
	earth_girl.is_burrowed = true
	var hero = CharacterData.new("HERO", "主人公", Vector2i(1, 0))
	hero.is_burrowed = true
	var fire = CharacterData.new("GIRL_FIRE", "炎の少女", Vector2i(2, 0))
	fire.kill()
	var stunned = EnemyData.new("WITCH_1", Enums.EnemyType.TRACKING, Vector2i(3, 0))
	stunned.stun_turns = 1
	var defeated = EnemyData.new("WITCH_2", Enums.EnemyType.TRACKING, Vector2i(4, 0))
	defeated.defeat()
	tm.setup_stage(_make_wind_line(5), [hero, earth_girl, fire], [stunned, defeated], "STAGE_TEST")

	var targets = tm.get_earth_targets("GIRL_EARTH")
	assert_false(targets.has("GIRL_EARTH"), "UT-MAGIC-E08: 潜行中の詠唱者自身は対象外")
	assert_false(targets.has("HERO"), "UT-MAGIC-E08: 潜行中の味方は対象外")
	assert_false(targets.has("GIRL_FIRE"), "UT-MAGIC-E08: 死亡中の味方は対象外")
	assert_false(targets.has("WITCH_1"), "UT-MAGIC-E08: スタン中の魔女は対象外")
	assert_false(targets.has("WITCH_2"), "UT-MAGIC-E08: 撃破中の魔女は対象外")
	assert_false(tm.execute_earth("GIRL_EARTH", "HERO"), "UT-MAGIC-E08: 潜行中の味方への詠唱は失敗")
	assert_false(tm.execute_earth("GIRL_EARTH", "WITCH_1"), "UT-MAGIC-E08: スタン中の魔女への詠唱は失敗")
	assert_false(tm.execute_earth("GIRL_EARTH", "UNKNOWN"), "UT-MAGIC-E08: 存在しない対象への詠唱は失敗")
	assert_false(tm.execute_earth("UNKNOWN", "HERO"), "UT-MAGIC-E08: 存在しない詠唱者は失敗")
	assert_false(earth_girl.has_acted, "UT-MAGIC-E08: 失敗時は行動済みにならない")
	assert_true(earth_girl.is_burrowed, "UT-MAGIC-E08: 失敗時は詠唱者の潜行も変わらない")
	assert_eq(stunned.stun_turns, 1, "UT-MAGIC-E08: スタンは重ならない")

	hero.is_burrowed = false
	earth_girl.has_acted = true
	assert_false(tm.execute_earth("GIRL_EARTH", "HERO"), "UT-MAGIC-E08: 行動済みの詠唱者は失敗")
	earth_girl.has_acted = false
	assert_false(tm.execute_magic("GIRL_EARTH", Enums.ElementType.EARTH, Vector2i(1, 0)), "UT-MAGIC-E08: execute_magicでの土魔術は受け付けない（execute_earthを使う）")
	assert_false(hero.is_burrowed, "UT-MAGIC-E08: execute_magicで土を指定しても効果は出ない")

## UT-MAGIC-B04: 土魔術の射程境界（射程6：距離6は対象可・距離7は不可）
func test_earth_range_boundary() -> void:
	var tm = TurnManager.new()
	var earth_girl = CharacterData.new("GIRL_EARTH", "土の少女", Vector2i(0, 0))
	var w6 = EnemyData.new("WITCH_1", Enums.EnemyType.TRACKING, Vector2i(6, 0))
	var w7 = EnemyData.new("WITCH_2", Enums.EnemyType.TRACKING, Vector2i(7, 0))
	tm.setup_stage(_make_wind_line(8), [earth_girl], [w6, w7], "STAGE_TEST")

	assert_eq(TurnManager.EARTH_RANGE, 6, "UT-MAGIC-B04: 既定の射程は6")
	var targets = tm.get_earth_targets("GIRL_EARTH")
	assert_true(targets.has("WITCH_1"), "UT-MAGIC-B04: 距離6は対象可")
	assert_false(targets.has("WITCH_2"), "UT-MAGIC-B04: 距離7は対象外")
	assert_true(targets.has("GIRL_EARTH"), "UT-MAGIC-B04: 距離0の自分自身は対象可")
	assert_false(tm.execute_earth("GIRL_EARTH", "WITCH_2"), "UT-MAGIC-B04: 射程外への詠唱は失敗")
	assert_true(tm.execute_earth("GIRL_EARTH", "WITCH_1"), "UT-MAGIC-B04: 射程内への詠唱は成功")

## UT-MAGIC-N10: スタン中の魔女は無害（踏んでも捕まらない・風で飛ばしてもぶつからない）
func test_stunned_witch_is_harmless() -> void:
	# 1歩移動でスタン中の魔女のマスに入っても捕まらない
	var tm = TurnManager.new()
	var hero = CharacterData.new("HERO", "主人公", Vector2i(0, 0))
	var girl = CharacterData.new("GIRL_FIRE", "炎の少女", Vector2i(4, 0))
	var witch = EnemyData.new("WITCH_1", Enums.EnemyType.TRACKING, Vector2i(1, 0))
	witch.stun_turns = 1
	tm.setup_stage(_make_wind_line(5), [hero, girl], [witch], "STAGE_TEST")
	var r1 = tm.step_unit(hero, Vector2i(1, 0), 1)
	assert_eq(r1.get("result"), "CONTINUE", "UT-MAGIC-N10: スタン中の魔女のマスは通過できる")
	assert_ne(tm.current_phase, Enums.TurnPhase.GAME_OVER, "UT-MAGIC-N10: 主人公は捕まらない")
	var r2 = tm.step_unit(girl, Vector2i(1, 0), 0)
	assert_eq(r2.get("result"), "ARRIVED", "UT-MAGIC-N10: スタン中の魔女のマスに止まれる")
	assert_true(girl.is_alive, "UT-MAGIC-N10: 少女は捕まらない")

	# 風魔術で飛ばしたキャラもスタン中の魔女にはぶつからず、そのマスに着地もできる
	var tm2 = TurnManager.new()
	var wind_girl = CharacterData.new("GIRL_WIND", "風の少女", Vector2i(0, 0))
	var hero2 = CharacterData.new("HERO", "主人公", Vector2i(1, 0))
	var w2 = EnemyData.new("WITCH_1", Enums.EnemyType.TRACKING, Vector2i(3, 0))
	w2.stun_turns = 1
	tm2.setup_stage(_make_wind_line(4), [hero2, wind_girl], [w2], "STAGE_TEST")
	var r3 = tm2.execute_wind("GIRL_WIND", "HERO", Vector2i.RIGHT)
	assert_eq(r3.get("result"), "BLOWN", "UT-MAGIC-N10: スタン中の魔女にはぶつからない")
	assert_eq(hero2.current_coord, Vector2i(3, 0), "UT-MAGIC-N10: スタン中の魔女のマスに着地できる")

## UT-MAGIC-E09: スタンが解けた直後のターンは同じ魔女を再スタンできない（連続スタン防止）
func test_earth_cannot_stun_consecutively() -> void:
	var tm = TurnManager.new()
	var earth_girl = CharacterData.new("GIRL_EARTH", "土の少女", Vector2i(0, 0))
	var witch = EnemyData.new("WITCH_1", Enums.EnemyType.TRACKING, Vector2i(3, 0))
	tm.setup_stage(_make_wind_line(5), [earth_girl], [witch], "STAGE_TEST")

	assert_true(tm.execute_earth("GIRL_EARTH", "WITCH_1"), "UT-MAGIC-E09: 1回目のスタン成功")
	tm.end_turn_and_advance()
	assert_false(tm.get_earth_targets("GIRL_EARTH").has("WITCH_1"), "UT-MAGIC-E09: スタン中は対象外")
	tm.end_turn_and_advance()
	assert_eq(witch.stun_turns, 0, "UT-MAGIC-E09: 2回休みの後にスタン解除")
	assert_eq(witch.stun_immune_turns, 1, "UT-MAGIC-E09: 解除直後は再スタン不可が1")
	assert_false(tm.get_earth_targets("GIRL_EARTH").has("WITCH_1"), "UT-MAGIC-E09: 解除直後のターンは対象外")
	assert_false(tm.execute_earth("GIRL_EARTH", "WITCH_1"), "UT-MAGIC-E09: 解除直後のターンは詠唱失敗")
	assert_true(tm.get_earth_targets("GIRL_EARTH").has("GIRL_EARTH"), "UT-MAGIC-E09: 味方への詠唱は引き続き可能")
	tm.end_turn_and_advance()
	assert_eq(witch.stun_immune_turns, 0, "UT-MAGIC-E09: 1ターン後に再スタン不可が解ける")
	assert_true(tm.execute_earth("GIRL_EARTH", "WITCH_1"), "UT-MAGIC-E09: その次のターンからは再びスタンできる")

	# 撃破されるとスタン・再スタン不可はリセットされる
	witch.defeat()
	assert_eq(witch.stun_turns, 0, "UT-MAGIC-E09: 撃破でスタンはリセット")
	assert_eq(witch.stun_immune_turns, 0, "UT-MAGIC-E09: 撃破で再スタン不可もリセット")
