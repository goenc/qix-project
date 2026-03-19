日時: 2026-03-19 14:26:49 JST
対象:
- scripts/game/base_main.gd
変更:
・capture ごとの差分 polygon と inactive border segment を収集し、AABB ベースで dirty guide のみ再計算するよう変更
確認:
・Godot 4.6.1 で scenes/base_main.tscn を headless 起動しエラーなく終了することを確認
・Godot 4.6.1 で scenes/base_main.tscn を通常起動し短時間で正常終了することを確認
