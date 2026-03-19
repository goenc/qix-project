区分補助線の capture 後補正を start 起点走査へ変更

・区分補助線の capture 後補正を START から最初の有効連続区間の終端を採用する順走査へ変更
・最後まで有効領域が続く場合は元の END を維持し 有効領域が一度も無い guide は非 active 化
・Godot headless の構文確認と通常起動の短時間確認を実施