extends Node2D

const TITLE_SCENE_PATH := "res://scenes/title_main.tscn"
const PlayfieldBoundary = preload("res://scripts/game/playfield_boundary.gd")
const BBOS_SCENE = preload("res://scenes/enemy/bbos.tscn")
const ACTION_QIX_DRAW := &"qix_draw"

@export var playfield_margin := Vector2(32.0, 40.0)
@export var playfield_min_size := Vector2(180.0, 120.0)
@export var hud_width := 280.0
@export var hud_gap := 32.0
@export var playfield_fill_color := Color(0.02, 0.02, 0.02, 1.0)
@export var claimed_fill_color := Color(0.45, 0.0, 0.7, 0.65)
@export var playfield_outer_frame_color := Color(0.35, 0.35, 0.35, 1.0)
@export var playfield_border_color := Color(1.0, 1.0, 1.0, 1.0)
@export var playfield_border_width := 3.0
@export var playfield_outer_frame_padding := 12.0

@onready var base_player = get_node_or_null("BasePlayer")
@onready var bbos: Node2D = get_node_or_null("BBOS")
@onready var boss: Node2D = get_node_or_null("Boss")
@onready var help_label: Label = $Ui/Root/HelpLabel
@onready var state_label: Label = $Ui/Root/StateLabel
@onready var position_label: Label = $Ui/Root/PositionLabel
@onready var claimed_label: Label = $Ui/Root/ClaimedLabel
@onready var hp_label: Label = $Ui/Root/HpLabel
@onready var result_label: Label = $Ui/Root/ResultLabel

var playfield_rect: Rect2 = Rect2()
var claimed_polygons: Array[PackedVector2Array] = []
var current_outer_loop: PackedVector2Array = PackedVector2Array()
var remaining_polygon: PackedVector2Array = PackedVector2Array()
var inactive_border_segments: Array[PackedVector2Array] = []
var claimed_area := 0.0
var inactive_border_color := Color(1.0, 1.0, 1.0, 0.1)
var game_over := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = false
	_register_input_map()
	_ensure_bbos_node()
	_recalculate_playfield_rect()
	_initialize_outer_loop_from_rect()
	_connect_player_signal()
	_apply_playfield_to_player()
	_apply_playfield_to_bbos()
	_sync_boss_marker()
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
	if game_over and !enabled:
		return
	get_tree().paused = enabled
	_sync_hud()


func _process(_delta: float) -> void:
	_sync_boss_marker()
	_sync_hud()


func _sync_hud() -> void:
	var playfield_area := playfield_rect.size.x * playfield_rect.size.y
	var claimed_ratio := 0.0
	if playfield_area > 0.0:
		claimed_ratio = clampf(claimed_area / playfield_area, 0.0, 1.0)
	claimed_label.text = "CLAIMED: %d%%" % int(round(claimed_ratio * 100.0))
	_update_hp_label()

	if game_over:
		state_label.text = "MODE: GAME OVER"
		result_label.text = "GAME OVER"
		help_label.text = "ESC: TITLE"
		if is_instance_valid(base_player):
			position_label.text = "POS: (%d, %d)" % [int(round(base_player.position.x)), int(round(base_player.position.y))]
		else:
			position_label.text = "POS: (-, -)"
		return

	if get_tree().paused:
		state_label.text = "MODE: PAUSED"
		position_label.text = "POS: (-, -)"
		result_label.text = ""
		help_label.text = "MOVE: ARROWS/WASD DRAW: SHIFT/PAD-A ESC: TITLE"
		return

	if !is_instance_valid(base_player):
		state_label.text = "MODE: BORDER"
		position_label.text = "POS: (-, -)"
		result_label.text = ""
		help_label.text = "MOVE: ARROWS/WASD DRAW: SHIFT/PAD-A ESC: TITLE"
		return

	var status: Dictionary = base_player.get_debug_status()
	var mode_text := str(status.get("mode_text", "BORDER"))
	var current_position: Vector2 = status.get("position", base_player.position)

	state_label.text = "MODE: %s" % mode_text
	position_label.text = "POS: (%d, %d)" % [int(round(current_position.x)), int(round(current_position.y))]
	result_label.text = ""
	help_label.text = "MOVE: ARROWS/WASD DRAW: SHIFT/PAD-A ESC: TITLE"


