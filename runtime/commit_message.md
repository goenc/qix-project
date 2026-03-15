BOSSの反射判定を円形基準へ変更

・BOSSの反射判定を中心点基準から円形基準へ変更した
・bbos.gd で collision_radius と min_collision_radius を追加し、生成範囲と反射後補正を円形中心基準へ置き換えた
・playfield_boundary.gd に直交多角形用の内側オフセット生成と円形反射用ヘルパーを追加した
・Godot headless の check-only で対象 2 スクリプトの構文確認を実施した
・Godot headless の 1 フレーム起動でプロジェクト読み込み時エラーが出ないことを確認した
・一時検証スクリプトで半径32の手前反射、半径縮小時の進入量増加、L字外周の内側ループ生成を確認した