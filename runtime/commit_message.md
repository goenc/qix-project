横切り後の紫区画更新で touched pair_key を反映して再生成漏れを防止

・capture 後に触れた区画定義の pair_key を prune 削除、guide 刷新削除、upsert 追加・上書きから収集するようにした。
・描画結果削除は削除対象 pair_key のみに限定し、再生成は update_region 交差または touched 所属または結果欠落の entry を対象にした。
・headless で verify_outer_loop、verify_player_border_corner、通常起動 quit を実行し成功を確認した。

