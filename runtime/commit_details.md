日時: 2026-03-15 15:43:26 +09:00
対象: BBOS の常時移動と白線内反射の最小実装
summary: BBOS がプレイフィールド内を常時移動し一定間隔で進行方向を再抽選するようにした。
変更:
・BBOS に移動速度と方向変更間隔と反射押し戻し量の export を追加した。
・毎フレーム移動し、HALF_SIZE ベースの矩形内で位置補正と軸別反射を行う処理を追加した。
・初回ランダム出現とリサイズ後の矩形内補正の既存挙動は維持した。
code_changes:
・scripts/enemy/bbos.gd に velocity と direction_change_timer を追加し _ready と _process と反射補助関数を実装した。
確認:
・C:\Godot\godot_console.exe --headless --path C:\Users\gonec\GameProjects\Godot\qix-project --quit が終了コード 0 で成功した。
verification:
・Godot CLI のヘッドレス起動でプロジェクトロードとスクリプト構文確認を実施した。
