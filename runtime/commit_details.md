日時: 2026-03-20 16:26:21
対象:
- scripts/game/base_main.gd
変更:
・補助線区分のベース矩形から claimed_polygons を多角形クリップで差し引いた描画ポリゴン配列を保持し、claimed 領域を除いた残りのみ薄紫描画するよう変更した。
確認:
・godot --headless --path . --check-only を実行し終了コード 0 で成功を確認した。
