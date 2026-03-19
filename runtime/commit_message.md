HUD通知とtrail cacheとboss marker同期の更新頻度を安全に削減

・base_player の HUD 通知を state と position で分離し position は一定距離移動時のみ通知するようにした
・visible trail が変化しないフレームでは trail damage cache を再構築しないようにした
・base_main の boss marker 同期で同一座標の再代入を抑制し marker drift は再同期で戻すようにした
・Godot 4.6.1 で headless 起動と非 headless 起動と headless 回帰確認を実施した
