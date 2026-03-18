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
・Godot を通常起動してプロジェクトが起動できることを確認した