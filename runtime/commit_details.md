日時: 2026-03-15 15:04:23 JST
summary: 切り取り後の残存領域だけを新しい有効外周として再構築し 薄い無効外周表示と移動制限を同期した
target: scripts/game/base_main.gd, scripts/player/base_player.gd
code_changes:
・BaseMain で claim 確定後に remaining_polygon と active_border_loop を更新し 旧外周の非採用区間を薄い線として保持するよう変更した
・BasePlayer で active_border_loop ベースの進行距離 許可領域判定 snap 接線計算へ置き換え 新しい白線上だけ移動できるよう変更した
verification:
・base_main シーンを headless 実行し 終了コード 0 で構文確認が通ることを確認した
