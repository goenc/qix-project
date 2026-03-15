extends Node2D

const TITLE_SCENE_PATH := "res://scenes/title_main.tscn"

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

@onready var base_player = $BasePlayer
@onready var bbos: Node2D = $BBOS
@onready var boss: Node2D = $Boss
@onready var state_label: Label = $Ui/Root/StateLabel
@onready var position_label: Label = $Ui/Root/PositionLabel
@onready var claimed_label: Label = $Ui/Root/ClaimedLabel

var playfield_rect: Rect2 = Rect2()
var claimed_polygons: Array[PackedVector2Array] = []
var claimed_area := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = false
	_register_input_map()
	_recalculate_playfield_rect()
	_apply_playfield_to_entities()
	if is_instance_valid(base_player) and !base_player.drawing_completed.is_connected(_on_player_drawing_completed):
		base_player.drawing_completed.connect(_on_player_drawing_completed)
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
	for polygon in claimed_polygons:
		if polygon.size() >= 3:
			draw_colored_polygon(polygon, claimed_fill_color)
	draw_rect(outer_rect, playfield_outer_frame_color, false, 2.0)
	draw_rect(playfield_rect, playfield_border_color, false, playfield_border_width)


func _on_viewport_size_changed() -> void:
	_recalculate_playfield_rect()
	_apply_playfield_to_entities()
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


func _apply_playfield_to_entities() -> void:
	if is_instance_valid(base_player):
		base_player.set_playfield_rect(playfield_rect)
	if is_instance_valid(bbos):
		bbos.set_playfield_rect(playfield_rect)


func _on_player_drawing_completed(
	start_point: Vector2,
	end_point: Vector2,
	finalized_trail_points: PackedVector2Array
) -> void:
	if playfield_rect.size.x <= 0.0 or playfield_rect.size.y <= 0.0:
		push_warning("Claim skipped: playfield rectangle is empty.")
		return

	_sync_boss_marker()
	if !is_instance_valid(boss):
		push_warning("Claim skipped: boss reference is missing.")
		return

	var snapped_start := _snap_point_to_border(start_point)
	var snapped_end := _snap_point_to_border(end_point)
	var start_progress := _point_to_border_progress(snapped_start)
	var end_progress := _point_to_border_progress(snapped_end)
	if is_equal_approx(start_progress, end_progress):
		push_warning("Claim skipped: start and end points resolved to the same border progress.")
		return

	var trail_points := _sanitize_trail_polyline(finalized_trail_points)
	if trail_points.size() < 2:
		push_warning("Claim skipped: finalized trail has fewer than 2 points.")
		return
	trail_points[0] = snapped_start
	trail_points[trail_points.size() - 1] = snapped_end

	var candidate_a := _build_claim_candidate(trail_points, snapped_start, snapped_end, true)
	var candidate_b := _build_claim_candidate(trail_points, snapped_start, snapped_end, false)
	if !_is_valid_claim_polygon(candidate_a) or !_is_valid_claim_polygon(candidate_b):
		push_warning("Claim skipped: candidate polygons could not be generated from the finalized trail.")
		return

	var boss_position := boss.global_position
	var boss_in_a := Geometry2D.is_point_in_polygon(boss_position, candidate_a)
	var boss_in_b := Geometry2D.is_point_in_polygon(boss_position, candidate_b)
	if boss_in_a == boss_in_b:
		push_warning("Claim skipped: boss-side region could not be determined.")
		return

	var claimed_polygon := candidate_b if boss_in_a else candidate_a
	claimed_polygons.append(_ensure_consistent_polygon_winding(claimed_polygon))
	_recalculate_claimed_area()
	queue_redraw()
	_sync_hud()


func _build_claim_candidate(
	trail_points: PackedVector2Array,
	start_point: Vector2,
	end_point: Vector2,
	clockwise: bool
) -> PackedVector2Array:
	var candidate := PackedVector2Array()
	for point in trail_points:
		if candidate.is_empty() or !candidate[candidate.size() - 1].is_equal_approx(point):
			candidate.append(point)

	for point in _build_border_path(end_point, start_point, clockwise):
		if candidate.is_empty() or !candidate[candidate.size() - 1].is_equal_approx(point):
			candidate.append(point)

	return _sanitize_polygon(candidate)


func _build_border_path(from_point: Vector2, to_point: Vector2, clockwise: bool) -> PackedVector2Array:
	var from_progress := _point_to_border_progress(_snap_point_to_border(from_point))
	var to_progress := _point_to_border_progress(_snap_point_to_border(to_point))
	var total_distance := _border_travel_distance(from_progress, to_progress, clockwise)
	var path := PackedVector2Array()
	if total_distance <= 0.0:
		return path

	var corners := []
	for corner in _get_border_corner_infos():
		var distance := _border_travel_distance(from_progress, float(corner["progress"]), clockwise)
		if distance > 0.001 and distance < total_distance - 0.001:
			corners.append({
				"distance": distance,
				"point": corner["point"]
			})

	corners.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["distance"]) < float(b["distance"])
	)

	for corner in corners:
		path.append(corner["point"])
	return path


