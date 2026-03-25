ボス領域15％以下でゲームクリア判定を追加

・scripts/game/base_main.gd に game_clear 状態を追加
・boss_region_ratio_cached 更新直後に 0.15 以下判定を実施
・HUD と debug pause の分岐をクリア状態対応に整理
・一時検証でクリア遷移、debug pause、GAME OVER を確認
