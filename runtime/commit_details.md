日時: 2026-03-20 09:17:27 JST
対象:
- scripts/player/base_player.gd
- tools/verify_outer_loop.gd
- tools/verify_player_border_corner.gd
変更:
・外形角の手前で入力を予約する線分キューと頂点到達時の安定した線分選択を追加し BORDER 中の描画開始条件も境界整合付きで厳格化した。
・短辺や外形更新直後でも border state の整合を保てる補助処理と player 専用のヘッドレス確認スクリプトを追加した。
確認:
・Godot 4.6.1 headless で tools/verify_player_border_corner.gd を実行し initial rectangle と first L capture と second jagged capture を確認した。
・Godot 4.6.1 で tools/verify_player_border_corner.gd の check-only と非ヘッドレス短時間起動を実行した。