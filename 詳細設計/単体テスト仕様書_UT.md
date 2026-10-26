# 詳細設計書：単体テスト仕様書 (UT Specification)

本書は、「すごろく×魔女の館脱出ゲーム」のコアロジックに対する単体テスト（Unit Test）仕様書である。
仕様書ベース・テスト生成スキル（`spec-to-test`）の体系に準拠し、**正常系・準正常系（エラー/バリデーション）・境界値・デシジョンテーブル**の4大観点により全テストケースを網羅的に定義する。

---

## 1. 単体テストスイート構成一覧

| テストスイート名 | 対象クラス | 検証概要 | テストファイル配置先 |
| :--- | :--- | :--- | :--- |
| **UT-BOARD** | `GridBoard` | マス登録、隣接接続、最短経路探索(BFS)、出目折り返し到達判定、障害物回避到達判定、直線走査、視界 | `実装コード/tests/test_grid_board.gd` |
| **UT-STEP** | `TurnManager` | 1歩ごとの接触判定（即死・少女殺害・潜行やり過ごし）、水トラップ即停止、特殊マス停止解決 | `実装コード/tests/test_step_movement.gd` |
| **UT-ENEMY** | `TurnManager` | 魔女追跡ターゲット選定優先順位、全員潜行時の初期位置移動、魔女水トラップ即停止、スタン処理 | `実装コード/tests/test_enemy_ai.gd` |
| **UT-MAGIC** | `TurnManager` | 4属性魔法（炎撃破、水トラップ生成、風吹っ飛ばし、土潜行・スタン）、詠唱制約、祈る潜行維持 | `実装コード/tests/test_magic_system.gd` |
| **UT-TURN** | `TurnManager` | ターン進行ライフサイクル、少女死亡後3ターン復活、エネミー復活、行動選択制約 | `実装コード/tests/test_turn_lifecycle.gd` |
| **UT-ITEM** | `ItemData` / Inventory | 固定出目ダイス（1〜6の賽）モデル整合性、インベントリ追加・消費・スタック処理 | `実装コード/tests/test_inventory_items.gd` |

---

## 2. 単体テスト観点マトリクス・詳細仕様

### 2.1 UT-BOARD：盤面および経路探索テスト (`test_grid_board.gd`)

| 区分 | テスト項目ID | テスト関数名 | 入力・事前条件 | 期待される判定・処理結果 |
| :--- | :--- | :--- | :--- | :--- |
| **正常系** | **UT-BOARD-N01** | `test_find_shortest_path_simple_line` | 3マスの直線盤面（`(0,0)-(1,0)-(2,0)`）、始点 `(0,0)`、終点 `(2,0)` | 経路配列 `[(0,0), (1,0), (2,0)]`（ステップ数2）が返却されること |
| **正常系** | **UT-BOARD-N02** | `test_reachable_cells_with_steps_allowing_turnaround` | 3マスの直線盤面、始点 `(0,0)`、出目 2 | `(2,0)`（直進）および `(0,0)`（折り返し）が到達可能マスに含まれること |
| **正常系** | **UT-BOARD-N03** | `test_find_farthest_linear_cell` | 5マスの直線盤面（`(0,0)`〜`(4,0)`）、走査方向 `Vector2i(1,0)` | 端のマス `(4,0)` が最遠マスとして正しく返却されること |
| **正常系** | **UT-BOARD-N04** | `test_line_of_sight_clear` | 4マスの直線盤面、始点 `(0,0)`、終点 `(3,0)` | 間に壁がなければ `has_clear_line_of_sight` が `true` を返すこと |
| **正常系** | **UT-BOARD-N05** | `test_reachable_cells_and_path_to_exit_with_excess_steps` | 距離2マスの位置にEXITマス、出目5（余り3）で振った場合 | 到達可能マスにEXITが含まれ、最短歩数で停止する有効経路が算出されること |
| **準正常系** | **UT-BOARD-E01** | `test_find_shortest_path_unreachable` | `(0,0)` と `(1,0)` の間に接続が存在しない未接続盤面 | 到達不能として空配列 `[]` が安全に返却されること |

