日時: 2026-03-20 09:45:41
対象:
- scripts/enemy/bbos.gd
- tools/verify_outer_loop.gd
- tools/verify_player_border_corner.gd
- tools/verify_shared.gd
変更:
・verify_outer_loop の BBOS 反射失敗は initial rectangle と first L capture と second jagged capture の全段階で共通に発生しており raw outer loop を叩く検証前提が BBOS の実効反射ループとずれていたため BBOS に反射ループ取得口を追加し検証をその基準へ統一した。
・player 外形角移動検証の重複補助関数を tools/verify_shared.gd に集約し 2 本の verify から共通利用する形へ最小限で整理した。
確認:
・Godot headless で tools/verify_outer_loop.gd が成功した。
・Godot headless で tools/verify_player_border_corner.gd が成功した。
・Godot 非 headless で base_main を 120 フレーム起動して正常終了した。