func _get_border_corner_infos() -> Array:
	var left := playfield_rect.position.x
	var top := playfield_rect.position.y
	var right := playfield_rect.end.x
	var bottom := playfield_rect.end.y
	var width := playfield_rect.size.x
	var height := playfield_rect.size.y
	return [
		{"progress": 0.0, "point": Vector2(left, top)},
		{"progress": width, "point": Vector2(right, top)},
		{"progress": width + height, "point": Vector2(right, bottom)},
		{"progress": width + height + width, "point": Vector2(left, bottom)}
	]


func _sanitize_trail_polyline(points: PackedVector2Array) -> PackedVector2Array:
	var sanitized := PackedVector2Array()
	for point in points:
		if sanitized.is_empty() or !sanitized[sanitized.size() - 1].is_equal_approx(point):
			sanitized.append(point)
	return sanitized


func _sanitize_polygon(points: PackedVector2Array) -> PackedVector2Array:
	var sanitized := _sanitize_trail_polyline(points)
	if sanitized.size() >= 2 and sanitized[0].is_equal_approx(sanitized[sanitized.size() - 1]):
		sanitized.resize(sanitized.size() - 1)
	return sanitized


func _is_valid_claim_polygon(polygon: PackedVector2Array) -> bool:
	return polygon.size() >= 3 and _polygon_area(polygon) > 0.5


func _ensure_consistent_polygon_winding(polygon: PackedVector2Array) -> PackedVector2Array:
	if _signed_polygon_area(polygon) <= 0.0:
		return polygon

	var reversed_polygon := PackedVector2Array()
	for index in range(polygon.size() - 1, -1, -1):
		reversed_polygon.append(polygon[index])
	return reversed_polygon


func _recalculate_claimed_area() -> void:
	var total_area := 0.0
	for polygon in claimed_polygons:
		total_area += _polygon_area(polygon)

	var playfield_area := maxf(0.0, playfield_rect.size.x * playfield_rect.size.y)
	claimed_area = minf(total_area, playfield_area) if playfield_area > 0.0 else total_area


func _polygon_area(polygon: PackedVector2Array) -> float:
	return absf(_signed_polygon_area(polygon))


func _signed_polygon_area(polygon: PackedVector2Array) -> float:
	if polygon.size() < 3:
		return 0.0

	var signed_area := 0.0
	for index in range(polygon.size()):
		var current: Vector2 = polygon[index]
		var next: Vector2 = polygon[(index + 1) % polygon.size()]
		signed_area += current.x * next.y - next.x * current.y
	return signed_area * 0.5


func _sync_boss_marker() -> void:
	if !is_instance_valid(boss):
		return
	if is_instance_valid(bbos):
		boss.global_position = bbos.global_position
		return
	if playfield_rect.size.x <= 0.0 or playfield_rect.size.y <= 0.0:
		return
	boss.global_position = _clamp_to_playfield(boss.global_position)


func _border_travel_distance(from_progress: float, to_progress: float, clockwise: bool) -> float:
	if clockwise:
		return _wrap_border_progress(to_progress - from_progress)
	return _wrap_border_progress(from_progress - to_progress)


func _point_to_border_progress(point: Vector2) -> float:
	var snapped := _snap_point_to_border(point)
	var left := playfield_rect.position.x
	var top := playfield_rect.position.y
	var width := playfield_rect.size.x
	var height := playfield_rect.size.y
	var right := playfield_rect.end.x
	var bottom := playfield_rect.end.y

	if absf(snapped.y - top) <= 0.001:
		return clampf(snapped.x - left, 0.0, width)
	if absf(snapped.x - right) <= 0.001:
		return width + clampf(snapped.y - top, 0.0, height)
	if absf(snapped.y - bottom) <= 0.001:
		return width + height + clampf(right - snapped.x, 0.0, width)
	return width + height + width + clampf(bottom - snapped.y, 0.0, height)


func _clamp_to_playfield(point: Vector2) -> Vector2:
	return Vector2(
		clampf(point.x, playfield_rect.position.x, playfield_rect.end.x),
		clampf(point.y, playfield_rect.position.y, playfield_rect.end.y)
	)


func _snap_point_to_border(point: Vector2) -> Vector2:
	var clamped := _clamp_to_playfield(point)
	var left_dist := absf(clamped.x - playfield_rect.position.x)
	var right_dist := absf(playfield_rect.end.x - clamped.x)
	var top_dist := absf(clamped.y - playfield_rect.position.y)
	var bottom_dist := absf(playfield_rect.end.y - clamped.y)
	var nearest := minf(minf(left_dist, right_dist), minf(top_dist, bottom_dist))

	if is_equal_approx(nearest, left_dist):
		clamped.x = playfield_rect.position.x
	elif is_equal_approx(nearest, right_dist):
		clamped.x = playfield_rect.end.x
	elif is_equal_approx(nearest, top_dist):
		clamped.y = playfield_rect.position.y
	else:
		clamped.y = playfield_rect.end.y
	return clamped


func _perimeter_length() -> float:
	return playfield_rect.size.x * 2.0 + playfield_rect.size.y * 2.0


func _wrap_border_progress(progress: float) -> float:
	var perimeter := _perimeter_length()
	if perimeter <= 0.0:
		return 0.0
	var wrapped := fmod(progress, perimeter)
	if wrapped < 0.0:
		wrapped += perimeter
	return wrapped
