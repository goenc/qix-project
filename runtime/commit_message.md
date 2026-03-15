QIXの囲み確定表示を追加

・QIXの囲み確定表示とCLAIMED更新を追加
・BasePlayerの描画完了時に開始点と終了点と複製した軌跡を通知するsignalを追加した
・BaseMainに外周経路から候補領域を作る分割処理とボス不在側のclaimed描画とCLAIMED比率更新を追加した
・BaseMainシーンにBossノードを追加してBBOS位置を参照できるようにした
・C:\Godot\godot.exe --headless --path . --scene res://scenes/base_main.tscn --quit-after 1で起動確認した