外形角の先行入力予約と線分遷移を安定化

・BasePlayer に角手前の予約入力と頂点到達時の安定した線分選択と BORDER 描画開始の安全確認を追加
・短辺連続と再同期直後でも border state の point と segment と distance を揃える補助処理を追加
・player 専用の headless 検証スクリプトを追加し 矩形4角と非矩形 loop の移動確認を実施