曲がり時の区分補助線を2方向生成に拡張

・曲がり通知で旧方向と新方向を渡し base_main 側で既存 guide_segments に2本の補助線を追加するよう修正
・既存の guide end 解決と capture 後補正と active 描画経路をそのまま各 guide に適用
・headless と通常起動で base_main シーンの起動確認を実施
