BOSS被弾判定と自機HPを追加

・BOSS被弾判定と自機HPおよびゲームオーバー表示を追加した
・BasePlayer に外周通常、外周Shift押下、内部侵入、巻き戻し中の被弾対象判定と HP3 と無敵時間と PickArea の有効制御を追加した
・BBOS にプレイヤー本体と描線の命中判定を追加し、BasePlayer の現在リスク状態に応じてダメージ対象を切り替えるようにした
・既存 HUD に HP 表示とゲームオーバー表示を追加した
・C:\Godot\godot_console.exe --headless --path . --quit-after 1 を実行した
・C:\Godot\godot_console.exe --headless --path . -s res://runtime/tmp_damage_check.gd で外周とShiftと内部侵入と巻き戻しとHP減少と無敵時間を確認した後に確認用スクリプトを削除した