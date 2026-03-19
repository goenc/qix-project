capture後のguide再計算を差分更新化

・capture ごとの差分 polygon と inactive border segment から dirty guide を抽出するよう変更
・dirty guide だけ `_resolve_guide_segment(..., true)` を再実行するよう変更
・Godot 4.6.1 で scenes/base_main.tscn の headless 起動と通常起動を確認
