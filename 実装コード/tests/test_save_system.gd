class_name TestSaveSystem
extends TestCase

## セーブ・ロードシステムの単体テスト（UT-SAVE-*）
## 実ファイルを汚さないよう、テスト専用ディレクトリ（user://test_saves）を使用する。

const TEST_DIR: String = "user://test_saves"

func run_all() -> void:
    _cleanup()
    test_save_data_round_trip()
    test_save_data_defaults()
    test_save_data_inventory_int_after_json()
    test_save_data_invalid_dict()
    test_save_and_load_slot()
    test_slot_boundaries()
    test_invalid_slot_rejected()
    test_load_missing_slot()
    test_load_corrupted_file()
    test_load_version_mismatch()
    test_delete_slot()
    test_has_any_save_and_latest()
    test_new_game_data()
    test_new_game_overwrites_slot()
    test_summaries()
    _cleanup()

func _cleanup() -> void:
    for s in range(1, SaveManager.SLOT_COUNT + 1):
        SaveManager.delete_slot(s, TEST_DIR)

func _make_data() -> SaveData:
    var d = SaveData.new()
    d.next_stage_id = "STAGE_3"
    d.cleared_stage_name = "キッチン"
    d.saved_at = "2026-11-17 20:00:00"
    var inv: Array[Dictionary] = []
    inv.append({"id": "DICE_1", "name": "1の賽", "value": 1, "type": "FIXED_DICE"})
    inv.append({"id": "DICE_6", "name": "6の賽", "value": 6, "type": "FIXED_DICE"})
    d.inventory = inv
    d.visited_event_ids = ["EVT_A", "EVT_B"]
    d.progress_flags = {"read_diary": true}
    d.clear_flags = {"STAGE_1": true, "STAGE_2": true}
    d.achievement_counters = {"total_turns": 42}
    return d

## UT-SAVE-N01: SaveData の辞書変換が可逆である
func test_save_data_round_trip() -> void:
    var d = _make_data()
    var r = SaveData.from_dict(d.to_dict())
    assert_not_null(r, "UT-SAVE-N01: 復元結果がnullでない")
    assert_eq(r.version, SaveData.CURRENT_VERSION, "UT-SAVE-N01: バージョン")
    assert_eq(r.next_stage_id, "STAGE_3", "UT-SAVE-N01: 次ステージID")
    assert_eq(r.cleared_stage_name, "キッチン", "UT-SAVE-N01: クリア済みステージ名")
    assert_eq(r.saved_at, "2026-11-17 20:00:00", "UT-SAVE-N01: セーブ日時")
    assert_eq(r.inventory.size(), 2, "UT-SAVE-N01: 所持アイテム数")
    assert_eq(r.inventory[1].get("value"), 6, "UT-SAVE-N01: アイテムの値")
    assert_eq(r.visited_event_ids, ["EVT_A", "EVT_B"], "UT-SAVE-N01: 踏んだイベントマス")
    assert_eq(r.progress_flags.get("read_diary"), true, "UT-SAVE-N01: 進行フラグ")
    assert_eq(r.clear_flags.get("STAGE_2"), true, "UT-SAVE-N01: クリアフラグ")
    assert_eq(r.achievement_counters.get("total_turns"), 42, "UT-SAVE-N01: 実績カウンタ")

## UT-SAVE-N02: 新規SaveDataの初期値（拡張枠が空で用意されている）
func test_save_data_defaults() -> void:
    var d = SaveData.new()
    assert_eq(d.version, SaveData.CURRENT_VERSION, "UT-SAVE-N02: 既定バージョン")
    assert_eq(d.next_stage_id, "", "UT-SAVE-N02: 次ステージID初期値は空")
    assert_true(d.inventory.is_empty(), "UT-SAVE-N02: インベントリ空")
    assert_true(d.visited_event_ids.is_empty(), "UT-SAVE-N02: イベント履歴空")
    assert_true(d.progress_flags.is_empty(), "UT-SAVE-N02: 進行フラグ空")
    assert_true(d.clear_flags.is_empty(), "UT-SAVE-N02: クリアフラグ空")
    assert_true(d.achievement_counters.is_empty(), "UT-SAVE-N02: 実績枠空")

## UT-SAVE-N03: JSON経由（float化）でもアイテム値がintで復元される
func test_save_data_inventory_int_after_json() -> void:
    var d = _make_data()
    var parsed = JSON.parse_string(JSON.stringify(d.to_dict()))
    var r = SaveData.from_dict(parsed)
    assert_not_null(r, "UT-SAVE-N03: 復元成功")
    assert_eq(typeof(r.inventory[0].get("value")), TYPE_INT, "UT-SAVE-N03: valueはint型")
    assert_eq(r.inventory[0].get("value"), 1, "UT-SAVE-N03: value値")

