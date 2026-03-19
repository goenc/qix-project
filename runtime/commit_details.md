日時: 2026-03-19 19:49:11 JST
対象:
- scripts/player/base_player.gd
- scripts/game/playfield_boundary.gd
変更:
・外形の角でだけ入力方向に応じて接続辺を選び border_progress を軽量補正する処理を追加した
確認:
・godot_console.exe のヘッドレス検証で角入力時に progress が接続辺へ切り替わることを確認した
・godot_console.exe のヘッドレス起動でプロジェクトが正常に起動することを確認した日時: 2026-03-19 20:37:06 JST
対象:
- scripts/player/base_player.gd
- scripts/game/playfield_boundary.gd
変更:
・外形移動の主状態を線分 index と線分内距離へ移行し BORDER 中の位置復元を線分ベースへ置き換えた
・PlayfieldBoundary に線分取得 線分距離 点位置復元 頂点接続 頂点入力選択の軽量補助関数を追加した
確認:
・Godot headless 起動でプロジェクト読み込み成功を確認した
・一時検証スクリプトで矩形4角 非矩形ループの角移動と外形更新後の再同期を確認した
