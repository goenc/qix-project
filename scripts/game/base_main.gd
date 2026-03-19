extends Node2D

const TITLE_SCENE_PATH := "res://scenes/title_main.tscn"
const InputActionUtils = preload("res://scripts/common/input_action_utils.gd")
const PlayfieldBoundary = preload("res://scripts/game/playfield_boundary.gd")
const BBOS_SCENE = preload("res://scenes/enemy/bbos.tscn")
const ACTION_QIX_DRAW := &"qix_draw"
const PLAYFIELD_SIZE := Vector2(904.0, 640.0)
const STAGE_REMAINING_BACKGROUND_TEXTURE = preload("res://assets/backgrounds/stages/stage_001/claimed_background_904x640.png")
const STAGE_COVER_BACKGROUND_TEXTURE = preload("res://assets/backgrounds/stages/stage_001/cover_background_904x640.png")

@export var playfield_margin := Vector2(32.0, 40.0)
@export var playfield_min_size := Vector2(180.0, 120.0)
@export var hud_width := 280.0
@export var hud_gap := 32.0
@export var playfield_fill_color := Color(0.02, 0.02, 0.02, 1.0)
@export var claimed_fill_color := Color(0.45, 0.0, 0.7, 0.05)
@export var playfield_outer_frame_color := Color(0.35, 0.35, 0.35, 1.0)
@export var playfield_border_color := Color(1.0, 1.0, 1.0, 1.0)
@export var playfield_border_width := 3.0
@export var playfield_outer_frame_padding := 12.0
@export var guide_segment_color := Color(1.0, 0.0, 0.0, 1.0)
@export var guide_vertical_color := Color(0.7, 0.0, 1.0, 1.0)
@export var guide_segment_width := 2.0

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
var stage_cover_polygon: PackedVector2Array = PackedVector2Array()
var stage_cover_uvs: PackedVector2Array = PackedVector2Array()
var claimed_polygons: Array[PackedVector2Array] = []
var current_outer_loop: PackedVector2Array = PackedVector2Array()
var remaining_polygon: PackedVector2Array = PackedVector2Array()
var inactive_border_segments: Array[PackedVector2Array] = []
var guide_segments: Array[Dictionary] = []
var claimed_area := 0.0
var inactive_border_color := Color(1.0, 1.0, 1.0, 0.1)
var game_over := false
var show_vertical_guides := true
var show_horizontal_guides := true


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
	_sync_debug_guide_visibility()
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


func set_show_vertical_guides_from_debug(enabled: bool) -> void:
	if show_vertical_guides == enabled:
		return
	show_vertical_guides = enabled
	queue_redraw()


func set_show_horizontal_guides_from_debug(enabled: bool) -> void:
	if show_horizontal_guides == enabled:
		return
	show_horizontal_guides = enabled
	queue_redraw()


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
	InputActionUtils.ensure_action(action_name, events)


func _replace_action_events(action_name: String, events: Array[InputEvent]) -> void:
	InputActionUtils.replace_action_events(action_name, events)


func _sync_draw_action_events(events: Array[InputEvent]) -> void:
	InputActionUtils.replace_existing_action_events(ACTION_QIX_DRAW, events)


func _key_event(keycode: Key) -> InputEventKey:
	return InputActionUtils.key_event(keycode, true, true)


func _joypad_button(button_index: JoyButton) -> InputEventJoypadButton:
	return InputActionUtils.joypad_button(button_index)


func _draw() -> void:
	if current_outer_loop.size() < 3:
		return

	draw_texture_rect(STAGE_REMAINING_BACKGROUND_TEXTURE, playfield_rect, false)
	if stage_cover_polygon.size() >= 3:
		var cover_colors := PackedColorArray()
		for _index in range(stage_cover_polygon.size()):
			cover_colors.append(Color.WHITE)
		draw_polygon(stage_cover_polygon, cover_colors, stage_cover_uvs, STAGE_COVER_BACKGROUND_TEXTURE)

	var outer_rect := playfield_rect.grow(playfield_outer_frame_padding)
	for polygon in claimed_polygons:
		if polygon.size() >= 3:
			draw_colored_polygon(polygon, claimed_fill_color)
	_draw_border_segments(inactive_border_segments, inactive_border_color)
	_draw_guide_segments()
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
	playfield_rect = _create_playfield_rect()
	if stage_cover_polygon.size() >= 3:
		_rebuild_stage_cover_uvs()


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
	if base_player.has_signal("guide_turn_created") and !base_player.guide_turn_created.is_connected(_on_player_guide_turn_created):
		base_player.guide_turn_created.connect(_on_player_guide_turn_created)
	if base_player.has_signal("hp_changed") and !base_player.hp_changed.is_connected(_on_player_hp_changed):
		base_player.hp_changed.connect(_on_player_hp_changed)
	if base_player.has_signal("defeated") and !base_player.defeated.is_connected(_on_player_defeated):
		base_player.defeated.connect(_on_player_defeated)


