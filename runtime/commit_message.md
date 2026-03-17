タイトル開始入力を qix_start に分離

・project.godot に qix_start を追加し Enter Space A START をタイトル開始専用入力として登録
・title_main.gd の開始判定を qix_start ベースの _input に変更し setup 後にウィンドウフォーカスを戻す処理を追加
・title.gd の開始文言を PRESS A / ENTER TO START に変更
・Godot headless で対象スクリプトの check-only とプロジェクト短時間起動を確認
