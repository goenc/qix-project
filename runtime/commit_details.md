日時: 2026-03-15 02:44:37 +09:00
summary: Shift押下中の内部移動を4方向化して斜め軌跡を防止した
対象: scripts/player/base_player.gd
code_changes:
・DRAWING専用の入力方向決定を追加し、最後に押した方向の軸だけを残すようにした
・軸切り替え時にコーナーポイントを追加し、trailの各区間が水平線か垂直線だけになるようにした
verification:
・godot_console --headless --path . -s res://runtime/verify_drawing_lock.gd で内部移動の軸固定と軌跡の直交性を確認した
・tools/run.ps1 で Godot 4.6.1 の起動を確認した
