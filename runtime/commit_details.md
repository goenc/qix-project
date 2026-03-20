base_main.gd:
- add current_outer_loop_metrics and refresh it when the outer loop changes
- pass cached metrics into split_outer_loop_by_trail
- compute added_claimed_area and per-capture AABBs in _append_claimed_capture_results
- update claimed_area by delta and append AABB deltas during finalize

playfield_boundary.gd:
- add an optional metrics argument to split_outer_loop_by_trail
- reuse provided metrics when they match the current loop size

Validation:
- godot --headless --path . --check-only

日時: 2026-03-20 11:03:56 JST
対象:
- scripts/game/playfield_boundary.gd
- scripts/enemy/bbos.gd
変更:
・BOSS の反射法線を fallback 優先にして角での軸丸めを抑え、反射後の押し戻し量を縮小した。
確認:
・Godot を headless で起動し、プロジェクト読み込みの成功を確認した。

日時: 2026-03-20 11:25:20 JST
対象:
- scripts/enemy/bbos.gd
- scripts/game/playfield_boundary.gd
変更:
・BBOS の境界判定をキャッシュ済みの内側ループ優先に切り替え、毎フレームの inset 再構築を避けるようにした。
・凹角で同一点付近の連続衝突を角はまりとして扱い、軽い脱出補正とクールダウンを追加した。
確認:
・Godot を headless で構文確認し、非ヘッドレスでも windowed 起動を自動終了付きで確認した。
