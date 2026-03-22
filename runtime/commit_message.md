自機表示を Sprite2D の方向付き歩行アニメへ変更

・base_player.tscn の Body を Soldier 01-1.png を使う Sprite2D に置き換え、3列4行の初期停止コマを設定
・base_player.gd の body 参照を Sprite2D 化し、state 色変更を modulate に変更
・移動入力と実移動方向に応じた向き保持と 左 中 右 中 の歩行フレーム更新を追加
・headless 検証で方向行と停止コマと歩行シーケンスと無敵時半透明を確認
・headless 起動と GUI 起動でプロジェクトがエラーなく立ち上がることを確認