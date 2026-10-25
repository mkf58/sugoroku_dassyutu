# 詳細設計書：単体テスト仕様書 (UT Specification)

本書は、「すごろく×魔女の館脱出ゲーム」のコアロジックに対する単体テスト（Unit Test）仕様書である。Godot Engine 4 のテストフレームワーク「GUT (Godot Unit Test)」または標準アサーションを用いた自動テストコード（`test_*.gd`）にそのまま落とし込める形式で記述する。

---

## 1. 単体テストスイート構成一覧

| テストスイート名 | 対象クラス | 検証内容 | テストファイル配置先 |
| :--- | :--- | :--- | :--- |
| **UT-BOARD** | `GridBoard` | マス登録、隣接接続、最短経路探索(BFS)、出目折り返し到達判定、障害物回避到達判定、最遠走査 | `実装コード/tests/test_grid_board.gd` |
| **UT-STEP** | `TurnManager` | 1歩ごとの接触判定（即死・少女殺害・潜行やり過ごし）、水トラップ即停止、特殊マス停止解決 | `実装コード/tests/test_step_movement.gd` |
| **UT-ENEMY** | `TurnManager` | 魔女追跡ターゲット選定優先順位、全員潜行時の初期位置移動、魔女水トラップ即停止、スタン処理 | `実装コード/tests/test_enemy_ai.gd` |
| **UT-MAGIC** | `TurnManager` | 4属性魔法（炎撃破、水トラップ生成、風吹っ飛ばし、土潜行・スタン）、詠唱制約 | `実装コード/tests/test_magic_system.gd` |
| **UT-TURN** | `TurnManager` | 少女死亡後の3ターン復活処理、エネミー復活、全味方行動完了遷移 | `実装コード/tests/test_turn_lifecycle.gd` |
| **UT-ITEM** | `ItemData` / Inventory | 固定出目ダイス（1〜6の賽）モデル整合性、インベントリ追加・消費・スタック処理 | `実装コード/tests/test_inventory_items.gd` |

---

## 2. テストケース詳細仕様

### 2.1 UT-BOARD: 盤面および経路探索テスト (`test_grid_board.gd`)

#### 【UT-BOARD-01】最短経路探索（BFS）の検証
- **テスト関数名：** `test_find_shortest_path_simple_line()`
- **前提条件 (Given)：**
  - 3マスの直線盤面（`(0,0) - (1,0) - (2,0)`）を構築し、相互に接続する。
- **実行操作 (When)：**
  - `find_shortest_path(Vector2i(0,0), Vector2i(2,0))` を呼び出す。
- **期待結果 (Then)：**
  - 返却される経路配列が `[Vector2i(0,0), Vector2i(1,0), Vector2i(2,0)]` と完全一致すること。
  - ステップ数が 2 であること。

#### 【UT-BOARD-02】壁・未接続による到達不能の検証
- **テスト関数名：** `test_find_shortest_path_unreachable()`
- **前提条件 (Given)：**
  - `(0,0)` と `(1,0)` の間に接続が存在しない盤面。
- **実行操作 (When)：**
  - `find_shortest_path(Vector2i(0,0), Vector2i(1,0))` を呼び出す。
- **期待結果 (Then)：**
  - 空の配列 `[]` が返却されること。

#### 【UT-BOARD-03】出目消費時の折り返し移動（行きつ戻りつ）可能判定
- **テスト関数名：** `test_reachable_cells_with_steps_allowing_turnaround()`
- **前提条件 (Given)：**
  - 3マスの直線盤面（`(0,0) - (1,0) - (2,0)`）で、現在地が `(0,0)`。
- **実行操作 (When)：**
  - 出目 2 での到達可能マス集合 `get_reachable_cells_with_steps(Vector2i(0,0), 2)` を取得する。
