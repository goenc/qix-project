日時: 2026-03-19 19:49:11 JST
対象:
- scripts/player/base_player.gd
- scripts/game/playfield_boundary.gd
変更:
・外形の角でだけ入力方向に応じて接続辺を選び border_progress を軽量補正する処理を追加した
確認:
・godot_console.exe のヘッドレス検証で角入力時に progress が接続辺へ切り替わることを確認した
・godot_console.exe のヘッドレス起動でプロジェクトが正常に起動することを確認した