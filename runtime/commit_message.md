ボス領域再計算失敗時の表示崩れを防止

・ボス領域ポリゴンの妥当性判定を追加し 再計算結果が3点未満または面積0の場合は空ポリゴンで上書きしないよう修正
・直前の有効なボス領域を維持し 有効値がない初期状態では remaining_polygon と current_outer_loop からのみ復旧する分岐を追加
・再計算失敗時の警告を連続抑止し 専用 verify で表示維持 復旧 クリア条件維持を確認
・godot_console --headless --path . --script tools/verify_boss_region_recalculation_guard.gd
・godot_console --headless --path . --script tools/verify_bbos_narrow_region.gd
・godot_console --headless --path . --quit-after 3
・godot --path . --quit-after 3
・git diff --check
