# 詳細設計書：単体テスト仕様書 (UT Specification)

本書は、「すごろく×魔女の館脱出ゲーム」のコアロジックに対する単体テスト（Unit Test）仕様書である。Godot Engine 4 のテストフレームワーク「GUT (Godot Unit Test)」または標準アサーションを用いた自動テストコード（`test_*.gd`）にそのまま落とし込める形式で記述する。

---

## 1. 単体テストスイート構成一覧

| テストスイート名 | 対象クラス | 検証内容 | テストファイル配置先 |
| :--- | :--- | :--- | :--- |
| **UT-BOARD** | `GridBoard` | マス登録、隣接接続、最短経路探索(BFS)、出目折り返し到達判定 | `実装コード/tests/test_grid_board.gd` |
| **UT-STEP** | `TurnManager` | 1歩ごとの接触判定（即死・少女殺害・潜行やり過ごし）、水トラップ即停止 | `実装コード/tests/test_step_movement.gd` |
| **UT-ENEMY** | `TurnManager` | 魔女追跡ターゲット選定優先順位、全員潜行時の初期位置移動 | `実装コード/tests/test_enemy_ai.gd` |
| **UT-MAGIC** | `TurnManager` | 4属性魔法（炎撃破、水トラップ生成、風吹っ飛ばし、土潜行・スタン） | `実装コード/tests/test_magic_system.gd` |
| **UT-TURN** | `TurnManager` | 少女死亡後の3ターン復活処理、エネミー復活、全味方行動完了遷移 | `実装コード/tests/test_turn_lifecycle.gd` |

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
  - `(2,0)`（右に2マス進む）だけでなく、`(0,0)`（右に1進んで左に1戻る折り返し）も到達可能マス（キーとして存在）として含まれること。
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

---

## 2.2 UT-STEP: 1歩ごとの接触・トラップ判定テスト (`test_step_movement.gd`)


#### 【UT-STEP-01】主人公が未潜行で魔女のマスを通過・侵入した際の即時ゲームオーバー判定
- **テスト関数名：** `test_hero_step_overlap_with_witch_causes_game_over()`
- **前提条件 (Given)：**
  - 主人公 `HERO` が `(0,0)`、魔女 `WITCH` が `(1,0)` に配置されている。
  - 主人公は未潜行（`is_burrowed == false`）。
  - 主人公は出目 2 で `[(0,0), (1,0), (2,0)]` の経路を移動する。
- **実行操作 (When)：**
  - 1歩目（`(0,0) -> (1,0)`）を `step_unit` で実行する。
- **期待結果 (Then)：**
  - 戻り値ステータスが `"GAME_OVER"` であること。
  - `TurnManager.current_phase` が `GAME_OVER` に遷移すること。
  - 残り歩数が残っていても2歩目（`(2,0)`）への移動は実行されないこと。

#### 【UT-STEP-02】土魔法で潜行中のユニットが魔女のマスを通過した際のやり過ごし検証
- **テスト関数名：** `test_burrowed_hero_can_pass_witch_safely()`
- **前提条件 (Given)：**
  - 主人公 `HERO` が `(0,0)` で地中潜行中（`is_burrowed == true`）。
  - 魔女が `(1,0)` に配置。
- **実行操作 (When)：**
  - 1歩目（`(1,0)` 魔女のいるマス）へ侵入する。
- **期待結果 (Then)：**
  - ゲームオーバーは発生せず、ステータス `"CONTINUE"` が返却されること。
  - 主人公の現在地が `(1,0)` に正常更新されること。

#### 【UT-STEP-03】水魔術トラップマス侵入時の残歩数破棄・即時ターン終了検証
- **テスト関数名：** `test_water_trap_stops_movement_immediately()`
- **前提条件 (Given)：**
  - `(1,0)` が `WATER_TRAP` マス。
  - 出目 3（経路: `[(0,0), (1,0), (2,0), (3,0)]`）で移動開始。
- **実行操作 (When)：**
  - 1歩目（`(1,0)`）を踏む。
- **期待結果 (Then)：**
  - ステータス `"WATER_TRAP_STOP"` が返却されること。
  - 残歩数 2 が強制破棄され、ユニットの現在地が `(1,0)` で確定すること。
  - ユニットの `has_acted` が `true` になること。

---

## 2.3 UT-ENEMY: 魔女ターゲット選定テスト (`test_enemy_ai.gd`)

#### 【UT-ENEMY-01】最短距離の未潜行ユニット優先選定
- **テスト関数名：** `test_witch_targets_nearest_unburrowed_unit()`
- **前提条件 (Given)：**
  - 魔女位置: `(5,0)`
  - 主人公位置: `(0,0)` (距離5)
  - 炎の少女位置: `(3,0)` (距離2)
