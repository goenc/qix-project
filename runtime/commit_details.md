日時: 2026-03-15 01:57:22 +09:00
対象: qix-project
summary: qix_draw を Shift のみにし描画開始直後の白線上移動拒否条件を明確化
code_changes:
・qix_draw の入力割り当てを Shift のみに変更し Z 割り当てを削除
・描画開始直後に白線上から白線上への移動を拒否する条件を既存挙動のまま明示化
verification:
・tools/run.ps1 を実行し Godot が起動継続したため 20 秒タイムアウトまで起動時エラーなしを確認
