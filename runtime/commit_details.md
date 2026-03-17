日時(JST): 2026-03-17 16:17:20 JST
summary: 入力登録共通化とcapture処理整理でe68a550時点の挙動を維持した
対象:
・scripts/common/input_action_utils.gd
・scripts/ui/title_main.gd
・scripts/game/base_main.gd
code_changes:
・InputMap 反映と InputEvent 生成だけを共通 helper に切り出し title と game の既存 action 登録仕様を維持した
・capture_closed 処理を epsilon 解決と loop 選定と claimed 反映と最終反映に分割し更新順と warning 条件を維持した
・stage cover の常設ログを削除し polygon と UV の再構築だけを担う構成へ整理した
verification:
・godot_console.exe --headless --path . --check-only --script res://scripts/common/input_action_utils.gd
・godot_console.exe --headless --path . --check-only --script res://scripts/ui/title_main.gd
・godot_console.exe --headless --path . --check-only --script res://scripts/game/base_main.gd
・godot_console.exe --headless --path . --quit-after 5
・headless SceneTree 検証で title→base の InputMap と qix_draw と pause と qix_start と capture_closed signal と stage_cover_polygon/UV を確認した