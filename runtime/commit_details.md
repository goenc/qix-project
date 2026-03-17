日時: 2026-03-17 10:38:11 JST
対象: project.godot
summary:
ベース画面を1280x720固定かつリサイズ不可に設定した。
code_changes:
・project.godot に display/window/size/viewport_width=1280 と display/window/size/viewport_height=720 と display/window/size/resizable=false を追加した。
verification:
・Godot 4.6.1 のヘッドレス起動でプロジェクトが終了コード0で起動できることを確認した。
