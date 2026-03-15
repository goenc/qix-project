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
var remaining_polygon: PackedVector2Array = PackedVector2Array()
var active_border_loop: PackedVector2Array = PackedVector2Array()
var inactive_border_segments: Array[PackedVector2Array] = []
var claimed_area := 0.0
var inactive_border_color := Color(1.0, 1.0, 1.0, 0.1)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = false
	_register_input_map()
	_recalculate_playfield_rect()
	_initialize_playfield_border_state()
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
	_draw_border_segments(inactive_border_segments, inactive_border_color)
	_draw_border_loop(active_border_loop, playfield_border_color)
	draw_rect(outer_rect, playfield_outer_frame_color, false, 2.0)


func _on_viewport_size_changed() -> void:
	_recalculate_playfield_rect()
	if claimed_polygons.is_empty():
		_initialize_playfield_border_state()
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
	if active_border_loop.is_empty() or remaining_polygon.is_empty():
		_initialize_playfield_border_state()
	if is_instance_valid(base_player):
		base_player.set_playfield_rect(playfield_rect)
		_sync_player_border_state()
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
	if active_border_loop.size() < 3:
		push_warning("Claim skipped: active border loop is not ready.")
		return

	var previous_active_border := active_border_loop.duplicate()
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
	var next_remaining_polygon := candidate_a if boss_in_a else candidate_b
	var remaining_path_clockwise := boss_in_a
	if !_rebuild_active_border_state(
		previous_active_border,
		next_remaining_polygon,
		snapped_start,
		snapped_end,
		remaining_path_clockwise
	):
		push_warning("Claim skipped: active border loop could not be rebuilt from the boss-side region.")
		return

	claimed_polygons.append(_ensure_consistent_polygon_winding(claimed_polygon))
	_recalculate_claimed_area()
	_sync_player_border_state()
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
	return _build_loop_path(active_border_loop, from_point, to_point, clockwise)


func _build_loop_path(
	loop: PackedVector2Array,
	from_point: Vector2,
	to_point: Vector2,
	clockwise: bool
) -> PackedVector2Array:
	var path := PackedVector2Array()
	if loop.size() < 2:
		return path

	var snapped_from := _snap_point_to_loop(loop, from_point)
	var snapped_to := _snap_point_to_loop(loop, to_point)
	var from_progress := _point_to_loop_progress(loop, snapped_from)
	var to_progress := _point_to_loop_progress(loop, snapped_to)
	var total_distance := _loop_travel_distance(_get_loop_total_length(loop), from_progress, to_progress, clockwise)
	if total_distance <= 0.0:
		return path

	var corners := []
	for vertex in _get_loop_vertex_infos(loop):
		var distance := _loop_travel_distance(
			_get_loop_total_length(loop),
			from_progress,
			float(vertex["progress"]),
			clockwise
		)
		if distance > 0.001 and distance < total_distance - 0.001:
			corners.append({
				"distance": distance,
				"point": vertex["point"]
			})

	corners.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["distance"]) < float(b["distance"])
	)

	for corner in corners:
		path.append(corner["point"])
	return path


func _build_loop_path_points(
	loop: PackedVector2Array,
	from_point: Vector2,
	to_point: Vector2,
	clockwise: bool
) -> PackedVector2Array:
	var path := PackedVector2Array()
	if loop.size() < 2:
		return path

	var snapped_from := _snap_point_to_loop(loop, from_point)
	var snapped_to := _snap_point_to_loop(loop, to_point)
	path.append(snapped_from)
	for point in _build_loop_path(loop, snapped_from, snapped_to, clockwise):
		if path.is_empty() or !path[path.size() - 1].is_equal_approx(point):
			path.append(point)
	if path.is_empty() or !path[path.size() - 1].is_equal_approx(snapped_to):
		path.append(snapped_to)
	return _sanitize_trail_polyline(path)


func _get_loop_vertex_infos(loop: PackedVector2Array) -> Array:
	var vertex_infos: Array = []
	if loop.size() < 2:
		return vertex_infos

	var progress := 0.0
	for index in range(loop.size()):
		vertex_infos.append({
			"progress": progress,
			"point": loop[index]
		})
		progress += loop[index].distance_to(loop[(index + 1) % loop.size()])
	return vertex_infos


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
	return _loop_travel_distance(_get_loop_total_length(active_border_loop), from_progress, to_progress, clockwise)


func _point_to_border_progress(point: Vector2) -> float:
	return _point_to_loop_progress(active_border_loop, point)


func _clamp_to_playfield(point: Vector2) -> Vector2:
	return Vector2(
		clampf(point.x, playfield_rect.position.x, playfield_rect.end.x),
		clampf(point.y, playfield_rect.position.y, playfield_rect.end.y)
	)


