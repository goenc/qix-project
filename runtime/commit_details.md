日時: 2026-03-20 15:34:28
対象:
- scripts/game/base_main.gd
変更:
・capture_actions の confirm remove reresolve から縦補助線 index を型安全に抽出するヘルパーを追加し int の不正呼び出しを除去した。
・差分更新フローは維持したまま affected keys 抽出と適用処理に範囲チェックと型判定を入れて実行時エラーを防止した。
確認:
・C:\\Godot\\godot.exe --headless --path . --check-only が成功することを確認した。
・C:\\Godot\\godot.exe --headless --path . --script tools/verify_outer_loop.gd が成功することを確認した。
