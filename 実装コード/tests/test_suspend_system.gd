class_name TestSuspendSystem
extends TestCase

## 中断セーブ（一時離席用スナップショット）の単体テスト（UT-SUSP-*）
## 実ファイルを汚さないよう、テスト専用ディレクトリを使用する。

const TEST_DIR: String = "user://test_saves_suspend"

func run_all() -> void:
    _cleanup()
    test_capture_units_and_turn()
    test_capture_cell_overrides()
    test_apply_restores_state()
    test_apply_ignores_unknown_ids()
    test_dict_round_trip_via_json()
    test_from_dict_invalid()
    test_save_load_suspend()
    test_suspend_overwrite()
    test_load_suspend_corrupted()
    test_slot_load_clears_suspend()
    test_consume_suspend()
    test_stun_immunity_round_trip()
    _cleanup()

func _cleanup() -> void:
    SaveManager.delete_suspend(TEST_DIR)
    for s in range(1, SaveManager.SLOT_COUNT + 1):
        SaveManager.delete_slot(s, TEST_DIR)

## 検証用の最小盤面（EVENTマスと通常マスを含む）
func _make_board() -> GridBoard:
    var board = GridBoard.new()
    board.add_cell(CellData.new(Vector2i(0, 0), Enums.CellType.NORMAL))
    board.add_cell(CellData.new(Vector2i(1, 0), Enums.CellType.NORMAL))
    board.add_cell(CellData.new(Vector2i(2, 0), Enums.CellType.EVENT))
    board.connect_cells(Vector2i(0, 0), Vector2i(1, 0))
    board.connect_cells(Vector2i(1, 0), Vector2i(2, 0))
    return board

func _make_tm(board: GridBoard) -> TurnManager:
    var tm = TurnManager.new()
    var hero = CharacterData.new("HERO", "主人公", Vector2i(0, 0))
    var girl = CharacterData.new("GIRL_FIRE", "炎の少女", Vector2i(0, 0))
    var witch = EnemyData.new("WITCH_1", Enums.EnemyType.TRACKING, Vector2i(2, 0))
    var chars: Array[CharacterData] = [hero, girl]
    var enemies: Array[EnemyData] = [witch]
    tm.setup_stage(board, chars, enemies, "STAGE_TEST")
    return tm

## 途中経過のある状態を作る
func _progress(tm: TurnManager) -> void:
    tm.current_turn = 5
    var hero: CharacterData = tm.characters["HERO"]
    hero.current_coord = Vector2i(1, 0)
    hero.has_acted = true
    var girl: CharacterData = tm.characters["GIRL_FIRE"]
    girl.kill()
    girl.revive_turn_count = 2
    girl.is_skipped = true
    var witch: EnemyData = tm.enemies["WITCH_1"]
    witch.current_coord = Vector2i(1, 0)
    witch.stun_turns = 1
    witch.patrol_index = 3

## UT-SUSP-N01: ターン数とユニット状態がスナップショットされる
func test_capture_units_and_turn() -> void:
    var board = _make_board()
    var tm = _make_tm(board)
    _progress(tm)
    var s = SuspendData.capture(tm, _make_board())
    assert_eq(s.stage_id, "STAGE_TEST", "UT-SUSP-N01: ステージID")
    assert_eq(s.current_turn, 5, "UT-SUSP-N01: ターン数")
    assert_eq(s.characters["HERO"]["coord"], [1, 0], "UT-SUSP-N01: 主人公座標")
    assert_eq(s.characters["HERO"]["has_acted"], true, "UT-SUSP-N01: 行動済み")
    assert_eq(s.characters["GIRL_FIRE"]["is_alive"], false, "UT-SUSP-N01: 少女の生死")
    assert_eq(s.characters["GIRL_FIRE"]["revive_turn_count"], 2, "UT-SUSP-N01: 復活カウンタ")
    assert_eq(s.characters["GIRL_FIRE"]["is_skipped"], true, "UT-SUSP-N01: 1回休み")
    assert_eq(s.enemies["WITCH_1"]["coord"], [1, 0], "UT-SUSP-N01: 魔女座標")
    assert_eq(s.enemies["WITCH_1"]["stun_turns"], 1, "UT-SUSP-N01: スタン")
    assert_eq(s.enemies["WITCH_1"]["patrol_index"], 3, "UT-SUSP-N01: 巡回インデックス")