func _initialize_outer_loop_from_rect() -> void:
	current_outer_loop = PlayfieldBoundary.create_rect_loop(playfield_rect)
	remaining_polygon = _create_playfield_cover_polygon()
	var initial_stage_cover_source := remaining_polygon if remaining_polygon.size() >= 3 else _create_playfield_cover_polygon()
	_rebuild_stage_cover_polygon_from_polygon(initial_stage_cover_source)
	queue_redraw()
	inactive_border_segments.clear()
	if claimed_polygons.is_empty():
		claimed_area = 0.0
	_refresh_guide_segments()


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

	var epsilon := _resolve_capture_epsilon()
	var candidate_loops := _build_capture_candidate_loops(trail_points, epsilon)
	if candidate_loops.size() < 2:
		push_warning("Capture skipped: candidate outer loops could not be generated.")
		return

	var retained_index := _select_boss_side_loop(candidate_loops, epsilon)
	if retained_index < 0 or retained_index >= candidate_loops.size():
		push_warning("Capture skipped: boss-side outer loop could not be determined.")
		return

	_apply_retained_capture_loop(candidate_loops[retained_index])
	var capture_delta := _append_claimed_capture_results(candidate_loops, retained_index)
	_finalize_capture_closed(capture_delta)


func _on_player_guide_turn_created(
	turn_point: Vector2,
	previous_direction: Vector2,
	new_direction: Vector2
) -> void:
	var guide_directions := [
		_normalize_guide_direction(previous_direction),
		_normalize_guide_direction(-new_direction)
	]

	for guide_direction in guide_directions:
		if guide_direction == Vector2.ZERO:
			continue

		var guide_segment := {
			"start": turn_point,
			"end": turn_point,
			"dir": guide_direction,
			"active": false
		}
		guide_segments.append(_resolve_guide_segment(guide_segment))
	queue_redraw()


func _get_boss_selection_point() -> Vector2:
	if is_instance_valid(bbos):
		return bbos.global_position
	if is_instance_valid(boss):
		return boss.global_position
	return current_outer_loop[0]


func _resolve_capture_epsilon() -> float:
	var epsilon := 2.0
	if is_instance_valid(base_player):
		epsilon = base_player.border_epsilon
	return epsilon


func _build_capture_candidate_loops(trail_points: PackedVector2Array, epsilon: float) -> Array[Dictionary]:
	return PlayfieldBoundary.split_outer_loop_by_trail(current_outer_loop, trail_points, epsilon)


func _select_boss_side_loop(candidate_loops: Array[Dictionary], epsilon: float) -> int:
	_sync_boss_marker()
	var selection_point := _get_boss_selection_point()
	return PlayfieldBoundary.select_loop_containing_point(candidate_loops, selection_point, epsilon)


func _apply_retained_capture_loop(retained_candidate: Dictionary) -> void:
	current_outer_loop = retained_candidate.get("loop", PackedVector2Array())
	var retained_polygon: PackedVector2Array = retained_candidate.get("polygon", PackedVector2Array())
	if retained_polygon.size() >= 3:
		remaining_polygon = retained_polygon
	var stage_cover_source := retained_polygon if retained_polygon.size() >= 3 else remaining_polygon
	_rebuild_stage_cover_polygon_from_polygon(stage_cover_source)
	inactive_border_segments.clear()


func _append_claimed_capture_results(candidate_loops: Array[Dictionary], retained_index: int) -> Dictionary:
	var captured_polygons_delta: Array[PackedVector2Array] = []
	var inactive_segments_delta: Array[PackedVector2Array] = []
	for index in range(candidate_loops.size()):
		if index == retained_index:
			continue
		var captured_polygon: PackedVector2Array = candidate_loops[index].get("polygon", PackedVector2Array())
		if captured_polygon.size() >= 3:
			claimed_polygons.append(captured_polygon)
			captured_polygons_delta.append(captured_polygon)
		var removed_path: PackedVector2Array = candidate_loops[index].get("boundary_path", PackedVector2Array())
		var removed_segments := _polyline_to_segments(removed_path)
		if removed_segments.is_empty():
			continue
		inactive_border_segments.append_array(removed_segments)
		inactive_segments_delta.append_array(removed_segments)

	return {
		"captured_polygons": captured_polygons_delta,
		"inactive_segments": inactive_segments_delta
	}


