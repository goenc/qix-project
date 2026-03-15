extends Node2D

const TITLE_SCENE_PATH := "res://scenes/title_main.tscn"

@export var playfield_margin := Vector2(32.0, 40.0)
@export var playfield_min_size := Vector2(180.0, 120.0)
@export var hud_width := 280.0
@export var hud_gap := 32.0
@export var playfield_fill_color := Color(0.02, 0.02, 0.02, 1.0)
@export var playfield_outer_frame_color := Color(0.35, 0.35, 0.35, 1.0)
@export var playfield_border_color := Color(1.0, 1.0, 1.0, 1.0)
@export var playfield_border_width := 3.0
@export var playfield_outer_frame_padding := 12.0

@onready var base_player = $BasePlayer
@onready var state_label: Label = $Ui/Root/StateLabel
@onready var position_label: Label = $Ui/Root/PositionLabel
@onready var claimed_label: Label = $Ui/Root/ClaimedLabel

var playfield_rect: Rect2 = Rect2()


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
	_sync_hud()


func _unhandled_input(_event: InputEvent) -> void:
	if Input.is_action_just_pressed("ui_cancel"):
		get_tree().paused = false
		get_tree().change_scene_to_file(TITLE_SCENE_PATH)


func is_pause_toggle_allowed() -> bool:
	return true


func set_paused_from_debug(enabled: bool) -> void:
	get_tree().paused = enabled
	_sync_hud()


func _process(_delta: float) -> void:
	_sync_hud()


func _sync_hud() -> void:
	claimed_label.text = "CLAIMED: 0%"

	if get_tree().paused:
		state_label.text = "MODE: PAUSED"
		position_label.text = "POS: (-, -)"
		return

	if !is_instance_valid(base_player):
		state_label.text = "MODE: BORDER"
		position_label.text = "POS: (-, -)"
		return

	var status: Dictionary = base_player.get_debug_status()
	var mode_text := str(status.get("mode_text", "BORDER"))
	var current_position: Vector2 = status.get("position", base_player.position)

	state_label.text = "MODE: %s" % mode_text
	position_label.text = "POS: (%d, %d)" % [int(round(current_position.x)), int(round(current_position.y))]


func _register_input_map() -> void:
	_ensure_action("move_left", [_key_event(KEY_LEFT), _key_event(KEY_A), _joypad_button(JOY_BUTTON_DPAD_LEFT)])
	_ensure_action("move_right", [_key_event(KEY_RIGHT), _key_event(KEY_D), _joypad_button(JOY_BUTTON_DPAD_RIGHT)])
	_ensure_action("move_up", [_key_event(KEY_UP), _key_event(KEY_W), _joypad_button(JOY_BUTTON_DPAD_UP)])
	_ensure_action("move_down", [_key_event(KEY_DOWN), _key_event(KEY_S), _joypad_button(JOY_BUTTON_DPAD_DOWN)])
	_replace_action_events("qix_draw", [_key_event(KEY_SHIFT), _joypad_button(JOY_BUTTON_A)])
	_ensure_action("ui_cancel", [_key_event(KEY_ESCAPE), _joypad_button(JOY_BUTTON_B), _joypad_button(JOY_BUTTON_BACK)])
	_ensure_action("pause", [_key_event(KEY_P), _joypad_button(JOY_BUTTON_START)])


func _ensure_action(action_name: String, events: Array[InputEvent]) -> void:
	if !InputMap.has_action(action_name):
		InputMap.add_action(action_name)
	if !InputMap.action_get_events(action_name).is_empty():
		return
	for event in events:
		InputMap.action_add_event(action_name, event)


func _replace_action_events(action_name: String, events: Array[InputEvent]) -> void:
	if !InputMap.has_action(action_name):
		InputMap.add_action(action_name)
	InputMap.action_erase_events(action_name)
	for event in events:
		InputMap.action_add_event(action_name, event)


func _key_event(keycode: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	return event


func _joypad_button(button_index: JoyButton) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.button_index = button_index
	return event


func _draw() -> void:
	if playfield_rect.size.x <= 0.0 or playfield_rect.size.y <= 0.0:
		return
	var outer_rect := playfield_rect.grow(playfield_outer_frame_padding)
	draw_rect(playfield_rect, playfield_fill_color, true)
	draw_rect(outer_rect, playfield_outer_frame_color, false, 2.0)
	draw_rect(playfield_rect, playfield_border_color, false, playfield_border_width)


func _on_viewport_size_changed() -> void:
	_recalculate_playfield_rect()
	_apply_playfield_to_player()
	queue_redraw()
	_sync_hud()


func _recalculate_playfield_rect() -> void:
	var viewport_rect := get_viewport_rect()
	var margin_x := minf(playfield_margin.x, viewport_rect.size.x * 0.08)
	var margin_y := minf(playfield_margin.y, viewport_rect.size.y * 0.1)
	var usable_width := maxf(playfield_min_size.x, viewport_rect.size.x - margin_x * 2.0)
	var dynamic_gap := minf(hud_gap, maxf(12.0, usable_width * 0.04))
	var preferred_hud_width := minf(hud_width, maxf(180.0, usable_width * 0.28))
	var max_hud_width := maxf(0.0, usable_width - 120.0 - dynamic_gap)
	var dynamic_hud_width := minf(preferred_hud_width, max_hud_width)
	var playfield_width := maxf(120.0, usable_width - dynamic_hud_width - dynamic_gap)
	var playfield_height := maxf(playfield_min_size.y, viewport_rect.size.y - margin_y * 2.0)
	playfield_rect = Rect2(
		Vector2(viewport_rect.position.x + margin_x, viewport_rect.position.y + margin_y),
		Vector2(playfield_width, playfield_height)
	)


func _apply_playfield_to_player() -> void:
	if is_instance_valid(base_player):
		base_player.set_playfield_rect(playfield_rect)