- **期待結果 (Then)：**
  - `(2,0)`（右に2マス進む）だけでなく、`(0,0)`（右に1進んで左に1戻る折り返し）も到達可能マスとして含まれること。
  - `(1,0)` は出目2では停止不可（奇数歩のため）であること。

#### 【UT-BOARD-04】指定歩数での折り返し経路生成の検証
- **テスト関数名：** `test_find_path_with_steps_turnaround()`
- **前提条件 (Given)：**
  - 3マスの直線盤面（`(0,0) - (1,0) - (2,0)`）で、現在地が `(0,0)`。
- **実行操作 (When)：**
  - 出目 2 で `(0,0)` へ戻る経路 `find_path_with_steps(Vector2i(0,0), Vector2i(0,0), 2)` を生成する。
- **期待結果 (Then)：**
  - 返却される経路配列が `[Vector2i(0,0), Vector2i(1,0), Vector2i(0,0)]` と完全一致すること。
  - 正確に 2 歩（配列長 3）で元のマスへ折り返して停止すること。

#### 【UT-BOARD-05】障害物（未潜行魔女）マスを考慮した到達可能マス除外の検証
- **テスト関数名：** `test_reachable_cells_excludes_obstacles()`
- **前提条件 (Given)：**
  - 4マスの直線盤面（`(0,0) - (1,0) - (2,0) - (3,0)`）。
  - `(1,0)` に障害物（未潜行魔女）が存在。
- **実行操作 (When)：**
  - `(0,0)` から出目 2 で、障害物 `[(1,0)]` を指定して `get_reachable_cells_with_steps` を実行。
- **期待結果 (Then)：**
  - 障害物マス `(1,0)` およびその先のマスは到達可能マスに含まれず、到達可能マス集合が空（または障害物を通過しないマスのみ）となること。

#### 【UT-BOARD-06】障害物マスを回避する迂回経路探索の検証
- **テスト関数名：** `test_find_path_detours_obstacles()`
- **前提条件 (Given)：**
  - ループ構造の盤面（メインストリートと迂回路）。
  - メインストリート上に障害物が配置されている。
- **実行操作 (When)：**
  - 障害物を指定して目的地への経路探索を実行。
- **期待結果 (Then)：**
  - 障害物マスを一切通らず、迂回路を経由する安全な経路が返却されること。

#### 【UT-BOARD-07】直線走査による最遠マス特定の検証
- **テスト関数名：** `test_find_farthest_linear_cell()`
- **前提条件 (Given)：**
  - 5マスの直線盤面（`(0,0)` 〜 `(4,0)`）。
- **実行操作 (When)：**
  - `(1,0)` から右方向 `Vector2i(1,0)` への走査を実行。
- **期待結果 (Then)：**
  - 端のマス `(4,0)` が最遠マスとして正しく返却されること。

---

## 2.2 UT-STEP: 1歩ごとの接触・トラップ・特殊マス判定テスト (`test_step_movement.gd`)

#### 【UT-STEP-01】主人公が未潜行で魔女のマスへ侵入した際の即時ゲームオーバー判定
- **テスト関数名：** `test_hero_step_overlap_with_witch_causes_game_over()`
- **前提条件 (Given)：**
  - 主人公 `HERO` が `(0,0)`、魔女 `WITCH` が `(1,0)` に配置。未潜行。
- **実行操作 (When)：**
  - 1歩目（`(0,0) -> (1,0)`）を `step_unit` で実行。
- **期待結果 (Then)：**
  - 戻り値ステータスが `"GAME_OVER"` であること。
  - `TurnManager.current_phase` が `GAME_OVER` に遷移すること。

#### 【UT-STEP-02】土魔法で潜行中のユニットが魔女のマスを通過した際のやり過ごし検証
- **テスト関数名：** `test_burrowed_hero_can_pass_witch_safely()`
- **前提条件 (Given)：**
  - 主人公 `HERO` が `(0,0)` で地中潜行中（`is_burrowed == true`）。魔女が `(1,0)`。