| **準正常系** | **UT-BOARD-E02** | `test_find_path_goal_is_obstacle` | 目的地 `(2,0)` に障害物（未潜行魔女）が存在 | 目的地自体が進入禁止のため空配列 `[]` が返却されること |
| **準正常系** | **UT-BOARD-E03** | `test_validate_path_disconnected` | 途中のマス接続が途切れている座標配列 | `validate_path` の戻り値が `false` であること |
| **境界値** | **UT-BOARD-B01** | `test_reachable_cells_min_step_one` | 3マスの直線盤面、始点 `(1,0)`、出目 1 | 隣接マス `(0,0)` と `(2,0)` のみ到達可能（現在地への折り返し不可） |
| **境界値** | **UT-BOARD-B02** | `test_reachable_cells_odd_vs_even_turnaround` | 直線盤面、出目 1（奇数） vs 出目 2（偶数） | 奇数出目では現在地停止不可、偶数出目でのみ現在地停止可能であること |
| **境界値** | **UT-BOARD-B03** | `test_reachable_cells_blocked_by_obstacles` | 唯一の通路に障害物（未潜行魔女）が配置されている | 障害物マスおよびその先のマスが除外され、到達可能マス集合が0件となること |
| **デシジョン** | **UT-BOARD-D01** | `test_find_path_detours_obstacles` | メインストリートと迂回路がある盤面（下記テーブル参照） | 障害物マスを回避し、迂回路を経由する安全な経路が算出されること |

#### 【デシジョンテーブル：UT-BOARD-D01 迂回経路探索】
| 条件項目 | ケース1（直進安全） | ケース2（迂回路回避） | ケース3（完全閉塞） |
| :--- | :---: | :---: | :---: |
| 最短経路上に障害物 | なし | **あり** | **あり** |
| 代替の迂回路が存在 | - | **あり** | なし（袋小路） |
| **期待される経路** | 最短経路（直線） | **迂回路を経由する安全な経路** | 空配列 `[]`（到達不可） |

---

### 2.2 UT-STEP：1歩判定・接触・トラップ・特殊マス (`test_step_movement.gd`)

| 区分 | テスト項目ID | テスト関数名 | 入力・事前条件 | 期待される判定・処理結果 |
| :--- | :--- | :--- | :--- | :--- |
| **正常系** | **UT-STEP-N01** | `test_step_continue_on_normal_cell` | 残り歩数 2、通常マス `(1,0)` に進入 | 戻り値 `"CONTINUE"`、ユニットの現在地が `(1,0)` に更新されること |
| **正常系** | **UT-STEP-N02** | `test_step_arrived_on_normal_cell` | 残り歩数 0、通常マス `(2,0)` に進入 | 戻り値 `"ARRIVED"`、ユニットの `has_acted = true` となること |
| **正常系** | **UT-STEP-N03** | `test_water_trap_stops_movement_immediately` | 残り歩数 2、`WATER_TRAP` マス `(1,0)` に進入 | 戻り値 `"WATER_TRAP_STOP"`、残歩数破棄、即座に `has_acted = true` |
| **正常系** | **UT-STEP-N04** | `test_special_stop_cells_resolution` | `ADDITIONAL_MOVE` / `ROLL_AGAIN` / `RETURN_TO_START` / `SKIP_TURN` 停止 | 追加移動権付与、再ロール権付与、初期位置送還、`is_skipped = true` が反映 |
| **正常系** | **UT-STEP-N05** | `test_event_and_exit_cells_resolution` | `EVENT`（宝箱）および `EXIT` マス停止 | `is_consumed = true`・イベント発火、`STAGE_CLEAR` 遷移 |
| **準正常系** | **UT-STEP-E01** | `test_step_unit_null_guard` | `unit = null` で `step_unit` を呼び出す | 例外落ちせず `"ERROR"` が安全に返却されること |
| **準正常系** | **UT-STEP-E02** | `test_step_board_null_guard` | `board = null` で `step_unit` を呼び出す | 例外落ちせず `"ERROR"` が安全に返却されること |
| **準正常系** | **UT-STEP-E03** | `test_consumed_event_cell_not_retriggered` | 既に `is_consumed == true` の `EVENT` マスに停止 | `cell_event_triggered` シグナルが二重発火しないこと |
| **境界値** | **UT-STEP-B01** | `test_step_first_step_overlap_with_witch` | 出目 3 の 1歩目で魔女マスに侵入 | 残歩数が残っていても即座に接触判定（`GAME_OVER`）が発動すること |
| **境界値** | **UT-STEP-B02** | `test_step_final_step_on_water_trap` | 残り歩数 0（最終歩）で水トラップに進入 | 通常到着ではなく水トラップ停止（`WATER_TRAP_STOP`）として処理されること |
| **デシジョン** | **UT-STEP-D01** | `test_realtime_enemy_contact_decision` | ユニット種別 × 潜行状態 × 接触対象（下記テーブル参照） | 即時ゲームオーバー／少女殺害／やり過ごし成功の分岐 |

