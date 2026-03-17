日時: 2026-03-17 16:50:32 JST 対象: BBOS の見た目差し替え summary: BBOS の赤い四角表示を black_hole 画像へ置き換え、Body のみを右回転させるようにした。 code_changes: ・scenes/enemy/bbos.tscn の Body を Polygon2D から Sprite2D に差し替え、res://assets/enemy/black_hole.png を中心基準かつ約 64x64 相当で表示する設定にした。 ・scripts/enemy/bbos.gd に body_rotation_speed_deg と Body 参照を追加し、_process の先頭で Body のみ正の角速度で回転させる処理を加えた。 verification: ・C:\Godot\godot_console.exe --headless --editor --quit --path . で debug build 相当のアセット再インポートを実施した。 ・headless 検証で Body が Sprite2D として black_hole.png を参照し、_process 呼び出しで回転角が増加することを確認した。

日時: 2026-03-17 23:12:28 JST
対象: BBOS のサイズ調整
summary: BBOS の縦サイズを viewport 高の半分に自動同期するようにした。
code_changes:
・scripts/enemy/bbos.gd に viewport 高比率 0.5 のサイズ同期処理を追加し、ready 時と viewport サイズ変更時に BBOS のスケールを更新するようにした。
・scripts/enemy/bbos.gd で見た目スケール変更に合わせて collision_radius も同期し、反射や被弾の当たり判定を表示サイズと一致させた。
verification:
・C:\Godot\godot.exe --headless --path . --scene res://scenes/base_main.tscn --quit-after 1 が成功し、BBOS を含むベースシーンの初期化が通ることを確認した。