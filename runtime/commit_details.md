日時: 2026-03-18 23:23:32 +09:00
対象:
- scripts/player/base_player.gd
- scripts/game/base_main.gd
変更:
・曲がり通知で旧方向と新方向を渡し base_main 側で曲がり点から旧方向と新方向逆向きの guide を2本追加するよう拡張した
確認:
・headless で base_main シーンを起動し解釈エラーが出ないことを確認した
・通常起動で base_main シーンが起動してすぐ終了できることを確認した
