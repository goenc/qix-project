extends Node

const TITLE_SCENE_PATH := "res://scenes/title_main.tscn"
const InputActionUtils = preload("res://scripts/common/input_action_utils.gd")

const STAGE_ENTRIES: Array[Dictionary] = [
	{
		"stage_id": 1,
		"title": "STAGE 1",
		"available": true,
		"scene_path": "res://scenes/base_main.tscn",
		"detail_text": "PLAYABLE / BASE MAIN"
	},
	{
		"stage_id": 2,
		"title": "STAGE 2",
		"available": false,
		"scene_path": "",
		"detail_text": "未実装のモックです"
	},
	{
		"stage_id": 3,
		"title": "STAGE 3",
		"available": false,
		"scene_path": "",
		"detail_text": "未実装のモックです"
	},
	{
		"stage_id": 4,
		"title": "STAGE 4",
		"available": false,
		"scene_path": "",
		"detail_text": "未実装のモックです"
	}
]

@onready var stage_select_screen := $StageSelect

var selected_stage_index := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = false
	_register_input_map()
	stage_select_screen.setup({})
	_refresh_screen()
	call_deferred("_grab_window_focus")


func _input(event: InputEvent) -> void:
	if !event.is_pressed() or event.is_echo():
		return
	if Input.is_action_just_pressed("ui_cancel"):
		get_tree().change_scene_to_file(TITLE_SCENE_PATH)
		return
	if Input.is_action_just_pressed("qix_start"):
		_activate_selected_stage()
		return
	if Input.is_action_just_pressed("move_left"):
		_move_selection(Vector2i.LEFT)
		return
	if Input.is_action_just_pressed("move_right"):
		_move_selection(Vector2i.RIGHT)
		return
	if Input.is_action_just_pressed("move_up"):
		_move_selection(Vector2i.UP)
		return
	if Input.is_action_just_pressed("move_down"):
		_move_selection(Vector2i.DOWN)


func is_pause_toggle_allowed() -> bool:
	return true


func set_paused_from_debug(enabled: bool) -> void:
	get_tree().paused = enabled


func _activate_selected_stage() -> void:
	var stage_entry := _get_selected_stage_entry()
	if stage_entry.is_empty():
		return
	if !bool(stage_entry.get("available", false)):
		return
	var scene_path := str(stage_entry.get("scene_path", ""))
	if scene_path.is_empty():
		return
	get_tree().paused = false
	get_tree().change_scene_to_file(scene_path)


func _move_selection(direction: Vector2i) -> void:
	var next_index := selected_stage_index
	match direction:
		Vector2i.LEFT:
			if selected_stage_index in [1, 3]:
				next_index = selected_stage_index - 1
		Vector2i.RIGHT:
			if selected_stage_index in [0, 2]:
				next_index = selected_stage_index + 1
		Vector2i.UP:
			if selected_stage_index in [2, 3]:
				next_index = selected_stage_index - 2
		Vector2i.DOWN:
			if selected_stage_index in [0, 1]:
				next_index = selected_stage_index + 2
		_:
			return

	if next_index == selected_stage_index:
		return

	selected_stage_index = next_index
	_refresh_screen()


func _refresh_screen() -> void:
	stage_select_screen.configure(STAGE_ENTRIES, selected_stage_index)


func _get_selected_stage_entry() -> Dictionary:
	if selected_stage_index < 0 or selected_stage_index >= STAGE_ENTRIES.size():
		return {}
	return STAGE_ENTRIES[selected_stage_index]


func _grab_window_focus() -> void:
	var window := get_window()
	if window != null:
		window.grab_focus()


func _register_input_map() -> void:
	_ensure_action("move_left", [_key_event(KEY_LEFT), _key_event(KEY_A), _joypad_button(JOY_BUTTON_DPAD_LEFT)])
	_ensure_action("move_right", [_key_event(KEY_RIGHT), _key_event(KEY_D), _joypad_button(JOY_BUTTON_DPAD_RIGHT)])
	_ensure_action("move_up", [_key_event(KEY_UP), _key_event(KEY_W), _joypad_button(JOY_BUTTON_DPAD_UP)])
	_ensure_action("move_down", [_key_event(KEY_DOWN), _key_event(KEY_S), _joypad_button(JOY_BUTTON_DPAD_DOWN)])
	_ensure_action("qix_start", [_key_event(KEY_ENTER), _key_event(KEY_SPACE), _joypad_button(JOY_BUTTON_A), _joypad_button(JOY_BUTTON_START)])
	_ensure_action("ui_cancel", [_key_event(KEY_ESCAPE), _joypad_button(JOY_BUTTON_B), _joypad_button(JOY_BUTTON_BACK)])
	_ensure_action("pause", [_key_event(KEY_P), _joypad_button(JOY_BUTTON_START)])


func _ensure_action(action_name: String, events: Array[InputEvent]) -> void:
	InputActionUtils.ensure_action(action_name, events)


func _key_event(keycode: Key) -> InputEventKey:
	return InputActionUtils.key_event(keycode, false, true)


func _joypad_button(button_index: JoyButton) -> InputEventJoypadButton:
	return InputActionUtils.joypad_button(button_index)