- **実行操作 (When)：**
  - `select_witch_target()` を実行する。
- **期待結果 (Then)：**
  - より距離の近い「炎の少女 (`GIRL_FIRE`)」がターゲットとして選定されること。

#### 【UT-ENEMY-02】同距離時のタイブレーク優先順位（主人公最優先）
- **テスト関数名：** `test_witch_targets_hero_on_equal_distance()`
- **前提条件 (Given)：**
  - 魔女位置: `(2,0)`
  - 主人公位置: `(0,0)` (距離2)
  - 炎の少女位置: `(4,0)` (距離2)
- **実行操作 (When)：**
  - `select_witch_target()` を実行する。
- **期待結果 (Then)：**
  - タイブレーク優先順位（`主人公 > 炎`）に従い、主人公 `HERO` がターゲットとして選定されること。

#### 【UT-ENEMY-03】潜行中ユニットのターゲット除外と全員潜行時の初期位置移動
- **テスト関数名：** `test_witch_returns_to_initial_when_all_burrowed()`
- **前提条件 (Given)：**
  - 魔女初期位置: `(5,5)`、現在地: `(2,2)`
  - 生存している味方全員（主人公・少女）が潜行中（`is_burrowed == true`）。
- **実行操作 (When)：**
  - `select_witch_target()` を実行する。
- **期待結果 (Then)：**
  - ターゲットが `null` であること。
  - 魔女の移動目標が初期位置 `(5,5)` に設定されること。

---

## 2.4 UT-MAGIC: 4属性魔法効果テスト (`test_magic_system.gd`)

#### 【UT-MAGIC-01】炎魔法による魔女撃破と2ターン復活カウンタ設定
- **テスト関数名：** `test_fire_magic_defeats_witch()`
- **前提条件 (Given)：**
  - 炎の少女が `(0,0)`、魔女が `(1,0)`（距離1マス）に配置。魔女は生存中。
- **実行操作 (When)：**
  - `execute_magic("GIRL_FIRE", ElementType.FIRE, Vector2i(1,0))` を実行。
- **期待結果 (Then)：**
  - 魔女の `is_alive` が `false` になること。
  - 魔女の `revive_turn_count` が 2 に設定されること。
  - 炎の少女の `has_acted` が `true` になること。

#### 【UT-MAGIC-02】水魔法によるトラップ生成
- **テスト関数名：** `test_water_magic_creates_trap()`
- **前提条件 (Given)：**
  - `(2,0)` は通常マス（`NORMAL`）。
- **実行操作 (When)：**
  - `execute_magic("GIRL_WATER", ElementType.WATER, Vector2i(2,0))` を実行。
- **期待結果 (Then)：**
  - `(2,0)` のマス種別が `WATER_TRAP` に変更されること。

---

## 2.5 UT-TURN: ターンライフサイクルと復活テスト (`test_turn_lifecycle.gd`)

#### 【UT-TURN-01】少女死亡後の3ターン経過による初期位置復活
- **テスト関数名：** `test_girl_revives_after_three_turns()`
- **前提条件 (Given)：**
  - 炎の少女の初期位置が `(0,0)`。
  - 魔女に捕縛され死亡（`is_alive == false`, `revive_turn_count == 3`）。
- **実行操作 (When)：**
  - 3回ターン終了（`end_turn_and_advance`）を経過させる。
- **期待結果 (Then)：**
  - 1ターン後：`revive_turn_count == 2`, `is_alive == false`
  - 2ターン後：`revive_turn_count == 1`, `is_alive == false`
  - 3ターン後：`revive_turn_count == 0`, `is_alive == true`, `current_coord == (0,0)` に完全復活すること。

#### 【UT-TURN-02】ターン進行後の味方行動リセットと再選択・行動フェーズ遷移の検証
- **テスト関数名：** `test_turn_advance_and_reselection()`
- **前提条件 (Given)：**
  - 主人公 `HERO` が配置され、1ターン目の行動済み（`has_acted == true`）。
- **実行操作 (When)：**
  - ターン終了（`end_turn_and_advance`）を実行し、`select_character("HERO")` を呼び出す。
- **期待結果 (Then)：**
  - `current_turn` が 2 に更新されること。
  - 主人公の `has_acted` が `false` にリセットされること。
  - 主人公の選択に成功（戻り値 `true`）し、`current_phase` が `PLAYER_ACTION_SELECT` に遷移すること。

