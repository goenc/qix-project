広域ポーリングを外して capture 差分中心に軽量化

・base_main の HUD 更新と pending guide 掃除をイベント駆動へ移行
・guide 軸キーと claimed / inactive border の AABB で guide / claimed 判定の前段を軽量化
・base_player の trail キャッシュと bbos の swept AABB で当たり判定候補を絞り込み
・Godot 4.6.1 の headless / 非 headless 起動で確認