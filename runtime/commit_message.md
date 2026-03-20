最新キャプチャで作成した縦補助線起点の左右探索へ区画判定を変更

・scripts/game/base_main.gd の _collect_guide_partition_rects() を隣接ペア方式から左右探索方式へ置き換えた。
・mid_x から current_outer_loop の水平外形線をたどって上下境界を求める既存方針と、claimed_polygons の内側除外を維持した。
・godot.exe --headless --path . --check-only で構文確認を行い成功した。
