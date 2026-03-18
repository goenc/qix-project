区分補助線を独立管理し終点再計算対応

・曲がる直前方向を通知する signal を base_player.gd に追加し、trail_points とは別に補助線生成の契機を取れるようにした
・base_main.gd に guide_segments を追加し、remaining_polygon と claimed_polygons の境界から終点を再計算する赤い補助線描画を実装した
・headless のスクリプト構文確認と base_main シーンの headless 非 headless 起動確認を実施した
