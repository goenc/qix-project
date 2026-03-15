外周ループ共有で自機移動とBBOS反射を統一

・外周ループ演算と trail 分割を playfield_boundary に集約した
・BaseMain で capture_closed を受けてボス側の残存外周を選択し Player と BBOS へ再配布するようにした
・BasePlayer を active_outer_loop 基準の外周移動へ差し替えた
・BBOS を active_outer_loop 全線分との最初の衝突で反射する方式へ置換した
・Godot 4.6 headless で初期矩形、L 字、凸凹の 3 状態を検証した