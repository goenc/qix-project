BBOS反射検証を実効ループ基準に修正

・verify_outer_loop の BBOS 反射ケースを raw outer loop ではなく BBOS の実効反射ループ基準へ揃えた
・initial rectangle と first L capture と second jagged capture の失敗原因が同一の検証前提ずれであることを反映した
・player 角移動検証の重複 helper を verify_shared に最小限で共通化した
・headless 2 本と非 headless 短時間起動で確認した
