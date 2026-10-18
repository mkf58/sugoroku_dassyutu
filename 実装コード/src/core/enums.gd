class_name Enums
extends RefCounted

## マス種別
enum CellType {
    NORMAL,            ## 通常マス
    EXIT,              ## 出口・階段マス
    EVENT,             ## イベントマス（宝箱、石碑等）
    ADDITIONAL_MOVE,   ## 追加移動マス
    RETURN_TO_START,   ## 振り出しマス
    SKIP_TURN,         ## 1回休みマス
    ROLL_AGAIN,        ## もう一度マス
    WATER_TRAP         ## 水魔術トラップ
}

## 魔法属性種別
enum ElementType {
    NONE,
    FIRE,              ## 炎（2マス以内の魔女撃破）
    WATER,             ## 水（永続トラップ生成）
    WIND,              ## 風（直線吹き飛ばし）
    EARTH              ## 土（地中潜行／魔女スタン）
}

## 魔女行動タイプ
enum EnemyType {
    TRACKING,          ## ダイス追跡型
    PATROL,            ## 周回巡回型
    SENSOR             ## トラップ感知型
}

## ターン進行フェーズ
enum TurnPhase {
    STAGE_INIT,        ## ステージ初期化
    PLAYER_UNIT_SELECT,## プレイヤー：行動ユニット選択
    PLAYER_ACTION_SELECT, ## プレイヤー：コマンド選択
    PLAYER_MOVING,     ## プレイヤー：移動＆1歩判定中
    ENEMY_THINKING,    ## エネミー：思考中
    ENEMY_MOVING,      ## エネミー：移動＆1歩判定中
    TURN_END,          ## ターン終了処理
    GAME_OVER,         ## 主人公死亡
    STAGE_CLEAR        ## ステージクリア
}

## アイテム種別
enum ItemType {
    FIXED_DICE,        ## 1〜6の固定ダイス
    CHOICE_DICE,       ## 意志の賽
    DOUBLE_DICE,       ## 双子の賽
    KEY_ITEM           ## キーアイテム
}
