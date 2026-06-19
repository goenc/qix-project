ボス領域通路判定の固定基準径変更をロールバック

・直前コミット 5705d91 の差分を逆適用し、ボス領域通路判定の固定基準径変更を取り消し
・BBOSの区画判定用基準径変更と通路polygon採用拒否ロジックを元に戻し、追加した検証コードも巻き戻し
・godot_console --headless --path . --script tools/verify_boss_region_recalculation_guard.gd で成功を確認
・godot_console --headless --path . --script tools/verify_outer_loop.gd で成功を確認
・git diff --check --cached で差分整合を確認

