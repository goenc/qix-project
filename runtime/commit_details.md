日時: 2026-03-19 16:42:26 JST
対象:
- scripts/player/base_player.gd
- scripts/game/base_main.gd
- HUD通知とtrail cacheとboss marker同期の頻度制御
変更:
・base_player の HUD 通知を state と position に分離し position は一定距離移動時のみ通知するようにして mode と HP 系は即時反映のまま維持した
・visible_points が前回と同一のときは trail damage cache を再生成しないようにして drawing と rewinding の見た目と当たり判定仕様は維持した
・base_main の boss marker 同期は前回同期位置と現在 marker 位置の両方を見て同一座標への再代入だけを省略するようにした
確認:
・Godot 4.6.1 で base_main の headless 起動と非 headless 起動が成功することを確認した
・headless 回帰スクリプトで drawing と rewinding の通知、capture 完了、pending guide cleanup、BBOS の反射と player と trail への hit、HP と HUD と GAME OVER、pause、title scene 初期化を確認した
