# 詳細設計書：UI制御およびシーン構造詳細設計書

本書は、「すごろく×魔女の館脱出ゲーム」におけるGodot Engine 4のノードツリー構成、ビューとロジックのバインディング、マウス入力ハンドリング仕様、Tweenアニメーション制御、および演出スキップ機構を記述した詳細設計書である。

---

## 1. シーン構成ツリー (Scene Tree Hierarchy)

メインゲーム画面 (`MainGame.tscn`) のノード構成：

```
MainGame (Node2D) [MainGame.gd]
├── Camera2D (Camera2D) [BoardCamera.gd] - スクロール＆ズーム制御
├── BoardView (Node2D) [BoardView.gd] - 盤面・マス・コマ描画
│   ├── CellsContainer (Node2D) - CellNode の親
│   ├── RoutePreview (Line2D) - ホバー時の点線矢印プレビュー
│   ├── PiecesContainer (Node2D) - UnitPiece の親
│   │   ├── HeroPiece (UnitPiece.tscn)
│   │   ├── GirlPiece (UnitPiece.tscn)
│   │   └── WitchPiece (UnitPiece.tscn)
│   └── EffectContainer (Node2D) - 魔法・トラップ演出
└── CanvasLayer (CanvasLayer) - 2D UIレイヤー
    ├── HUD (Control) [HUD.gd]
    │   ├── TurnBanner (Panel) - ターン数・現在フェーズ表示
    │   ├── ActionPanel (HBoxContainer) - [ダイス移動] [アイテム] [魔法] [祈る]
    │   ├── DiceResultDisplay (TextureRect/Label) - 出目表示
    │   └── MenuButtons (VBoxContainer) - [ヘルプ] [コンフィグ]
    ├── DangerVignette (ColorRect) [Vignette.gd] - 魔女接近時の画面減光シェーダー
    ├── HelpModal (Control) [HelpModal.tscn] - ルール・マス効果モーダル
    ├── ConfigModal (Control) [ConfigModal.tscn] - 演出スキップ・音量設定
    └── GameOverScreen (Control) [GameOverScreen.tscn] - 捕縛リザルト画面
```

---

## 2. マウス入力ハンドリング仕様 (`BoardCamera.gd` / `BoardView.gd`)

基本設計で確定した**「左クリック＝すべて確定・選択」「右クリック＝すべてキャンセル・閉じる」「左ドラッグ＝マップスクロール」**を厳格に実装する。

### 2.1 入力状態遷移とイベント処理

```gdscript
## BoardView.gd の入力制御
func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventMouseButton:
        if event.button_index == MOUSE_BUTTON_LEFT:
            if event.pressed:
                _on_left_click_pressed(event.position)
            else:
                _on_left_click_released(event.position)
                
        elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
            _on_right_click_pressed()
            
    elif event is InputEventMouseMotion:
        _on_mouse_motion(event.position, event.relative)
```

| 入力アクション | 状況・コンテキスト | 実行される動作 |
| :--- | :--- | :--- |
| **ターン開始時** | プレイヤーターン開始 | 操作中キャラが発光。マウスポインタ位置にダイスボタンが重なるようコマンドメニューを展開（即座にダイスを振れる） |
| **左クリック (押下)** | コマンド表示中 | ダイス移動・アイテム・魔法・祈る・閉じるのいずれかを実行 |
| **左クリック (押下)** | 移動先選択中（到達可能マス上） | 当該マスへの移動を確定し、コマの移動を開始（1クリック移動） |
| **左クリック (押下)** | コマ移動中 (Tween実行中) | **Tweenを即座に完了（`skip_current_move()`）し、目的マスへ瞬間移動** |
| **左ドラッグ / 中ドラッグ** | 盤面確認モード中 | カメラをドラッグ移動（マップスクロール・パン移動） |
| **マウスホイール** | 常時 | 盤面カメラのズームイン / ズームアウト（0.5倍〜2.5倍） |
| **右クリック (押下)** | コマンドメニュー表示中 | メニューを非表示にし、盤面確認モードへ移行 |
| **右クリック (押下)** | 盤面確認モード中 | 現在のマウスポインタ位置にコマンドメニューを再展開（ダイスボタンがマウス直下に合致） |
| **右クリック / ドラッグ** | 移動先選択中 | 出目確定後のため出目キャンセルは不可（移動必須）。右ドラッグで盤面カメラをパン移動可能 |
| **右クリック (押下)** | アイテムモーダル表示中 | モーダルを閉じてコマンドメニューへ復帰 |

| **マウスホバー** | 移動先選択中（到達可能マス上） | スタートからそのマスまでの最短ルートを点線矢印（`Line2D`）で描画 |


---

## 3. アニメーション制御とテンポ最適化 (Tween & Skip)

死にゲー特有のストレスを排除するため、全アニメーションに「高速化・スキップ」を設ける。

### 3.1 味方コマの移動アニメーション (`UnitPiece.gd`)