## UT-SAVE-E01: 不正な辞書からの復元はnull
func test_save_data_invalid_dict() -> void:
    assert_null(SaveData.from_dict({}), "UT-SAVE-E01: 空辞書はnull")
    assert_null(SaveData.from_dict({"version": SaveData.CURRENT_VERSION}), "UT-SAVE-E01: next_stage_id欠落はnull")

## UT-SAVE-N04: スロット保存と読込
func test_save_and_load_slot() -> void:
    var ok = SaveManager.save_slot(2, _make_data(), TEST_DIR)
    assert_true(ok, "UT-SAVE-N04: 保存成功")
    assert_true(SaveManager.has_slot(2, TEST_DIR), "UT-SAVE-N04: スロット2が存在")
    assert_false(SaveManager.has_slot(1, TEST_DIR), "UT-SAVE-N04: 他スロットは未保存")
    var r = SaveManager.load_slot(2, TEST_DIR)
    assert_not_null(r, "UT-SAVE-N04: 読込成功")
    assert_eq(r.next_stage_id, "STAGE_3", "UT-SAVE-N04: 次ステージID一致")
    assert_eq(r.inventory.size(), 2, "UT-SAVE-N04: アイテム数一致")
    SaveManager.delete_slot(2, TEST_DIR)

## UT-SAVE-B01: スロット番号の境界（1と3は有効）
func test_slot_boundaries() -> void:
    assert_true(SaveManager.save_slot(1, _make_data(), TEST_DIR), "UT-SAVE-B01: スロット1")
    assert_true(SaveManager.save_slot(SaveManager.SLOT_COUNT, _make_data(), TEST_DIR), "UT-SAVE-B01: 最終スロット")
    assert_eq(SaveManager.SLOT_COUNT, 3, "UT-SAVE-B01: スロット数は3")
    SaveManager.delete_slot(1, TEST_DIR)
    SaveManager.delete_slot(SaveManager.SLOT_COUNT, TEST_DIR)

## UT-SAVE-B02: 範囲外スロット（0, 4, 負数）は拒否される
func test_invalid_slot_rejected() -> void:
    for s in [0, 4, -1]:
        assert_false(SaveManager.save_slot(s, _make_data(), TEST_DIR), "UT-SAVE-B02: 保存拒否 slot=%d" % s)
        assert_null(SaveManager.load_slot(s, TEST_DIR), "UT-SAVE-B02: 読込null slot=%d" % s)
        assert_false(SaveManager.has_slot(s, TEST_DIR), "UT-SAVE-B02: 存在しない slot=%d" % s)
    assert_false(SaveManager.save_slot(1, null, TEST_DIR), "UT-SAVE-B02: nullデータ保存は失敗")

## UT-SAVE-E02: 未保存スロットの読込はnull
func test_load_missing_slot() -> void:
    assert_null(SaveManager.load_slot(1, TEST_DIR), "UT-SAVE-E02: 未保存はnull")

## UT-SAVE-E03: 破損ファイルの読込はnull（クラッシュしない）
func test_load_corrupted_file() -> void:
    DirAccess.make_dir_recursive_absolute(TEST_DIR)
    var f = FileAccess.open(SaveManager.slot_path(1, TEST_DIR), FileAccess.WRITE)
    f.store_string("{ これはJSONではない")
    f.close()
    assert_null(SaveManager.load_slot(1, TEST_DIR), "UT-SAVE-E03: 破損JSONはnull")
    SaveManager.delete_slot(1, TEST_DIR)

## UT-SAVE-E04: 未来バージョンのデータは読込拒否
func test_load_version_mismatch() -> void:
    var d = _make_data()
    d.version = SaveData.CURRENT_VERSION + 1
    SaveManager.save_slot(1, d, TEST_DIR)
    assert_null(SaveManager.load_slot(1, TEST_DIR), "UT-SAVE-E04: 新しすぎるバージョンはnull")
    SaveManager.delete_slot(1, TEST_DIR)

