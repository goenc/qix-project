capture後補正の補助線終端を境界再取得へ統一

・_apply_capture_guide_segment_correctionで found 時は常に first_valid_point から元の end までを境界再取得するよう変更
・境界再取得に失敗した場合と補正後終端が開始点と同等の場合は補助線を無効化し corrected_end = end の逃げ道を削除
・godot_console --headless --path . --editor --quit と verify_outer_loop.gd と verify_player_border_corner.gd の headless 確認を実施
