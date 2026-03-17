BBOS の見た目を black_hole 画像へ差し替え

・BBOS の赤い四角表示を black_hole 画像へ置き換え、Body のみを右回転させるようにした。
・scenes/enemy/bbos.tscn の Body を Polygon2D から Sprite2D に差し替え、res://assets/enemy/black_hole.png を中心基準かつ約 64x64 相当で表示する設定にした。
・scripts/enemy/bbos.gd に body_rotation_speed_deg と Body 参照を追加し、_process の先頭で Body のみ正の角速度で回転させる処理を加えた。
・C:\Godot\godot_console.exe --headless --editor --quit --path . で debug build 相当のアセット再インポートを実施した。
・headless 検証で Body が Sprite2D として black_hole.png を参照し、_process 呼び出しで回転角が増加することを確認した。