#### 【デシジョンテーブル：UT-STEP-D01 リアルタイム接触判定】
| 操作ユニット | 潜行状態 (`is_burrowed`) | 進入マスの状態 | 戻り値ステータス | フェーズ / 状態変化 |
| :--- | :---: | :--- | :--- | :--- |
| 主人公 (`HERO`) | `false` (地上) | 生存中の魔女 | **`"GAME_OVER"`** | `current_phase = GAME_OVER`, 即死 |
| 主人公 (`HERO`) | `true` (地中) | 生存中の魔女 | **`"CONTINUE"`** | やり過ごし成功シグナル発火, 生存維持 |
| 少女 (`GIRL_*`) | `false` (地上) | 生存中の魔女 | **`"GIRL_DIED"`** | `is_alive = false`, `revive_turns = 3` |
| 少女 (`GIRL_*`) | `true` (地中) | 生存中の魔女 | **`"CONTINUE"`** | やり過ごし成功シグナル発火, 生存維持 |
| 任意ユニット | 任意 | 撃破済み魔女 | 通常進行 (`"CONTINUE"` / `"ARRIVED"`) | 接触判定スキップ（通過可能） |

---

### 2.3 UT-ENEMY：魔女ターゲット選定・追跡・トラップ停止 (`test_enemy_ai.gd`)

| 区分 | テスト項目ID | テスト関数名 | 入力・事前条件 | 期待される判定・処理結果 |
| :--- | :--- | :--- | :--- | :--- |
| **正常系** | **UT-ENEMY-N01** | `test_witch_targets_nearest_unburrowed_unit` | 距離5の主人公、距離2の炎の少女（未潜行） | 最短距離の炎の少女 (`GIRL_FIRE`) が選定されること |
| **正常系** | **UT-ENEMY-N02** | `test_witch_targets_hero_on_equal_distance` | 距離2の主人公、距離2の炎の少女（同距離） | タイブレーク優先順位に従い主人公 (`HERO`) が選定されること |
| **正常系** | **UT-ENEMY-N03** | `test_witch_returns_to_initial_when_all_burrowed` | 生存味方全員が地中潜行中（`is_burrowed == true`） | ターゲットが `null` となり、初期配置マスへ向かうこと |
| **正常系** | **UT-ENEMY-N04** | `test_witch_stops_immediately_on_water_trap` | 魔女の移動経路上に `WATER_TRAP` マスが存在 | 魔女も水マス進入の瞬間に即時停止し、残歩数が破棄されること |
| **正常系** | **UT-ENEMY-N05** | `test_witch_stun_skips_turn` | 魔女の `stun_turns == 1` | 移動せず待機し、`stun_turns` が 0 に減少すること |
| **準正常系** | **UT-ENEMY-E01** | `test_witch_target_no_survivors` | 全味方ユニットが死亡中 | 例外をスローせず安全に `null` が返却されること |
| **境界値** | **UT-ENEMY-B01** | `test_witch_target_zero_distance` | 魔女と味方が同一座標に配置 | 距離 0 として正しく最短ターゲットに選定されること |
| **境界値** | **UT-ENEMY-B02** | `test_witch_stun_counter_decrement` | `stun_turns = 1` の魔女がターン経過 | 1から0へ遷移し、次ターンから移動可能へ復帰すること |
| **デシジョン** | **UT-ENEMY-D01** | `test_witch_target_selection_decision_table` | 生存・潜行・距離・属性優先度（下記テーブル参照） | 厳格なルールに基づく追跡ターゲット選定 |

#### 【デシジョンテーブル：UT-ENEMY-D01 ターゲット選定優先順位】
| 候補ユニット | 生存状態 | 潜行状態 | 魔女からの距離 | 属性優先度 | 判定結果 |
| :--- | :---: | :---: | :---: | :---: | :--- |
| 炎の少女 | 生存 | 未潜行 | **2マス** | 2位 | **選定（最短距離優先）** |
| 主人公 | 生存 | 未潜行 | 3マス | 1位 | 次点（距離が遠いため） |
| 風の少女 | **死亡** | 未潜行 | 1マス | 3位 | **除外（死亡中）** |
| 水の少女 | 生存 | **潜行中** | 1マス | 4位 | **除外（感知不能）** |
| 主人公 | 生存 | 未潜行 | **2マス** | **1位** | **選定（同距離タイブレーク）** |
| 炎の少女 | 生存 | 未潜行 | **2マス** | 2位 | 次点 |
| 全味方 | 生存 | **全員潜行中** | - | - | **`null`（初期位置へ帰還）** |

---

### 2.4 UT-MAGIC：4属性魔法効果・制約・潜行継続 (`test_magic_system.gd`)

