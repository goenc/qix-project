extends Node2D

const TITLE_SCENE_PATH := "res://scenes/title_main.tscn"

@export var playfield_margin := Vector2(72.0, 124.0)
@export var playfield_min_size := Vector2(180.0, 120.0)
@export var playfield_border_color := Color(0.4, 0.95, 0.7, 1.0)
@export var playfield_border_width := 3.0

@onready var base_player: BasePlayer = $BasePlayer
@onready var status_label: Label = $Ui/Root/StatusLabel
@onready var position_label: Label = $Ui/Root/PositionLabel

var playfield_rect := Rect2()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = false
	_register_input_map()
	_recalculate_playfield_rect()
	_apply_playfield_to_player()
	var viewport := get_viewport()
	if is_instance_valid(viewport) and !viewport.size_changed.is_connected(_on_viewport_size_changed):
		viewport.size_changed.connect(_on_viewport_size_changed)
	queue_redraw()
	_sync_debug_labels()


func _unhandled_input(_event: InputEvent) -> void:
	if Input.is_action_just_pressed("ui_cancel"):
		get_tree().paused = false
		get_tree().change_scene_to_file(TITLE_SCENE_PATH)


func is_pause_toggle_allowed() -> bool:
	return true


func set_paused_from_debug(enabled: bool) -> void:
	get_tree().paused = enabled
	_sync_debug_labels()


func _process(_delta: float) -> void:
	_sync_debug_labels()


func _sync_debug_labels() -> void:
	if get_tree().paused:
		status_label.text = "PAUSED"
		position_label.text = "POS: (-, -)  MODE: PAUSED"
		return

	if !is_instance_valid(base_player):
		status_label.text = "BORDER"
		position_label.text = "POS: (-, -)  MODE: WAITING"
		return

	var debug_status := base_player.get_debug_status()
	var state_text := str(debug_status.get("state", "BORDER"))
	var current_pos: Vector2 = debug_status.get("position", base_player.position)
	var on_border := bool(debug_status.get("is_on_border", true))
	var mode_text := "DRAWING_INSIDE" if state_text == "DRAWING" else ("BORDER_ONLY" if on_border else "TRANSITION")

	status_label.text = state_text
	position_label.text = "POS: (%.1f, %.1f)  MODE: %s" % [current_pos.x, current_pos.y, mode_text]


func _register_input_map() -> void:
	_ensure_action("move_left", [_key_event(KEY_LEFT), _key_event(KEY_A), _joypad_button(JOY_BUTTON_DPAD_LEFT)])
	_ensure_action("move_right", [_key_event(KEY_RIGHT), _key_event(KEY_D), _joypad_button(JOY_BUTTON_DPAD_RIGHT)])
	_ensure_action("move_up", [_key_event(KEY_UP), _key_event(KEY_W), _joypad_button(JOY_BUTTON_DPAD_UP)])
	_ensure_action("move_down", [_key_event(KEY_DOWN), _key_event(KEY_S), _joypad_button(JOY_BUTTON_DPAD_DOWN)])
	_ensure_action("qix_draw", [_key_event(KEY_Z), _key_event(KEY_SHIFT), _joypad_button(JOY_BUTTON_X)])
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


func _draw() -> void:
	if playfield_rect.size.x <= 0.0 or playfield_rect.size.y <= 0.0:
		return
	draw_rect(playfield_rect, playfield_border_color, false, playfield_border_width)


func _on_viewport_size_changed() -> void:
	_recalculate_playfield_rect()
	_apply_playfield_to_player()
	queue_redraw()
	_sync_debug_labels()


func _recalculate_playfield_rect() -> void:
	var viewport_rect := get_viewport_rect()
	var margin_x := minf(playfield_margin.x, viewport_rect.size.x * 0.35)
	var margin_y := minf(playfield_margin.y, viewport_rect.size.y * 0.35)
	var width := maxf(playfield_min_size.x, viewport_rect.size.x - margin_x * 2.0)
	var height := maxf(playfield_min_size.y, viewport_rect.size.y - margin_y * 2.0)
	var position_x := viewport_rect.position.x + (viewport_rect.size.x - width) * 0.5
	var position_y := viewport_rect.position.y + (viewport_rect.size.y - height) * 0.5
	playfield_rect = Rect2(Vector2(position_x, position_y), Vector2(width, height))


func _apply_playfield_to_player() -> void:
	if is_instance_valid(base_player):
		base_player.set_playfield_rect(playfield_rect)
