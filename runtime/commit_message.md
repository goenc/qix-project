capture 後の guide 再解決対象を差分ベースで絞り込む

・guide に capture_generation を付与し 今回生成 guide と既存 guide を判別できるようにした
・今回生成 guide のうち END が今回 captured polygon 内にあるものを論理削除するようにした
・既存 guide のうち capture delta に触れたものだけ start 起点で再解決するようにした
・Godot 4.6.1 の headless 起動と通常起動が終了コード 0 で通ることを確認した