ガイドserviceをfacade化して内部責務を再分離

・BaseMainGuideService を facade に縮小し Resolution Capture PartitionFill の3 service を追加
・guide 解決 pending 管理 capture 後処理 partition fill 更新を sub service へ移送して _main 反映点を facade に集約
・base_main.gd は変更せず guide service の公開APIを維持
・godot_console --headless --path . --script res://scripts/game/services/base_main_guide_service.gd --check-only で構文確認
・godot_console --headless --path . --script res://scripts/game/services/base_main_guide_resolution_service.gd --check-only で構文確認
・godot_console --headless --path . --script res://scripts/game/services/base_main_guide_capture_service.gd --check-only で構文確認
・godot_console --headless --path . --script res://scripts/game/services/base_main_guide_partition_fill_service.gd --check-only で構文確認
・godot_console --headless --path . --quit-after 5 と godot_console --headless --path . --scene res://scenes/base_main.tscn --quit-after 5 で起動確認