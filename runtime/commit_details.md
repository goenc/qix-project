日時: 2026-03-15 13:28:50 JST
summary: 内部線への手前停止を接触点停止へ変更
対象:
scripts/player/base_player.gd
code_changes:
・既存内部線との判定を最初の接触点を返す方式へ変更した
・描画移動を接触点まで進めて接触後も既存内部線の跨ぎと重なりを継続禁止にした
verification:
・git show 38c6e63 -- scripts/player/base_player.gd で不具合原因を確認した
・tools/run.ps1 を実行し Godot プロセスの起動を確認した
