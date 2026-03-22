ボス領域比率をBBOS直径へ反映

・boss_region_ratio_cached を BBOS へ渡し初期化時と再計算時に再反映する処理を追加
・BBOS のサイズ更新を base 直径と領域比率ベースへ変更し最低直径を元サイズの一割に固定
・Godot headless で base_main.gd と bbos.gd の check only を実行し短時間起動確認を実施