func _snap_point_to_border(point: Vector2) -> Vector2:
	return _snap_point_to_loop(active_border_loop, point)


func _perimeter_length() -> float:
	return _get_loop_total_length(active_border_loop)


func _wrap_border_progress(progress: float) -> float:
	return _wrap_loop_progress(progress, _perimeter_length())


func _wrap_loop_progress(progress: float, total_length: float) -> float:
	if total_length <= 0.0:
		return 0.0
	var wrapped := fmod(progress, total_length)
	if wrapped < 0.0:
		wrapped += total_length
	return wrapped


func _loop_travel_distance(total_length: float, from_progress: float, to_progress: float, clockwise: bool) -> float:
	if total_length <= 0.0:
		return 0.0
	if clockwise:
		return _wrap_loop_progress(to_progress - from_progress, total_length)
	return _wrap_loop_progress(from_progress - to_progress, total_length)


func _point_to_loop_progress(loop: PackedVector2Array, point: Vector2) -> float:
	return float(_get_loop_projection(loop, point).get("progress", 0.0))


func _snap_point_to_loop(loop: PackedVector2Array, point: Vector2) -> Vector2:
	return _get_loop_projection(loop, point).get("point", point)


func _get_loop_projection(loop: PackedVector2Array, point: Vector2) -> Dictionary:
	if loop.size() < 2:
		return {
			"point": _clamp_to_playfield(point),
			"progress": 0.0,
			"distance": point.distance_to(_clamp_to_playfield(point))
		}

	var best_distance := INF
	var best_point := loop[0]
	var best_progress := 0.0
	var progress := 0.0
	for index in range(loop.size()):
		var segment_start: Vector2 = loop[index]
		var segment_end: Vector2 = loop[(index + 1) % loop.size()]
		var segment_length := segment_start.distance_to(segment_end)
		if segment_length <= 0.001:
			continue

		var projected_point := Geometry2D.get_closest_point_to_segment(point, segment_start, segment_end)
		var distance := point.distance_to(projected_point)
		if distance < best_distance - 0.001:
			best_distance = distance
			best_point = projected_point
			best_progress = progress + clampf(segment_start.distance_to(projected_point), 0.0, segment_length)

		progress += segment_length

	return {
		"point": best_point,
		"progress": best_progress,
		"distance": best_distance
	}


func _get_loop_total_length(loop: PackedVector2Array) -> float:
	if loop.size() < 2:
		return 0.0

	var total_length := 0.0
	for index in range(loop.size()):
		total_length += loop[index].distance_to(loop[(index + 1) % loop.size()])
	return total_length


func _initialize_playfield_border_state() -> void:
	var rect_polygon := _ensure_consistent_polygon_winding(_rect_to_polygon(playfield_rect))
	remaining_polygon = rect_polygon
	active_border_loop = rect_polygon.duplicate()
	inactive_border_segments.clear()


func _sync_player_border_state() -> void:
	if is_instance_valid(base_player):
		base_player.set_active_border(active_border_loop, remaining_polygon)


func _rebuild_active_border_state(
	previous_active_border: PackedVector2Array,
	next_remaining_polygon: PackedVector2Array,
	start_point: Vector2,
	end_point: Vector2,
	remaining_path_clockwise: bool
) -> bool:
	var sanitized_remaining := _ensure_consistent_polygon_winding(_sanitize_polygon(next_remaining_polygon))
	if !_is_valid_claim_polygon(sanitized_remaining):
		return false

	var next_active_border := _sanitize_polygon(sanitized_remaining)
	if next_active_border.size() < 3:
		return false

	var removed_path := _build_loop_path_points(
		previous_active_border,
		start_point,
		end_point,
		remaining_path_clockwise
	)

	remaining_polygon = sanitized_remaining
	active_border_loop = next_active_border
	inactive_border_segments = _polyline_to_segments(removed_path)
	return true


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
	for index in range(loop.size()):
		draw_line(loop[index], loop[(index + 1) % loop.size()], color, playfield_border_width)


func _draw_border_segments(segments: Array[PackedVector2Array], color: Color) -> void:
	for segment in segments:
		if segment.size() < 2:
			continue
		for index in range(segment.size() - 1):
			draw_line(segment[index], segment[index + 1], color, playfield_border_width)


func _rect_to_polygon(rect: Rect2) -> PackedVector2Array:
	var polygon := PackedVector2Array()
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return polygon

	polygon.append(rect.position)
	polygon.append(Vector2(rect.end.x, rect.position.y))
	polygon.append(rect.end)
	polygon.append(Vector2(rect.position.x, rect.end.y))
	return polygon
