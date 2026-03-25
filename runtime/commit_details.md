・`scripts/game/base_main.gd` のゲームクリア演出だけを調整しました
・`clear_reveal_speed` を 0.6 に下げ、黒い前面の消え方を遅くしました
・クリア演出時のみ外形線を cutoff_y でクリップして、黒い前面と同じ進行で消えるようにしました
・通常プレイ中の外形線描画と、ボス非表示 / GAME CLEAR / ESC 遷移の挙動は維持しています
・`godot.exe --headless --path . --check-only --script res://tools/verify_outer_loop.gd` で構文読み込み確認を行いました
