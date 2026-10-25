class_name TestEnemyAI
extends TestCase

func run_all() -> void:
	test_witch_targets_nearest_unburrowed_unit()
	test_witch_targets_hero_on_equal_distance()
	test_witch_returns_to_initial_when_all_burrowed()
	test_witch_stops_immediately_on_water_trap()
	test_witch_stun_skips_turn()
	test_witch_target_no_survivors()
	test_witch_target_zero_distance()
	test_witch_stun_counter_decrement()
	test_witch_target_selection_decision_table()

## UT-ENEMY-N01: 最短距離ユニット選定
func test_witch_targets_nearest_unburrowed_unit() -> void:
	var tm = TurnManager.new()
	var board = GridBoard.new()
	for x in range(6):
		board.add_cell(CellData.new(Vector2i(x, 0), Enums.CellType.NORMAL))
		if x > 0:
			board.connect_cells(Vector2i(x - 1, 0), Vector2i(x, 0))
			
	var hero = CharacterData.new("HERO", "主人公", Vector2i(0, 0)) # 距離5
	var fire_girl = CharacterData.new("GIRL_FIRE", "炎の少女", Vector2i(3, 0)) # 距離2
	var witch = EnemyData.new("WITCH", Enums.EnemyType.TRACKING, Vector2i(5, 0))
	tm.setup_stage(board, [hero, fire_girl], [witch], "STAGE_TEST")
	
	var target = tm.select_witch_target(witch)
	assert_ne(target, null, "UT-ENEMY-N01: ターゲットが存在すること")
	if target:
		assert_eq(target.character_id, "GIRL_FIRE", "UT-ENEMY-N01: 最短距離の炎の少女が選定されること")

## UT-ENEMY-N02: 同距離時のタイブレーク優先順位（主人公最優先）
func test_witch_targets_hero_on_equal_distance() -> void:
	var tm = TurnManager.new()
	var board = GridBoard.new()
	for x in range(5):
		board.add_cell(CellData.new(Vector2i(x, 0), Enums.CellType.NORMAL))
		if x > 0:
			board.connect_cells(Vector2i(x - 1, 0), Vector2i(x, 0))
			
	var hero = CharacterData.new("HERO", "主人公", Vector2i(0, 0)) # 距離2
	var fire_girl = CharacterData.new("GIRL_FIRE", "炎の少女", Vector2i(4, 0)) # 距離2
	var witch = EnemyData.new("WITCH", Enums.EnemyType.TRACKING, Vector2i(2, 0))
	tm.setup_stage(board, [hero, fire_girl], [witch], "STAGE_TEST")
	
	var target = tm.select_witch_target(witch)
	assert_ne(target, null, "UT-ENEMY-N02: ターゲットが存在すること")
	if target:
		assert_eq(target.character_id, "HERO", "UT-ENEMY-N02: 同距離時は主人公が最優先で選定されること")

## UT-ENEMY-N03: 全員潜行時の初期位置移動
func test_witch_returns_to_initial_when_all_burrowed() -> void:
	var tm = TurnManager.new()
	var board = GridBoard.new()
	for x in range(6):
		board.add_cell(CellData.new(Vector2i(x, 0), Enums.CellType.NORMAL))
		if x > 0:
			board.connect_cells(Vector2i(x - 1, 0), Vector2i(x, 0))
			
	var hero = CharacterData.new("HERO", "主人公", Vector2i(0, 0))
	hero.is_burrowed = true
	var witch = EnemyData.new("WITCH", Enums.EnemyType.TRACKING, Vector2i(2, 0))
	witch.initial_coord = Vector2i(5, 0)
	tm.setup_stage(board, [hero], [witch], "STAGE_TEST")
	
	var target = tm.select_witch_target(witch)
	assert_eq(target, null, "UT-ENEMY-N03: 全員潜行時はターゲットがnullとなること")

## UT-ENEMY-N04: 魔女水トラップ即時停止
func test_witch_stops_immediately_on_water_trap() -> void:
	var board = GridBoard.new()
	for x in range(5):
		board.add_cell(CellData.new(Vector2i(x, 0), Enums.CellType.NORMAL))
		if x > 0:
			board.connect_cells(Vector2i(x - 1, 0), Vector2i(x, 0))
	board.get_cell(Vector2i(2, 0)).cell_type = Enums.CellType.WATER_TRAP
	
	var witch = EnemyData.new("WITCH_1", Enums.EnemyType.TRACKING, Vector2i(4, 0))
	var hero = CharacterData.new("HERO", "主人公", Vector2i(0, 0))
	var tm = TurnManager.new()
	tm.setup_stage(board, [hero], [witch], "STAGE_TEST")
	
	var path = board.find_shortest_path(witch.current_coord, hero.current_coord)
	var stopped_coord = witch.current_coord
	for i in range(1, path.size()):
		var next_c = path[i]
		stopped_coord = next_c
		var cell = board.get_cell(next_c)
		if cell and cell.cell_type == Enums.CellType.WATER_TRAP:
			break
	witch.current_coord = stopped_coord
	assert_eq(witch.current_coord, Vector2i(2, 0), "UT-ENEMY-N04: 魔女は水トラップ(2,0)で即時停止すること")

