紫塗り生成をremaining polygon交差方式へ置換して欠けを修正

・guide partition の塗り結果生成を claimed 差分方式から entry矩形と remaining polygon の交差方式へ変更
・交差結果の有効ポリゴンのみ保存し remaining polygon 不正時や交差なし時は pair キーを削除する挙動へ統一
・capture 後の塗り結果更新を touched pair 局所更新から全 pair 再計算へ変更して古いキャッシュ残りを防止
・godot_console headless 起動でデバッグ実行確認を実施し終了コード0を確認
