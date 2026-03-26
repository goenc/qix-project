切り抜き評価バーを追加

・上部に評価バーと切り抜き率表示を追加し初期値50で開始するようにした
・一回分の added_claimed_area から評価増減を計算し 0 から 100 に clamp するようにした
・閾値と増減値と評価バー帯高さと BAD GOOD 文言を専用 service に集約した
・godot_console --headless --path . --quit で起動確認した
・godot --path . --quit-after 2 で非 headless 起動確認した
・godot_console --headless --path . --script runtime/cut_rating_smoke.gd 実行時に区間判定と clamp を確認した
