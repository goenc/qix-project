敵接触時に侵入開始位置へ自機を復帰するよう修正

・BasePlayer に侵入開始 border 座標の保持変数を追加し BORDER から DRAWING へ入る瞬間の座標を保存するよう修正
・apply_boss_damage で DRAWING と REWINDING 時だけ保存座標へ戻し trail_points の破棄と状態復帰を行うよう修正
・finish_rewinding の共通復帰処理を追加し trail_line が残らないよう整理
・Godot headless で BasePlayer と BBOS のスクリプト読み込み確認を実施
