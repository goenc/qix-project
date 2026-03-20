capture_actions の index 抽出を型安全化して縦補助線差分更新時の実行時エラーを修正

・confirm remove reresolve の action ごとに index 取り出しを分岐し int float string 以外を無視する処理を追加
・_collect_affected_vertical_guide_keys_from_capture_actions と _apply_capture_guide_actions で範囲外と不正型を安全にスキップするよう修正
・C:\Godot\godot.exe --headless --path . --check-only を実行して成功を確認
・C:\Godot\godot.exe --headless --path . --script tools/verify_outer_loop.gd を実行して成功を確認
