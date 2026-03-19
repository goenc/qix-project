capture 中の補助線を pending 扱いに変更

・capture 中は補助線の確定 end を保存せず 仮表示だけを行うようにした
・capture 確定後に今回 generation の補助線を削除判定と確定解決へ分離した
・base_main シーンを headless と通常起動で確認した