capture後補正の補助線終端を境界再取得に修正

・有効領域への進入点と離脱有無を返すよう補正用走査結果を見直し 補正後ENDの最終決定を capture 補正側へ集約
・有効領域から抜けた場合は 最初の有効点以降の区間で既存基準の境界ヒットを再取得し 内部点で終わらないよう修正
・godot_console --headless --path . --editor --quit で headless 起動確認を実施