func _register_input_map() -> void:
	_ensure_action("move_left", [_key_event(KEY_LEFT), _key_event(KEY_A), _joypad_button(JOY_BUTTON_DPAD_LEFT)])
	_ensure_action("move_right", [_key_event(KEY_RIGHT), _key_event(KEY_D), _joypad_button(JOY_BUTTON_DPAD_RIGHT)])
	_ensure_action("move_up", [_key_event(KEY_UP), _key_event(KEY_W), _joypad_button(JOY_BUTTON_DPAD_UP)])
	_ensure_action("move_down", [_key_event(KEY_DOWN), _key_event(KEY_S), _joypad_button(JOY_BUTTON_DPAD_DOWN)])
	_sync_draw_action_events([_key_event(KEY_SHIFT), _joypad_button(JOY_BUTTON_A)])
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


func _sync_draw_action_events(events: Array[InputEvent]) -> void:
	if !InputMap.has_action(ACTION_QIX_DRAW):
		return
	InputMap.action_erase_events(ACTION_QIX_DRAW)
	for event in events:
		InputMap.action_add_event(ACTION_QIX_DRAW, event)


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
	if current_outer_loop.size() < 3:
		return

	var outer_rect := playfield_rect.grow(playfield_outer_frame_padding)
	if remaining_polygon.size() >= 3:
		draw_colored_polygon(remaining_polygon, playfield_fill_color)
	for polygon in claimed_polygons:
		if polygon.size() >= 3:
			draw_colored_polygon(polygon, claimed_fill_color)
	_draw_border_segments(inactive_border_segments, inactive_border_color)
	_draw_border_loop(current_outer_loop, playfield_border_color)
	draw_rect(outer_rect, playfield_outer_frame_color, false, 2.0)


func _on_viewport_size_changed() -> void:
	_recalculate_playfield_rect()
	if claimed_polygons.is_empty() or current_outer_loop.is_empty():
		_initialize_outer_loop_from_rect()
	_apply_playfield_to_player()
	_apply_playfield_to_bbos()
	_sync_boss_marker()
	_recalculate_claimed_area()
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


func _ensure_bbos_node() -> void:
	if is_instance_valid(bbos):
		return

	var bbos_instance := BBOS_SCENE.instantiate()
	bbos_instance.name = "BBOS"
	add_child(bbos_instance)
	bbos = bbos_instance as Node2D


func _connect_player_signal() -> void:
	if !is_instance_valid(base_player):
		return
	if !base_player.capture_closed.is_connected(_on_player_capture_closed):
		base_player.capture_closed.connect(_on_player_capture_closed)
	if base_player.has_signal("hp_changed") and !base_player.hp_changed.is_connected(_on_player_hp_changed):
		base_player.hp_changed.connect(_on_player_hp_changed)
	if base_player.has_signal("defeated") and !base_player.defeated.is_connected(_on_player_defeated):
		base_player.defeated.connect(_on_player_defeated)


func _initialize_outer_loop_from_rect() -> void:
	current_outer_loop = PlayfieldBoundary.create_rect_loop(playfield_rect)
	remaining_polygon = current_outer_loop
	inactive_border_segments.clear()
	if claimed_polygons.is_empty():
		claimed_area = 0.0


func _apply_playfield_to_player() -> void:
	if current_outer_loop.is_empty():
		_initialize_outer_loop_from_rect()
	if !is_instance_valid(base_player):
		return

	base_player.set_playfield_rect(playfield_rect)
	base_player.set_active_outer_loop(current_outer_loop)


func _apply_playfield_to_bbos() -> void:
	if current_outer_loop.is_empty():
		_initialize_outer_loop_from_rect()
	if !is_instance_valid(bbos):
		return
	if bbos.has_method("set_playfield_rect"):
		bbos.call("set_playfield_rect", playfield_rect)
	if bbos.has_method("set_active_outer_loop"):
		bbos.call("set_active_outer_loop", current_outer_loop)


