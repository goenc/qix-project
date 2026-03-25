未切断面積基準へゲームクリア判定を変更

・base_main.gd のクリア判定を remaining_polygon 面積比へ変更
・remaining_polygon が無効な場合は -1.0 扱いにして誤判定を防止
・Godot headless 起動で構文確認を実施
