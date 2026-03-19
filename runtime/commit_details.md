日時: 2026-03-19 15:24:33 JST
対象:
- scripts/game/base_main.gd
変更:
・capture 中に生成した補助線を pending 扱いにして仮表示だけを行い capture 確定後にだけ確定解決と削除判定を行うよう整理した
確認:
・Godot 4.6.1 で base_main シーンを headless と通常起動の両方で 30 iteration 起動しエラーなく終了することを確認した