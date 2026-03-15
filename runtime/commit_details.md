日時: 2026-03-15 13:16:21 JST
summary: 内部侵入中の移動候補が既存の内部線と交差・重なり・端点接触する場合に停止するようにした
target: scripts/player/base_player.gd
code_changes:
・描画中の候補セグメントを既存の trail_points と現在位置から組み立てた内部線に対して判定し無効移動を early return するようにした
・軸平行セグメント専用の交差・重なり・端点接触判定 helper を追加し直前隣接セグメントの共有端点だけ除外した
verification:
・tools/run.ps1 を起動してアプリケーション開始を確認した