func _collect_dirty_guide_indices_from_capture_delta(capture_delta: Dictionary) -> Array[int]:
	var dirty_indices: Array[int] = []
	var captured_polygons_delta: Array[PackedVector2Array] = []
	if capture_delta.has("captured_polygons"):
		captured_polygons_delta = capture_delta["captured_polygons"]
	var inactive_segments_delta: Array[PackedVector2Array] = []
	if capture_delta.has("inactive_segments"):
		inactive_segments_delta = capture_delta["inactive_segments"]
	if captured_polygons_delta.is_empty() and inactive_segments_delta.is_empty():
		return dirty_indices

	var epsilon := _get_guide_epsilon()
	var captured_rects: Array[Rect2] = []
	for polygon in captured_polygons_delta:
		if polygon.size() < 3:
			continue
		captured_rects.append(_build_points_aabb(polygon))

	var inactive_rects: Array[Rect2] = []
	for segment in inactive_segments_delta:
		if segment.size() < 2:
			continue
		inactive_rects.append(_build_points_aabb(segment))

	for index in range(guide_segments.size()):
		if _guide_segment_overlaps_capture_delta(guide_segments[index], captured_rects, inactive_rects, epsilon):
			dirty_indices.append(index)
	return dirty_indices


func _guide_segment_overlaps_capture_delta(
	guide_segment: Dictionary,
	captured_rects: Array[Rect2],
	inactive_rects: Array[Rect2],
	epsilon: float
) -> bool:
	var direction := _normalize_guide_direction(guide_segment.get("dir", Vector2.ZERO))
	if direction == Vector2.ZERO:
		return false

	var start: Vector2 = guide_segment.get("start", Vector2.ZERO)
	var end: Vector2 = guide_segment.get("end", start)
	for rect in captured_rects:
		if _segment_overlaps_rect(start, end, direction, rect, epsilon):
			return true
	for rect in inactive_rects:
		if _segment_overlaps_rect(start, end, direction, rect, epsilon):
			return true
	return false


func _segment_overlaps_rect(
	start: Vector2,
	end: Vector2,
	direction: Vector2,
	rect: Rect2,
	epsilon: float
) -> bool:
	if absf(direction.x) > 0.0:
		var segment_min_x := minf(start.x, end.x)
		var segment_max_x := maxf(start.x, end.x)
		return (
			start.y >= rect.position.y - epsilon
			and start.y <= rect.end.y + epsilon
			and segment_max_x >= rect.position.x - epsilon
			and segment_min_x <= rect.end.x + epsilon
		)

	var segment_min_y := minf(start.y, end.y)
	var segment_max_y := maxf(start.y, end.y)
	return (
		start.x >= rect.position.x - epsilon
		and start.x <= rect.end.x + epsilon
		and segment_max_y >= rect.position.y - epsilon
		and segment_min_y <= rect.end.y + epsilon
	)


func _build_points_aabb(points: PackedVector2Array) -> Rect2:
	if points.is_empty():
		return Rect2()

	var min_point := points[0]
	var max_point := points[0]
	for index in range(1, points.size()):
		var point := points[index]
		min_point.x = minf(min_point.x, point.x)
		min_point.y = minf(min_point.y, point.y)
		max_point.x = maxf(max_point.x, point.x)
		max_point.y = maxf(max_point.y, point.y)
	return Rect2(min_point, max_point - min_point)


func _finalize_capture_closed(capture_delta: Dictionary) -> void:
	_recalculate_claimed_area()
	_apply_playfield_to_player()
	_apply_playfield_to_bbos()
	var dirty_indices := _collect_dirty_guide_indices_from_capture_delta(capture_delta)
	if !dirty_indices.is_empty():
		_refresh_dirty_guide_segments(dirty_indices, true)
	_sync_boss_marker()
	queue_redraw()
	_sync_hud()


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


func _create_playfield_rect() -> Rect2:
	var viewport_rect := get_viewport_rect()
	return Rect2(viewport_rect.position + playfield_margin, PLAYFIELD_SIZE)


