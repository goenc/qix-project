base_player の当たり判定デバッグ表示を修正

・BasePlayer を debug_player_collision グループに登録して既存 PickArea の CollisionShape2D を Hitbox Overlay の描画対象に含めた
・headless 検証で object select の候補取得と当たり判定の移動追従を確認した
・tools/run.ps1 でプロジェクト起動確認を行い 新規エラーがないことを確認した
