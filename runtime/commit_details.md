日時: 2026-03-20 16:47:09 JST
対象:
- scripts/game/base_main.gd
変更:
・縦補助線をx単位の1本代表からxとtop_yとbottom_yを持つ区間キー管理へ変更し同一xの複数区間を保持するように修正
・区画生成を左右区間のy重なり必須に変更し重なり帯で外形水平線を解決して上下分断後も別区画を生成可能に修正
・capture_deltaのAABBとaffected_vertical_guide_keysから更新帯を算出して影響エントリのみ削除再構築する差分更新へ変更
確認:
・godot --headless --path . --quit を実行し終了コード0を確認
