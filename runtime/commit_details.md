日時: 2026-03-19 14:43:12 +09:00
対象:
- scripts/game/base_main.gd
変更:
・guide の軸座標インデックスを追加し capture 差分 AABB に重なる座標帯から dirty guide 候補を抽出するよう変更
確認:
・godot_console で headless 起動と通常起動を短時間実行し エラーなく終了することを確認
