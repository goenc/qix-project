前景背景ポリゴン更新経路を共通化して切断面の後景表示を修正

・stage_cover_polygon を初期化時と capture 確定時の両方で _rebuild_stage_cover_polygon_from_polygon 経由に統一した
・retained_candidate の polygon から前景描画用 polygon を再構築し remaining_polygon と stage_cover_polygon の最小ログを追加した
・Godot headless の check-only と一時検証で capture 後に retained 側のみ前景が残ることを確認した
