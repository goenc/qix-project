日時: 2026-03-14 21:58:56 +09:00
summary: QIX風ベース画面のプレイ領域と外周描線の基礎を実装
対象:
res://scenes/base_main.tscn
res://scripts/game/base_main.gd
res://scripts/player/base_player.gd
code_changes:
・base_main に左寄せのプレイ領域矩形描画と右 HUD 更新と qix_draw 入力登録を追加した
・BasePlayer を BORDER と DRAWING の2状態へ置き換え 外周移動と TrailLine による描線開始終了を実装した
verification:
・godot_console --headless --path . --scene res://scenes/base_main.tscn --quit-after 2 が成功した
・godot_console --headless --path . --scene res://scenes/title_main.tscn --quit-after 2 が成功した
・tools/run.ps1 の起動を確認し Godot プロセスを停止して終了した
