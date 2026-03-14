debug pause と base_player 選択を修正

・title_main と base_main の両方で debug pause が成立するように修正
・base_player に物理ピック用の Area2D と CollisionShape2D を追加し、object inspector でクリック選択できるように修正
・base_player を PROCESS_MODE_PAUSABLE にして pause 中の移動を停止
・DebugManager の pause controller 呼び出しを安全化
・tools/run.ps1 の起動継続と headless 実行の正常終了を確認
