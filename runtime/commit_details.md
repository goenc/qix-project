日時: 2026-03-18 23:45:08 JST
対象:
- debug/manager/debug_manager_window.tscn
- debug/manager/debug_manager_window.gd
- debug/DebugManager.gd
- scripts/game/base_main.gd
変更:
・デバッグマネージャーに縦補助線と横補助線の表示トグルを追加しゲーム画面へ即時反映する連携を実装した
・base_main.gd の補助線描画に縦横別の表示スキップ条件を追加し既存の色と内部データを維持した
確認:
・Godot を headless で起動して構文エラーなく読み込めることを確認した
・Godot を通常起動してプロジェクトが起動できることを確認した日時: 2026-03-19 09:53:50 JST
対象:
- scripts/game/base_main.gd
変更:
・区分補助線の capture 後補正を END 側からの逆走査ではなく START から最初の有効連続区間を探す順走査へ変更した
確認:
・Godot headless の check only で scripts/game/base_main.gd の構文確認を実施した
・Godot を通常起動して 3 秒の自動終了まで起動確認を実施した