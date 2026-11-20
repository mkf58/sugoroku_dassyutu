- セッション開始時に共通ルールである、AGENTS.mdを必ず読み込むこと。
- 読み込んだことを最初に報告すること
- 以下は Claude Code固有の差分のみ記載する

# 自動読み込み（@インポート）
AGENTS.md の「セッション開始時（必須）」ファイルのうち、小さいものは以下の @インポートでセッション開始時に自動的にコンテキストへ読み込まれる。
手動で Read し直す必要はない（最初の応答で「読み込んだ」旨の報告だけは行うこと）。

@AGENTS.md
@.agent/memory/MEMORY.md
@.agent/handoff/HANDOFF.md
@.spec/TODO.md

- `.spec/PLAN.md` は2500行超のため自動読み込みしない。セッション開始時は「1. 提案」と、末尾の最新QA（`grep -n "^### Q" .spec/PLAN.md` で位置を確認）のみ Read し、必要に応じて該当Qを参照する。
- `.spec/KNOWLEDGE.md` / `.spec/SPEC.md` は必要時に参照する。

# AGENTS.md の用語と Claude Code の対応
| AGENTS.md / Antigravity の記述 | Claude Code での対応 |
|---|---|
| `write_file` 権限の常時許可 | `.claude/settings.json` の `Edit(/**)`（Write/Edit両方に適用） |
| `git` の `command` 権限の常時許可 | `.claude/settings.json` の `Bash(git *)` / `PowerShell(git *)` |
| ワークフロー（`.agent/workflows/`） | スラッシュコマンド `.claude/commands/`（`/handoff`, `/newplan`） |
| スキル（`.agent/skills/`） | `.claude/skills/`（`spec-to-test`, `make_project`） |
| ローカル自動メモリを使用しない | `.claude/settings.json` の `"autoMemoryEnabled": false` で無効化済み。知見は `.agent/memory/MEMORY.md` へ |
| 質問・確認事項のログ | AskUserQuestion で質問した場合も、質問と回答を必ず `.spec/PLAN.md`「2. 深堀り・QA」に追記する |

- `.claude/settings.json` は権限設定のためユーザー自身が作成・管理する（AIは自分の権限を広げる変更をしない）。
- 事前許可は上記に加え、devマージ前に必須の `run_tests.ps1` 実行のみ追加している。`git push --force` / `-f` は deny。それ以外の権限を settings.json に追加する場合はユーザーに確認すること。
- `.agent/` 側（Antigravity/Gemini用）と `.claude/` 側のコマンド・スキルは同一内容の複製。どちらかを修正したら、もう一方にも同じ修正を反映すること。
- Claude Code デスクトップアプリのタスクリストは画面表示用。プロジェクトの正式なタスク管理は引き続き `.spec/TODO.md` で行う。

# 実行環境（Windows）
- シェルは PowerShell 5.1 が主、Bash（Git Bash）も利用可。PowerShell では `&&` が使えない点に注意。
- 単体テスト: `powershell -ExecutionPolicy Bypass -File .\run_tests.ps1`
  - Godot 実行ファイル: `C:\Users\mkf11\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe`（なければ PATH の `godot`）
  - テストランナー: `実装コード/tests/test_runner.gd`（スイートは `実装コード/tests/test_*.gd`）
  - 合格条件: 出力末尾の `TOTAL FAILED: 0`
  - CI（`.github/workflows/ci.yml`）は Godot 4.3.0 を使用しており、ローカル（4.7.2）とバージョンが異なる点に留意。
- Godot プロジェクトのルートは `実装コード/`（`project.godot`）。コードは `src/core`（ロジック）、`src/ui`、`src/views`、`scenes/`。
- GDScript のインデントは半角スペース4個。`*.gd.uid` は Godot が自動生成するファイルなので手で編集しない（新規 .gd 作成時は Godot 側で生成されたものをコミットする）。
- 既存の `.md` には UTF-8 BOM 付きのものがある（TODO.md, HANDOFF.md, result.md 等）。編集時に文字化けさせないこと。
