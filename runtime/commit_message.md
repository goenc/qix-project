入力登録共通化とcapture処理整理

・InputMap 反映と InputEvent 生成を共通 helper に切り出し既存の action 登録挙動を維持した
・capture_closed の更新順と warning 条件を変えずに責務分割した
・stage cover の常設ログを削除し polygon と UV の再構築経路を整理した
・Godot headless の構文確認と title→base の InputMap と signal と stage cover 検証を実施した