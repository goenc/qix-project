日時: 2026-03-14 20:56:17 JST
対象: base_player の当たり判定デバッグ表示
summary: base_player の Hitbox Overlay 表示対象漏れを修正した
code_changes:
・BasePlayer ルートを debug_player_collision グループに登録し 既存の PickArea と CollisionShape2D を Overlay 描画対象に含めた
verification:
・headless 検証で BasePlayer のグループ登録 PickArea の debug_pick_owner object select の候補取得 移動時の CollisionShape2D 追従を確認した
・tools/run.ps1 起動確認で title_main を起点にプロジェクトが正常起動し 即時クラッシュや新規エラーがないことを確認した
変更:
・BasePlayer の scene ルートに debug_player_collision グループを追加した
確認:
・Hitbox Overlay の描画条件と object select の利用条件を既存実装のまま満たすことを確認した
