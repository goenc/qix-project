日時: 2026-03-19 14:59:14 +09:00
対象:
- scripts/game/base_main.gd
変更:
・guide に capture_generation を付与し capture 後の dirty guide を今回生成 guide の削除と既存 guide の start 起点再解決に分類する処理へ変更
確認:
・Godot 4.6.1 で headless 起動と通常起動を quit-after 120 付きで実行し 終了コード 0 を確認