## UT-SAVE-N05: スロット削除
func test_delete_slot() -> void:
    SaveManager.save_slot(3, _make_data(), TEST_DIR)
    assert_true(SaveManager.delete_slot(3, TEST_DIR), "UT-SAVE-N05: 削除成功")
    assert_false(SaveManager.has_slot(3, TEST_DIR), "UT-SAVE-N05: 削除後は存在しない")
    assert_false(SaveManager.delete_slot(3, TEST_DIR), "UT-SAVE-N05: 二重削除はfalse")

## UT-SAVE-N06: セーブ有無・最新スロット判定
func test_has_any_save_and_latest() -> void:
    assert_false(SaveManager.has_any_save(TEST_DIR), "UT-SAVE-N06: 初期はセーブなし")
    assert_eq(SaveManager.latest_slot(TEST_DIR), 0, "UT-SAVE-N06: セーブなしは0")
    var a = _make_data()
    a.saved_at = "2026-11-17 10:00:00"
    var b = _make_data()
    b.saved_at = "2026-11-17 12:00:00"
    SaveManager.save_slot(1, b, TEST_DIR)
    SaveManager.save_slot(2, a, TEST_DIR)
    assert_true(SaveManager.has_any_save(TEST_DIR), "UT-SAVE-N06: セーブあり")
    assert_eq(SaveManager.latest_slot(TEST_DIR), 1, "UT-SAVE-N06: 最新日時のスロット")
    _cleanup()

## UT-SAVE-N08: 「はじめから」用の初期セーブデータ（ステージ1開始状態）
func test_new_game_data() -> void:
    var d = SaveData.new_game("STAGE_1")
    assert_eq(d.next_stage_id, "STAGE_1", "UT-SAVE-N08: 開始ステージ")
    assert_eq(d.cleared_stage_name, "", "UT-SAVE-N08: クリア済みステージ名は空")
    assert_true(d.is_initial(), "UT-SAVE-N08: 開始前セーブと判定される")
    assert_eq(d.inventory.size(), 1, "UT-SAVE-N08: 初期所持品は1件")
    assert_eq(d.inventory[0].get("value"), 1, "UT-SAVE-N08: 初期所持品は1の賽")
    assert_false(d.saved_at.is_empty(), "UT-SAVE-N08: セーブ日時が入る")
    assert_true(d.visited_event_ids.is_empty() and d.clear_flags.is_empty(), "UT-SAVE-N08: 進行状態は空")
    var cleared = _make_data()
    assert_false(cleared.is_initial(), "UT-SAVE-N08: クリア後データは開始前ではない")
    var r = SaveData.from_dict(JSON.parse_string(JSON.stringify(d.to_dict())))
    assert_not_null(r, "UT-SAVE-N08: JSON経由で復元可能")
    assert_true(r.is_initial(), "UT-SAVE-N08: 復元後も開始前判定")

## UT-SAVE-D01: 使用済みスロットへの「はじめから」は初期セーブで上書きされ、空きスロットには新規作成される
func test_new_game_overwrites_slot() -> void:
    SaveManager.save_slot(2, _make_data(), TEST_DIR)
    assert_true(SaveManager.save_slot(2, SaveData.new_game("STAGE_1"), TEST_DIR), "UT-SAVE-D01: 上書き保存成功")
    var r = SaveManager.load_slot(2, TEST_DIR)
    assert_eq(r.next_stage_id, "STAGE_1", "UT-SAVE-D01: 上書き後は開始ステージ")
    assert_eq(r.inventory.size(), 1, "UT-SAVE-D01: 旧所持品は残らない")
    assert_false(SaveManager.has_slot(1, TEST_DIR), "UT-SAVE-D01: 他スロットは影響を受けない")
    assert_true(SaveManager.save_slot(1, SaveData.new_game("STAGE_1"), TEST_DIR), "UT-SAVE-D01: 空きスロットへ新規作成")
    assert_true(SaveManager.has_slot(1, TEST_DIR), "UT-SAVE-D01: 新規作成後は存在")
    _cleanup()
## UT-SAVE-N07: スロット一覧サマリ（空スロットはnull）
func test_summaries() -> void:
    SaveManager.save_slot(2, _make_data(), TEST_DIR)
    var s = SaveManager.list_slots(TEST_DIR)
    assert_eq(s.size(), 3, "UT-SAVE-N07: 常に3件")
    assert_null(s[0], "UT-SAVE-N07: スロット1は空")
    assert_not_null(s[1], "UT-SAVE-N07: スロット2はデータあり")
    assert_eq(s[1].next_stage_id, "STAGE_3", "UT-SAVE-N07: 内容一致")
    assert_null(s[2], "UT-SAVE-N07: スロット3は空")
    _cleanup()