- **実行操作 (When)：**
  - 1歩目（`(1,0)`）へ侵入。
- **期待結果 (Then)：**
  - ゲームオーバーは発生せず、ステータス `"CONTINUE"` が返却されること。

#### 【UT-STEP-03】水魔術トラップマス侵入時の残歩数破棄・即時ターン終了検証
- **テスト関数名：** `test_water_trap_stops_movement_immediately()`
- **前提条件 (Given)：**
  - `(1,0)` が `WATER_TRAP` マス。出目 3 で移動開始。
- **実行操作 (When)：**
  - 1歩目（`(1,0)`）を踏む。
- **期待結果 (Then)：**
  - ステータス `"WATER_TRAP_STOP"` が返却されること。
  - 残歩数 2 が強制破棄され、ユニットの現在地が `(1,0)` で確定し、`has_acted` が `true` になること。

#### 【UT-STEP-04】少女が魔女と同マス接触した際の殺害と復活カウンタ設定
- **テスト関数名：** `test_girl_step_overlap_with_witch_kills_girl()`
- **前提条件 (Given)：**
  - 炎の少女 `GIRL_FIRE` が `(0,0)`、魔女が `(1,0)` に配置。
- **実行操作 (When)：**
  - 1歩目（`(1,0)`）へ侵入。
- **期待結果 (Then)：**
  - 戻り値が `"GIRL_DIED"` であること。
  - 少女の `is_alive` が `false`、`revive_turn_count` が 3 に設定されること。

#### 【UT-STEP-05】特殊停止マス（ADDITIONAL_MOVE / ROLL_AGAIN / RETURN_TO_START / SKIP_TURN）の効果検証
- **テスト関数名：** `test_special_stop_cells_resolution()`
- **前提条件 (Given)：**
  - 各特殊マスが配置された盤面。
- **実行操作 (When)：**
  - 各マスに対して `resolve_stop_cell` を実行。
- **期待結果 (Then)：**
  - `ADDITIONAL_MOVE`：追加歩数シグナル発火、`has_acted = false`。
  - `ROLL_AGAIN`：再ロールシグナル発火、`has_acted = false`。
  - `RETURN_TO_START`：`current_coord = initial_coord` に送還。
  - `SKIP_TURN`：`is_skipped = true` に設定。

#### 【UT-STEP-06】EVENTマスおよびEXITマス停止の検証
- **テスト関数名：** `test_event_and_exit_cells_resolution()`
- **前提条件 (Given)：**
  - 宝箱マス（`EVENT`）およびゴールマス（`EXIT`）。
- **実行操作 (When)：**
  - `resolve_stop_cell` を実行。
- **期待結果 (Then)：**
  - `EVENT`：`is_consumed = true` に更新され、`cell_event_triggered` シグナル発火。
  - `EXIT`：`stage_cleared` シグナル発火、フェーズが `STAGE_CLEAR` に遷移。

---

## 2.3 UT-ENEMY: 魔女ターゲット選定・追跡・トラップ停止テスト (`test_enemy_ai.gd`)

#### 【UT-ENEMY-01】最短距離の未潜行ユニット優先選定
- **テスト関数名：** `test_witch_targets_nearest_unburrowed_unit()`
- **期待結果：** より距離の近い未潜行ユニットが選定されること。

#### 【UT-ENEMY-02】同距離時のタイブレーク優先順位（主人公最優先）
- **テスト関数名：** `test_witch_targets_hero_on_equal_distance()`
- **期待結果：** 同距離時は優先順位マップ（`主人公 > 炎 > 風 > 水 > 土`）に従い主人公が選定されること。

#### 【UT-ENEMY-03】潜行中ユニットのターゲット除外と全員潜行時の初期位置移動
- **テスト関数名：** `test_witch_returns_to_initial_when_all_burrowed()`
- **期待結果：** 全員潜行時はターゲットが `null` となり、初期位置へ向かうこと。

