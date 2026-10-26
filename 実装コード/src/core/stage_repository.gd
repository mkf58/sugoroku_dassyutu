class_name StageRepository
extends RefCounted

## ステージ定義リポジトリクラス
## Stage 1〜Stage 6 の盤面・キャラクター配置データを提供する。

const STAGE_IDS: Array[String] = [
    "STAGE_1",
    "STAGE_2",
    "STAGE_3",
    "STAGE_4",
    "STAGE_5",
    "STAGE_6"
]

static func get_first_stage_id() -> String:
    return STAGE_IDS[0]

static func get_all_stage_ids() -> Array[String]:
    return STAGE_IDS.duplicate()

static func get_stage(stage_id: String) -> StageData:
    match stage_id:
        "STAGE_1":
            return _create_stage_1()
        "STAGE_2":
            return _create_stage_2()
        "STAGE_3":
            return _create_stage_3()
        "STAGE_4":
            return _create_stage_4()
        "STAGE_5":
            return _create_stage_5()
        "STAGE_6":
            return _create_stage_6()
        _:
            DebugLogger.warn("StageRepository.get_stage", "未定義のステージIDが要求されました", {"stage_id": stage_id})
            return null

## 共通の回廊型仮盤面生成ヘルパー
static func _create_template_board(length: int = 14) -> GridBoard:
    var board = GridBoard.new()
    # 1. 中央メインストリート（Y=3, X=1〜length）
    for x in range(1, length + 1):
        var type = Enums.CellType.NORMAL
        if x == 4:
            type = Enums.CellType.SKIP_TURN
        elif x == 6:
            type = Enums.CellType.WATER_TRAP
        elif x == 9:
            type = Enums.CellType.ADDITIONAL_MOVE
        elif x == length:
            type = Enums.CellType.EXIT
        board.add_cell(CellData.new(Vector2i(x, 3), type))
        if x > 1:
            board.connect_cells(Vector2i(x - 1, 3), Vector2i(x, 3))

    # 2. 北側回廊（Y=1, X=3〜11）
    for x in range(3, 12):
        var type = Enums.CellType.NORMAL
        if x == 3:
            type = Enums.CellType.ADDITIONAL_MOVE
        elif x == 5 or x == 11:
            type = Enums.CellType.EVENT
        elif x == 7:
            type = Enums.CellType.ROLL_AGAIN
        elif x == 9:
            type = Enums.CellType.WATER_TRAP
        board.add_cell(CellData.new(Vector2i(x, 1), type))
        if x > 3:
            board.connect_cells(Vector2i(x - 1, 1), Vector2i(x, 1))

    # 3. 南側回廊（Y=5, X=3〜11）
    for x in range(3, 12):
        var type = Enums.CellType.NORMAL
        if x == 3 or x == 11:
            type = Enums.CellType.EVENT
        elif x == 5:
            type = Enums.CellType.RETURN_TO_START
        elif x == 7:
            type = Enums.CellType.ADDITIONAL_MOVE
        elif x == 9:
            type = Enums.CellType.ROLL_AGAIN
        board.add_cell(CellData.new(Vector2i(x, 5), type))
        if x > 3:
            board.connect_cells(Vector2i(x - 1, 5), Vector2i(x, 5))

    # 4. 連絡通路
    for connect_x in [3, 7, 11]:
        board.add_cell(CellData.new(Vector2i(connect_x, 2), Enums.CellType.NORMAL))
        board.connect_cells(Vector2i(connect_x, 1), Vector2i(connect_x, 2))
        board.connect_cells(Vector2i(connect_x, 2), Vector2i(connect_x, 3))
        board.add_cell(CellData.new(Vector2i(connect_x, 4), Enums.CellType.NORMAL))
        board.connect_cells(Vector2i(connect_x, 3), Vector2i(connect_x, 4))
        board.connect_cells(Vector2i(connect_x, 4), Vector2i(connect_x, 5))

    return board

