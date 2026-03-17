日時: 2026-03-17 11:04:03 +09:00
対象: タイトル画面の開始入力
変更:
・project.godot に qix_start を追加し Enter Space A START をタイトル開始専用入力として明示した
・title_main.gd の開始判定を qix_start ベースの _input に切り替え setup 後にウィンドウフォーカスを戻す処理を追加した
・title.gd の開始文言を PRESS A / ENTER TO START に変更した
確認:
・Godot headless で title_main.gd の check-only が成功した
・Godot headless で title.gd の check-only が成功した
・Godot headless でプロジェクトを quit-after 2 で起動しエラーなく終了した

日時: 2026-03-17 13:53:00 +09:00
対象: ゲーム画面のグレー背景塗り
変更:
・scripts/game/base_main.gd の _draw から remaining_polygon に対するグレー塗り描画を削除した
・claimed_polygons の紫塗りと inactive_border_segments と current_outer_loop と outer_rect の描画処理は変更していない
確認:
・Godot headless で base_main.gd の check-only が成功した
・Godot headless で base_main.tscn を --quit 付きで起動しエラーなく終了した
