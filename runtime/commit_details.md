日時: 2026-03-15 13:42:35 JST
summary: qix_draw を Shift と PAD-A の両対応にしてヘルプ表示を更新
code_changes:
・base_main.gd の qix_draw 入力登録を Shift と JOY_BUTTON_A の併用へ変更
・base_main.tscn の HelpLabel 表示を SHIFT/PAD-A 表記へ更新
verification:
・tools/run.ps1 を実行し Godot の起動を確認
