補助線区分塗りを claimed 領域差し引き方式へ変更

・scripts/game/base_main.gd の補助線区分保持を描画ポリゴン配列対応に変更した
・ベース矩形から claimed_polygons を Geometry2D.clip_polygons で差し引き、残存領域のみ描画するようにした
・既存エントリ再評価時にも差し引き結果を再計算するよう更新した
・godot --headless --path . --check-only の成功を確認した