```gdscript
var current_move_tween: Tween = null

func animate_move_path(path: Array[Vector2i], step_callback: Callable, on_complete: Callable) -> void:
    if config_move_speed == MoveSpeed.INSTANT:
        # コンフィグが「常にスキップ」の場合は一瞬で完了
        for i in range(1, path.size()):
            step_callback.call(path[i], path.size() - 1 - i)
        global_position = board_view.coord_to_world(path[-1])
        on_complete.call()
        return

    current_move_tween = create_tween()
    current_move_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    
    for i in range(1, path.size()):
        var target_pos = board_view.coord_to_world(path[i])
        var remain = path.size() - 1 - i
        
        # 1歩ごとの放物線ジャンプ (0.15秒)
        current_move_tween.tween_callback(func():
            # 1歩進むごとのロジック判定コールバック
            var result = step_callback.call(path[i], remain)
            if result.get("status") in ["GAME_OVER", "GIRL_DIED", "WATER_TRAP_STOP"]:
                current_move_tween.kill() # 接触・トラップ時は以降のTween中断
        )
        current_move_tween.tween_property(self, "global_position", target_pos, 0.15)
        
    current_move_tween.tween_callback(on_complete)

## 移動中の画面クリックで即座に完了させるメソッド
func skip_current_move(final_coord: Vector2i, on_complete: Callable) -> void:
    if current_move_tween and current_move_tween.is_valid():
        current_move_tween.kill()
        global_position = board_view.coord_to_world(final_coord)
        on_complete.call()
```

### 3.2 エネミーの全員一瞬移動
通常移動時（誰も捕まらない移動）、全エネミーは順次移動ではなく**全員同時に一瞬（0.08秒 または 即時）**で移動し、プレイヤーに待ち時間を一切発生させない。

```gdscript
func execute_all_enemies_simultaneous_move(move_plans: Array[Dictionary], on_finished: Callable) -> void:
    var all_tween = create_tween()
    for plan in move_plans:
        var enemy_piece = get_enemy_piece(plan.enemy_id)
        var target_pos = board_view.coord_to_world(plan.to_coord)
        all_tween.parallel().tween_property(enemy_piece, "global_position", target_pos, 0.08)
        
    all_tween.tween_callback(on_finished)
```

---

## 4. 魔女頭上アイコン・危険接近演出 (`WitchPiece.gd` / `DangerVignette.gd`)

### 4.1 ヘイトアイコン（追跡ターゲット）の頭上表示
魔女ピースの頭上に `Sprite2D` を配置し、TurnManager からの `enemy_target_changed` シグナルを受信してターゲットの顔アイコンを切り替える。
- 切り替え時：頭上アイコンがピョンと跳ねるTween + 警告音（ピピッ）

### 4.2 心拍SEおよび減光ビネット演出 (`DangerVignette.gd`)
- 主人公と魔女の距離が4マス以内、または周回型・感知型の危険視野に入った場合：
  - 画面四隅が赤黒く減光（`ColorRect` のシェーダー透明度をフェードイン）。
  - 低音の心拍SE（ドクン…ドクン…）をループ再生。距離が縮まるほどテンポが上昇。

---

## 5. シーン遷移管理およびタイトル画面詳細設計 (`SceneManager.gd` / `TitleScreen.gd`)

### 5.1 シーンマネージャー仕様 (`res://src/core/scene_manager.gd`)
プロジェクト全域の画面遷移を一元管理するAutoloadシングルトン。

- **役割と機能：**
  - シーン切替処理（`change_scene_to_file`）の安全なカプセル化
  - 画面間のトランジション（最前面CanvasLayerでの黒フェードアウト＆フェードイン：各0.25〜0.35秒）
  - 二重呼び出し防御（`is_transitioning` フラグによるガード）
  - ヘッドレスモード（UT実行環境等）での安全なフォールバック（Tweenスキップ・直接切替）
  - シーン間受け渡しパラメータ（`current_stage_id`, `retry_count`, `save_data`）の保持
- **定数定義：**
  - `SCENE_TITLE = "res://scenes/title_screen.tscn"`
  - `SCENE_MAIN_GAME = "res://scenes/main_game.tscn"`
  - `SCENE_STAGE_SELECT = "res://scenes/stage_select_screen.tscn"`
- **公開API：**
  - `change_scene(target_path: String, params: Dictionary = {}, with_fade: bool = true) -> void`
  - `change_to_title(with_fade: bool = true) -> void`
  - `change_to_main_game(stage_id: String = "", with_fade: bool = true) -> void`
  - `get_param(key: String, default_value = null) -> Variant`
  - `set_param(key: String, value: Variant) -> void`
  - `has_save_data() -> bool`

### 5.2 タイトル画面仕様 (`res://scenes/title_screen.tscn` / `res://src/ui/title_screen.gd`)
- **ノード構成：**
  ```
  TitleScreen (Control) [title_screen.gd]
  ├── Background (ColorRect) - 濃紺・暗色ダークトーン
  ├── TitlePanel (VBoxContainer)
  │   ├── TitleLabel (Label) - 『すごろく×魔女の館脱出』
  │   └── SubtitleLabel (Label) - - Sacrifice & Dice in the Witch's Mansion -
  ├── MenuContainer (VBoxContainer)
  │   ├── NewGameButton (Button) - [はじめから]
  │   ├── ContinueButton (Button) - [つづきから] (セーブ有無で活性/非活性)
  │   ├── HelpButton (Button) - [遊び方/ヘルプ]
  │   └── QuitButton (Button) - [ゲーム終了]
  ├── HelpModal (Control) [HelpModal.tscn] - 遊び方モーダル
  └── VersionLabel (Label) - v0.1.0 PoC
  ```
- **画面アクション：**
  - `NewGameButton` 押下：`SceneManager.change_to_main_game("STAGE_1")`
  - `ContinueButton` 押下：セーブデータが存在する場合、該当ステージで `SceneManager.change_to_main_game()`
  - `HelpButton` 押下：`HelpModal.show_modal()`
  - `QuitButton` 押下：`get_tree().quit()`