func _create_playfield_cover_polygon() -> PackedVector2Array:
	var rect := playfield_rect
	var polygon := PackedVector2Array()
	polygon.append(rect.position)
	polygon.append(rect.position + Vector2(rect.size.x, 0.0))
	polygon.append(rect.position + rect.size)
	polygon.append(rect.position + Vector2(0.0, rect.size.y))
	return polygon


func _rebuild_stage_cover_polygon_from_polygon(source_polygon: PackedVector2Array) -> void:
	if source_polygon.size() < 3:
		return

	var rebuilt_polygon := PlayfieldBoundary.sanitize_loop(source_polygon)
	if rebuilt_polygon.size() < 3:
		return

	stage_cover_polygon = rebuilt_polygon.duplicate()
	_rebuild_stage_cover_uvs()


func _rebuild_stage_cover_uvs() -> void:
	stage_cover_uvs = _build_stage_cover_uvs(stage_cover_polygon)


func _build_stage_cover_uvs(points: PackedVector2Array) -> PackedVector2Array:
	var uvs := PackedVector2Array()
	if is_zero_approx(playfield_rect.size.x) or is_zero_approx(playfield_rect.size.y):
		return uvs

	for point in points:
		uvs.append(Vector2(
			clampf((point.x - playfield_rect.position.x) / playfield_rect.size.x, 0.0, 1.0),
			clampf((point.y - playfield_rect.position.y) / playfield_rect.size.y, 0.0, 1.0)
	))
	return uvs


func _draw_guide_segments() -> void:
	var epsilon := _get_guide_epsilon()
	for guide_segment in guide_segments:
		if !bool(guide_segment.get("active", false)):
			continue
		var start: Vector2 = guide_segment.get("start", Vector2.ZERO)
		var end: Vector2 = guide_segment.get("end", start)
		var direction: Vector2 = guide_segment.get("dir", Vector2.ZERO)
		if start.distance_to(end) <= epsilon:
			continue
		var is_vertical := absf(direction.y) > 0.0
		if is_vertical and !show_vertical_guides:
			continue
		if absf(direction.x) > 0.0 and !show_horizontal_guides:
			continue
		var guide_color := guide_vertical_color if absf(direction.y) > 0.0 else guide_segment_color
		draw_line(start, end, guide_color, guide_segment_width)


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


func _refresh_guide_segments(apply_capture_correction: bool = false) -> void:
	for index in range(guide_segments.size()):
		guide_segments[index] = _resolve_guide_segment(guide_segments[index], apply_capture_correction)


func _refresh_dirty_guide_segments(dirty_indices: Array[int], apply_capture_correction: bool = true) -> void:
	for index in dirty_indices:
		if index < 0 or index >= guide_segments.size():
			continue
		guide_segments[index] = _resolve_guide_segment(guide_segments[index], apply_capture_correction)


func _resolve_guide_segment(guide_segment: Dictionary, apply_capture_correction: bool = false) -> Dictionary:
	var epsilon := _get_guide_epsilon()
	var resolved_segment := guide_segment.duplicate()
	var start: Vector2 = resolved_segment.get("start", Vector2.ZERO)
	var direction := _normalize_guide_direction(resolved_segment.get("dir", Vector2.ZERO))
	resolved_segment["start"] = start
	resolved_segment["end"] = start
	resolved_segment["dir"] = direction
	resolved_segment["active"] = false
	if direction == Vector2.ZERO:
		return resolved_segment

	var end_result := _resolve_guide_segment_end(start, direction, epsilon)
	if !bool(end_result.get("hit", false)):
		return resolved_segment

	var end_point: Vector2 = end_result.get("end", start)
	if start.distance_to(end_point) <= epsilon:
		return resolved_segment
	resolved_segment["end"] = end_point
	resolved_segment["active"] = true
	if apply_capture_correction:
		return _apply_capture_guide_segment_correction(resolved_segment, epsilon)
	return resolved_segment


func _resolve_guide_segment_end(start: Vector2, direction: Vector2, epsilon: float) -> Dictionary:
	var hit := _find_first_guide_boundary_hit(start, direction, epsilon)
	if !bool(hit.get("hit", false)):
		return {
			"hit": false,
			"end": start
		}

	var end_point: Vector2 = hit.get("point", start)
	if start.distance_to(end_point) <= epsilon:
		return {
			"hit": false,
			"end": start
		}

	return {
		"hit": true,
		"end": end_point
	}


