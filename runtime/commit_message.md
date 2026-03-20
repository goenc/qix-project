補助線区分の薄紫表示をボス直径連動の縦補助線長条件で制限

・scripts/game/base_main.gdで薄紫矩形の追加時に左右縦補助線長とボス直径1.2倍の比較条件を追加
・保持済みguide_partition_fill_entriesの剪定時にも同条件を適用して再評価時の不整合を防止
・C:\Godot\godot.exe --headless --path . --check-only で構文確認済み
