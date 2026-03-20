BBOS の凹角はまりを抑えるため、境界判定をキャッシュ化し角脱出を追加した

・scripts/enemy/bbos.gd で内側ループのキャッシュを導入し、角はまり時に軽い脱出補正とクールダウンを追加した。
・scripts/game/playfield_boundary.gd で cached inset loop を受け取れるようにし、毎フレームの build_inset_loop を回避した。
・Godot を headless と non-headless で起動し、構文確認と実プレイ起動確認を行った。
