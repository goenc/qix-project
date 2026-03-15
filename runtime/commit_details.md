日時: 2026-03-15 17:29:43 +09:00
summary: BOSSが細い通路で停止せず現在半径に応じて入口反射するよう修正
対象:
・scripts/enemy/bbos.gd
・scripts/game/playfield_boundary.gd
code_changes:
・active_inner_loop が作れない形状でも移動停止せず outer loop 基準の円形侵入判定へフォールバックするように変更
・現在の collision_radius で通行可否を判定する補助と inset loop 不成立時の局所ヒット検出を playfield_boundary に追加
・狭い通路の入口では進入方向を返す法線を優先し反射後に押し戻して再侵入しにくくした
verification:
・Godot headless の check-only で scripts/enemy/bbos.gd の構文確認が成功
・Godot headless の check-only で scripts/game/playfield_boundary.gd の構文確認が成功
・Godot headless でプロジェクトを 1 フレーム起動して正常終了を確認
・一時確認スクリプトで細い通路の入口反射と半径縮小後の通行を確認
