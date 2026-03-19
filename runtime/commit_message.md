guide の dirty 抽出を座標インデックス化

・scripts/game/base_main.gd で縦横 guide の軸座標インデックスを管理し guide 追加時と再構築時に登録するよう変更
・capture 差分 AABB に重なる x と y の座標帯から候補 guide のみを収集し 最終 dirty 判定は既存ロジックを維持
・headless 起動と通常起動を短時間実行し エラーなく終了することを確認