## UT-SUSP-N02: 初期盤面との差分マス（消費済み・水トラップ）のみ保存される
func test_capture_cell_overrides() -> void:
    var board = _make_board()
    var tm = _make_tm(board)
    board.get_cell(Vector2i(2, 0)).is_consumed = true
    board.get_cell(Vector2i(1, 0)).cell_type = Enums.CellType.WATER_TRAP
    var s = SuspendData.capture(tm, _make_board())
    assert_eq(s.cell_overrides.size(), 2, "UT-SUSP-N02: 差分は2マス")
    var types := {}
    for o in s.cell_overrides:
        types[str(o["coord"])] = o
    assert_eq(types["[1, 0]"]["cell_type"], Enums.CellType.WATER_TRAP, "UT-SUSP-N02: 水トラップ化")
    assert_eq(types["[2, 0]"]["is_consumed"], true, "UT-SUSP-N02: 消費済み")
    var clean = SuspendData.capture(_make_tm(_make_board()), _make_board())
    assert_true(clean.cell_overrides.is_empty(), "UT-SUSP-N02: 差分なしなら空")

## UT-SUSP-N03: 復元で盤面状態が再現される
func test_apply_restores_state() -> void:
    var src_board = _make_board()
    var src = _make_tm(src_board)
    _progress(src)
    src_board.get_cell(Vector2i(2, 0)).is_consumed = true
    src_board.get_cell(Vector2i(1, 0)).cell_type = Enums.CellType.WATER_TRAP
    var s = SuspendData.capture(src, _make_board())

    var dst = _make_tm(_make_board())
    assert_true(s.apply_to(dst), "UT-SUSP-N03: 復元成功")
    assert_eq(dst.current_turn, 5, "UT-SUSP-N03: ターン数")
    assert_eq(dst.characters["HERO"].current_coord, Vector2i(1, 0), "UT-SUSP-N03: 主人公座標")
    assert_true(dst.characters["HERO"].has_acted, "UT-SUSP-N03: 行動済み")
    assert_false(dst.characters["GIRL_FIRE"].is_alive, "UT-SUSP-N03: 少女は死亡中")
    assert_eq(dst.characters["GIRL_FIRE"].revive_turn_count, 2, "UT-SUSP-N03: 復活カウンタ")
    assert_eq(dst.enemies["WITCH_1"].current_coord, Vector2i(1, 0), "UT-SUSP-N03: 魔女座標")
    assert_eq(dst.enemies["WITCH_1"].stun_turns, 1, "UT-SUSP-N03: スタン")
    assert_true(dst.board.get_cell(Vector2i(2, 0)).is_consumed, "UT-SUSP-N03: 消費済みマス")
    assert_eq(dst.board.get_cell(Vector2i(1, 0)).cell_type, Enums.CellType.WATER_TRAP, "UT-SUSP-N03: 水トラップ")

## UT-SUSP-E01: 存在しないID・座標は無視されクラッシュしない
func test_apply_ignores_unknown_ids() -> void:
    var s = SuspendData.capture(_make_tm(_make_board()), _make_board())
    s.characters["GHOST"] = {"coord": [0, 0], "is_alive": true, "has_acted": false, "revive_turn_count": 0, "is_burrowed": false, "is_skipped": false}
    s.enemies["GHOST_W"] = {"coord": [0, 0], "is_alive": true, "revive_turn_count": 0, "stun_turns": 0, "patrol_index": 0}
    s.cell_overrides.append({"coord": [99, 99], "cell_type": Enums.CellType.NORMAL, "is_consumed": true})
    var dst = _make_tm(_make_board())
    assert_true(s.apply_to(dst), "UT-SUSP-E01: 不明IDがあっても復元成功")
    assert_false(dst.characters.has("GHOST"), "UT-SUSP-E01: 不明キャラは追加されない")
    assert_false(s.apply_to(null), "UT-SUSP-E01: TurnManagerがnullなら失敗")

