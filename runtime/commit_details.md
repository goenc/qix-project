日時: 2026-03-15 02:56:21 JST
対象: scripts/player/base_player.gd
summary
内部移動を四方向限定に保ったまま Shift 離しの巻き戻しと再押下での途中再開を BasePlayer に追加した。
code_changes
・PlayerState に REWINDING を追加し巻き戻し開始 中断 完了の状態遷移を実装した。
・内部移動の入力方向を最後に押した方向優先で四方向に制限する専用関数へ整理した。
・trail_points と TrailLine を現在位置ベースで再構築し巻き戻し中と再開後の表示同期を維持した。
verification
・godot_console --headless --path . --quit で起動確認に成功した。
・tools/run.ps1 の起動確認に成功した。
