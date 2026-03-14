# debug 起動依存整理メモ

## 現在の起動経路

1. `project.godot` の `run/main_scene` は `res://scenes/title_main.tscn`
2. `res://scripts/ui/title_main.gd` が最小入力を登録し `ui_accept` で `res://scenes/base_main.tscn` へ遷移
3. autoload の `DebugInputData` と `DebugManager` は起動直後から有効
4. `DebugManager` は `debug/manager` `debug/windows` `debug/panels` `debug/overlays` `debug/common` 配下を必要時に生成する
5. 旧ゲーム本体の `res://scenes/main.tscn -> res://scenes/stages/stage_01.tscn` 経路は残置し、通常の debug 起動ルートからは外した

## 保持

- `project.godot`
  - `run/main_scene` がタイトル起動の起点
  - autoload の `DebugInputData` `DebugManager` が debug 起動に必須
- `res://scenes/title_main.tscn`
- `res://scripts/ui/title_main.gd`
- `res://scenes/ui/title.tscn`
- `res://scripts/ui/title.gd`
- `res://scenes/base_main.tscn`
- `res://scripts/game/base_main.gd`
- `res://scenes/player/base_player.tscn`
- `res://scripts/player/base_player.gd`
- `res://debug/**`
  - manager window
  - input debugger
  - input log
  - object inspector
  - hitbox overlay

## 保留

- `res://scripts/game/game_route.gd`
  - 旧 `main.tscn` 系のために autoload 設定は残置
  - 新 debug 起動ルートでは未使用なので、旧経路を完全に退役させる段階で削除可否を再確認する

## 削除候補

- `res://scenes/main.tscn`
- `res://scripts/game/game_manager.gd`
- `res://scenes/stages/stage_01.tscn`
- `res://scripts/game/stage_01.gd`
- `res://scenes/player/player.tscn`
- `res://scripts/player/player.gd`
- `res://scenes/player/player_bullet.tscn`
- `res://scripts/player/player_bullet.gd`
- `res://scenes/enemy_walker.tscn`
- `res://scripts/game/enemy_walker.gd`
- `res://scenes/enemy_turret.tscn`
- `res://scripts/game/enemy_turret.gd`
- `res://scenes/enemy_bullet.tscn`
- `res://scripts/game/enemy_bullet.gd`
- `res://scenes/boss.tscn`
- `res://scripts/game/boss.gd`
- `res://scenes/ground_tileset.tres`
- `res://scenes/tile_block.tscn`
- `res://scenes/ui/hud.tscn`
- `res://scripts/ui/hud.gd`
- `res://scenes/ui/clear.tscn`
- `res://scripts/ui/clear.gd`
- `res://assets/player/*`
- `res://data/config/game_config.json`
- `res://data/config/stage_01.json`

## 段階整理メモ

- 今回は削除を実行していない
- 次段階は `GameRoute` autoload の要否確認と、旧 `main.tscn` 系一式を 1 グループずつ退役させる
- asset と json は scene / script の切り離し完了後に削除確認する