## UT-SUSP-N04: JSON経由でも型が正しく復元される
func test_dict_round_trip_via_json() -> void:
    var tm = _make_tm(_make_board())
    _progress(tm)
    var s = SuspendData.capture(tm, _make_board())
    s.active_slot = 2
    var inv: Array[Dictionary] = []
    inv.append({"id": "DICE_4", "name": "4の賽", "value": 4, "type": "FIXED_DICE"})
    s.inventory = inv
    s.visited_event_ids = ["EVT_X"]
    s.progress_flags = {"read": true}
    s.clear_flags = {"STAGE_1": true}
    s.achievement_counters = {"turns": 7}
    var r = SuspendData.from_dict(JSON.parse_string(JSON.stringify(s.to_dict())))
    assert_not_null(r, "UT-SUSP-N04: 復元成功")
    assert_eq(r.current_turn, 5, "UT-SUSP-N04: ターン数はint")
    assert_eq(typeof(r.current_turn), TYPE_INT, "UT-SUSP-N04: ターン数の型")
    assert_eq(r.active_slot, 2, "UT-SUSP-N04: アクティブスロット")
    assert_eq(r.inventory[0]["value"], 4, "UT-SUSP-N04: アイテム値")
    assert_eq(typeof(r.inventory[0]["value"]), TYPE_INT, "UT-SUSP-N04: アイテム値の型")
    var dst = _make_tm(_make_board())
    assert_true(r.apply_to(dst), "UT-SUSP-N04: JSON経由でも適用可能")
    assert_eq(dst.characters["HERO"].current_coord, Vector2i(1, 0), "UT-SUSP-N04: 座標がVector2i")
    assert_eq(r.visited_event_ids, ["EVT_X"], "UT-SUSP-N04: イベント履歴")

## UT-SUSP-E02: 不正な辞書はnull
func test_from_dict_invalid() -> void:
    assert_null(SuspendData.from_dict({}), "UT-SUSP-E02: 空辞書")
    assert_null(SuspendData.from_dict({"version": 1, "stage_id": "S"}), "UT-SUSP-E02: 必須キー欠落")
    assert_null(SuspendData.from_dict({"version": 1, "stage_id": "", "current_turn": 1, "characters": {}, "enemies": {}}), "UT-SUSP-E02: ステージID空")

## UT-SUSP-N05: 中断データの保存・読込・削除
func test_save_load_suspend() -> void:
    assert_false(SaveManager.has_suspend(TEST_DIR), "UT-SUSP-N05: 初期は存在しない")
    var s = SuspendData.capture(_make_tm(_make_board()), _make_board())
    assert_true(SaveManager.save_suspend(s, TEST_DIR), "UT-SUSP-N05: 保存成功")
    assert_true(SaveManager.has_suspend(TEST_DIR), "UT-SUSP-N05: 保存後は存在")
    var r = SaveManager.load_suspend(TEST_DIR)
    assert_not_null(r, "UT-SUSP-N05: 読込成功")
    assert_eq(r.stage_id, "STAGE_TEST", "UT-SUSP-N05: ステージID一致")
    assert_true(SaveManager.delete_suspend(TEST_DIR), "UT-SUSP-N05: 削除成功")
    assert_false(SaveManager.has_suspend(TEST_DIR), "UT-SUSP-N05: 削除後は存在しない")
    assert_false(SaveManager.delete_suspend(TEST_DIR), "UT-SUSP-N05: 二重削除はfalse")
    assert_false(SaveManager.save_suspend(null, TEST_DIR), "UT-SUSP-N05: nullは保存失敗")

