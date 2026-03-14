extends Node2D
class_name GameManager

const CONFIG_PATH := "res://data/config/game_config.json"
const TITLE_SCENE_PATH := "res://scenes/title_main.tscn"

enum GameState {
	PLAYING,
	CLEAR,
}

var game_state: GameState = GameState.PLAYING
var game_config: Dictionary = {}
var stage = null

@onready var stage_mount = $StageMount
@onready var player = $Player
@onready var hud = $Hud
@onready var clear_screen = $Clear


func _ready() -> void:
	_register_input_map()
	game_config = _load_json(CONFIG_PATH)
	_apply_window_settings()
	_load_stage(_get_game_route().consume_next_stage())
	stage.setup(self, game_config)
	stage.attach_player(player)
	player.setup(self, game_config)
	hud.setup(game_config)
	clear_screen.setup(game_config)
	stage.boss_defeated.connect(_on_boss_defeated)
	stage.player_out_of_bounds.connect(_on_player_out_of_bounds)
	player.life_changed.connect(_on_player_life_changed)
	player.defeated.connect(_on_player_defeated)
	_start_game()


func _unhandled_input(_event: InputEvent) -> void:
	if get_tree().paused:
		return
	if game_state == GameState.CLEAR and Input.is_action_just_pressed("ui_accept"):
		get_tree().paused = false
		get_tree().change_scene_to_file(TITLE_SCENE_PATH)


func get_stage():
	return stage


func is_gameplay_active() -> bool:
	return game_state == GameState.PLAYING and !get_tree().paused


func is_pause_toggle_allowed() -> bool:
	return game_state == GameState.PLAYING


func set_paused_from_debug(enabled: bool) -> void:
	if game_state == GameState.PLAYING:
		get_tree().paused = enabled
	hud.set_paused(get_tree().paused)


func _start_game() -> void:
	game_state = GameState.PLAYING
	get_tree().paused = false
	stage.reset_stage()
	player.reset_for_stage(stage.get_spawn_position(), game_config)
	player.apply_camera_limits(stage.get_camera_limits())
	player.show()
	player.set_gameplay_active(true)
	stage.set_gameplay_active(true)
	clear_screen.set_active(false)
	hud.set_active(true)
	hud.set_paused(false)
	hud.update_life(player.get_life(), player.get_max_life())


func _show_clear() -> void:
	game_state = GameState.CLEAR
	get_tree().paused = false
	stage.set_gameplay_active(false)
	player.set_gameplay_active(false)
	clear_screen.set_active(true)
	hud.set_active(false)
	hud.set_paused(false)


func _restart_stage() -> void:
	if game_state == GameState.PLAYING:
		_start_game()


func _on_boss_defeated() -> void:
	_show_clear()


func _on_player_out_of_bounds() -> void:
	call_deferred("_restart_stage")


func _on_player_life_changed(current_life: int, max_life: int) -> void:
	hud.update_life(current_life, max_life)


func _on_player_defeated() -> void:
	call_deferred("_restart_stage")


func _apply_window_settings() -> void:
	var window := get_window()
	var window_config: Dictionary = game_config.get("window", {})
	var width := int(window_config.get("width", 640))
	var height := int(window_config.get("height", 360))
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	window.content_scale_size = Vector2i(width, height)
	window.size = Vector2i(width, height)


func _load_json(path: String) -> Dictionary:
	if !FileAccess.file_exists(path):
		return {}
	var raw_text := FileAccess.get_file_as_string(path)
	var parsed = JSON.parse_string(raw_text)
	if parsed is Dictionary:
		return parsed
	return {}


func _register_input_map() -> void:
	_ensure_action("move_left", [_key_event(KEY_LEFT), _key_event(KEY_A), _joypad_button(JOY_BUTTON_DPAD_LEFT)])
	_ensure_action("move_right", [_key_event(KEY_RIGHT), _key_event(KEY_D), _joypad_button(JOY_BUTTON_DPAD_RIGHT)])
	_ensure_action("jump", [_key_event(KEY_Z), _key_event(KEY_SPACE), _joypad_button(JOY_BUTTON_B)])
	_ensure_action("shoot", [_key_event(KEY_X), _key_event(KEY_C), _joypad_button(JOY_BUTTON_Y)])
	_ensure_action("ui_accept", [_key_event(KEY_ENTER), _key_event(KEY_SPACE), _joypad_button(JOY_BUTTON_A), _joypad_button(JOY_BUTTON_START)])
	_ensure_action("ui_cancel", [_key_event(KEY_ESCAPE), _joypad_button(JOY_BUTTON_B), _joypad_button(JOY_BUTTON_BACK)])
	_ensure_action("pause", [_key_event(KEY_P), _joypad_button(JOY_BUTTON_START)])


func _ensure_action(action_name: String, events: Array[InputEvent]) -> void:
	if !InputMap.has_action(action_name):
		InputMap.add_action(action_name)
	if !InputMap.action_get_events(action_name).is_empty():
		return
	for event in events:
		InputMap.action_add_event(action_name, event)


func _key_event(keycode: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	return event


func _joypad_button(button_index: JoyButton) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.button_index = button_index
	return event


func _load_stage(stage_scene_path: String) -> void:
	for child in stage_mount.get_children():
		stage_mount.remove_child(child)
		child.queue_free()
	var packed_scene := load(stage_scene_path) as PackedScene
	if packed_scene == null:
		push_error("Failed to load stage scene: %s" % stage_scene_path)
		return
	stage = packed_scene.instantiate()
	stage_mount.add_child(stage)


func _get_game_route() -> Node:
	return get_node("/root/GameRoute")
