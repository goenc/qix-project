日時: 2026-03-14 20:29:44 +09:00
対象: QIX 初期プロジェクトの debug pause と object inspector 選択修正
summary: title_main と base_main の両方で debug pause が成立し、base_player を object inspector でクリック選択できるように修正
code_changes:
・base_player に Area2D と CollisionShape2D を追加し、debug_pick_owner メタで選択対象を BasePlayer ルートへ解決するようにした
・base_player を PROCESS_MODE_PAUSABLE にして、base_main が常時処理でも pause 中の十字移動が止まるようにした
・title_main に set_paused_from_debug と is_pause_toggle_allowed を追加し、タイトル中も debug pause を受けられるようにした
・DebugManager の pause controller 呼び出し前に has_method を確認し、不在時や解決揺れで不正終了しないようにした
verification:
・tools/run.ps1 を実行し、タイムアウトまで起動継続することを確認した
・godot_console --headless --path . --quit-after 120 が exit code 0 で終了し、新規エラー出力がないことを確認した
