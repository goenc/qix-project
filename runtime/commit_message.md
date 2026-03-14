Shift解放時の侵入線巻き戻しを追加

・Shift解放時に侵入線を破棄せず始点まで逆順で巻き戻すROLLBACK状態を追加
・PlayerState に ROLLBACK と巻き戻し用メンバを追加し、_process と get_state_text と移動拘束を新状態対応に更新
・Shift解放時に _start_rollback へ遷移し、trail_points を保持したまま _process_rollback で線を縮めながら開始点へ戻す処理を追加
・_finish_rollback で外周復帰時に trail_line をクリアし、既存の _finish_drawing による閉路完了フローは維持
・tools/run.ps1 を別プロセスで起動し、Godot が起動したことを確認後に停止
