QIX初期プロジェクト化で旧アクション構成を撤去

・QIX初期プロジェクトとして旧アクションゲーム構成を撤去し、タイトルから移動確認できる最小導線へ整理した
・project.godot から GameRoute autoload を削除し、プロジェクト名を初期構成向けに更新した
・title_main と base_main の導線を維持したまま、タイトル文言と入力定義を最小構成向けに整理した
・旧ゲーム用の scene script asset config と対応する uid を、参照確認後に削除した
・godot_console --path . --headless --quit-after 5 が成功した
・tools/run.ps1 で Godot ウィンドウ起動を確認した
・一時検証スクリプトで title_main から base_main への遷移と base_player の右移動と ESC 復帰を確認した