## UT-SUSP-B01: 新たに中断セーブすると上書きされる（1枠のみ）
func test_suspend_overwrite() -> void:
    var tm = _make_tm(_make_board())
    var a = SuspendData.capture(tm, _make_board())
    a.current_turn = 3
    SaveManager.save_suspend(a, TEST_DIR)
    var b = SuspendData.capture(tm, _make_board())
    b.current_turn = 9
    SaveManager.save_suspend(b, TEST_DIR)
    assert_eq(SaveManager.load_suspend(TEST_DIR).current_turn, 9, "UT-SUSP-B01: 後勝ちで上書き")
    SaveManager.delete_suspend(TEST_DIR)

## UT-SUSP-E03: 破損ファイルはnull
func test_load_suspend_corrupted() -> void:
    DirAccess.make_dir_recursive_absolute(TEST_DIR)
    var f = FileAccess.open(SaveManager.suspend_path(TEST_DIR), FileAccess.WRITE)
    f.store_string("{ 壊れている")
    f.close()
    assert_null(SaveManager.load_suspend(TEST_DIR), "UT-SUSP-E03: 破損はnull")
    SaveManager.delete_suspend(TEST_DIR)

## UT-SUSP-D01: どのスロットをロードしても中断データは消える
func test_slot_load_clears_suspend() -> void:
    var d = SaveData.new()
    d.next_stage_id = "STAGE_2"
    for slot in [1, 2, 3]:
        SaveManager.save_slot(slot, d, TEST_DIR)
        SaveManager.save_suspend(SuspendData.capture(_make_tm(_make_board()), _make_board()), TEST_DIR)
        var r = SaveManager.load_slot_and_clear_suspend(slot, TEST_DIR)
        assert_not_null(r, "UT-SUSP-D01: スロット%dの読込成功" % slot)
        assert_false(SaveManager.has_suspend(TEST_DIR), "UT-SUSP-D01: スロット%dロード後に中断データ消滅" % slot)
    # 読込失敗（空きスロット）の場合は中断データを消さない
    SaveManager.delete_slot(1, TEST_DIR)
    SaveManager.save_suspend(SuspendData.capture(_make_tm(_make_board()), _make_board()), TEST_DIR)
    assert_null(SaveManager.load_slot_and_clear_suspend(1, TEST_DIR), "UT-SUSP-D01: 空きスロットはnull")
    assert_true(SaveManager.has_suspend(TEST_DIR), "UT-SUSP-D01: 失敗時は中断データを保持")

## UT-SUSP-N06: 中断データのロードも1回で消える
func test_consume_suspend() -> void:
    SaveManager.save_suspend(SuspendData.capture(_make_tm(_make_board()), _make_board()), TEST_DIR)
    var r = SaveManager.consume_suspend(TEST_DIR)
    assert_not_null(r, "UT-SUSP-N06: 読込成功")
    assert_false(SaveManager.has_suspend(TEST_DIR), "UT-SUSP-N06: ロード後は消える")
    assert_null(SaveManager.consume_suspend(TEST_DIR), "UT-SUSP-N06: 2回目はnull")

## UT-SUSP-N07: 再スタン不可ターンも中断データで保存・復元される
func test_stun_immunity_round_trip() -> void:
    var src = _make_tm(_make_board())
    src.enemies["WITCH_1"].stun_immune_turns = 1
    var s = SuspendData.capture(src, _make_board())
    assert_eq(s.enemies["WITCH_1"]["stun_immune_turns"], 1, "UT-SUSP-N07: 再スタン不可が保存される")
    var restored = SuspendData.from_dict(JSON.parse_string(JSON.stringify(s.to_dict())))
    var dst = _make_tm(_make_board())
    assert_true(restored.apply_to(dst), "UT-SUSP-N07: 復元成功")
    assert_eq(dst.enemies["WITCH_1"].stun_immune_turns, 1, "UT-SUSP-N07: JSON経由でも再スタン不可が復元される")
    # 古い中断データ（キーなし）は0として扱う
    var old = SuspendData.capture(src, _make_board())
    old.enemies["WITCH_1"].erase("stun_immune_turns")
    var dst2 = _make_tm(_make_board())
    old.apply_to(dst2)
    assert_eq(dst2.enemies["WITCH_1"].stun_immune_turns, 0, "UT-SUSP-N07: キーがなければ0")