func _apply_capture_guide_segment_correction(guide_segment: Dictionary, epsilon: float) -> Dictionary:
	var corrected_segment := guide_segment.duplicate()
	if !bool(corrected_segment.get("active", false)):
		return corrected_segment

	var start: Vector2 = corrected_segment.get("start", Vector2.ZERO)
	var end: Vector2 = corrected_segment.get("end", start)
	var direction := _normalize_guide_direction(corrected_segment.get("dir", Vector2.ZERO))
	var correction_result := _find_first_valid_guide_region_end_on_segment(start, end, direction, epsilon)
	if !bool(correction_result.get("found", false)):
		corrected_segment["end"] = start
		corrected_segment["active"] = false
		return corrected_segment

	var corrected_end: Vector2 = correction_result.get("point", start)
	if start.distance_to(corrected_end) <= epsilon:
		corrected_segment["end"] = start
		corrected_segment["active"] = false
		return corrected_segment

	corrected_segment["end"] = corrected_end
	corrected_segment["active"] = true
	return corrected_segment


func _find_first_valid_guide_region_end_on_segment(
	start: Vector2,
	end: Vector2,
	direction: Vector2,
	epsilon: float
) -> Dictionary:
	var scan_bounds := _get_guide_scan_bounds(start, end, direction)
	if !bool(scan_bounds.get("valid", false)):
		return {"found": false}

	var scan_from := int(scan_bounds.get("from", 0))
	var scan_to := int(scan_bounds.get("to", 0))
	var scan_step := int(scan_bounds.get("step", 0))
	var max_iterations := int(ceil(start.distance_to(end))) + 2
	var found_valid_region := false
	var last_valid_point := start
	for iteration in range(max_iterations):
		var axis_value := scan_from + scan_step * iteration
		if scan_step < 0 and axis_value < scan_to:
			axis_value = scan_to
		elif scan_step > 0 and axis_value > scan_to:
			axis_value = scan_to

		var sample_point := _build_guide_scan_point(scan_bounds, axis_value)
		var is_valid_point := _is_point_in_valid_guide_region(sample_point, epsilon)
		if is_valid_point:
			found_valid_region = true
			last_valid_point = sample_point
		elif found_valid_region:
			return {
				"found": true,
				"point": last_valid_point
			}

		if axis_value == scan_to:
			break

	if found_valid_region:
		return {
			"found": true,
			"point": end
		}
	return {"found": false}


func _get_guide_scan_bounds(start: Vector2, end: Vector2, direction: Vector2) -> Dictionary:
	if absf(direction.x) > 0.0:
		if direction.x > 0.0:
			return {
				"valid": true,
				"horizontal": true,
				"from": int(ceil(start.x)),
				"to": int(floor(end.x)),
				"fixed": int(round(start.y)),
				"step": 1
			}
		return {
			"valid": true,
			"horizontal": true,
			"from": int(floor(start.x)),
			"to": int(ceil(end.x)),
			"fixed": int(round(start.y)),
			"step": -1
		}

	if absf(direction.y) > 0.0:
		if direction.y > 0.0:
			return {
				"valid": true,
				"horizontal": false,
				"from": int(ceil(start.y)),
				"to": int(floor(end.y)),
				"fixed": int(round(start.x)),
				"step": 1
			}
		return {
			"valid": true,
			"horizontal": false,
			"from": int(floor(start.y)),
			"to": int(ceil(end.y)),
			"fixed": int(round(start.x)),
			"step": -1
		}

	return {"valid": false}


func _build_guide_scan_point(scan_bounds: Dictionary, axis_value: int) -> Vector2:
	var fixed_axis := float(scan_bounds.get("fixed", 0))
	if bool(scan_bounds.get("horizontal", false)):
		return Vector2(float(axis_value), fixed_axis)
	return Vector2(fixed_axis, float(axis_value))


func _find_first_guide_boundary_hit(start: Vector2, direction: Vector2, epsilon: float) -> Dictionary:
	var ray_end := _build_guide_ray_end(start, direction, epsilon)
	var best_hit := {"hit": false}
	best_hit = _pick_nearest_guide_hit(best_hit, _find_guide_loop_hit(start, ray_end, _get_guide_boundary_loop(), epsilon), epsilon)
	for polygon in claimed_polygons:
		best_hit = _pick_nearest_guide_hit(best_hit, _find_guide_loop_hit(start, ray_end, polygon, epsilon), epsilon)
	return best_hit


