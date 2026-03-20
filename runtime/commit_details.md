日時: 2026-03-20 16:47:09 JST
対象:
- scripts/game/base_main.gd
変更:
・縦補助線をx単位の1本代表からxとtop_yとbottom_yを持つ区間キー管理へ変更し同一xの複数区間を保持するように修正
・区画生成を左右区間のy重なり必須に変更し重なり帯で外形水平線を解決して上下分断後も別区画を生成可能に修正
・capture_deltaのAABBとaffected_vertical_guide_keysから更新帯を算出して影響エントリのみ削除再構築する差分更新へ変更
確認:
・godot --headless --path . --quit を実行し終了コード0を確認
日時: 2026-03-20 21:46:43
対象:
- scripts/game/base_main.gd
変更:
・guide_partition_fill_entries を区画定義専用にし、描画結果を guide_partition_fill_polygons_by_key へ分離して capture 後更新を prune、定義再生成、fill 再生成へ段階化した
・String(...) を _stringify_value 経由の str(...) へ置換し、capture action index と interval key の文字列化で constructor 呼び出しを排除した
確認:
・C:\Godot\godot.exe --headless --path . --script scripts/game/base_main.gd --check-only が成功
・C:\Godot\godot.exe --headless --path . --quit-after 1 が成功
・C:\Godot\godot.exe --headless --path . --script tools/verify_outer_loop.gd が成功し initial、L、jagged capture の検証が通過
・C:\Godot\godot.exe --headless --path . --script tools/verify_player_border_corner.gd が成功