| 区分 | テスト項目ID | テスト関数名 | 入力・事前条件 | 期待される判定・処理結果 |
| :--- | :--- | :--- | :--- | :--- |
| **正常系** | **UT-MAGIC-N01** | `test_fire_magic_defeats_witch` | 2マス以内の魔女を対象に炎魔法詠唱 | 魔女撃破（`is_alive = false`）、復活カウンタ 2、詠唱者行動済み |
| **正常系** | **UT-MAGIC-N02** | `test_water_magic_creates_trap` | 盤面マスを対象に水魔法詠唱 | 対象マスが `WATER_TRAP` に変更、詠唱者行動済み |
| **正常系** | **UT-MAGIC-N03** | `test_burrowed_unit_wait_maintains_burrow` | 潜行中ユニットで「待機・祈る」実行 | `is_burrowed = true` を維持したまま行動済みとなること |
| **正常系** | **UT-MAGIC-N04** | `test_unburrow_on_action` | 潜行中ユニットで魔法詠唱または移動 | 詠唱・移動と同時に地中から出現し `is_burrowed = false` |
| **準正常系** | **UT-MAGIC-E01** | `test_magic_fails_when_dead` | 死亡中ユニット（`is_alive == false`）で詠唱 | 詠唱拒否（戻り値 `false`） |
| **準正常系** | **UT-MAGIC-E02** | `test_magic_fails_when_already_acted` | 既に行動済みユニット（`has_acted == true`）で詠唱 | 詠唱拒否（戻り値 `false`） |
| **準正常系** | **UT-MAGIC-E03** | `test_magic_fails_caster_not_found` | 未登録のキャラクターIDで詠唱 | 詠唱拒否（戻り値 `false`） |
| **準正常系** | **UT-MAGIC-E04** | `test_fire_magic_fails_no_target` | 対象座標に魔女が存在しない | 詠唱失敗（戻り値 `false`） |
| **境界値** | **UT-MAGIC-B01** | `test_fire_magic_range_boundary` | 距離 2（境界内） vs 距離 3（境界外） | 距離2は成功、距離3は失敗すること |
| **デシジョン** | **UT-MAGIC-D01** | `test_earth_magic_burrow_and_stun` | 対象座標の内容（空きマス vs 魔女、下記テーブル参照） | 自身の地中潜行 または 魔女スタンが排他発動 |

#### 【デシジョンテーブル：UT-MAGIC-D01 土魔法の効果分岐】
| 対象座標の内容 | 詠唱者の潜行状態 (`is_burrowed`) | 魔女のスタンターン (`stun_turns`) | 備考 |
| :--- | :---: | :---: | :--- |
| 魔女が存在する座標 | 変化なし (`false`) | **`stun_turns = 1`** | 魔女の足止め（次ターン移動スキップ） |
| 空きマス（または味方座標） | **`is_burrowed = true`** | 変化なし | 地中潜行（魔女やり過ごしモード） |

---

### 2.5 UT-TURN：ターン進行・復活・行動選択制約 (`test_turn_lifecycle.gd`)

| 区分 | テスト項目ID | テスト関数名 | 入力・事前条件 | 期待される判定・処理結果 |
| :--- | :--- | :--- | :--- | :--- |
| **正常系** | **UT-TURN-N01** | `test_turn_advance_and_reselection` | ターン終了（`end_turn_and_advance`）実行 | `current_turn` が +1 され、全生存ユニットの `has_acted = false` リセット |
| **正常系** | **UT-TURN-N02** | `test_girl_revives_after_three_turns` | 少女死亡（`revive_turn_count = 3`）から3ターン経過 | 1T後:2, 2T後:1, 3T後:0（`is_alive = true`、初期座標復活） |
| **正常系** | **UT-TURN-N03** | `test_witch_revives_after_two_turns` | 魔女撃破（`revive_turn_count = 2`）から2ターン経過 | 1T後:1, 2T後:0（`is_alive = true`、初期座標復活） |
| **準正常系** | **UT-TURN-E01** | `test_select_character_fails_when_dead` | 死亡中ユニットを選択 | 選択拒否（戻り値 `false`） |
| **準正常系** | **UT-TURN-E02** | `test_select_character_fails_when_acted` | 行動済みユニットを選択 | 選択拒否（戻り値 `false`） |
| **準正常系** | **UT-TURN-E03** | `test_select_character_fails_when_skipped` | 1回休み（`is_skipped == true`）のユニットを選択 | 選択拒否（戻り値 `false`） |
| **準正常系** | **UT-TURN-E04** | `test_select_character_fails_not_found` | 未登録キャラクターIDを選択 | 選択拒否（戻り値 `false`） |
| **境界値** | **UT-TURN-B01** | `test_revive_exact_turn_boundary` | 復活カウント 1（前ターン） vs 0（完了時） | カウント1では依然死亡、0になった瞬間に完全復活 |

