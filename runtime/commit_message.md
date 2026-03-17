ゲーム画面の枠内背景を二層化

・scripts/game/base_main.gd に 904x640 の playfield rect と stage_cover_polygon API を追加
・scripts/game/base_main.gd の _draw で枠内後景の常時表示と前景 polygon 描画を追加
・assets/backgrounds/stages に remaining_background_904x640.png と cover_background_904x640.png を追加して指定パスへ整合
・Godot headless で base_main.gd の check-only と base_main.tscn の短時間起動を確認
