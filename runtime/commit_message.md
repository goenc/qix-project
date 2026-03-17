ゲーム画面のグレー背景塗りを除去

・scripts/game/base_main.gd の _draw から remaining_polygon に対するグレー塗り描画を削除
・claimed_polygons の紫塗りと inactive_border_segments と current_outer_loop と outer_rect の描画処理は維持
・Godot headless で base_main.gd の check-only と base_main.tscn の短時間起動を確認
