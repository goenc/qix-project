日時: 2026/03/20 15:09:07
対象:
- scripts/game/base_main.gd
- runtime/commit_details.md
- runtime/commit_message.md
変更:
・最新キャプチャで作成した縦補助線を起点に左右の既存有効縦補助線を探索して矩形候補を作るように変更した。
確認:
・godot.exe --headless --path . --check-only で構文確認が成功した。
日時: 2026/03/20 15:22:35
対象:
- scripts/game/base_main.gd
変更:
・補助線区分の薄紫矩形を保持配列から描画し、最新キャプチャで確定した縦補助線を起点に左右の既存有効線だけを使う差分更新へ変更した。
確認:
・godot.exe --headless --path . --check-only で構文確認が成功した。
