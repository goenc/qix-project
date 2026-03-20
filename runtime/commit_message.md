外形角の先行入力予約で最新入力を優先するよう修正

・頂点到達時に最新入力で辺選択を再判定し queued を fallback のみに変更
・queued の整合性検証と active outer loop 更新時のクリアを追加
・矩形と非矩形の角入力検証に最新入力優先ケースと queued fallback ケースを追加
・headless と非 headless の verify_player_border_corner.gd が initial rectangle と first L capture と second jagged capture を通過
・verify_outer_loop.gd の BBOS 反射確認は既存失敗を再確認