ボス領域の通路拡大判定を固定基準径へ分離

・BBOSの区画判定用基準径を初期衝突径固定へ変更
・再計算したボス領域がボスを含む広い部屋かを検証し、通路形状は採用しないよう修正
・ボス領域ガード検証とBBOS基準径検証を追加
・godot_console --headless --path . --script tools/verify_boss_region_recalculation_guard.gd で成功を確認
・godot_console --headless --path . --script tools/verify_enemy_player_hit.gd で成功を確認
・godot_console --headless --path . --script tools/verify_bbos_narrow_region.gd で成功を確認
・godot_console --headless --path . --script tools/verify_outer_loop.gd で成功を確認
・godot_console --headless --path . --quit-after 3 で起動確認
・godot --path . --quit-after 3 で非headless起動確認
・git diff --check で差分整合を確認