#### 【UT-ENEMY-04】魔女のエネミーターン移動中の水トラップ即時停止
- **テスト関数名：** `test_witch_stops_immediately_on_water_trap()`
- **前提条件 (Given)：**
  - 魔女が追跡移動中に水トラップマス（`WATER_TRAP`）に進入。
- **実行操作 (When)：**
  - 魔女のステップ移動を実行。
- **期待結果 (Then)：**
  - 魔女も水マスを踏んだ瞬間に即座に停止し、残歩数が破棄されて行動終了となること。

#### 【UT-ENEMY-05】スタン状態の魔女の行動スキップ
- **テスト関数名：** `test_witch_stun_skips_turn()`
- **前提条件 (Given)：**
  - 魔女の `stun_turns == 1`。
- **実行操作 (When)：**
  - エネミーターン移動を実行。
- **期待結果 (Then)：**
  - 移動が実行されず現在地にとどまり、`stun_turns` が 0 に減少すること。

---

## 2.4 UT-MAGIC: 4属性魔法効果・制約テスト (`test_magic_system.gd`)

#### 【UT-MAGIC-01】炎魔法による魔女撃破と2ターン復活カウンタ設定
- **テスト関数名：** `test_fire_magic_defeats_witch()`
- **期待結果：** 魔女撃破、`revive_turn_count = 2`、詠唱者行動済み。

#### 【UT-MAGIC-02】水魔法によるトラップ生成
- **テスト関数名：** `test_water_magic_creates_trap()`
- **期待結果：** 対象マスが `WATER_TRAP` に変化すること。

#### 【UT-MAGIC-03】土魔法による地中潜行および魔女スタン
- **テスト関数名：** `test_earth_magic_burrow_and_stun()`
- **期待結果：**
  - 空きマス対象時：詠唱者が `is_burrowed = true`。
  - 魔女対象時：魔女が `stun_turns = 1`。

#### 【UT-MAGIC-04】魔法詠唱の制約チェック（死亡時・行動済み時の拒否）
- **テスト関数名：** `test_magic_execution_constraints()`
- **期待結果：** 死亡中や既に行動済みのユニットは魔法詠唱に失敗（`false` 返却）すること。

#### 【UT-MAGIC-05】土潜行中の「待機・祈る」による潜行維持
- **テスト関数名：** `test_burrowed_unit_wait_maintains_burrow()`
- **期待結果：** `execute_wait` 実行後も `is_burrowed = true` が維持されること。

---

## 2.5 UT-TURN: ターンライフサイクルと復活テスト (`test_turn_lifecycle.gd`)

#### 【UT-TURN-01】少女死亡後の3ターン経過による初期位置復活
- **テスト関数名：** `test_girl_revives_after_three_turns()`
- **期待結果：** 3ターン経過後に `is_alive = true`、初期座標で完全復活。

#### 【UT-TURN-02】ターン進行後の味方行動リセットと再選択・行動フェーズ遷移の検証
- **テスト関数名：** `test_turn_advance_and_reselection()`
- **期待結果：** ターン加算、`has_acted = false` リセット、ユニット選択フェーズ遷移。

---

## 2.6 UT-ITEM: アイテムデータおよびインベントリ操作テスト (`test_inventory_items.gd`)

#### 【UT-ITEM-01】固定出目ダイス（1〜6の賽）のモデル整合性
- **テスト関数名：** `test_fixed_dice_items_model()`
- **期待結果：** 「1の賽」〜「6の賽」がそれぞれ固定値 1〜6 を保持し、種別が `FIXED_DICE` であること。

#### 【UT-ITEM-02】インベントリへのアイテム追加・消費・スタック処理
- **テスト関数名：** `test_inventory_add_and_consume()`
- **期待結果：** アイテム取得でインベントリ配列に追加され、使用時に指定アイテムが確実に消費されること。
