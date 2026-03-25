base_main を service 分割して責務を整理

・base_main の HUD と capture と guide と boss region 処理を service へ委譲し scene 制御と状態保持に限定
・guide と capture と boss region 用の service script を追加し draw data と計算責務を分離
・PlayfieldBoundary に共有する pure helper を追加して幾何補助の重複を抑制
・通常起動と base_main シーン直接起動で headless と GUI の起動確認
