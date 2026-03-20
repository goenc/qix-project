日時: 2026-03-20 09:29:48 JST
対象:
- scripts/player/base_player.gd
- tools/verify_outer_loop.gd
- tools/verify_player_border_corner.gd
変更:
・外形角の queued を事前候補に限定し頂点到達時は最新入力の再判定を最優先するよう修正
・queued の整合性検証と active outer loop 更新時のクリアを追加し誤適用を防止
・矩形と非矩形の角入力検証に最新入力優先ケースと queued fallback ケースを追加
確認:
・headless と非 headless の verify_player_border_corner.gd で initial rectangle と first L capture と second jagged capture が通過することを確認
・headless と非 headless の verify_outer_loop.gd で BBOS 反射確認が既存失敗のまま再現することを確認