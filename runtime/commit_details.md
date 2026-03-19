日時: 2026-03-19 15:24:33 JST
対象:
- scripts/game/base_main.gd
変更:
・capture 中に生成した補助線を pending 扱いにして仮表示だけを行い capture 確定後にだけ確定解決と削除判定を行うよう整理した
確認:
・Godot 4.6.1 で base_main シーンを headless と通常起動の両方で 30 iteration 起動しエラーなく終了することを確認した日時: 2026-03-19 16:16:58 JST
対象:
- scripts/game/base_main.gd
- scripts/player/base_player.gd
- scripts/enemy/bbos.gd
変更:
・base_main の HUD 更新と pending guide 掃除を player / BBOS の変化通知へ移し、guide 軸キーと claimed / inactive border の AABB を追加して capture 差分時だけ重い再解決を行うようにした。
・base_player に debug 状態通知と trail 当たり判定キャッシュを追加し、bbos に swept AABB による player / trail 候補絞り込みと position_changed 通知を追加した。
確認:
・Godot 4.6.1 で headless 起動と非 headless 起動をそれぞれ quit-after 1 で実行し、起動エラーが出ないことを確認した。
