日時: 2026-03-15 02:18:54 JST
summary: Shift保持中のみ内側移動を継続し離した瞬間に未確定線を破棄して外周へ戻す仕様を追加
対象: scripts/player/base_player.gd
code_changes:
・DRAWING状態の先頭でqix_draw保持を判定し、離していたらそのフレームでキャンセルしてBORDERへ戻るようにした
・未確定trail_pointsとTrailLineをクリアし、現在位置を最寄り外周へスナップしてborder_progressと見た目を復帰する処理を追加した
verification:
・tools/run.ps1 を起動し、起動確認後に確認用プロセスを終了した

