日時: 2026-03-17 15:47:02 +09:00
対象: scripts/game/base_main.gd
summary: 切断後の前景背景ポリゴン更新経路を共通化し切られた側で後景画像が見えるように修正
code_changes:
・stage_cover_polygon を _rebuild_stage_cover_polygon_from_polygon 経由で確定するようにし 初期化時と capture 確定時の両方で同じ経路を通すようにした
・capture 確定時は retained_candidate の polygon を優先して前景描画用 polygon を再構築し 残存 polygon と前景 polygon のサイズを最小ログで確認できるようにした
verification:
・C:\Godot\godot.exe --headless --path . --script scripts/game/base_main.gd --check-only
・Godot headless の一時検証スクリプトで capture 後に stage_cover_polygon が remaining_polygon と一致し claimed 側が前景 polygon 外になることを確認