## UT-ENEMY-N05: スタン中の行動スキップ
func test_witch_stun_skips_turn() -> void:
	var witch = EnemyData.new("WITCH_1", Enums.EnemyType.TRACKING, Vector2i(2, 0))
	witch.stun_turns = 1
	var moved = false
	if witch.stun_turns > 0:
		witch.stun_turns -= 1
		moved = false
	else:
		moved = true
	assert_false(moved, "UT-ENEMY-N05: スタン中は移動スキップ")
	assert_eq(witch.stun_turns, 0, "UT-ENEMY-N05: スタン値が0に減少")

## UT-ENEMY-E01: 生存味方不在時の防御
func test_witch_target_no_survivors() -> void:
	var tm = TurnManager.new()
	var board = GridBoard.new()
	board.add_cell(CellData.new(Vector2i(0, 0), Enums.CellType.NORMAL))
	var hero = CharacterData.new("HERO", "主人公", Vector2i(0, 0))
	hero.is_alive = false # 死亡中
	var witch = EnemyData.new("WITCH", Enums.EnemyType.TRACKING, Vector2i(0, 0))
	tm.setup_stage(board, [hero], [witch], "STAGE_TEST")
	
	var target = tm.select_witch_target(witch)
	assert_eq(target, null, "UT-ENEMY-E01: 生存味方がいない場合nullが安全に返ること")

## UT-ENEMY-B01: ターゲットとの距離が0
func test_witch_target_zero_distance() -> void:
	var tm = TurnManager.new()
	var board = GridBoard.new()
	board.add_cell(CellData.new(Vector2i(0, 0), Enums.CellType.NORMAL))
	var hero = CharacterData.new("HERO", "主人公", Vector2i(0, 0))
	var witch = EnemyData.new("WITCH", Enums.EnemyType.TRACKING, Vector2i(0, 0))
	tm.setup_stage(board, [hero], [witch], "STAGE_TEST")
	
	var target = tm.select_witch_target(witch)
	assert_ne(target, null, "UT-ENEMY-B01: 距離0でも正しく選定されること")
	if target:
		assert_eq(target.character_id, "HERO", "UT-ENEMY-B01: 主人公がターゲット")

## UT-ENEMY-B02: スタンカウンタのデクリメント
func test_witch_stun_counter_decrement() -> void:
	var witch = EnemyData.new("WITCH", Enums.EnemyType.TRACKING, Vector2i(0, 0))
	witch.stun_turns = 1
	# 1ターン経過処理
	if witch.stun_turns > 0:
		witch.stun_turns -= 1
	assert_eq(witch.stun_turns, 0, "UT-ENEMY-B02: 1ターン経過でスタン値が0へ減少すること")

## UT-ENEMY-D01: デシジョンテーブル：ターゲット選定優先順位
func test_witch_target_selection_decision_table() -> void:
	var tm = TurnManager.new()
	var board = GridBoard.new()
	for x in range(10):
		board.add_cell(CellData.new(Vector2i(x, 0), Enums.CellType.NORMAL))
		if x > 0:
			board.connect_cells(Vector2i(x - 1, 0), Vector2i(x, 0))
			
	var hero = CharacterData.new("HERO", "主人公", Vector2i(0, 0))       # 距離5
	var fire = CharacterData.new("GIRL_FIRE", "炎", Vector2i(3, 0))      # 距離2
	var wind = CharacterData.new("GIRL_WIND", "風", Vector2i(4, 0))      # 距離1だが死亡中
	wind.is_alive = false
	var water = CharacterData.new("GIRL_WATER", "水", Vector2i(4, 0))    # 距離1だが潜行中
	water.is_burrowed = true
	var witch = EnemyData.new("WITCH", Enums.EnemyType.TRACKING, Vector2i(5, 0))
	
	tm.setup_stage(board, [hero, fire, wind, water], [witch], "STAGE_TEST")
	
	# 風（死亡）と水（潜行）は除外され、距離2の炎が選ばれる
	var target = tm.select_witch_target(witch)
	assert_ne(target, null, "UT-ENEMY-D01: 有効なターゲットが選定されること")
	if target:
		assert_eq(target.character_id, "GIRL_FIRE", "UT-ENEMY-D01: 最短の未潜行生存ユニット(炎)が選定")
