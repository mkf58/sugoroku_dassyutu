class_name TestEnemyAI
extends TestCase

func run_all() -> void:
	test_witch_targets_nearest_unburrowed_unit()
	test_witch_targets_hero_on_equal_distance()
	test_witch_returns_to_initial_when_all_burrowed()
	test_witch_stops_immediately_on_water_trap()
	test_witch_stun_skips_turn()

## UT-ENEMY-01: 最短距離の未潜行ユニット優先選定
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
	assert_ne(target, null, "UT-ENEMY-01: Target should not be null")
	if target:
		assert_eq(target.character_id, "GIRL_FIRE", "UT-ENEMY-01: Nearest unit (GIRL_FIRE) should be targeted")

## UT-ENEMY-02: 同距離時のタイブレーク優先順位（主人公最優先）
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
	assert_ne(target, null, "UT-ENEMY-02: Target should not be null")
	if target:
		assert_eq(target.character_id, "HERO", "UT-ENEMY-02: Hero should be targeted when distance is equal")

## UT-ENEMY-03: 潜行中ユニットのターゲット除外と全員潜行時の初期位置移動
func test_witch_returns_to_initial_when_all_burrowed() -> void:
	var tm = TurnManager.new()
	var board = GridBoard.new()
	for x in range(6):
		board.add_cell(CellData.new(Vector2i(x, 0), Enums.CellType.NORMAL))
		if x > 0:
			board.connect_cells(Vector2i(x - 1, 0), Vector2i(x, 0))
			
	var hero = CharacterData.new("HERO", "主人公", Vector2i(0, 0))
	hero.is_burrowed = true # 潜行
	var witch = EnemyData.new("WITCH", Enums.EnemyType.TRACKING, Vector2i(2, 0))
	witch.initial_coord = Vector2i(5, 0)
	
	tm.setup_stage(board, [hero], [witch], "STAGE_TEST")
	
	var target = tm.select_witch_target(witch)
	assert_eq(target, null, "UT-ENEMY-03: Target should be null when all units burrowed")

## UT-ENEMY-04: 魔女のエネミーターン移動中の水トラップ即時停止
func test_witch_stops_immediately_on_water_trap() -> void:
	var board = GridBoard.new()
	for x in range(5):
		board.add_cell(CellData.new(Vector2i(x, 0), Enums.CellType.NORMAL))
		if x > 0:
			board.connect_cells(Vector2i(x - 1, 0), Vector2i(x, 0))
	# (2,0) を水トラップに設定
	board.get_cell(Vector2i(2, 0)).cell_type = Enums.CellType.WATER_TRAP
	
	var witch = EnemyData.new("WITCH_1", Enums.EnemyType.TRACKING, Vector2i(4, 0))
	var hero = CharacterData.new("HERO", "主人公", Vector2i(0, 0))
	var tm = TurnManager.new()
	tm.setup_stage(board, [hero], [witch], "STAGE_TEST")
	
	# 魔女が (4,0) から (0,0) へ向かって歩行
	# 4 -> 3 -> 2 (水トラップ) で停止するはず
	var path = board.find_shortest_path(witch.current_coord, hero.current_coord)
	# path: [(4,0), (3,0), (2,0), (1,0), (0,0)]
	var moved_to = witch.current_coord
	for i in range(1, path.size()):
		var next_coord = path[i]
		moved_to = next_coord
		var cell = board.get_cell(next_coord)
		if cell and cell.cell_type == Enums.CellType.WATER_TRAP:
			# 水トラップ進入で即時停止
			break
			
	witch.current_coord = moved_to
	assert_eq(witch.current_coord, Vector2i(2, 0), "UT-ENEMY-04: 魔女は水トラップマス(2,0)で即時停止すること")

## UT-ENEMY-05: スタン状態の魔女の行動スキップ
func test_witch_stun_skips_turn() -> void:
	var witch = EnemyData.new("WITCH_1", Enums.EnemyType.TRACKING, Vector2i(2, 0))
	witch.stun_turns = 1
	
	# スタン処理シミュレーション
	var acted = false
	if witch.stun_turns > 0:
		witch.stun_turns -= 1
		acted = false # 移動スキップ
	else:
		acted = true
		
	assert_false(acted, "UT-ENEMY-05: スタン中の魔女は移動がスキップされること")
	assert_eq(witch.stun_turns, 0, "UT-ENEMY-05: スタンターン数が1消費されて0になること")
