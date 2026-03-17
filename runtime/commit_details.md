日時: 2026-03-17 11:04:03 +09:00
対象: タイトル画面の開始入力
変更:
・project.godot に qix_start を追加し Enter Space A START をタイトル開始専用入力として明示した
・title_main.gd の開始判定を qix_start ベースの _input に切り替え setup 後にウィンドウフォーカスを戻す処理を追加した
・title.gd の開始文言を PRESS A / ENTER TO START に変更した
確認:
・Godot headless で title_main.gd の check-only が成功した
・Godot headless で title.gd の check-only が成功した
・Godot headless でプロジェクトを quit-after 2 で起動しエラーなく終了した