func _find_guide_loop_hit(
	start: Vector2,
	ray_end: Vector2,
	loop: PackedVector2Array,
	epsilon: float
) -> Dictionary:
	if loop.size() < 2:
		return {"hit": false}

	var hit := PlayfieldBoundary.find_first_boundary_hit(start, ray_end, loop, epsilon)
	if !bool(hit.get("hit", false)):
		return {"hit": false}

	var hit_point: Vector2 = hit.get("point", start)
	var hit_distance := start.distance_to(hit_point)
	if hit_distance <= epsilon:
		return {"hit": false}

	return {
		"hit": true,
		"point": hit_point,
		"distance": hit_distance
	}


func _pick_nearest_guide_hit(current_hit: Dictionary, candidate_hit: Dictionary, epsilon: float) -> Dictionary:
	if !bool(candidate_hit.get("hit", false)):
		return current_hit
	if !bool(current_hit.get("hit", false)):
		return candidate_hit
	if float(candidate_hit.get("distance", INF)) < float(current_hit.get("distance", INF)) - epsilon:
		return candidate_hit
	return current_hit


func _build_guide_ray_end(start: Vector2, direction: Vector2, epsilon: float) -> Vector2:
	var margin := maxf(epsilon * 8.0, 8.0)
	if absf(direction.x) > 0.0:
		var target_x := playfield_rect.end.x + margin if direction.x > 0.0 else playfield_rect.position.x - margin
		return Vector2(target_x, start.y)
	if absf(direction.y) > 0.0:
		var target_y := playfield_rect.end.y + margin if direction.y > 0.0 else playfield_rect.position.y - margin
		return Vector2(start.x, target_y)
	return start


func _get_guide_boundary_loop() -> PackedVector2Array:
	if remaining_polygon.size() >= 3:
		return remaining_polygon
	return current_outer_loop


func _is_point_in_valid_guide_region(point: Vector2, epsilon: float) -> bool:
	if _is_point_in_claimed_region(point, epsilon):
		return false
	if _is_point_on_inactive_border(point, epsilon):
		return false
	return _is_point_in_remaining_region(point, epsilon)


func _is_point_in_claimed_region(point: Vector2, epsilon: float) -> bool:
	for polygon in claimed_polygons:
		if polygon.size() < 3:
			continue
		if Geometry2D.is_point_in_polygon(point, polygon) or PlayfieldBoundary.is_point_on_loop(polygon, point, epsilon):
			return true
	return false


func _is_point_on_inactive_border(point: Vector2, epsilon: float) -> bool:
	for segment in inactive_border_segments:
		for index in range(segment.size() - 1):
			if _is_point_on_segment(point, segment[index], segment[index + 1], epsilon):
				return true
	return false


func _is_point_on_segment(point: Vector2, segment_start: Vector2, segment_end: Vector2, epsilon: float) -> bool:
	var segment := segment_end - segment_start
	var segment_length_squared := segment.length_squared()
	if segment_length_squared <= epsilon * epsilon:
		return point.distance_to(segment_start) <= epsilon

	var projection := clampf((point - segment_start).dot(segment) / segment_length_squared, 0.0, 1.0)
	var projected_point := segment_start + segment * projection
	return projected_point.distance_to(point) <= epsilon


func _is_point_in_remaining_region(point: Vector2, epsilon: float) -> bool:
	var boundary_loop := _get_guide_boundary_loop()
	if boundary_loop.size() >= 3:
		return Geometry2D.is_point_in_polygon(point, boundary_loop) or PlayfieldBoundary.is_point_on_loop(boundary_loop, point, epsilon)
	if playfield_rect.size.x <= 0.0 or playfield_rect.size.y <= 0.0:
		return false
	return playfield_rect.has_point(point)


func _normalize_guide_direction(direction: Vector2) -> Vector2:
	if absf(direction.x) > absf(direction.y):
		return Vector2(signf(direction.x), 0.0)
	if absf(direction.y) > 0.0:
		return Vector2(0.0, signf(direction.y))
	return Vector2.ZERO


func _get_guide_epsilon() -> float:
	return maxf(PlayfieldBoundary.DEFAULT_EPSILON * 10.0, _resolve_capture_epsilon() * 0.25)


func _sync_debug_guide_visibility() -> void:
	var debug_manager := get_node_or_null("/root/DebugManager")
	if !is_instance_valid(debug_manager):
		return
	if debug_manager.has_method("is_vertical_guides_enabled"):
		show_vertical_guides = bool(debug_manager.call("is_vertical_guides_enabled"))
	if debug_manager.has_method("is_horizontal_guides_enabled"):
		show_horizontal_guides = bool(debug_manager.call("is_horizontal_guides_enabled"))


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
