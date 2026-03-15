日時: 2026-03-15 19:52:36 +09:00
対象: qix_draw 入力名統一と欠落時の起動時検知
summary: qix_draw を唯一の正式入力名として固定し InputMap 欠落時に原因が即分かるようにした
code_changes:
・project.godot に qix_draw の Shift と PAD-A 定義を追加し base_main では既存定義がある場合だけ qix_draw のイベントを正規化するよう変更
・base_player.gd に ACTION_QIX_DRAW 定数と起動時の InputMap.has_action 検知を追加し qix_draw 参照を定数ヘルパー経由へ統一
verification:
・C:\Godot\godot.exe --headless --path . --scene res://scenes/base_main.tscn --quit が成功
・一時 headless スクリプトで Shift と PAD-A の BORDER から DRAWING 開始 離して REWINDING 再押下で再開を確認
・一時 headless スクリプトで qix_draw を削除した場合に明示エラーが 1 回だけ出ることを確認
