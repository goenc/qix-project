区分補助線を追加し終点区間の有効領域補正を実装

・scripts/game/base_main.gd の guide 終点解決を共通化し、capture 後だけ 1 ドット逆走査で有効領域末端へ補正するようにした
・claimed 側と inactive 側を無効扱いにする判定を追加し、有効領域が無い補助線は active=false にするようにした
・Godot 4.6.1 の headless script check と base_main シーンの headless / 非 headless 起動確認を実施した