func _on_player_capture_closed(trail_points: PackedVector2Array) -> void:
	if current_outer_loop.size() < 3:
		push_warning("Capture skipped: outer loop is not ready.")
		return

	var epsilon := 2.0
	if is_instance_valid(base_player):
		epsilon = base_player.border_epsilon

	var candidate_loops := PlayfieldBoundary.split_outer_loop_by_trail(current_outer_loop, trail_points, epsilon)
	if candidate_loops.size() < 2:
		push_warning("Capture skipped: candidate outer loops could not be generated.")
		return

	_sync_boss_marker()
	var selection_point := _get_boss_selection_point()
	var retained_index := PlayfieldBoundary.select_loop_containing_point(candidate_loops, selection_point, epsilon)
	if retained_index < 0 or retained_index >= candidate_loops.size():
		push_warning("Capture skipped: boss-side outer loop could not be determined.")
		return

	var retained_candidate: Dictionary = candidate_loops[retained_index]
	current_outer_loop = retained_candidate.get("loop", PackedVector2Array())
	remaining_polygon = retained_candidate.get("polygon", PackedVector2Array())
	inactive_border_segments.clear()

	for index in range(candidate_loops.size()):
		if index == retained_index:
			continue
		var captured_polygon: PackedVector2Array = candidate_loops[index].get("polygon", PackedVector2Array())
		if captured_polygon.size() >= 3:
			claimed_polygons.append(captured_polygon)
		var removed_path: PackedVector2Array = candidate_loops[index].get("boundary_path", PackedVector2Array())
		inactive_border_segments.append_array(_polyline_to_segments(removed_path))

	_recalculate_claimed_area()
	_apply_playfield_to_player()
	_apply_playfield_to_bbos()
	_sync_boss_marker()
	queue_redraw()
	_sync_hud()


func _get_boss_selection_point() -> Vector2:
	if is_instance_valid(bbos):
		return bbos.global_position
	if is_instance_valid(boss):
		return boss.global_position
	return current_outer_loop[0]


func _recalculate_claimed_area() -> void:
	var total_area := 0.0
	for polygon in claimed_polygons:
		total_area += PlayfieldBoundary.polygon_area(polygon)

	var playfield_area := maxf(0.0, playfield_rect.size.x * playfield_rect.size.y)
	claimed_area = minf(total_area, playfield_area) if playfield_area > 0.0 else total_area


func _sync_boss_marker() -> void:
	if !is_instance_valid(boss):
		return
	if is_instance_valid(bbos):
		boss.global_position = bbos.global_position
		return
	if current_outer_loop.size() >= 3:
		boss.global_position = PlayfieldBoundary.ensure_point_inside(current_outer_loop, boss.global_position, 2.0)


func _polyline_to_segments(points: PackedVector2Array) -> Array[PackedVector2Array]:
	var segments: Array[PackedVector2Array] = []
	for index in range(points.size() - 1):
		var segment_start: Vector2 = points[index]
		var segment_end: Vector2 = points[index + 1]
		if segment_start.is_equal_approx(segment_end):
			continue
		var segment := PackedVector2Array()
		segment.append(segment_start)
		segment.append(segment_end)
		segments.append(segment)
	return segments


func _draw_border_loop(loop: PackedVector2Array, color: Color) -> void:
	if loop.size() < 2:
		return
	var draw_points := PlayfieldBoundary.build_draw_polyline(loop)
	for index in range(draw_points.size() - 1):
		draw_line(draw_points[index], draw_points[index + 1], color, playfield_border_width)


func _draw_border_segments(segments: Array[PackedVector2Array], color: Color) -> void:
	for segment in segments:
		if segment.size() < 2:
			continue
		for index in range(segment.size() - 1):
			draw_line(segment[index], segment[index + 1], color, playfield_border_width)


func _update_hp_label() -> void:
	if !is_instance_valid(hp_label):
		return

	if !is_instance_valid(base_player):
		hp_label.text = "HP: -/-"
		return

	if base_player.has_method("get_current_hp") and base_player.has_method("get_max_hp"):
		hp_label.text = "HP: %d/%d" % [base_player.get_current_hp(), base_player.get_max_hp()]
		return

	hp_label.text = "HP: -/-"


func _on_player_hp_changed(_current_hp: int, _max_hp: int) -> void:
	_sync_hud()


func _on_player_defeated() -> void:
	game_over = true
	get_tree().paused = true
	_sync_hud()