## Stage 1: 2F 廊下・客室（チュートリアル、少女なし）
static func _create_stage_1() -> StageData:
    var board = _create_template_board(14)
    var enemies: Array[Dictionary] = [
        {"id": "WITCH_1", "name": "魔女", "type": Enums.EnemyType.TRACKING, "coord": Vector2i(12, 3)}
    ]
    var companions: Array[Dictionary] = []
    return StageData.new(
        "STAGE_1",
        "Stage 1: 2F 廊下・客室 (チュートリアル)",
        1,
        board,
        Vector2i(1, 3),
        enemies,
        companions,
        "STAGE_2"
    )

## Stage 2: 1F キッチン・食堂（炎の少女）
static func _create_stage_2() -> StageData:
    var board = _create_template_board(14)
    var enemies: Array[Dictionary] = [
        {"id": "WITCH_2", "name": "追跡する魔女", "type": Enums.EnemyType.TRACKING, "coord": Vector2i(12, 3)}
    ]
    var companions: Array[Dictionary] = [
        {"id": "GIRL_FIRE", "name": "炎の少女", "element": Enums.ElementType.FIRE, "coord": Vector2i(1, 1)}
    ]
    return StageData.new(
        "STAGE_2",
        "Stage 2: 1F キッチン・食堂",
        2,
        board,
        Vector2i(1, 3),
        enemies,
        companions,
        "STAGE_3"
    )

## Stage 3: 中庭・古井戸（水の少女）
static func _create_stage_3() -> StageData:
    var board = _create_template_board(14)
    var enemies: Array[Dictionary] = [
        {"id": "WITCH_3", "name": "中庭の魔女", "type": Enums.EnemyType.TRACKING, "coord": Vector2i(12, 3)}
    ]
    var companions: Array[Dictionary] = [
        {"id": "GIRL_WATER", "name": "水の少女", "element": Enums.ElementType.WATER, "coord": Vector2i(1, 1)}
    ]
    return StageData.new(
        "STAGE_3",
        "Stage 3: 庭園・古井戸",
        3,
        board,
        Vector2i(1, 3),
        enemies,
        companions,
        "STAGE_4"
    )

## Stage 4: 別邸・時計塔（風の少女）
static func _create_stage_4() -> StageData:
    var board = _create_template_board(14)
    var enemies: Array[Dictionary] = [
        {"id": "WITCH_4", "name": "時計塔の魔女", "type": Enums.EnemyType.TRACKING, "coord": Vector2i(12, 3)}
    ]
    var companions: Array[Dictionary] = [
        {"id": "GIRL_WIND", "name": "風の少女", "element": Enums.ElementType.WIND, "coord": Vector2i(1, 1)}
    ]
    return StageData.new(
        "STAGE_4",
        "Stage 4: 別邸・時計塔",
        4,
        board,
        Vector2i(1, 3),
        enemies,
        companions,
        "STAGE_5"
    )

## Stage 5: 地下室・地下墓所（土の少女）
static func _create_stage_5() -> StageData:
    var board = _create_template_board(14)
    var enemies: Array[Dictionary] = [
        {"id": "WITCH_5", "name": "地下墓所の魔女", "type": Enums.EnemyType.TRACKING, "coord": Vector2i(12, 3)}
    ]
    var companions: Array[Dictionary] = [
        {"id": "GIRL_EARTH", "name": "土の少女", "element": Enums.ElementType.EARTH, "coord": Vector2i(1, 1)}
    ]
    return StageData.new(
        "STAGE_5",
        "Stage 5: 地下室・地下墓所",
        5,
        board,
        Vector2i(1, 3),
        enemies,
        companions,
        "STAGE_6"
    )

## Stage 6: 裏口・墓地（最終脱出階層）
static func _create_stage_6() -> StageData:
    var board = _create_template_board(14)
    var enemies: Array[Dictionary] = [
        {"id": "WITCH_6", "name": "館の主・怨念核", "type": Enums.EnemyType.TRACKING, "coord": Vector2i(12, 3)}
    ]
    var companions: Array[Dictionary] = []
    return StageData.new(
        "STAGE_6",
        "Stage 6: 裏口・墓地 (最終脱出地点)",
        6,
        board,
        Vector2i(1, 3),
        enemies,
        companions,
        "" # 最終ステージのため次は空文字
    )
