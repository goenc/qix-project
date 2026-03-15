BBOS を固定出現する敵として追加

・BaseMain に BBOS インスタンスを追加し playfield_rect の適用を共通化した
・BBOS の scene と script を追加し 64x64 の見た目と当たり判定を定義した
・BBOS がプレイフィールド内へ一度だけランダム出現し 画面サイズ変更時は場内へ clamp されるようにした
・ヘッドレスで base_main.tscn を起動し 終了コード 0 を確認した
