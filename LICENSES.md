# 著作権・ライセンス管理台帳 (LICENSES.md)

本書は、「すごろく×魔女の館脱出ゲーム」の開発および将来的な配信（Steam / itch.io等での商用・無料配信）において使用するゲームエンジン、外部ライブラリ、フォント、音響素材（BGM・SE）、画像素材等の著作権・ライセンス情報を一元管理する公式ドキュメントである。

リリース時の権利侵害トラブルやクレジット表記漏れを防止するため、**「新しい素材や外部アセットをプロジェクトへ追加する際は、必ず本書に追記すること」**を開発ルールとする。

---

## 1. 素材追加時の運用ルール・チェックリスト

外部素材（フリー素材・有料アセット含む）を採用する際は、以下のフローを必ず確認・実行する：

1. **商用利用の可否：** 将来の有料販売（Steam等）を想定し、**商用利用可能（Commercial Use Allowed）**な素材のみ採用する。「非商用限定 (Non-Commercial)」は原則使用禁止。
2. **クレジット表記義務の有無：** 著作権表示（Attribution）が必須か、任意かを確認する。
3. **改変の可否：** 画像トリミングや音源のループ編集、ピッチ変更等の改変が許可されているか確認する。
4. **再配布制限：** プロジェクトのリポジトリ（Git）に含めることが再配布規約に抵触しないか確認する。
5. **台帳への記載：** 採用決定後、直ちに本ファイルの「素材一覧台帳」に追記する。

---

## 2. ゲームエンジンおよび主要コンポーネント

### (1) Godot Engine 4
- **用途：** ゲーム実行エンジン
- **ライセンス：** **MIT License**
- **商用利用：** 可能
- **改変・再配布：** 可能
- **クレジット表記義務：** **あり**（ゲーム内クレジット画面、または配布ファイル内のテキスト等に著作権表示およびMITライセンス条文を記載する必要あり）
- **公式クレジット文（英語原文）：**
```text
This game uses Godot Engine, available under the following license:

Copyright (c) 2014-present Godot Engine contributors.
Copyright (c) 2007-2014 Juan Linietsky, Ariel Manzur.

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

- **サードパーティ同梱コンポーネントについて：**
  Godot Engine バイナリには FreeType, libpng, HarfBuzz などのオープンソースライブラリが静的リンクされています。Godot Engine 自体がこれらすべてを包括してライセンス管理を行っているため、エクスポートされたゲーム内に上記の Godot MIT ライセンス表示を含めることで要件を満たすことができます。

---

## 3. 素材一覧台帳 (Asset Inventory)

現在プロジェクトで採用している素材、および採用候補素材の管理一覧：

| 分類 | 素材名・アセット名 | 入手元 / 配布サイト | ライセンス種別 | クレジット表記義務 | 商用利用 | 備考・指定表記テキスト |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **エンジン** | Godot Engine 4.x | [godotengine.org](https://godotengine.org/) | MIT License | **必須** | ○ | 上記のMIT条文を同梱またはクレジット画面に記載 |
| **テスト** | GUT (Godot Unit Test) | [GitHub (bitwes/Gut)](https://github.com/bitwes/Gut) | MIT License | 任意(開発時のみ) | ○ | 開発・単体テスト用ツール |
| **フォント** | Noto Sans JP (候補) | [Google Fonts](https://fonts.google.com/) | SIL OFL 1.1 | **必須**(同梱時) | ○ | Open Font License 条文を同梱 |
| **フォント** | Zen Antique Soft (候補) | [Google Fonts](https://fonts.google.com/) | SIL OFL 1.1 | **必須**(同梱時) | ○ | 和風・ホラー調テキスト用候補 |
| **SE** | 効果音ラボ (候補) | [soundeffect-lab.info](https://soundeffect-lab.info/) | 独自規約(フリー) | 表記不要(推奨) | ○ | フォーリー音響、陶器破壊音、UI音等 |
| **SE** | VSQ plus+ (候補) | [vsq.co.jp](https://vsq.co.jp/plus/) | 独自規約(フリー) | 表記不要 | ○ | 足音、環境音、心拍音等 |
| **BGM** | DOVA-SYNDROME (候補) | [dova-s.jp](https://dova-s.jp/) | 独自規約(音源ごと) | 作曲者による | ○ | 各楽曲ごとの個別ライセンス要確認 |
| **BGM** | 甘茶の音楽工房 (候補) | [amachamusic.chagasi.com](https://amachamusic.chagasi.com/) | 独自規約(フリー) | **必須** | ○ | 「音楽：甘茶の音楽工房」の表記 |

---

## 4. ゲーム内クレジット画面用テンプレート (コピペ用完成形)

ゲーム本編の「クレジット画面（スタッフロール）」または同梱する `CREDITS.txt` にそのまま掲載できる表示フォーマットです。素材を追加するたびに、ここへ追記します。

```text
============================================================
すごろく×魔女の館脱出 (Sacrifice & Dice in the Witch's Mansion)
クレジット・使用ライセンス
============================================================

【開発・制作】
[開発者名 / サークル名]

【ゲームエンジン】
Godot Engine 4 (MIT License)
Copyright (c) 2014-present Godot Engine contributors.
Copyright (c) 2007-2014 Juan Linietsky, Ariel Manzur.

【フォント】
- Noto Sans JP / Zen Antique Soft
  Licensed under the SIL Open Font License, Version 1.1.

【音響素材 (SE / BGM)】
- 効果音ラボ (https://soundeffect-lab.info/)
- 甘茶の音楽工房 (https://amachamusic.chagasi.com/)
- VSQ plus+ (https://vsq.co.jp/plus/)

============================================================
```

---

## 5. 新規素材追加テンプレート (追加時はここをコピー)

新しい音源や画像を採用した際は、以下の行を「3. 素材一覧台帳」へ追記してください：

```markdown
| [分類] | [素材名] | [配布元URL] | [ライセンス名] | [必須/不要] | [○/×] | [指定のクレジット表記文] |
```
