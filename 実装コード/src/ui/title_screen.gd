class_name TitleScreen
extends Control

## タイトル画面制御スクリプト
## 「はじめから」「つづきから」「遊び方/ヘルプ」「ゲーム終了」のアクションを制御する。

@onready var new_game_btn: Button = $MenuContainer/NewGameButton
@onready var continue_btn: Button = $MenuContainer/ContinueButton
@onready var help_btn: Button = $MenuContainer/HelpButton
@onready var quit_btn: Button = $MenuContainer/QuitButton
@onready var help_modal: HelpModal = $CanvasLayer/HelpModal

func _ready() -> void:
    new_game_btn.pressed.connect(_on_new_game_pressed)
    continue_btn.pressed.connect(_on_continue_pressed)
    help_btn.pressed.connect(_on_help_pressed)
    quit_btn.pressed.connect(_on_quit_pressed)

    # セーブデータが存在しない場合は「つづきから」を無効化（または薄く表示）
    var has_save = false
    if Engine.has_singleton("SceneManager"):
        var sm = Engine.get_singleton("SceneManager")
        has_save = sm.has_save_data()
    elif get_node_or_null("/root/SceneManager"):
        var sm = get_node("/root/SceneManager")
        has_save = sm.has_save_data()
        
    continue_btn.disabled = not has_save
    if not has_save:
        continue_btn.tooltip_text = "セーブデータが存在しません"
        
    # 初期フォーカスを「はじめから」へ
    new_game_btn.grab_focus()

func _on_new_game_pressed() -> void:
    DebugLogger.info("TitleScreen._on_new_game_pressed", "「はじめから」が選択されました")
    if get_node_or_null("/root/SceneManager"):
        get_node("/root/SceneManager").change_to_main_game("STAGE_1")
    else:
        # シングルトン未配置時のフォールバック
        get_tree().change_scene_to_file("res://scenes/main_game.tscn")

func _on_continue_pressed() -> void:
    DebugLogger.info("TitleScreen._on_continue_pressed", "「つづきから」が選択されました")
    if get_node_or_null("/root/SceneManager"):
        get_node("/root/SceneManager").change_to_main_game("STAGE_1")
    else:
        get_tree().change_scene_to_file("res://scenes/main_game.tscn")

func _on_help_pressed() -> void:
    if help_modal:
        help_modal.show_modal()

func _on_quit_pressed() -> void:
    DebugLogger.info("TitleScreen._on_quit_pressed", "ゲームを終了します")
    get_tree().quit()