---

### 2.6 UT-ITEM：アイテムデータ・インベントリ操作 (`test_inventory_items.gd`)

| 区分 | テスト項目ID | テスト関数名 | 入力・事前条件 | 期待される判定・処理結果 |
| :--- | :--- | :--- | :--- | :--- |
| **正常系** | **UT-ITEM-N01** | `test_fixed_dice_items_model` | 「1の賽」〜「6の賽」の辞書データ定義 | それぞれ値 1〜6 を保持し、種別が `FIXED_DICE` であること |
| **正常系** | **UT-ITEM-N02** | `test_inventory_add_and_consume` | インベントリへの追加、および `pop_at` による消費 | 指定インデックスのアイテムが取り出され、インベントリ残数が正しく減少 |
| **境界値** | **UT-ITEM-B01** | `test_dice_value_boundaries` | 最小出目（1の賽: `value=1`）および最大出目（6の賽: `value=6`） | 境界値が正しく設定・保持されること |
| **境界値** | **UT-ITEM-B02** | `test_inventory_empty_to_populated` | 所持数 0 個 → 1 個追加 → 消費で 0 個 | インベントリ要素数の整合性が担保されること |

---

### 2.7 UT-SCENE：画面遷移管理・パラメータ保持 (`test_scene_manager.gd`)

| 区分 | テスト項目ID | テスト関数名 | 入力・事前条件 | 期待される判定・処理結果 |
| :--- | :--- | :--- | :--- | :--- |
| **正常系** | **UT-SCENE-N01** | `test_change_scene_registers_target` | 遷移先パスとパラメータを指定して `change_scene` 呼び出し | ターゲットパスおよび渡したパラメータが `SceneManager` に正しく保持されること |
| **正常系** | **UT-SCENE-N02** | `test_scene_param_get_and_set` | `set_param("stage_id", "STAGE_1")` 実行 | `get_param("stage_id")` で `"STAGE_1"` が取得できること |
| **正常系** | **UT-SCENE-N03** | `test_convenience_methods` | `change_to_title()`, `change_to_main_game()` 呼び出し | 定義された定数パス（`SCENE_TITLE`, `SCENE_MAIN_GAME`）が正しくターゲットに設定されること |
| **準正常系** | **UT-SCENE-E01** | `test_prevent_double_transition` | 遷移中フラグ `is_transitioning = true` の状態で再度 `change_scene` 呼び出し | 重複実行が無視（スキップ）され、最初の遷移先が保持されること |
| **準正常系** | **UT-SCENE-E02** | `test_invalid_param_key` | 未設定のパラメータキーを `get_param("unknown", "default_val")` で取得 | 指定したデフォルト値 `"default_val"` が安全に返却されること |
| **境界値** | **UT-SCENE-B01** | `test_empty_params_dictionary` | パラメータに空の辞書 `{}` を渡して遷移 | エラーなく受け付けられ、パラメータがクリア/空辞書となること |

---

### 2.8 UT-STAGE：ステージデータおよび階層遷移定義 (`test_stage_system.gd`)

| 区分 | テスト項目ID | テスト関数名 | 入力・事前条件 | 期待される判定・処理結果 |
| :--- | :--- | :--- | :--- | :--- |
| **正常系** | **UT-STAGE-N01** | `test_get_stage_data_returns_valid_stage` | `StageRepository.get_stage("STAGE_1")` 実行 | 有効な `StageData` が返却され、盤面モデル・主人公座標・魔女が設定されていること |
| **正常系** | **UT-STAGE-N02** | `test_stage_transition_chain` | Stage 1 から `next_stage_id` を走査 | STAGE_1〜6 まで順序正しくチェーンし、最終ステージ（STAGE_6）の `next_stage_id` は空文字であること |
| **正常系** | **UT-STAGE-N03** | `test_companion_elements_per_stage` | 各ステージの同行者設定を走査 | Stage 1 は同行者0人、Stage 2は炎、Stage 3は水、Stage 4は風、Stage 5は土の少女が設定されていること |
| **準正常系** | **UT-STAGE-E01** | `test_get_invalid_stage_returns_null` | 未知のステージID（例：`"STAGE_999"`）を指定 | 例外クラッシュせず安全に `null` が返却されること |
| **境界値** | **UT-STAGE-B01** | `test_all_stage_ids_registered` | `StageRepository.get_all_stage_ids()` 呼び出し | 登録数が 6 件（STAGE_1 〜 STAGE_6）過不足なく返却されること |


