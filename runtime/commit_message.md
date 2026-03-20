横切り後の区画塗り保持を定義層と描画結果層に分離して String エラーを除去

・base_main.gd で String(...) を全廃し _stringify_value に統一
・補助線区分エントリを区画定義専用にし 描画結果は guide_partition_fill_polygons_by_key へ分離
・capture 後更新を prune と定義再生成と claimed 差し引き後 fill 再生成に分割
・headless 構文確認と outer_loop/player_border 検証スクリプトが成功