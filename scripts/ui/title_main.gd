extends Node

const MAIN_SCENE_PATH := "res://scenes/base_main.tscn"

@onready var title_screen: TitleScreen = $Title


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = false
	_register_input_map()
	title_screen.setup({})
	call_deferred("_grab_window_focus")


func _input(event: InputEvent) -> void:
	if !event.is_pressed() or event.is_echo():
		return
	if Input.is_action_just_pressed("qix_start"):
		get_tree().change_scene_to_file(MAIN_SCENE_PATH)


func is_pause_toggle_allowed() -> bool:
	return true


func set_paused_from_debug(enabled: bool) -> void:
	get_tree().paused = enabled


func _register_input_map() -> void:
	_ensure_action("move_left", [_key_event(KEY_LEFT), _key_event(KEY_A), _joypad_button(JOY_BUTTON_DPAD_LEFT)])
	_ensure_action("move_right", [_key_event(KEY_RIGHT), _key_event(KEY_D), _joypad_button(JOY_BUTTON_DPAD_RIGHT)])
	_ensure_action("move_up", [_key_event(KEY_UP), _key_event(KEY_W), _joypad_button(JOY_BUTTON_DPAD_UP)])
	_ensure_action("move_down", [_key_event(KEY_DOWN), _key_event(KEY_S), _joypad_button(JOY_BUTTON_DPAD_DOWN)])
	_ensure_action("qix_start", [_key_event(KEY_ENTER), _key_event(KEY_SPACE), _joypad_button(JOY_BUTTON_A), _joypad_button(JOY_BUTTON_START)])
	_ensure_action("ui_cancel", [_key_event(KEY_ESCAPE), _joypad_button(JOY_BUTTON_B), _joypad_button(JOY_BUTTON_BACK)])
	_ensure_action("pause", [_key_event(KEY_P), _joypad_button(JOY_BUTTON_START)])


func _grab_window_focus() -> void:
	var window := get_window()
	if window != null:
		window.grab_focus()


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
