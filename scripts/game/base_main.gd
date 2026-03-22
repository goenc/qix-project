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
@export var guide_short_segment_color := Color(0.0, 1.0, 0.0, 1.0)
@export var guide_segment_width := 2.0
@export var guide_debug_point_radius := 4.0
@export var guide_vertical_start_point_color := Color(0.2, 0.95, 1.0, 1.0)
@export var guide_vertical_end_point_color := Color(1.0, 0.9, 0.2, 1.0)
@export var guide_horizontal_start_point_color := Color(0.2, 1.0, 0.45, 1.0)
@export var guide_horizontal_end_point_color := Color(1.0, 0.45, 0.2, 1.0)
@export var guide_partition_fill_color := Color(0.75, 0.55, 1.0, 0.5)
@export var boss_region_fill_color := Color(0.0, 1.0, 0.0, 0.5)

@onready var base_player = get_node_or_null("BasePlayer")
@onready var bbos: Node2D = get_node_or_null("BBOS")
@onready var boss: Node2D = get_node_or_null("Boss")
@onready var help_label: Label = $Ui/Root/HelpLabel
@onready var state_label: Label = $Ui/Root/StateLabel
@onready var position_label: Label = $Ui/Root/PositionLabel
@onready var claimed_label: Label = $Ui/Root/ClaimedLabel
@onready var boss_region_label: Label = $Ui/Root/BossRegionLabel
@onready var hp_label: Label = $Ui/Root/HpLabel
@onready var result_label: Label = $Ui/Root/ResultLabel

var playfield_rect: Rect2 = Rect2()
var stage_cover_polygon: PackedVector2Array = PackedVector2Array()
var stage_cover_uvs: PackedVector2Array = PackedVector2Array()
var claimed_polygons: Array[PackedVector2Array] = []
var claimed_polygon_aabbs: Array[Rect2] = []
var guide_partition_fill_entries: Array[Dictionary] = []
var guide_partition_fill_polygons_by_key: Dictionary = {}
var guide_partition_fill_entry_key_sequence := 0
var boss_region_polygon: PackedVector2Array = PackedVector2Array()
var current_outer_loop: PackedVector2Array = PackedVector2Array()
var current_outer_loop_metrics: Dictionary = {}
var remaining_polygon: PackedVector2Array = PackedVector2Array()
var inactive_border_segments: Array[PackedVector2Array] = []
var inactive_border_segment_aabbs: Array[Rect2] = []
var guide_segments: Array[Dictionary] = []
var vertical_guide_indices_by_x: Dictionary = {}
var horizontal_guide_indices_by_y: Dictionary = {}
var vertical_guide_axis_keys: Array[int] = []
var horizontal_guide_axis_keys: Array[int] = []
var playfield_area_cached := 0.0
var claimed_area := 0.0
var claimed_ratio_cached := 0.0
var boss_region_area_cached := 0.0
var boss_region_ratio_cached := 0.0
var inactive_border_color := Color(1.0, 1.0, 1.0, 0.1)
var game_over := false
var show_vertical_guides := true
var show_horizontal_guides := true
var show_area_fills := true
var show_area_percent_labels := true
var current_capture_generation := 0
var capture_preview_active := false
var last_synced_boss_marker_position := Vector2.ZERO
var has_last_synced_boss_marker_position := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = false
	_register_input_map()
	_ensure_bbos_node()
	_recalculate_playfield_rect()
	_initialize_outer_loop_from_rect()
	_connect_player_signal()
	_connect_bbos_signal()
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


func set_show_area_fills_from_debug(enabled: bool) -> void:
	if show_area_fills == enabled:
		return
	show_area_fills = enabled
	queue_redraw()


func set_show_area_percent_labels_from_debug(enabled: bool) -> void:
	if show_area_percent_labels == enabled:
		return
	show_area_percent_labels = enabled
	_sync_hud()


func _refresh_playfield_area_cache() -> void:
	playfield_area_cached = maxf(0.0, playfield_rect.size.x * playfield_rect.size.y)
	_refresh_claimed_ratio_cache()
	_refresh_boss_region_ratio_cache()


func _refresh_claimed_ratio_cache() -> void:
	claimed_ratio_cached = 0.0
	if playfield_area_cached > 0.0:
		claimed_ratio_cached = clampf(claimed_area / playfield_area_cached, 0.0, 1.0)


func _refresh_boss_region_ratio_cache() -> void:
	boss_region_ratio_cached = 0.0
	if playfield_area_cached > 0.0 and boss_region_area_cached > 0.0:
		boss_region_ratio_cached = clampf(boss_region_area_cached / playfield_area_cached, 0.0, 1.0)


func _set_boss_region_polygon(polygon: PackedVector2Array) -> void:
	boss_region_polygon = polygon
	boss_region_area_cached = 0.0
	if boss_region_polygon.size() >= 3:
		boss_region_area_cached = PlayfieldBoundary.polygon_area(boss_region_polygon)
	_refresh_boss_region_ratio_cache()


func _sync_hud_area_labels() -> void:
	if show_area_percent_labels:
		claimed_label.text = "CLAIMED: %d%%" % int(round(claimed_ratio_cached * 100.0))
		boss_region_label.text = "BOSS REGION: %d%%" % int(round(boss_region_ratio_cached * 100.0))
		return
	claimed_label.text = "CLAIMED: OFF"
	boss_region_label.text = "BOSS REGION: OFF"


func _sync_hud() -> void:
	_sync_hud_area_labels()
	_update_hp_label()

	if game_over:
		state_label.text = "MODE: GAME OVER"
		result_label.text = "GAME OVER"
		help_label.text = "ESC: TITLE"
		if is_instance_valid(base_player):
			_sync_hud_position(base_player.position)
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
	_sync_hud_status(status)
	_sync_hud_position(status.get("position", base_player.position))


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
	if show_area_fills:
		for polygon in claimed_polygons:
			if polygon.size() >= 3:
				draw_colored_polygon(polygon, claimed_fill_color)
		if boss_region_polygon.size() >= 3:
			draw_colored_polygon(boss_region_polygon, boss_region_fill_color)
		_draw_guide_partition_fills()
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
	_refresh_playfield_area_cache()
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
	if base_player.has_signal("debug_status_changed") and !base_player.debug_status_changed.is_connected(_on_player_debug_status_changed):
		base_player.debug_status_changed.connect(_on_player_debug_status_changed)
	if base_player.has_signal("debug_position_changed") and !base_player.debug_position_changed.is_connected(_on_player_debug_position_changed):
		base_player.debug_position_changed.connect(_on_player_debug_position_changed)
	if base_player.has_signal("capture_preview_changed") and !base_player.capture_preview_changed.is_connected(_on_player_capture_preview_changed):
		base_player.capture_preview_changed.connect(_on_player_capture_preview_changed)
	if base_player.has_method("get_state_text"):
		var mode_text := _stringify_value(base_player.call("get_state_text"), "")
		capture_preview_active = mode_text == "DRAWING" or mode_text == "REWINDING"


func _connect_bbos_signal() -> void:
	if !is_instance_valid(bbos):
		return
	var position_changed_callable := Callable(self, "_on_bbos_position_changed")
	if bbos.has_signal("position_changed") and !bbos.is_connected("position_changed", position_changed_callable):
		bbos.connect("position_changed", position_changed_callable)


func _initialize_outer_loop_from_rect() -> void:
	current_outer_loop = PlayfieldBoundary.create_rect_loop(playfield_rect)
	_refresh_current_outer_loop_metrics()
	remaining_polygon = _create_playfield_cover_polygon()
	var initial_stage_cover_source := remaining_polygon if remaining_polygon.size() >= 3 else _create_playfield_cover_polygon()
	_rebuild_stage_cover_polygon_from_polygon(initial_stage_cover_source)
	guide_partition_fill_entries.clear()
	guide_partition_fill_polygons_by_key.clear()
	guide_partition_fill_entry_key_sequence = 0
	var initial_boss_region_polygon := remaining_polygon if remaining_polygon.size() >= 3 else _create_playfield_cover_polygon()
	_set_boss_region_polygon(initial_boss_region_polygon)
	_apply_boss_region_ratio_to_bbos()
	queue_redraw()
	inactive_border_segments.clear()
	inactive_border_segment_aabbs.clear()
	capture_preview_active = false
	if claimed_polygons.is_empty():
		claimed_area = 0.0
		_refresh_claimed_ratio_cache()
	_rebuild_spatial_caches()
	_rebuild_guide_axis_indices()
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
	_apply_boss_region_ratio_to_bbos()


func _apply_boss_region_ratio_to_bbos() -> void:
	if !is_instance_valid(bbos):
		return
	if bbos.has_method("set_boss_region_ratio"):
		bbos.call("set_boss_region_ratio", boss_region_ratio_cached)


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

	var completed_capture_generation := current_capture_generation
	current_capture_generation += 1
	_apply_retained_capture_loop(candidate_loops[retained_index])
	var capture_delta := _append_claimed_capture_results(candidate_loops, retained_index)
	_finalize_capture_closed(capture_delta, completed_capture_generation)


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
			"active": false,
			"capture_generation": current_capture_generation,
			"pending": true
		}
		guide_segments.append(guide_segment)
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
	return PlayfieldBoundary.split_outer_loop_by_trail(
		current_outer_loop,
		trail_points,
		epsilon,
		current_outer_loop_metrics
	)


func _select_boss_side_loop(candidate_loops: Array[Dictionary], epsilon: float) -> int:
	_sync_boss_marker()
	var selection_point := _get_boss_selection_point()
	return PlayfieldBoundary.select_loop_containing_point(candidate_loops, selection_point, epsilon)


func _apply_retained_capture_loop(retained_candidate: Dictionary) -> void:
	current_outer_loop = retained_candidate.get("loop", PackedVector2Array())
	_refresh_current_outer_loop_metrics()
	var retained_polygon: PackedVector2Array = retained_candidate.get("polygon", PackedVector2Array())
	if retained_polygon.size() >= 3:
		remaining_polygon = retained_polygon
	var stage_cover_source := retained_polygon if retained_polygon.size() >= 3 else remaining_polygon
	_rebuild_stage_cover_polygon_from_polygon(stage_cover_source)
	inactive_border_segments.clear()
	inactive_border_segment_aabbs.clear()


func _append_claimed_capture_results(candidate_loops: Array[Dictionary], retained_index: int) -> Dictionary:
	var captured_polygons_delta: Array[PackedVector2Array] = []
	var captured_polygon_aabbs: Array[Rect2] = []
	var inactive_segments_delta: Array[PackedVector2Array] = []
	var inactive_segment_aabbs: Array[Rect2] = []
	var added_claimed_area := 0.0
	for index in range(candidate_loops.size()):
		if index == retained_index:
			continue
		var captured_polygon: PackedVector2Array = candidate_loops[index].get("polygon", PackedVector2Array())
		if captured_polygon.size() >= 3:
			claimed_polygons.append(captured_polygon)
			captured_polygons_delta.append(captured_polygon)
			captured_polygon_aabbs.append(_build_points_aabb(captured_polygon))
			var captured_polygon_area := float(candidate_loops[index].get("area", -1.0))
			if captured_polygon_area < 0.0:
				captured_polygon_area = PlayfieldBoundary.polygon_area(captured_polygon)
			added_claimed_area += captured_polygon_area
		var removed_path: PackedVector2Array = candidate_loops[index].get("boundary_path", PackedVector2Array())
		var removed_segments := _polyline_to_segments(removed_path)
		if removed_segments.is_empty():
			continue
		inactive_border_segments.append_array(removed_segments)
		inactive_segments_delta.append_array(removed_segments)
		for segment in removed_segments:
			inactive_segment_aabbs.append(_build_points_aabb(segment))

	return {
		"captured_polygons": captured_polygons_delta,
		"captured_polygon_aabbs": captured_polygon_aabbs,
		"inactive_segments": inactive_segments_delta,
		"inactive_segment_aabbs": inactive_segment_aabbs,
		"added_claimed_area": added_claimed_area
	}


func _build_capture_context(capture_delta: Dictionary, capture_generation: int) -> Dictionary:
	return {
		"capture_delta": capture_delta,
		"capture_generation": capture_generation,
		"captured_polygons": _extract_captured_polygons_from_capture_delta(capture_delta),
		"captured_polygon_aabbs": _extract_capture_delta_rects(capture_delta, "captured_polygon_aabbs"),
		"inactive_segment_aabbs": _extract_capture_delta_rects(capture_delta, "inactive_segment_aabbs"),
		"added_claimed_area": float(capture_delta.get("added_claimed_area", 0.0)),
		"guide_epsilon": _get_guide_epsilon()
	}


func _collect_dirty_guide_indices_from_capture_context(capture_context: Dictionary) -> Array[int]:
	var dirty_indices: Array[int] = []
	var captured_rects: Array[Rect2] = capture_context.get("captured_polygon_aabbs", [])
	var inactive_rects: Array[Rect2] = capture_context.get("inactive_segment_aabbs", [])
	if captured_rects.is_empty() and inactive_rects.is_empty():
		return dirty_indices

	var epsilon := float(capture_context.get("guide_epsilon", _get_guide_epsilon()))
	var candidate_indices := _collect_candidate_guide_indices_from_rects(captured_rects, inactive_rects, epsilon)
	for index in candidate_indices:
		if _guide_segment_overlaps_capture_delta(guide_segments[index], captured_rects, inactive_rects, epsilon):
			dirty_indices.append(index)
	return dirty_indices


func _collect_candidate_guide_indices_from_rects(
	captured_rects: Array[Rect2],
	inactive_rects: Array[Rect2],
	epsilon: float
) -> Array[int]:
	var candidate_index_set: Dictionary = {}
	for rect in captured_rects:
		_append_axis_index_candidates_from_rect(rect, epsilon, candidate_index_set)
	for rect in inactive_rects:
		_append_axis_index_candidates_from_rect(rect, epsilon, candidate_index_set)

	var candidate_indices: Array[int] = []
	for index in candidate_index_set.keys():
		candidate_indices.append(int(index))
	candidate_indices.sort()
	return candidate_indices


func _append_axis_index_candidates_from_rect(rect: Rect2, epsilon: float, candidate_index_set: Dictionary) -> void:
	var min_x := int(floor(rect.position.x - epsilon))
	var max_x := int(ceil(rect.end.x + epsilon))
	_append_axis_index_candidates_in_range(
		vertical_guide_axis_keys,
		vertical_guide_indices_by_x,
		min_x,
		max_x,
		true,
		candidate_index_set
	)

	var min_y := int(floor(rect.position.y - epsilon))
	var max_y := int(ceil(rect.end.y + epsilon))
	_append_axis_index_candidates_in_range(
		horizontal_guide_axis_keys,
		horizontal_guide_indices_by_y,
		min_y,
		max_y,
		false,
		candidate_index_set
	)


func _append_axis_index_candidates_in_range(
	axis_keys: Array[int],
	axis_indices: Dictionary,
	min_axis_key: int,
	max_axis_key: int,
	expect_vertical: bool,
	candidate_index_set: Dictionary
) -> void:
	for axis_key in axis_keys:
		if axis_key < min_axis_key:
			continue
		if axis_key > max_axis_key:
			break
		_append_axis_index_bucket_candidates(axis_indices, axis_key, expect_vertical, candidate_index_set)


func _append_axis_index_bucket_candidates(
	axis_indices: Dictionary,
	axis_key: int,
	expect_vertical: bool,
	candidate_index_set: Dictionary
) -> void:
	if !axis_indices.has(axis_key):
		return

	var bucket: Array = axis_indices[axis_key]
	for raw_index in bucket:
		var index := int(raw_index)
		if index < 0 or index >= guide_segments.size():
			continue

		var guide_segment := guide_segments[index]
		if _is_pending_guide_segment(guide_segment):
			continue
		if !bool(guide_segment.get("active", false)):
			continue
		var direction := _normalize_guide_direction(guide_segment.get("dir", Vector2.ZERO))
		if direction == Vector2.ZERO:
			continue

		var is_vertical := absf(direction.y) > 0.0
		if is_vertical != expect_vertical:
			continue
		if _get_guide_axis_key(guide_segment) != axis_key:
			continue
		candidate_index_set[index] = true


func _clear_guide_axis_indices() -> void:
	vertical_guide_indices_by_x.clear()
	horizontal_guide_indices_by_y.clear()
	vertical_guide_axis_keys.clear()
	horizontal_guide_axis_keys.clear()


func _rebuild_guide_axis_indices() -> void:
	_clear_guide_axis_indices()
	for index in range(guide_segments.size()):
		_register_guide_axis_index(index, guide_segments[index])
	_rebuild_guide_axis_key_lists()


func _rebuild_guide_axis_key_lists() -> void:
	vertical_guide_axis_keys = _sorted_axis_keys(vertical_guide_indices_by_x)
	horizontal_guide_axis_keys = _sorted_axis_keys(horizontal_guide_indices_by_y)


func _sorted_axis_keys(axis_indices: Dictionary) -> Array[int]:
	var sorted_keys: Array[int] = []
	for axis_key in axis_indices.keys():
		sorted_keys.append(int(axis_key))
	sorted_keys.sort()
	return sorted_keys


func _register_guide_axis_index(index: int, guide_segment: Dictionary) -> void:
	if _is_pending_guide_segment(guide_segment):
		return
	var direction := _normalize_guide_direction(guide_segment.get("dir", Vector2.ZERO))
	if direction == Vector2.ZERO:
		return

	var axis_key := _get_guide_axis_key(guide_segment)
	if absf(direction.y) > 0.0:
		_append_guide_axis_index(vertical_guide_indices_by_x, axis_key, index)
		return
	if absf(direction.x) > 0.0:
		_append_guide_axis_index(horizontal_guide_indices_by_y, axis_key, index)


func _append_guide_axis_index(axis_indices: Dictionary, axis_key: int, index: int) -> void:
	var bucket: Array = axis_indices.get(axis_key, [])
	bucket.append(index)
	axis_indices[axis_key] = bucket


func _get_guide_axis_key(guide_segment: Dictionary) -> int:
	var start: Vector2 = guide_segment.get("start", Vector2.ZERO)
	var direction := _normalize_guide_direction(guide_segment.get("dir", Vector2.ZERO))
	if absf(direction.y) > 0.0:
		return int(round(start.x))
	if absf(direction.x) > 0.0:
		return int(round(start.y))
	return 0


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


func _rebuild_spatial_caches() -> void:
	_rebuild_claimed_polygon_aabbs()
	_rebuild_inactive_border_segment_aabbs()


func _rebuild_claimed_polygon_aabbs() -> void:
	claimed_polygon_aabbs = _build_polygon_aabbs(claimed_polygons)


func _rebuild_inactive_border_segment_aabbs() -> void:
	inactive_border_segment_aabbs = _build_segment_aabbs(inactive_border_segments)


func _build_polygon_aabbs(polygons: Array[PackedVector2Array]) -> Array[Rect2]:
	var aabbs: Array[Rect2] = []
	for polygon in polygons:
		aabbs.append(_build_points_aabb(polygon))
	return aabbs


func _build_segment_aabbs(segments: Array[PackedVector2Array]) -> Array[Rect2]:
	var aabbs: Array[Rect2] = []
	for segment in segments:
		aabbs.append(_build_points_aabb(segment))
	return aabbs


func _build_segment_aabb_from_points(segment_start: Vector2, segment_end: Vector2) -> Rect2:
	var segment := PackedVector2Array()
	segment.append(segment_start)
	segment.append(segment_end)
	return _build_points_aabb(segment)


func _extract_capture_delta_rects(capture_delta: Dictionary, key: String) -> Array[Rect2]:
	var rects: Array[Rect2] = []
	if !capture_delta.has(key):
		return rects
	for raw_rect in capture_delta[key]:
		if typeof(raw_rect) != TYPE_RECT2:
			continue
		rects.append(raw_rect)
	return rects


func _append_capture_delta_aabbs(capture_delta: Dictionary) -> void:
	var captured_polygon_aabbs := _extract_capture_delta_rects(capture_delta, "captured_polygon_aabbs")
	if !captured_polygon_aabbs.is_empty():
		claimed_polygon_aabbs.append_array(captured_polygon_aabbs)

	var inactive_segment_aabbs := _extract_capture_delta_rects(capture_delta, "inactive_segment_aabbs")
	if !inactive_segment_aabbs.is_empty():
		inactive_border_segment_aabbs.append_array(inactive_segment_aabbs)


func _point_overlaps_rect(point: Vector2, rect: Rect2, epsilon: float) -> bool:
	return (
		point.x >= rect.position.x - epsilon
		and point.x <= rect.end.x + epsilon
		and point.y >= rect.position.y - epsilon
		and point.y <= rect.end.y + epsilon
	)


func _rects_overlap(a: Rect2, b: Rect2, padding: float = 0.0) -> bool:
	return (
		a.position.x <= b.end.x + padding
		and a.end.x >= b.position.x - padding
		and a.position.y <= b.end.y + padding
		and a.end.y >= b.position.y - padding
	)


func _extract_captured_polygons_from_capture_delta(capture_delta: Dictionary) -> Array[PackedVector2Array]:
	var captured_polygons_delta: Array[PackedVector2Array] = []
	if capture_delta.has("captured_polygons"):
		captured_polygons_delta = capture_delta["captured_polygons"]
	return captured_polygons_delta


func _is_pending_guide_segment(guide_segment: Dictionary) -> bool:
	return bool(guide_segment.get("pending", false))


func _is_guide_created_in_current_capture(guide_segment: Dictionary, capture_generation: int) -> bool:
	return int(guide_segment.get("capture_generation", -1)) == capture_generation


func _is_point_in_any_polygon(
	point: Vector2,
	polygons: Array[PackedVector2Array],
	polygon_aabbs: Array[Rect2],
	epsilon: float
) -> bool:
	for index in range(polygons.size()):
		if index < polygon_aabbs.size() and !_point_overlaps_rect(point, polygon_aabbs[index], epsilon):
			continue
		var polygon := polygons[index]
		if polygon.size() < 3:
			continue
		if Geometry2D.is_point_in_polygon(point, polygon) or PlayfieldBoundary.is_point_on_loop(polygon, point, epsilon):
			return true
	return false


func _guide_end_is_inside_capture_delta(
	guide_segment: Dictionary,
	captured_polygons_delta: Array[PackedVector2Array],
	captured_polygon_aabbs: Array[Rect2],
	epsilon: float
) -> bool:
	if !bool(guide_segment.get("active", false)):
		return false
	var start: Vector2 = guide_segment.get("start", Vector2.ZERO)
	var end: Vector2 = guide_segment.get("end", start)
	return _is_point_in_any_polygon(end, captured_polygons_delta, captured_polygon_aabbs, epsilon)


func _guide_body_is_inside_capture_delta(
	guide_segment: Dictionary,
	captured_polygons_delta: Array[PackedVector2Array],
	captured_polygon_aabbs: Array[Rect2],
	epsilon: float
) -> bool:
	if !bool(guide_segment.get("active", false)):
		return false

	var start: Vector2 = guide_segment.get("start", Vector2.ZERO)
	var end: Vector2 = guide_segment.get("end", start)
	var direction := _normalize_guide_direction(guide_segment.get("dir", Vector2.ZERO))
	if direction == Vector2.ZERO:
		return false

	var scan_bounds := _get_guide_scan_bounds(start, end, direction)
	if !bool(scan_bounds.get("valid", false)):
		return false

	var scan_from := int(scan_bounds.get("from", 0))
	var scan_to := int(scan_bounds.get("to", 0))
	var scan_step := int(scan_bounds.get("step", 0))
	var max_iterations := int(ceil(start.distance_to(end))) + 2
	for iteration in range(max_iterations):
		var axis_value := scan_from + scan_step * iteration
		if scan_step < 0 and axis_value < scan_to:
			axis_value = scan_to
		elif scan_step > 0 and axis_value > scan_to:
			axis_value = scan_to

		var sample_point := _build_guide_scan_point(scan_bounds, axis_value)
		if sample_point.distance_to(start) <= epsilon:
			if axis_value == scan_to:
				break
			continue
		if !_is_point_on_segment(sample_point, start, end, epsilon):
			if axis_value == scan_to:
				break
			continue
		if _is_point_in_any_polygon(sample_point, captured_polygons_delta, captured_polygon_aabbs, epsilon):
			return true

		if axis_value == scan_to:
			break
	return false


func _guide_end_or_body_is_inside_capture_delta(
	guide_segment: Dictionary,
	captured_polygons_delta: Array[PackedVector2Array],
	captured_polygon_aabbs: Array[Rect2],
	epsilon: float
) -> bool:
	if _guide_end_is_inside_capture_delta(guide_segment, captured_polygons_delta, captured_polygon_aabbs, epsilon):
		return true
	return _guide_body_is_inside_capture_delta(guide_segment, captured_polygons_delta, captured_polygon_aabbs, epsilon)


func _guide_segment_touches_capture_delta(
	guide_segment: Dictionary,
	captured_polygons_delta: Array[PackedVector2Array],
	captured_polygon_aabbs: Array[Rect2],
	epsilon: float
) -> bool:
	if !bool(guide_segment.get("active", false)):
		return false

	var start: Vector2 = guide_segment.get("start", Vector2.ZERO)
	var end: Vector2 = guide_segment.get("end", start)
	var direction := _normalize_guide_direction(guide_segment.get("dir", Vector2.ZERO))
	if direction == Vector2.ZERO:
		return false
	if _is_point_in_any_polygon(end, captured_polygons_delta, captured_polygon_aabbs, epsilon):
		return true

	var scan_bounds := _get_guide_scan_bounds(start, end, direction)
	if !bool(scan_bounds.get("valid", false)):
		return false

	var scan_from := int(scan_bounds.get("from", 0))
	var scan_to := int(scan_bounds.get("to", 0))
	var scan_step := int(scan_bounds.get("step", 0))
	var max_iterations := int(ceil(start.distance_to(end))) + 2
	for iteration in range(max_iterations):
		var axis_value := scan_from + scan_step * iteration
		if scan_step < 0 and axis_value < scan_to:
			axis_value = scan_to
		elif scan_step > 0 and axis_value > scan_to:
			axis_value = scan_to

		var sample_point := _build_guide_scan_point(scan_bounds, axis_value)
		if !_is_point_on_segment(sample_point, start, end, epsilon):
			if axis_value == scan_to:
				break
			continue
		if _is_point_in_any_polygon(sample_point, captured_polygons_delta, captured_polygon_aabbs, epsilon):
			return true

		if axis_value == scan_to:
			break
	return false


func _guide_newly_enters_capture_delta(
	guide_segment: Dictionary,
	capture_generation: int,
	captured_polygons_delta: Array[PackedVector2Array],
	captured_polygon_aabbs: Array[Rect2],
	epsilon: float
) -> bool:
	if _is_guide_created_in_current_capture(guide_segment, capture_generation):
		return false
	return _guide_segment_touches_capture_delta(guide_segment, captured_polygons_delta, captured_polygon_aabbs, epsilon)


func _reset_guide_segment_for_reresolve(guide_segment: Dictionary) -> Dictionary:
	var reset_segment := guide_segment.duplicate()
	var start: Vector2 = reset_segment.get("start", Vector2.ZERO)
	reset_segment["end"] = start
	reset_segment["active"] = false
	return reset_segment


func _build_confirmed_guide_segment(guide_segment: Dictionary) -> Dictionary:
	var confirmed_segment := guide_segment.duplicate()
	confirmed_segment["pending"] = false
	return confirmed_segment


func _collect_pending_guide_indices_for_capture(capture_generation: int) -> Array[int]:
	var pending_indices: Array[int] = []
	for index in range(guide_segments.size()):
		var guide_segment := guide_segments[index]
		if !_is_pending_guide_segment(guide_segment):
			continue
		if !_is_guide_created_in_current_capture(guide_segment, capture_generation):
			continue
		pending_indices.append(index)
	return pending_indices


func _is_pending_guide_captured(
	resolved_guide_segment: Dictionary,
	captured_polygons_delta: Array[PackedVector2Array],
	captured_polygon_aabbs: Array[Rect2],
	epsilon: float
) -> bool:
	if !bool(resolved_guide_segment.get("active", false)):
		return true
	return _guide_end_or_body_is_inside_capture_delta(
		resolved_guide_segment,
		captured_polygons_delta,
		captured_polygon_aabbs,
		epsilon
	)


func _resolve_pending_guide_segment_for_capture(guide_segment: Dictionary) -> Dictionary:
	return _resolve_guide_segment(_build_confirmed_guide_segment(guide_segment), true)


func _reresolve_guide_segment_for_capture(guide_segment: Dictionary) -> Dictionary:
	return _resolve_guide_segment(_reset_guide_segment_for_reresolve(guide_segment), true)


func _collect_pending_guide_capture_actions(capture_context: Dictionary, actions: Dictionary) -> void:
	var captured_polygons_delta: Array[PackedVector2Array] = capture_context.get("captured_polygons", [])
	var captured_polygon_aabbs: Array[Rect2] = capture_context.get("captured_polygon_aabbs", [])
	var capture_generation := int(capture_context.get("capture_generation", -1))
	var epsilon := float(capture_context.get("guide_epsilon", _get_guide_epsilon()))
	var pending_indices := _collect_pending_guide_indices_for_capture(capture_generation)
	for index in pending_indices:
		var resolved_segment := _resolve_pending_guide_segment_for_capture(guide_segments[index])
		if _is_pending_guide_captured(resolved_segment, captured_polygons_delta, captured_polygon_aabbs, epsilon):
			actions["remove"].append(index)
			continue
		actions["confirm"].append({
			"index": index,
			"segment": resolved_segment
		})


func _collect_dirty_guide_capture_actions(capture_context: Dictionary, actions: Dictionary) -> void:
	var captured_polygons_delta: Array[PackedVector2Array] = capture_context.get("captured_polygons", [])
	if captured_polygons_delta.is_empty():
		return

	var captured_polygon_aabbs: Array[Rect2] = capture_context.get("captured_polygon_aabbs", [])
	var capture_generation := int(capture_context.get("capture_generation", -1))
	var epsilon := float(capture_context.get("guide_epsilon", _get_guide_epsilon()))
	var candidate_indices := _collect_dirty_guide_indices_from_capture_context(capture_context)
	for index in candidate_indices:
		if index < 0 or index >= guide_segments.size():
			continue
		var guide_segment := guide_segments[index]
		if _is_pending_guide_segment(guide_segment):
			continue
		if !bool(guide_segment.get("active", false)):
			continue
		if _is_guide_created_in_current_capture(guide_segment, capture_generation):
			if _guide_end_is_inside_capture_delta(guide_segment, captured_polygons_delta, captured_polygon_aabbs, epsilon):
				actions["remove"].append(index)
			continue
		if _guide_newly_enters_capture_delta(
			guide_segment,
			capture_generation,
			captured_polygons_delta,
			captured_polygon_aabbs,
			epsilon
		):
			actions["reresolve"].append(index)


func _collect_guide_capture_actions(capture_context: Dictionary) -> Dictionary:
	var actions := {
		"remove": [],
		"confirm": [],
		"reresolve": []
	}
	_collect_pending_guide_capture_actions(capture_context, actions)
	_collect_dirty_guide_capture_actions(capture_context, actions)
	return actions


func _sort_unique_descending_indices(indices: Array) -> Array[int]:
	var unique_indices: Dictionary = {}
	for raw_index in indices:
		var parsed_index := _try_parse_capture_action_index(raw_index)
		if !bool(parsed_index.get("valid", false)):
			continue
		var index = parsed_index.get("index", -1)
		if typeof(index) != TYPE_INT:
			continue
		unique_indices[index] = true

	var sorted_indices: Array[int] = []
	for index in unique_indices.keys():
		if typeof(index) != TYPE_INT:
			continue
		sorted_indices.append(index)
	sorted_indices.sort()
	sorted_indices.reverse()
	return sorted_indices


func _try_parse_capture_action_index(raw_index: Variant) -> Dictionary:
	if typeof(raw_index) == TYPE_INT:
		return {
			"valid": true,
			"index": raw_index
		}

	if typeof(raw_index) == TYPE_FLOAT:
		var raw_float := float(raw_index)
		if !is_finite(raw_float):
			return {"valid": false}
		var rounded_index := int(round(raw_float))
		if !is_equal_approx(raw_float, float(rounded_index)):
			return {"valid": false}
		return {
			"valid": true,
			"index": rounded_index
		}

	if typeof(raw_index) == TYPE_STRING:
		var raw_text := _stringify_value(raw_index, "").strip_edges()
		if raw_text.is_empty() or !raw_text.is_valid_int():
			return {"valid": false}
		return {
			"valid": true,
			"index": raw_text.to_int()
		}

	return {"valid": false}


func _extract_capture_action_index(action_name: String, action_data: Variant) -> Dictionary:
	if action_name == "confirm":
		if typeof(action_data) != TYPE_DICTIONARY:
			return {"valid": false}
		var confirm_action: Dictionary = action_data
		return _try_parse_capture_action_index(confirm_action.get("index", null))
	return _try_parse_capture_action_index(action_data)


func _apply_capture_guide_actions(capture_actions: Dictionary) -> void:
	var confirmed_indices: Array[int] = []
	var confirm_updates: Array = capture_actions.get("confirm", [])
	for update in confirm_updates:
		var parsed_index := _extract_capture_action_index("confirm", update)
		if !bool(parsed_index.get("valid", false)):
			continue
		var index = parsed_index.get("index", -1)
		if typeof(index) != TYPE_INT:
			continue
		if index < 0 or index >= guide_segments.size():
			continue
		if typeof(update) != TYPE_DICTIONARY:
			continue
		guide_segments[index] = update.get("segment", guide_segments[index])
		confirmed_indices.append(index)

	var reresolve_indices: Array = capture_actions.get("reresolve", [])
	for raw_index in reresolve_indices:
		var parsed_index := _extract_capture_action_index("reresolve", raw_index)
		if !bool(parsed_index.get("valid", false)):
			continue
		var index = parsed_index.get("index", -1)
		if typeof(index) != TYPE_INT:
			continue
		if index < 0 or index >= guide_segments.size():
			continue
		guide_segments[index] = _reresolve_guide_segment_for_capture(guide_segments[index])

	var remove_indices := _sort_unique_descending_indices(capture_actions.get("remove", []))
	for index in remove_indices:
		if index < 0 or index >= guide_segments.size():
			continue
		guide_segments.remove_at(index)

	if !remove_indices.is_empty():
		_rebuild_guide_axis_indices()
		return

	var needs_axis_key_refresh := false
	for index in _sort_unique_descending_indices(confirmed_indices):
		if index < 0 or index >= guide_segments.size():
			continue
		_register_guide_axis_index(index, guide_segments[index])
		needs_axis_key_refresh = true
	if needs_axis_key_refresh:
		_rebuild_guide_axis_key_lists()


func _apply_claimed_area_capture_delta(capture_context: Dictionary) -> void:
	claimed_area += float(capture_context.get("added_claimed_area", 0.0))
	if playfield_area_cached > 0.0:
		claimed_area = minf(claimed_area, playfield_area_cached)
	_refresh_claimed_ratio_cache()


func _finalize_capture_closed(capture_delta: Dictionary, capture_generation: int) -> void:
	var capture_context := _build_capture_context(capture_delta, capture_generation)
	_apply_claimed_area_capture_delta(capture_context)
	_append_capture_delta_aabbs(capture_delta)
	_apply_playfield_to_player()
	_apply_playfield_to_bbos()
	var capture_actions := _collect_guide_capture_actions(capture_context)
	var affected_vertical_guide_keys := _collect_affected_vertical_guide_keys_from_capture_actions(capture_actions)
	_apply_capture_guide_actions(capture_actions)
	_sync_guide_partition_fill_entries_after_capture(affected_vertical_guide_keys, capture_delta)
	_sync_boss_marker()
	_recalculate_boss_region_polygon_after_capture()
	_sync_hud()
	queue_redraw()


func _build_boss_region_capture_context() -> Dictionary:
	var epsilon := _get_guide_epsilon()
	var selection_point := _get_boss_selection_point()
	var boundary_segments := _build_boss_region_boundary_segments(epsilon)
	if boundary_segments.is_empty():
		return {}

	var start_hit := _find_boss_region_start_hit(selection_point, boundary_segments, epsilon)
	if !bool(start_hit.get("hit", false)):
		return {}

	return {
		"epsilon": epsilon,
		"selection_point": selection_point,
		"boundary_segments": boundary_segments,
		"start_hit": start_hit
	}


func _build_boss_region_graph_from_capture_context(boss_region_context: Dictionary) -> Dictionary:
	var boundary_segments: Array[Dictionary] = boss_region_context.get("boundary_segments", [])
	var start_hit: Dictionary = boss_region_context.get("start_hit", {})
	if boundary_segments.is_empty() or !bool(start_hit.get("hit", false)):
		return {}
	return _build_boss_region_graph(
		boundary_segments,
		start_hit,
		float(boss_region_context.get("epsilon", _get_guide_epsilon()))
	)


func _is_valid_traced_boss_region_loop(
	traced_loop: PackedVector2Array,
	selection_point: Vector2,
	epsilon: float
) -> bool:
	if traced_loop.size() < 3:
		return false
	return (
		Geometry2D.is_point_in_polygon(selection_point, traced_loop)
		or PlayfieldBoundary.is_point_on_loop(traced_loop, selection_point, epsilon)
	)


func _recalculate_boss_region_polygon_after_capture() -> void:
	var boss_region_context := _build_boss_region_capture_context()
	if boss_region_context.is_empty():
		_set_boss_region_polygon(PackedVector2Array())
		_apply_boss_region_ratio_to_bbos()
		return

	var epsilon := float(boss_region_context.get("epsilon", _get_guide_epsilon()))
	var selection_point: Vector2 = boss_region_context.get("selection_point", Vector2.ZERO)
	var graph := _build_boss_region_graph_from_capture_context(boss_region_context)
	if graph.is_empty():
		_set_boss_region_polygon(PackedVector2Array())
		_apply_boss_region_ratio_to_bbos()
		return
	var traced_loop := _trace_boss_region_loop_clockwise(graph, epsilon)
	if !_is_valid_traced_boss_region_loop(traced_loop, selection_point, epsilon):
		_set_boss_region_polygon(PackedVector2Array())
		_apply_boss_region_ratio_to_bbos()
		return

	_set_boss_region_polygon(traced_loop)
	_apply_boss_region_ratio_to_bbos()


func _build_boss_region_boundary_segments(epsilon: float) -> Array[Dictionary]:
	var boundary_segments: Array[Dictionary] = []
	if current_outer_loop.size() >= 2:
		for index in range(current_outer_loop.size()):
			_append_boss_region_boundary_segment(
				boundary_segments,
				"outer_%d" % index,
				"outer",
				current_outer_loop[index],
				current_outer_loop[(index + 1) % current_outer_loop.size()],
				epsilon
			)

	for index in range(guide_segments.size()):
		var guide_segment := guide_segments[index]
		if _is_pending_guide_segment(guide_segment):
			continue
		if !bool(guide_segment.get("active", false)):
			continue

		var start: Vector2 = guide_segment.get("start", Vector2.ZERO)
		var end: Vector2 = guide_segment.get("end", start)
		if start.distance_to(end) <= epsilon:
			continue

		var is_vertical := absf(start.x - end.x) <= epsilon
		var guide_length := _get_guide_segment_axis_length(start, end, is_vertical)
		if !_is_guide_segment_within_short_threshold(guide_length, epsilon):
			continue

		_append_boss_region_boundary_segment(
			boundary_segments,
			"green_%d" % index,
			"green",
			start,
			end,
			epsilon
		)

	return boundary_segments


func _append_boss_region_boundary_segment(
	boundary_segments: Array[Dictionary],
	segment_id: String,
	segment_type: String,
	start: Vector2,
	end: Vector2,
	epsilon: float
) -> void:
	if start.distance_to(end) <= epsilon:
		return

	var normalized_start := start
	var normalized_end := end
	if absf(start.y - end.y) <= epsilon and start.x > end.x:
		normalized_start = end
		normalized_end = start
	elif absf(start.x - end.x) <= epsilon and start.y > end.y:
		normalized_start = end
		normalized_end = start

	boundary_segments.append({
		"id": segment_id,
		"type": segment_type,
		"start": normalized_start,
		"end": normalized_end
	})


func _find_boss_region_start_hit(selection_point: Vector2, boundary_segments: Array[Dictionary], epsilon: float) -> Dictionary:
	var best_hit := {"hit": false}
	for segment in boundary_segments:
		var candidate_hit := _build_boss_region_start_hit_candidate(selection_point, segment, epsilon)
		if !bool(candidate_hit.get("hit", false)):
			continue
		if !bool(best_hit.get("hit", false)):
			best_hit = candidate_hit
			continue

		var candidate_distance := float(candidate_hit.get("distance", INF))
		var best_distance := float(best_hit.get("distance", INF))
		if candidate_distance < best_distance - epsilon:
			best_hit = candidate_hit
			continue
		if is_equal_approx(candidate_distance, best_distance):
			var candidate_type := _stringify_value(candidate_hit.get("segment_type", ""), "")
			var best_type := _stringify_value(best_hit.get("segment_type", ""), "")
			if candidate_type == "green" and best_type != "green":
				best_hit = candidate_hit
	return best_hit


func _build_boss_region_start_hit_candidate(selection_point: Vector2, segment: Dictionary, epsilon: float) -> Dictionary:
	var segment_start: Vector2 = segment.get("start", Vector2.ZERO)
	var segment_end: Vector2 = segment.get("end", segment_start)
	var segment_type := _stringify_value(segment.get("type", ""), "")

	if absf(segment_start.x - segment_end.x) <= epsilon:
		var candidate_x := segment_start.x
		if candidate_x <= selection_point.x + epsilon:
			return {"hit": false}
		var min_y := minf(segment_start.y, segment_end.y) - epsilon
		var max_y := maxf(segment_start.y, segment_end.y) + epsilon
		if selection_point.y < min_y or selection_point.y > max_y:
			return {"hit": false}
		var hit_point := Vector2(candidate_x, selection_point.y)
		return {
			"hit": true,
			"point": hit_point,
			"distance": selection_point.distance_to(hit_point),
			"segment_id": _stringify_value(segment.get("id", ""), ""),
			"segment_type": segment_type
		}

	if absf(segment_start.y - segment_end.y) > epsilon:
		return {"hit": false}
	if absf(segment_start.y - selection_point.y) > epsilon:
		return {"hit": false}

	var min_x := minf(segment_start.x, segment_end.x)
	var max_x := maxf(segment_start.x, segment_end.x)
	if max_x <= selection_point.x + epsilon:
		return {"hit": false}

	var candidate_x := min_x
	if candidate_x <= selection_point.x + epsilon:
		return {"hit": false}

	var hit_point := Vector2(candidate_x, segment_start.y)
	return {
		"hit": true,
		"point": hit_point,
		"distance": selection_point.distance_to(hit_point),
		"segment_id": _stringify_value(segment.get("id", ""), ""),
		"segment_type": segment_type
	}


func _build_boss_region_graph(boundary_segments: Array[Dictionary], start_hit: Dictionary, epsilon: float) -> Dictionary:
	var split_points_by_segment: Dictionary = {}
	var start_segment_id := _stringify_value(start_hit.get("segment_id", ""), "")
	var start_point: Vector2 = start_hit.get("point", Vector2.ZERO)
	for segment in boundary_segments:
		var segment_id := _stringify_value(segment.get("id", ""), "")
		var split_points: Array[Vector2] = []
		_append_unique_boss_region_point(split_points, segment.get("start", Vector2.ZERO), epsilon)
		_append_unique_boss_region_point(split_points, segment.get("end", Vector2.ZERO), epsilon)
		if segment_id == start_segment_id:
			_append_unique_boss_region_point(split_points, start_point, epsilon)
		split_points_by_segment[segment_id] = split_points

	for segment_index in range(boundary_segments.size()):
		for other_index in range(segment_index + 1, boundary_segments.size()):
			var intersections := _collect_boss_region_segment_intersections(
				boundary_segments[segment_index],
				boundary_segments[other_index],
				epsilon
			)
			if intersections.is_empty():
				continue

			var segment_id := _stringify_value(boundary_segments[segment_index].get("id", ""), "")
			var other_id := _stringify_value(boundary_segments[other_index].get("id", ""), "")
			var segment_points: Array[Vector2] = split_points_by_segment.get(segment_id, [])
			var other_points: Array[Vector2] = split_points_by_segment.get(other_id, [])
			for intersection_point in intersections:
				_append_unique_boss_region_point(segment_points, intersection_point, epsilon)
				_append_unique_boss_region_point(other_points, intersection_point, epsilon)
			split_points_by_segment[segment_id] = segment_points
			split_points_by_segment[other_id] = other_points

	var nodes: Array[Dictionary] = []
	var edges: Array[Dictionary] = []
	var edge_keys: Dictionary = {}
	for segment in boundary_segments:
		var segment_id := _stringify_value(segment.get("id", ""), "")
		var segment_type := _stringify_value(segment.get("type", ""), "")
		var split_points: Array[Vector2] = split_points_by_segment.get(segment_id, [])
		var ordered_points := _sort_boss_region_points_on_segment(split_points, segment, epsilon)
		for point_index in range(ordered_points.size() - 1):
			var from_point: Vector2 = ordered_points[point_index]
			var to_point: Vector2 = ordered_points[point_index + 1]
			if from_point.distance_to(to_point) <= epsilon:
				continue

			var from_node_id := _find_or_append_boss_region_node(nodes, from_point, epsilon)
			var to_node_id := _find_or_append_boss_region_node(nodes, to_point, epsilon)
			if from_node_id == to_node_id:
				continue

			var edge_key := _build_boss_region_edge_key(segment_type, from_node_id, to_node_id)
			if edge_keys.has(edge_key):
				continue

			var edge_index := edges.size()
			edges.append({
				"a": from_node_id,
				"b": to_node_id,
				"type": segment_type
			})
			edge_keys[edge_key] = true
			_append_boss_region_node_edge(nodes, from_node_id, edge_index)
			_append_boss_region_node_edge(nodes, to_node_id, edge_index)

	return {
		"nodes": nodes,
		"edges": edges,
		"start_node_id": _find_boss_region_node_id(nodes, start_point, epsilon)
	}


func _collect_boss_region_segment_intersections(segment_a: Dictionary, segment_b: Dictionary, epsilon: float) -> Array[Vector2]:
	var intersections: Array[Vector2] = []
	var a_start: Vector2 = segment_a.get("start", Vector2.ZERO)
	var a_end: Vector2 = segment_a.get("end", a_start)
	var b_start: Vector2 = segment_b.get("start", Vector2.ZERO)
	var b_end: Vector2 = segment_b.get("end", b_start)
	var a_horizontal := absf(a_start.y - a_end.y) <= epsilon
	var b_horizontal := absf(b_start.y - b_end.y) <= epsilon

	if a_horizontal != b_horizontal:
		var horizontal_start := a_start if a_horizontal else b_start
		var horizontal_end := a_end if a_horizontal else b_end
		var vertical_start := b_start if a_horizontal else a_start
		var vertical_end := b_end if a_horizontal else a_end
		var candidate_point := Vector2(vertical_start.x, horizontal_start.y)
		if (
			candidate_point.x >= minf(horizontal_start.x, horizontal_end.x) - epsilon
			and candidate_point.x <= maxf(horizontal_start.x, horizontal_end.x) + epsilon
			and candidate_point.y >= minf(vertical_start.y, vertical_end.y) - epsilon
			and candidate_point.y <= maxf(vertical_start.y, vertical_end.y) + epsilon
		):
			_append_unique_boss_region_point(intersections, candidate_point, epsilon)
		return intersections

	if a_horizontal and absf(a_start.y - b_start.y) <= epsilon:
		for candidate_point in [a_start, a_end, b_start, b_end]:
			if _is_point_on_segment(candidate_point, a_start, a_end, epsilon) and _is_point_on_segment(candidate_point, b_start, b_end, epsilon):
				_append_unique_boss_region_point(intersections, candidate_point, epsilon)
		return intersections

	if !a_horizontal and absf(a_start.x - b_start.x) <= epsilon:
		for candidate_point in [a_start, a_end, b_start, b_end]:
			if _is_point_on_segment(candidate_point, a_start, a_end, epsilon) and _is_point_on_segment(candidate_point, b_start, b_end, epsilon):
				_append_unique_boss_region_point(intersections, candidate_point, epsilon)
		return intersections

	return intersections


func _append_unique_boss_region_point(points: Array[Vector2], point: Vector2, epsilon: float) -> void:
	for existing_point in points:
		if existing_point.distance_to(point) <= epsilon:
			return
	points.append(point)


func _sort_boss_region_points_on_segment(points: Array[Vector2], segment: Dictionary, epsilon: float) -> Array[Vector2]:
	var ordered_points: Array[Vector2] = []
	for point in points:
		_append_unique_boss_region_point(ordered_points, point, epsilon)

	var segment_start: Vector2 = segment.get("start", Vector2.ZERO)
	var segment_end: Vector2 = segment.get("end", segment_start)
	var horizontal := absf(segment_start.y - segment_end.y) <= epsilon
	ordered_points.sort_custom(func(a: Vector2, b: Vector2) -> bool:
		if horizontal:
			if absf(a.x - b.x) > epsilon:
				return a.x < b.x
			return a.y < b.y
		if absf(a.y - b.y) > epsilon:
			return a.y < b.y
		return a.x < b.x
	)
	return ordered_points


func _find_or_append_boss_region_node(nodes: Array[Dictionary], point: Vector2, epsilon: float) -> int:
	var node_id := _find_boss_region_node_id(nodes, point, epsilon)
	if node_id >= 0:
		return node_id

	nodes.append({
		"point": point,
		"edges": []
	})
	return nodes.size() - 1


func _find_boss_region_node_id(nodes: Array[Dictionary], point: Vector2, epsilon: float) -> int:
	for node_index in range(nodes.size()):
		var node_point: Vector2 = nodes[node_index].get("point", Vector2.ZERO)
		if node_point.distance_to(point) <= epsilon:
			return node_index
	return -1


func _append_boss_region_node_edge(nodes: Array[Dictionary], node_id: int, edge_index: int) -> void:
	if node_id < 0 or node_id >= nodes.size():
		return
	var edges_for_node: Array = nodes[node_id].get("edges", [])
	edges_for_node.append(edge_index)
	nodes[node_id]["edges"] = edges_for_node


func _build_boss_region_edge_key(segment_type: String, node_a: int, node_b: int) -> String:
	var min_node := mini(node_a, node_b)
	var max_node := maxi(node_a, node_b)
	return "%s:%d:%d" % [segment_type, min_node, max_node]


func _trace_boss_region_loop_clockwise(graph: Dictionary, epsilon: float) -> PackedVector2Array:
	var nodes: Array[Dictionary] = graph.get("nodes", [])
	var edges: Array[Dictionary] = graph.get("edges", [])
	var start_node_id := int(graph.get("start_node_id", -1))
	if start_node_id < 0 or start_node_id >= nodes.size():
		return PackedVector2Array()

	var current_node_id := start_node_id
	var previous_node_id := -1
	var incoming_direction := Vector2.RIGHT
	var visited_directed_edges: Dictionary = {}
	var loop_points := PackedVector2Array()
	loop_points.append(nodes[start_node_id].get("point", Vector2.ZERO))
	var max_steps := maxi(edges.size() * 2 + 4, 8)
	for step in range(max_steps):
		var next_step := _choose_next_boss_region_step(
			nodes,
			edges,
			current_node_id,
			previous_node_id,
			incoming_direction,
			step == 0,
			epsilon
		)
		if !bool(next_step.get("found", false)):
			return PackedVector2Array()

		var next_node_id := int(next_step.get("node_id", -1))
		var edge_index := int(next_step.get("edge_index", -1))
		if next_node_id < 0 or edge_index < 0:
			return PackedVector2Array()

		var directed_edge_key := "%d>%d:%d" % [current_node_id, next_node_id, edge_index]
		if visited_directed_edges.has(directed_edge_key):
			return PackedVector2Array()
		visited_directed_edges[directed_edge_key] = true

		loop_points.append(nodes[next_node_id].get("point", Vector2.ZERO))
		if next_node_id == start_node_id:
			if loop_points.size() < 4:
				return PackedVector2Array()
			return PlayfieldBoundary.sanitize_loop(loop_points)

		previous_node_id = current_node_id
		current_node_id = next_node_id
		incoming_direction = next_step.get("direction", Vector2.ZERO)

	return PackedVector2Array()


func _choose_next_boss_region_step(
	nodes: Array[Dictionary],
	edges: Array[Dictionary],
	current_node_id: int,
	previous_node_id: int,
	incoming_direction: Vector2,
	is_start_step: bool,
	epsilon: float
) -> Dictionary:
	if current_node_id < 0 or current_node_id >= nodes.size():
		return {"found": false}

	var current_node: Dictionary = nodes[current_node_id]
	var current_point: Vector2 = current_node.get("point", Vector2.ZERO)
	var candidate_steps: Array[Dictionary] = []
	var raw_edges: Array = current_node.get("edges", [])
	for raw_edge_index in raw_edges:
		var edge_index := int(raw_edge_index)
		if edge_index < 0 or edge_index >= edges.size():
			continue

		var edge: Dictionary = edges[edge_index]
		var node_a := int(edge.get("a", -1))
		var node_b := int(edge.get("b", -1))
		var next_node_id := node_b if node_a == current_node_id else node_a
		if next_node_id < 0 or next_node_id >= nodes.size():
			continue
		if next_node_id == previous_node_id:
			continue

		var next_point: Vector2 = nodes[next_node_id].get("point", Vector2.ZERO)
		var step_direction := next_point - current_point
		if step_direction.length_squared() <= epsilon * epsilon:
			continue
		step_direction = step_direction.normalized()
		if is_start_step and step_direction.dot(Vector2.RIGHT) > 1.0 - 0.001:
			continue

		candidate_steps.append({
			"found": true,
			"edge_index": edge_index,
			"node_id": next_node_id,
			"direction": step_direction,
			"type": _stringify_value(edge.get("type", ""), ""),
			"turn_angle": fposmod(incoming_direction.angle_to(step_direction), TAU),
			"distance": current_point.distance_to(next_point)
		})

	var prioritized_steps := candidate_steps
	for candidate in candidate_steps:
		if _stringify_value(candidate.get("type", ""), "") == "green":
			prioritized_steps = []
			for green_candidate in candidate_steps:
				if _stringify_value(green_candidate.get("type", ""), "") == "green":
					prioritized_steps.append(green_candidate)
			break

	if prioritized_steps.is_empty():
		return {"found": false}

	var best_step: Dictionary = prioritized_steps[0]
	for candidate in prioritized_steps:
		var candidate_angle := float(candidate.get("turn_angle", TAU))
		var best_angle := float(best_step.get("turn_angle", TAU))
		if candidate_angle < best_angle - epsilon:
			best_step = candidate
			continue
		if is_equal_approx(candidate_angle, best_angle):
			var candidate_distance := float(candidate.get("distance", INF))
			var best_distance := float(best_step.get("distance", INF))
			if candidate_distance < best_distance - epsilon:
				best_step = candidate
	return best_step


func _recalculate_claimed_area() -> void:
	var total_area := 0.0
	for polygon in claimed_polygons:
		total_area += PlayfieldBoundary.polygon_area(polygon)

	claimed_area = minf(total_area, playfield_area_cached) if playfield_area_cached > 0.0 else total_area
	_refresh_claimed_ratio_cache()


func _refresh_current_outer_loop_metrics() -> void:
	if current_outer_loop.size() < 3:
		current_outer_loop_metrics = {}
		return

	current_outer_loop_metrics = PlayfieldBoundary.build_loop_metrics(current_outer_loop)


func _sync_boss_marker() -> void:
	if !is_instance_valid(boss):
		return

	var target_position := boss.global_position
	var has_target_position := false
	if is_instance_valid(bbos):
		target_position = bbos.global_position
		has_target_position = true
	elif current_outer_loop.size() >= 3:
		target_position = PlayfieldBoundary.ensure_point_inside(current_outer_loop, boss.global_position, 2.0)
		has_target_position = true

	if !has_target_position:
		return
	if (
		has_last_synced_boss_marker_position
		and last_synced_boss_marker_position.is_equal_approx(target_position)
		and boss.global_position.is_equal_approx(target_position)
	):
		return

	boss.global_position = target_position
	last_synced_boss_marker_position = target_position
	has_last_synced_boss_marker_position = true


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


func _draw_guide_partition_fills() -> void:
	if !show_vertical_guides:
		return
	var partition_polygons := _collect_guide_partition_rects()
	for polygon in partition_polygons:
		draw_colored_polygon(polygon, guide_partition_fill_color)


func _collect_guide_partition_rects() -> Array[PackedVector2Array]:
	var polygons: Array[PackedVector2Array] = []
	var epsilon := _get_guide_epsilon()
	for entry in guide_partition_fill_entries:
		var entry_key := _extract_guide_partition_entry_storage_key(entry)
		if entry_key.is_empty() or !guide_partition_fill_polygons_by_key.has(entry_key):
			continue
		var fill_polygons: Array = guide_partition_fill_polygons_by_key[entry_key]
		for raw_polygon in fill_polygons:
			if typeof(raw_polygon) != TYPE_PACKED_VECTOR2_ARRAY:
				continue
			var polygon: PackedVector2Array = raw_polygon
			if !_is_guide_partition_fill_polygon_drawable(polygon, epsilon):
				continue
			polygons.append(polygon)
	return polygons


func _sync_guide_partition_fill_entries_after_capture(
	affected_vertical_guide_keys: Dictionary,
	capture_delta: Dictionary
) -> void:
	var epsilon := _get_guide_epsilon()
	var horizontal_outer_segments := _collect_horizontal_outer_loop_segments(epsilon)
	if horizontal_outer_segments.is_empty():
		guide_partition_fill_entries.clear()
		guide_partition_fill_polygons_by_key.clear()
		guide_partition_fill_entry_key_sequence = 0
		return

	var existing_vertical_guides := _collect_unique_active_vertical_guides(horizontal_outer_segments, epsilon)
	if existing_vertical_guides.is_empty():
		guide_partition_fill_entries.clear()
		guide_partition_fill_polygons_by_key.clear()
		guide_partition_fill_entry_key_sequence = 0
		return

	var existing_vertical_guides_by_interval_key: Dictionary = {}
	for guide in existing_vertical_guides:
		var interval_key := _stringify_value(guide.get("interval_key", ""), "")
		if interval_key.is_empty():
			continue
		existing_vertical_guides_by_interval_key[interval_key] = guide

	var update_region := _build_guide_partition_update_region(affected_vertical_guide_keys, capture_delta, epsilon)
	var touched_pair_keys: Dictionary = {}
	var removed_partition_keys := _prune_guide_partition_fill_entries(
		existing_vertical_guides_by_interval_key,
		update_region,
		epsilon
	)
	_touch_guide_partition_pair_keys(touched_pair_keys, removed_partition_keys)

	var guides_to_refresh := _collect_vertical_guides_for_partition_refresh(existing_vertical_guides, update_region, epsilon)
	if !bool(update_region.get("has_update", false)):
		_erase_guide_partition_fill_results(removed_partition_keys)
		_rebuild_all_guide_partition_fill_results(epsilon)
		return

	var refreshed_interval_keys: Dictionary = {}
	for guide in guides_to_refresh:
		var interval_key := _stringify_value(guide.get("interval_key", ""), "")
		if interval_key.is_empty() or refreshed_interval_keys.has(interval_key):
			continue
		refreshed_interval_keys[interval_key] = true
		var refresh_removed_keys := _refresh_guide_partition_fill_entries_for_vertical_guide(
			guide,
			existing_vertical_guides,
			horizontal_outer_segments,
			update_region,
			epsilon,
			touched_pair_keys
		)
		for pair_key in refresh_removed_keys:
			removed_partition_keys.append(pair_key)
		_touch_guide_partition_pair_keys(touched_pair_keys, refresh_removed_keys)

	_erase_guide_partition_fill_results(removed_partition_keys)
	_rebuild_all_guide_partition_fill_results(epsilon)


func _build_guide_partition_update_region(
	affected_vertical_guide_keys: Dictionary,
	capture_delta: Dictionary,
	epsilon: float
) -> Dictionary:
	var affected_x_keys: Dictionary = {}
	var has_x_key_range := false
	var min_x_key := INF
	var max_x_key := -INF
	for raw_key in affected_vertical_guide_keys.keys():
		var x_key := int(raw_key)
		affected_x_keys[x_key] = true
		has_x_key_range = true
		min_x_key = minf(min_x_key, float(x_key))
		max_x_key = maxf(max_x_key, float(x_key))

	var has_rect_range := false
	var min_x := INF
	var max_x := -INF
	var min_y := INF
	var max_y := -INF
	var delta_aabbs := _collect_capture_delta_aabbs_for_partition_update(capture_delta)
	for rect in delta_aabbs:
		has_rect_range = true
		min_x = minf(min_x, rect.position.x)
		max_x = maxf(max_x, rect.end.x)
		min_y = minf(min_y, rect.position.y)
		max_y = maxf(max_y, rect.end.y)

	if has_x_key_range:
		min_x = minf(min_x, min_x_key)
		max_x = maxf(max_x, max_x_key)

	return {
		"has_update": has_x_key_range or has_rect_range,
		"affected_x_keys": affected_x_keys,
		"has_x_range": has_x_key_range or has_rect_range,
		"has_y_range": has_rect_range,
		"min_x": min_x,
		"max_x": max_x,
		"min_y": min_y,
		"max_y": max_y,
		"expand": maxf(epsilon, 1.0)
	}


func _collect_capture_delta_aabbs_for_partition_update(capture_delta: Dictionary) -> Array[Rect2]:
	var rects := _extract_capture_delta_rects(capture_delta, "captured_polygon_aabbs")
	rects.append_array(_extract_capture_delta_rects(capture_delta, "inactive_segment_aabbs"))
	return rects


func _collect_vertical_guides_for_partition_refresh(
	existing_vertical_guides: Array[Dictionary],
	update_region: Dictionary,
	epsilon: float
) -> Array[Dictionary]:
	var guides_to_refresh: Array[Dictionary] = []
	for guide in existing_vertical_guides:
		if !_is_vertical_guide_affected_by_update_region(guide, update_region, epsilon):
			continue
		guides_to_refresh.append(guide)
	return guides_to_refresh


func _is_vertical_guide_affected_by_update_region(
	guide: Dictionary,
	update_region: Dictionary,
	epsilon: float
) -> bool:
	if !bool(update_region.get("has_update", false)):
		return false

	var x_key := int(guide.get("x_key", 0))
	var affected_x_keys: Dictionary = update_region.get("affected_x_keys", {})
	if affected_x_keys.has(x_key):
		return true

	var expand := float(update_region.get("expand", epsilon))
	if bool(update_region.get("has_x_range", false)):
		var min_x := float(update_region.get("min_x", 0.0)) - expand
		var max_x := float(update_region.get("max_x", 0.0)) + expand
		var x := float(guide.get("x", 0.0))
		if x < min_x or x > max_x:
			return false

	if !bool(update_region.get("has_y_range", false)):
		return true

	var min_y := float(update_region.get("min_y", 0.0)) - expand
	var max_y := float(update_region.get("max_y", 0.0)) + expand
	var top_y := float(guide.get("top_y", 0.0))
	var bottom_y := float(guide.get("bottom_y", top_y))
	return bottom_y >= min_y and top_y <= max_y


func _collect_affected_vertical_guide_keys_from_capture_actions(capture_actions: Dictionary) -> Dictionary:
	var affected_vertical_guide_keys: Dictionary = {}
	var action_names := ["confirm", "remove", "reresolve"]
	for action_name in action_names:
		var action_entries: Array = capture_actions.get(action_name, [])
		for action_entry in action_entries:
			var parsed_index := _extract_capture_action_index(action_name, action_entry)
			if !bool(parsed_index.get("valid", false)):
				continue
			var index = parsed_index.get("index", -1)
			if typeof(index) != TYPE_INT:
				continue
			if index < 0 or index >= guide_segments.size():
				continue
			var guide_segment := guide_segments[index]
			var direction := _normalize_guide_direction(guide_segment.get("dir", Vector2.ZERO))
			if absf(direction.y) <= 0.0:
				continue
			affected_vertical_guide_keys[_get_guide_axis_key(guide_segment)] = true
	return affected_vertical_guide_keys


func _refresh_guide_partition_fill_entries_for_vertical_guide(
	guide: Dictionary,
	existing_vertical_guides: Array[Dictionary],
	horizontal_outer_segments: Array[Dictionary],
	update_region: Dictionary,
	epsilon: float,
	touched_pair_keys: Dictionary
) -> Array[String]:
	var removed_partition_keys := _remove_guide_partition_fill_entries_for_guide_interval(guide, update_region, epsilon)

	var left_guide := _find_vertical_partition_guide_on_side(
		guide,
		existing_vertical_guides,
		true,
		epsilon
	)
	if !left_guide.is_empty():
		_append_guide_partition_fill_entry_between(
			left_guide,
			guide,
			horizontal_outer_segments,
			epsilon,
			touched_pair_keys
		)

	var right_guide := _find_vertical_partition_guide_on_side(
		guide,
		existing_vertical_guides,
		false,
		epsilon
	)
	if !right_guide.is_empty():
		_append_guide_partition_fill_entry_between(
			guide,
			right_guide,
			horizontal_outer_segments,
			epsilon,
			touched_pair_keys
		)
	return removed_partition_keys


func _append_guide_partition_fill_entry_between(
	left_guide: Dictionary,
	right_guide: Dictionary,
	horizontal_outer_segments: Array[Dictionary],
	epsilon: float,
	touched_pair_keys: Dictionary
) -> void:
	if !_should_fill_guide_partition_between_vertical_guides(left_guide, right_guide, epsilon):
		return

	var overlap := _resolve_vertical_guide_overlap_range(left_guide, right_guide, epsilon)
	if !bool(overlap.get("found", false)):
		return
	var overlap_top_y := float(overlap.get("top_y", 0.0))
	var overlap_bottom_y := float(overlap.get("bottom_y", overlap_top_y))
	if overlap_bottom_y - overlap_top_y <= epsilon:
		return

	var left_x := float(left_guide.get("x", 0.0))
	var right_x := float(right_guide.get("x", left_x))
	if right_x - left_x <= epsilon:
		return

	var bounds := _resolve_guide_partition_vertical_bounds_for_pair(
		left_guide,
		right_guide,
		left_x,
		right_x,
		overlap_top_y,
		overlap_bottom_y,
		horizontal_outer_segments,
		epsilon
	)
	if !bool(bounds.get("found", false)):
		return

	var top_y := float(bounds.get("top_y", 0.0))
	var bottom_y := float(bounds.get("bottom_y", top_y))
	if bottom_y <= top_y + epsilon:
		return

	var rect := Rect2(Vector2(left_x, top_y), Vector2(right_x - left_x, bottom_y - top_y))
	if !_guide_partition_entry_has_valid_base_rect({
		"rect": rect,
		"left_x": left_x,
		"right_x": right_x,
		"top_y": top_y,
		"bottom_y": bottom_y
	}, epsilon):
		return

	var left_guide_key := int(left_guide.get("x_key", int(round(left_x))))
	var right_guide_key := int(right_guide.get("x_key", int(round(right_x))))
	var left_interval_key := _stringify_value(left_guide.get("interval_key", ""), "")
	var right_interval_key := _stringify_value(right_guide.get("interval_key", ""), "")
	_upsert_guide_partition_fill_entry({
		"left_x": left_x,
		"right_x": right_x,
		"top_y": top_y,
		"bottom_y": bottom_y,
		"left_x_key": left_guide_key,
		"left_top_y": float(left_guide.get("top_y", 0.0)),
		"left_bottom_y": float(left_guide.get("bottom_y", left_guide.get("top_y", 0.0))),
		"left_height": _get_vertical_partition_guide_length(left_guide),
		"right_x_key": right_guide_key,
		"right_top_y": float(right_guide.get("top_y", 0.0)),
		"right_bottom_y": float(right_guide.get("bottom_y", right_guide.get("top_y", 0.0))),
		"right_height": _get_vertical_partition_guide_length(right_guide),
		"left_interval_key": left_interval_key,
		"right_interval_key": right_interval_key,
		"pair_key": _build_guide_partition_pair_key(left_interval_key, right_interval_key),
		"persist": true,
		"left_guide_key": left_guide_key,
		"right_guide_key": right_guide_key,
		"rect": rect
	}, touched_pair_keys)


func _upsert_guide_partition_fill_entry(entry: Dictionary, touched_pair_keys: Dictionary) -> void:
	var pair_key := _extract_guide_partition_entry_pair_key(entry)
	if pair_key.is_empty():
		return
	entry["pair_key"] = pair_key
	if _is_guide_partition_fill_entry_persistent(entry):
		var entry_key := _stringify_value(entry.get("entry_key", ""), "")
		if entry_key.is_empty():
			entry_key = _allocate_guide_partition_fill_entry_key(pair_key)
			entry["entry_key"] = entry_key
		_touch_guide_partition_pair_key(touched_pair_keys, entry_key)
	else:
		_touch_guide_partition_pair_key(touched_pair_keys, pair_key)
	var entry_index := _find_guide_partition_fill_entry_index(entry)
	if entry_index >= 0:
		guide_partition_fill_entries[entry_index] = entry
		return
	guide_partition_fill_entries.append(entry)


func _find_guide_partition_fill_entry_index(entry_to_match: Dictionary) -> int:
	var entry_key := _stringify_value(entry_to_match.get("entry_key", ""), "")
	if !entry_key.is_empty():
		for index in range(guide_partition_fill_entries.size()):
			var entry := guide_partition_fill_entries[index]
			if _stringify_value(entry.get("entry_key", ""), "") == entry_key:
				return index
		return -1

	var pair_key := _extract_guide_partition_entry_pair_key(entry_to_match)
	for index in range(guide_partition_fill_entries.size()):
		var entry := guide_partition_fill_entries[index]
		var entry_pair_key := _extract_guide_partition_entry_pair_key(entry)
		if entry_pair_key == pair_key:
			return index
	return -1


func _build_guide_partition_pair_key(left_interval_key: String, right_interval_key: String) -> String:
	return "%s|%s" % [left_interval_key, right_interval_key]


func _extract_guide_partition_entry_pair_key(entry: Dictionary) -> String:
	var pair_key := _stringify_value(entry.get("pair_key", ""), "")
	if !pair_key.is_empty():
		return pair_key
	var left_interval_key := _stringify_value(entry.get("left_interval_key", ""), "")
	var right_interval_key := _stringify_value(entry.get("right_interval_key", ""), "")
	if !left_interval_key.is_empty() and !right_interval_key.is_empty():
		return _build_guide_partition_pair_key(left_interval_key, right_interval_key)
	return _build_guide_partition_pair_key(
		_stringify_value(entry.get("left_guide_key", ""), ""),
		_stringify_value(entry.get("right_guide_key", ""), "")
	)


func _extract_guide_partition_entry_storage_key(entry: Dictionary) -> String:
	var entry_key := _stringify_value(entry.get("entry_key", ""), "")
	if !entry_key.is_empty():
		return entry_key
	return _extract_guide_partition_entry_pair_key(entry)


func _allocate_guide_partition_fill_entry_key(pair_key: String) -> String:
	guide_partition_fill_entry_key_sequence += 1
	return "%s#%d" % [pair_key, guide_partition_fill_entry_key_sequence]


func _is_guide_partition_fill_entry_persistent(entry: Dictionary) -> bool:
	return bool(entry.get("persist", true))


func _touch_guide_partition_pair_key(touched_pair_keys: Dictionary, pair_key: String) -> void:
	if pair_key.is_empty():
		return
	touched_pair_keys[pair_key] = true


func _touch_guide_partition_pair_keys(touched_pair_keys: Dictionary, pair_keys: Array[String]) -> void:
	for pair_key in pair_keys:
		_touch_guide_partition_pair_key(touched_pair_keys, pair_key)


func _remove_guide_partition_fill_entries_for_guide_interval(
	guide: Dictionary,
	update_region: Dictionary,
	epsilon: float
) -> Array[String]:
	var removed_partition_keys: Array[String] = []
	var interval_key := _stringify_value(guide.get("interval_key", ""), "")
	if interval_key.is_empty():
		return removed_partition_keys
	for index in range(guide_partition_fill_entries.size() - 1, -1, -1):
		var entry := guide_partition_fill_entries[index]
		if _is_guide_partition_fill_entry_persistent(entry):
			continue
		var left_interval_key := _stringify_value(entry.get("left_interval_key", ""), "")
		var right_interval_key := _stringify_value(entry.get("right_interval_key", ""), "")
		if left_interval_key == interval_key or right_interval_key == interval_key:
			removed_partition_keys.append(_extract_guide_partition_entry_storage_key(entry))
			guide_partition_fill_entries.remove_at(index)
			continue
		if !_guide_partition_entry_intersects_update_region(entry, update_region, epsilon):
			continue
		if _guide_partition_entry_touches_guide_x(entry, guide, epsilon):
			removed_partition_keys.append(_extract_guide_partition_entry_storage_key(entry))
			guide_partition_fill_entries.remove_at(index)
	return removed_partition_keys


func _guide_partition_entry_touches_guide_x(entry: Dictionary, guide: Dictionary, epsilon: float) -> bool:
	var guide_x := float(guide.get("x", 0.0))
	var left_x := float(entry.get("left_x", guide_x))
	var right_x := float(entry.get("right_x", guide_x))
	return absf(left_x - guide_x) <= epsilon or absf(right_x - guide_x) <= epsilon


func _guide_partition_entry_intersects_update_region(
	entry: Dictionary,
	update_region: Dictionary,
	epsilon: float
) -> bool:
	if !bool(update_region.get("has_update", false)):
		return true
	var rect = entry.get("rect", Rect2())
	if typeof(rect) != TYPE_RECT2:
		return false
	var entry_rect: Rect2 = rect
	if bool(update_region.get("has_x_range", false)):
		var min_x := float(update_region.get("min_x", entry_rect.position.x)) - epsilon
		var max_x := float(update_region.get("max_x", entry_rect.end.x)) + epsilon
		if entry_rect.end.x < min_x or entry_rect.position.x > max_x:
			return false
	if bool(update_region.get("has_y_range", false)):
		var min_y := float(update_region.get("min_y", entry_rect.position.y)) - epsilon
		var max_y := float(update_region.get("max_y", entry_rect.end.y)) + epsilon
		if entry_rect.end.y < min_y or entry_rect.position.y > max_y:
			return false
	return true


func _prune_guide_partition_fill_entries(
	active_vertical_guides_by_interval_key: Dictionary,
	_update_region: Dictionary,
	epsilon: float
) -> Array[String]:
	var removed_partition_keys: Array[String] = []
	for index in range(guide_partition_fill_entries.size() - 1, -1, -1):
		var entry := guide_partition_fill_entries[index]
		if _is_guide_partition_fill_entry_persistent(entry):
			continue
		if !_guide_partition_entry_has_active_vertical_guides(entry, active_vertical_guides_by_interval_key):
			removed_partition_keys.append(_extract_guide_partition_entry_storage_key(entry))
			guide_partition_fill_entries.remove_at(index)
			continue
		if !_guide_partition_entry_lengths_within_threshold(entry, epsilon):
			removed_partition_keys.append(_extract_guide_partition_entry_storage_key(entry))
			guide_partition_fill_entries.remove_at(index)
			continue
		if !_guide_partition_entry_has_valid_base_rect(entry, epsilon):
			removed_partition_keys.append(_extract_guide_partition_entry_storage_key(entry))
			guide_partition_fill_entries.remove_at(index)
	return removed_partition_keys


func _collect_horizontal_outer_loop_segments(epsilon: float) -> Array[Dictionary]:
	var segments: Array[Dictionary] = []
	for index in range(current_outer_loop.size()):
		var start: Vector2 = current_outer_loop[index]
		var end: Vector2 = current_outer_loop[(index + 1) % current_outer_loop.size()]
		if absf(start.y - end.y) > epsilon:
			continue
		var min_x := minf(start.x, end.x)
		var max_x := maxf(start.x, end.x)
		if max_x - min_x <= epsilon:
			continue
		segments.append({
			"id": index,
			"start": start,
			"end": end,
			"y": (start.y + end.y) * 0.5,
			"min_x": min_x,
			"max_x": max_x
		})
	return segments


func _collect_unique_active_vertical_guides(horizontal_outer_segments: Array[Dictionary], epsilon: float) -> Array[Dictionary]:
	var guides_by_interval_key: Dictionary = {}
	for axis_key in vertical_guide_axis_keys:
		if !vertical_guide_indices_by_x.has(axis_key):
			continue
		var bucket: Array = vertical_guide_indices_by_x[axis_key]
		for raw_index in bucket:
			var guide_index := int(raw_index)
			if guide_index < 0 or guide_index >= guide_segments.size():
				continue
			var candidate := _build_vertical_partition_guide_candidate(
				guide_segments[guide_index],
				horizontal_outer_segments,
				epsilon
			)
			if candidate.is_empty():
				continue
			var interval_key := _stringify_value(candidate.get("interval_key", ""), "")
			if interval_key.is_empty():
				continue
			guides_by_interval_key[interval_key] = candidate

	var sorted_guides: Array[Dictionary] = []
	for interval_key in guides_by_interval_key.keys():
		sorted_guides.append(guides_by_interval_key[interval_key])
	sorted_guides.sort_custom(Callable(self, "_sort_vertical_partition_guide"))
	return sorted_guides


func _collect_created_vertical_guides(horizontal_outer_segments: Array[Dictionary], epsilon: float) -> Array[Dictionary]:
	var created_guides: Array[Dictionary] = []
	var latest_capture_generation := current_capture_generation - 1
	if latest_capture_generation < 0:
		return created_guides

	for index in range(guide_segments.size()):
		var guide_segment := guide_segments[index]
		if _is_pending_guide_segment(guide_segment):
			continue
		if !bool(guide_segment.get("active", false)):
			continue
		if int(guide_segment.get("capture_generation", -1)) != latest_capture_generation:
			continue

		var candidate := _build_vertical_partition_guide_candidate(
			guide_segment,
			horizontal_outer_segments,
			epsilon
		)
		if candidate.is_empty():
			continue
		candidate["index"] = index
		created_guides.append(candidate)
	return created_guides


func _build_vertical_partition_guide_candidate(
	guide_segment: Dictionary,
	_horizontal_outer_segments: Array[Dictionary],
	epsilon: float
) -> Dictionary:
	if _is_pending_guide_segment(guide_segment):
		return {}
	if !bool(guide_segment.get("active", false)):
		return {}

	var direction := _normalize_guide_direction(guide_segment.get("dir", Vector2.ZERO))
	if absf(direction.y) <= 0.0:
		return {}

	var start: Vector2 = guide_segment.get("start", Vector2.ZERO)
	var end: Vector2 = guide_segment.get("end", start)
	if absf(start.x - end.x) > epsilon:
		return {}

	var top_point := start
	var bottom_point := end
	if top_point.y > bottom_point.y:
		top_point = end
		bottom_point = start
	if bottom_point.y - top_point.y <= epsilon:
		return {}

	var x := (start.x + end.x) * 0.5
	var x_key := int(round(x))
	var top_y := top_point.y
	var bottom_y := bottom_point.y
	var interval_key := _build_vertical_guide_interval_key(x_key, top_y, bottom_y, epsilon)
	return {
		"x": x,
		"x_key": x_key,
		"top_y": top_y,
		"bottom_y": bottom_y,
		"height": bottom_y - top_y,
		"interval_key": interval_key
	}


func _sort_vertical_partition_guide(a: Dictionary, b: Dictionary) -> bool:
	var ax := float(a.get("x", 0.0))
	var bx := float(b.get("x", 0.0))
	if !is_equal_approx(ax, bx):
		return ax < bx
	var atop := float(a.get("top_y", 0.0))
	var btop := float(b.get("top_y", 0.0))
	if !is_equal_approx(atop, btop):
		return atop < btop
	return float(a.get("bottom_y", atop)) < float(b.get("bottom_y", btop))


func _build_vertical_guide_interval_key(x_key: int, top_y: float, bottom_y: float, epsilon: float) -> String:
	var quantize_unit := maxf(epsilon, 0.001)
	var top_key := int(round(top_y / quantize_unit))
	var bottom_key := int(round(bottom_y / quantize_unit))
	return "%d:%d:%d" % [x_key, top_key, bottom_key]


func _find_vertical_partition_guide_on_side(
	reference_guide: Dictionary,
	candidate_guides: Array[Dictionary],
	search_left: bool,
	epsilon: float
) -> Dictionary:
	var reference_x := float(reference_guide.get("x", 0.0))
	var reference_interval_key := _stringify_value(reference_guide.get("interval_key", ""), "")
	var best_candidate: Dictionary = {}
	var best_distance := INF
	var best_overlap_height := -INF
	for candidate in candidate_guides:
		if _stringify_value(candidate.get("interval_key", ""), "") == reference_interval_key:
			continue
		var overlap := _resolve_vertical_guide_overlap_range(reference_guide, candidate, epsilon)
		if !bool(overlap.get("found", false)):
			continue
		var overlap_height := float(overlap.get("bottom_y", 0.0)) - float(overlap.get("top_y", 0.0))
		if overlap_height <= epsilon:
			continue
		var candidate_x := float(candidate.get("x", 0.0))
		var distance := 0.0
		if search_left:
			if candidate_x >= reference_x - epsilon:
				continue
			distance = reference_x - candidate_x
		else:
			if candidate_x <= reference_x + epsilon:
				continue
			distance = candidate_x - reference_x
		if distance <= epsilon:
			continue
		if (
			best_candidate.is_empty()
			or distance < best_distance - epsilon
			or (
				absf(distance - best_distance) <= epsilon
				and (
					overlap_height > best_overlap_height + epsilon
					or (
						absf(overlap_height - best_overlap_height) <= epsilon
						and _is_vertical_partition_guide_candidate_better(candidate, best_candidate)
					)
				)
			)
		):
			best_candidate = candidate
			best_distance = distance
			best_overlap_height = overlap_height
	return best_candidate


func _resolve_vertical_guide_overlap_range(left_guide: Dictionary, right_guide: Dictionary, epsilon: float) -> Dictionary:
	var left_top := float(left_guide.get("top_y", 0.0))
	var left_bottom := float(left_guide.get("bottom_y", left_top))
	var right_top := float(right_guide.get("top_y", 0.0))
	var right_bottom := float(right_guide.get("bottom_y", right_top))
	var top_y := maxf(left_top, right_top)
	var bottom_y := minf(left_bottom, right_bottom)
	if bottom_y - top_y <= epsilon:
		return {"found": false}
	return {
		"found": true,
		"top_y": top_y,
		"bottom_y": bottom_y
	}


func _find_touching_horizontal_outer_segment(
	point: Vector2,
	horizontal_outer_segments: Array[Dictionary],
	epsilon: float
) -> Dictionary:
	for segment in horizontal_outer_segments:
		var min_x := float(segment.get("min_x", point.x))
		var max_x := float(segment.get("max_x", point.x))
		if point.x < min_x - epsilon or point.x > max_x + epsilon:
			continue
		var y := float(segment.get("y", point.y))
		if absf(point.y - y) > epsilon:
			continue
		var start: Vector2 = segment.get("start", point)
		var end: Vector2 = segment.get("end", point)
		if !_is_point_on_segment(point, start, end, epsilon):
			continue
		return {
			"found": true,
			"id": int(segment.get("id", -1)),
			"y": y
		}
	return {"found": false}


func _is_vertical_partition_guide_candidate_better(candidate: Dictionary, current: Dictionary) -> bool:
	var candidate_height := float(candidate.get("height", 0.0))
	var current_height := float(current.get("height", 0.0))
	if candidate_height > current_height:
		return true
	if candidate_height < current_height:
		return false
	return float(candidate.get("top_y", 0.0)) < float(current.get("top_y", 0.0))


func _should_fill_guide_partition_between_vertical_guides(
	left_guide: Dictionary,
	right_guide: Dictionary,
	epsilon: float
) -> bool:
	var boss_diameter := _get_partition_fill_target_boss_diameter()
	if boss_diameter <= epsilon:
		return false
	var max_vertical_guide_length := boss_diameter * 1.2
	var left_length := _get_vertical_partition_guide_length(left_guide)
	var right_length := _get_vertical_partition_guide_length(right_guide)
	return left_length <= max_vertical_guide_length + epsilon and right_length <= max_vertical_guide_length + epsilon


func _get_vertical_partition_guide_length(guide: Dictionary) -> float:
	var top_y := float(guide.get("top_y", 0.0))
	var bottom_y := float(guide.get("bottom_y", top_y))
	return absf(bottom_y - top_y)


func _get_partition_fill_target_boss_diameter() -> float:
	if is_instance_valid(bbos):
		if bbos.has_method("_get_effective_collision_radius"):
			return maxf(float(bbos.call("_get_effective_collision_radius")), 0.0) * 2.0
		if bbos.has_method("get"):
			return maxf(float(bbos.get("collision_radius")), 0.0) * 2.0
	if is_instance_valid(boss) and boss.has_method("get"):
		return maxf(float(boss.get("collision_radius")), 0.0) * 2.0
	return 0.0


func _build_guide_partition_rect_between(
	left_guide: Dictionary,
	right_guide: Dictionary,
	horizontal_outer_segments: Array[Dictionary],
	epsilon: float
) -> Rect2:
	var overlap := _resolve_vertical_guide_overlap_range(left_guide, right_guide, epsilon)
	if !bool(overlap.get("found", false)):
		return Rect2()
	var overlap_top_y := float(overlap.get("top_y", 0.0))
	var overlap_bottom_y := float(overlap.get("bottom_y", overlap_top_y))
	if overlap_bottom_y - overlap_top_y <= epsilon:
		return Rect2()

	var left_x := float(left_guide.get("x", 0.0))
	var right_x := float(right_guide.get("x", left_x))
	if right_x - left_x <= epsilon:
		return Rect2()

	var bounds := _resolve_guide_partition_vertical_bounds_for_pair(
		left_guide,
		right_guide,
		left_x,
		right_x,
		overlap_top_y,
		overlap_bottom_y,
		horizontal_outer_segments,
		epsilon
	)
	if !bool(bounds.get("found", false)):
		return Rect2()
	var top_y := float(bounds.get("top_y", 0.0))
	var bottom_y := float(bounds.get("bottom_y", top_y))
	if bottom_y <= top_y + epsilon:
		return Rect2()

	return Rect2(Vector2(left_x, top_y), Vector2(right_x - left_x, bottom_y - top_y))


func _resolve_guide_partition_vertical_bounds_for_pair(
	left_guide: Dictionary,
	right_guide: Dictionary,
	left_x: float,
	right_x: float,
	overlap_top_y: float,
	overlap_bottom_y: float,
	horizontal_outer_segments: Array[Dictionary],
	epsilon: float
) -> Dictionary:
	var mid_x := (left_x + right_x) * 0.5
	var top_y := INF
	var bottom_y := -INF
	for segment in horizontal_outer_segments:
		var min_x := float(segment.get("min_x", mid_x))
		var max_x := float(segment.get("max_x", mid_x))
		if mid_x < min_x - epsilon or mid_x > max_x + epsilon:
			continue
		var y := float(segment.get("y", 0.0))
		if y < overlap_top_y - epsilon or y > overlap_bottom_y + epsilon:
			continue
		top_y = minf(top_y, y)
		bottom_y = maxf(bottom_y, y)

	if !is_finite(top_y) or !is_finite(bottom_y):
		return {"found": false}
	top_y = maxf(top_y, overlap_top_y)
	bottom_y = minf(bottom_y, overlap_bottom_y)
	if bottom_y <= top_y + epsilon:
		return {"found": false}
	return {
		"found": true,
		"top_y": top_y,
		"bottom_y": bottom_y
	}

func _build_rect_polygon(rect: Rect2) -> PackedVector2Array:
	var polygon := PackedVector2Array()
	polygon.append(rect.position)
	polygon.append(Vector2(rect.end.x, rect.position.y))
	polygon.append(rect.end)
	polygon.append(Vector2(rect.position.x, rect.end.y))
	return polygon


func _is_guide_partition_fill_polygon_drawable(polygon: PackedVector2Array, epsilon: float) -> bool:
	if polygon.size() < 3:
		return false
	var aabb := _build_points_aabb(polygon)
	if aabb.size.x <= epsilon or aabb.size.y <= epsilon:
		return false
	return absf(PlayfieldBoundary.polygon_area(polygon)) > epsilon * epsilon


func _stringify_value(value: Variant, default_text: String = "") -> String:
	if typeof(value) == TYPE_NIL:
		return default_text
	return str(value)


func _erase_guide_partition_fill_results(storage_keys: Array[String]) -> void:
	for storage_key in storage_keys:
		if storage_key.is_empty():
			continue
		guide_partition_fill_polygons_by_key.erase(storage_key)


func _rebuild_all_guide_partition_fill_results(epsilon: float) -> void:
	guide_partition_fill_polygons_by_key.clear()
	for entry in guide_partition_fill_entries:
		_refresh_guide_partition_fill_result_for_entry(entry, epsilon)


func _refresh_guide_partition_fill_result_for_entry(entry: Dictionary, epsilon: float) -> void:
	var storage_key := _extract_guide_partition_entry_storage_key(entry)
	if storage_key.is_empty():
		return
	var rect = entry.get("rect", Rect2())
	if typeof(rect) != TYPE_RECT2:
		guide_partition_fill_polygons_by_key.erase(storage_key)
		return
	var entry_rect: Rect2 = rect
	if !_guide_partition_entry_has_valid_base_rect(entry, epsilon):
		guide_partition_fill_polygons_by_key.erase(storage_key)
		return

	if remaining_polygon.size() < 3:
		guide_partition_fill_polygons_by_key.erase(storage_key)
		return

	var rect_polygon := _build_rect_polygon(entry_rect)
	var intersected: Array = Geometry2D.intersect_polygons(rect_polygon, remaining_polygon)
	if intersected.is_empty():
		guide_partition_fill_polygons_by_key.erase(storage_key)
		return

	var fill_polygons: Array[PackedVector2Array] = []
	for raw_polygon in intersected:
		if typeof(raw_polygon) != TYPE_PACKED_VECTOR2_ARRAY:
			continue
		var fill_polygon: PackedVector2Array = raw_polygon
		if !_is_guide_partition_fill_polygon_drawable(fill_polygon, epsilon):
			continue
		fill_polygons.append(fill_polygon)
	if fill_polygons.is_empty():
		guide_partition_fill_polygons_by_key.erase(storage_key)
		return
	guide_partition_fill_polygons_by_key[storage_key] = fill_polygons


func _guide_partition_entry_has_active_vertical_guides(
	entry: Dictionary,
	active_vertical_guides_by_interval_key: Dictionary
) -> bool:
	var left_interval_key := _stringify_value(
		entry.get("left_interval_key", entry.get("left_guide_key", "")),
		""
	)
	var right_interval_key := _stringify_value(
		entry.get("right_interval_key", entry.get("right_guide_key", "")),
		""
	)
	if left_interval_key.is_empty() or right_interval_key.is_empty():
		return false
	return (
		active_vertical_guides_by_interval_key.has(left_interval_key)
		and active_vertical_guides_by_interval_key.has(right_interval_key)
	)


func _guide_partition_entry_lengths_within_threshold(entry: Dictionary, epsilon: float) -> bool:
	var boss_diameter := _get_partition_fill_target_boss_diameter()
	if boss_diameter <= epsilon:
		return false
	var max_vertical_guide_length := boss_diameter * 1.2
	var left_length := float(entry.get(
		"left_height",
		absf(float(entry.get("left_bottom_y", 0.0)) - float(entry.get("left_top_y", 0.0)))
	))
	var right_length := float(entry.get(
		"right_height",
		absf(float(entry.get("right_bottom_y", 0.0)) - float(entry.get("right_top_y", 0.0)))
	))
	return left_length <= max_vertical_guide_length + epsilon and right_length <= max_vertical_guide_length + epsilon


func _get_guide_segment_axis_length(start: Vector2, end: Vector2, is_vertical: bool) -> float:
	if is_vertical:
		return absf(end.y - start.y)
	return absf(end.x - start.x)


func _is_guide_segment_within_short_threshold(guide_length: float, epsilon: float) -> bool:
	var boss_diameter := _get_partition_fill_target_boss_diameter()
	if boss_diameter <= epsilon:
		return false
	return guide_length <= boss_diameter * 1.2 + epsilon


func _guide_partition_entry_has_valid_base_rect(entry: Dictionary, epsilon: float) -> bool:
	var left_x := float(entry.get("left_x", 0.0))
	var right_x := float(entry.get("right_x", left_x))
	var top_y := float(entry.get("top_y", 0.0))
	var bottom_y := float(entry.get("bottom_y", top_y))
	if right_x - left_x <= epsilon:
		return false
	if bottom_y - top_y <= epsilon:
		return false
	var rect = entry.get("rect", Rect2())
	if typeof(rect) != TYPE_RECT2:
		return false
	var entry_rect: Rect2 = rect
	return entry_rect.size.x > epsilon and entry_rect.size.y > epsilon


func _is_rect_fully_in_invalid_guide_region(rect: Rect2, epsilon: float) -> bool:
	var sample_points := _build_rect_interior_sample_points(rect)
	for sample_point in sample_points:
		if _is_point_in_valid_guide_region(sample_point, epsilon):
			return false
	return true


func _build_rect_interior_sample_points(rect: Rect2) -> Array[Vector2]:
	var min_x := rect.position.x
	var max_x := rect.end.x
	var min_y := rect.position.y
	var max_y := rect.end.y
	var center_x := (min_x + max_x) * 0.5
	var center_y := (min_y + max_y) * 0.5
	return [
		Vector2(min_x, min_y),
		Vector2(max_x, min_y),
		Vector2(min_x, max_y),
		Vector2(max_x, max_y),
		Vector2(center_x, center_y)
	]


func _draw_guide_segments() -> void:
	var epsilon := _get_guide_epsilon()
	for guide_segment in guide_segments:
		var draw_segment := guide_segment
		if _is_pending_guide_segment(guide_segment):
			draw_segment = _build_pending_guide_preview_segment(guide_segment)
		if !bool(draw_segment.get("active", false)):
			continue
		var start: Vector2 = draw_segment.get("start", Vector2.ZERO)
		var end: Vector2 = draw_segment.get("end", start)
		var direction: Vector2 = draw_segment.get("dir", Vector2.ZERO)
		if start.distance_to(end) <= epsilon:
			continue
		var is_vertical := absf(direction.y) > 0.0
		if is_vertical and !show_vertical_guides:
			continue
		if absf(direction.x) > 0.0 and !show_horizontal_guides:
			continue
		var guide_length := _get_guide_segment_axis_length(start, end, is_vertical)
		var guide_color := guide_vertical_color if is_vertical else guide_segment_color
		if _is_guide_segment_within_short_threshold(guide_length, epsilon):
			guide_color = guide_short_segment_color
		draw_line(start, end, guide_color, guide_segment_width)
		var start_point_color := guide_vertical_start_point_color if is_vertical else guide_horizontal_start_point_color
		var end_point_color := guide_vertical_end_point_color if is_vertical else guide_horizontal_end_point_color
		draw_circle(start, guide_debug_point_radius, start_point_color)
		draw_circle(end, guide_debug_point_radius, end_point_color)


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
		if _is_pending_guide_segment(guide_segments[index]):
			continue
		guide_segments[index] = _resolve_guide_segment(guide_segments[index], apply_capture_correction)


func _refresh_dirty_guide_segments(dirty_indices: Array[int], apply_capture_correction: bool = true) -> void:
	for index in dirty_indices:
		if index < 0 or index >= guide_segments.size():
			continue
		if _is_pending_guide_segment(guide_segments[index]):
			continue
		guide_segments[index] = _resolve_guide_segment(guide_segments[index], apply_capture_correction)


func _build_pending_guide_preview_segment(guide_segment: Dictionary) -> Dictionary:
	var preview_segment := _build_confirmed_guide_segment(guide_segment)
	var epsilon := _get_guide_epsilon()
	var start: Vector2 = preview_segment.get("start", Vector2.ZERO)
	var direction := _normalize_guide_direction(preview_segment.get("dir", Vector2.ZERO))
	preview_segment["start"] = start
	preview_segment["end"] = start
	preview_segment["dir"] = direction
	preview_segment["active"] = false
	if direction == Vector2.ZERO:
		return preview_segment

	var end_result := _resolve_pending_guide_preview_end(start, direction, epsilon)
	if !bool(end_result.get("hit", false)):
		return preview_segment

	var end_point: Vector2 = end_result.get("end", start)
	if start.distance_to(end_point) <= epsilon:
		return preview_segment
	preview_segment["end"] = end_point
	preview_segment["active"] = true
	return preview_segment


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


func _resolve_pending_guide_preview_end(start: Vector2, direction: Vector2, epsilon: float) -> Dictionary:
	var hit := _find_pending_guide_preview_hit(start, direction, epsilon)
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

	var boundary_search_start: Vector2 = correction_result.get("first_valid_point", start)
	var boundary_line := _find_first_orthogonal_guide_boundary_segment_on_segment(
		start,
		boundary_search_start,
		end,
		direction,
		epsilon
	)
	if !bool(boundary_line.get("found", false)):
		corrected_segment["end"] = start
		corrected_segment["active"] = false
		return corrected_segment

	var corrected_end := start
	if absf(direction.y) > 0.0:
		corrected_end = Vector2(start.x, float(boundary_line.get("coordinate", start.y)))
	elif absf(direction.x) > 0.0:
		corrected_end = Vector2(float(boundary_line.get("coordinate", start.x)), start.y)
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
	var first_valid_point := start
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
			if !found_valid_region:
				first_valid_point = sample_point
			found_valid_region = true
			last_valid_point = sample_point
		elif found_valid_region:
			return {
				"found": true,
				"first_valid_point": first_valid_point,
				"last_valid_point": last_valid_point,
				"exited": true
			}

		if axis_value == scan_to:
			break

	if found_valid_region:
		return {
			"found": true,
			"first_valid_point": first_valid_point,
			"last_valid_point": last_valid_point,
			"exited": false
		}
	return {"found": false}


func _find_first_orthogonal_guide_boundary_segment_on_segment(
	start: Vector2,
	search_start: Vector2,
	end: Vector2,
	direction: Vector2,
	epsilon: float
) -> Dictionary:
	if direction == Vector2.ZERO:
		return {"found": false}

	var search_rect := _build_segment_aabb_from_points(search_start, end)
	var best_line := _find_first_orthogonal_guide_boundary_segment_on_loop(
		start,
		search_start,
		end,
		direction,
		_get_guide_boundary_loop(),
		epsilon
	)
	for index in range(claimed_polygons.size()):
		if index < claimed_polygon_aabbs.size() and !_rects_overlap(search_rect, claimed_polygon_aabbs[index], epsilon):
			continue
		best_line = _pick_nearest_orthogonal_guide_boundary_segment(
			best_line,
			_find_first_orthogonal_guide_boundary_segment_on_loop(
				start,
				search_start,
				end,
				direction,
				claimed_polygons[index],
				epsilon
			),
			epsilon
		)
	return best_line


func _find_first_orthogonal_guide_boundary_segment_on_loop(
	start: Vector2,
	search_start: Vector2,
	end: Vector2,
	direction: Vector2,
	loop: PackedVector2Array,
	epsilon: float
) -> Dictionary:
	if loop.size() < 2:
		return {"found": false}

	var best_line := {"found": false}
	for index in range(loop.size()):
		var segment_start: Vector2 = loop[index]
		var segment_end: Vector2 = loop[(index + 1) % loop.size()]
		best_line = _pick_nearest_orthogonal_guide_boundary_segment(
			best_line,
			_build_orthogonal_guide_boundary_segment_candidate(
				start,
				search_start,
				end,
				direction,
				segment_start,
				segment_end,
				index,
				epsilon
			),
			epsilon
		)
	return best_line


func _build_orthogonal_guide_boundary_segment_candidate(
	start: Vector2,
	search_start: Vector2,
	end: Vector2,
	direction: Vector2,
	segment_start: Vector2,
	segment_end: Vector2,
	segment_index: int,
	epsilon: float
) -> Dictionary:
	if absf(direction.y) > 0.0:
		if absf(segment_start.y - segment_end.y) > epsilon:
			return {"found": false}

		var candidate_y := segment_start.y
		if !_is_inclusive_guide_range(start.x, segment_start.x, segment_end.x, epsilon):
			return {"found": false}
		if !_is_inclusive_guide_range(candidate_y, search_start.y, end.y, epsilon):
			return {"found": false}

		var distance := (candidate_y - start.y) * signf(direction.y)
		if distance <= epsilon:
			return {"found": false}

		return {
			"found": true,
			"coordinate": candidate_y,
			"distance": distance,
			"segment_index": segment_index,
			"segment_start": segment_start,
			"segment_end": segment_end
		}

	if absf(direction.x) > 0.0:
		if absf(segment_start.x - segment_end.x) > epsilon:
			return {"found": false}

		var candidate_x := segment_start.x
		if !_is_inclusive_guide_range(start.y, segment_start.y, segment_end.y, epsilon):
			return {"found": false}
		if !_is_inclusive_guide_range(candidate_x, search_start.x, end.x, epsilon):
			return {"found": false}

		var distance := (candidate_x - start.x) * signf(direction.x)
		if distance <= epsilon:
			return {"found": false}

		return {
			"found": true,
			"coordinate": candidate_x,
			"distance": distance,
			"segment_index": segment_index,
			"segment_start": segment_start,
			"segment_end": segment_end
		}

	return {"found": false}


func _pick_nearest_orthogonal_guide_boundary_segment(current_best: Dictionary, candidate: Dictionary, epsilon: float) -> Dictionary:
	if !bool(candidate.get("found", false)):
		return current_best
	if !bool(current_best.get("found", false)):
		return candidate
	if float(candidate.get("distance", INF)) < float(current_best.get("distance", INF)) - epsilon:
		return candidate
	return current_best


func _is_inclusive_guide_range(value: float, range_start: float, range_end: float, epsilon: float) -> bool:
	return value >= minf(range_start, range_end) - epsilon and value <= maxf(range_start, range_end) + epsilon


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
	return _find_first_guide_boundary_hit_on_segment(start, ray_end, epsilon)


func _find_first_guide_boundary_hit_on_segment(start: Vector2, ray_end: Vector2, epsilon: float) -> Dictionary:
	if start.distance_to(ray_end) <= epsilon:
		return {"hit": false}
	var ray_rect := _build_segment_aabb_from_points(start, ray_end)
	var best_hit := {"hit": false}
	best_hit = _pick_nearest_guide_hit(best_hit, _find_guide_loop_hit(start, ray_end, _get_guide_boundary_loop(), epsilon), epsilon)
	for index in range(claimed_polygons.size()):
		if index < claimed_polygon_aabbs.size() and !_rects_overlap(ray_rect, claimed_polygon_aabbs[index], epsilon):
			continue
		best_hit = _pick_nearest_guide_hit(best_hit, _find_guide_loop_hit(start, ray_end, claimed_polygons[index], epsilon), epsilon)
	return best_hit


func _find_pending_guide_preview_hit(start: Vector2, direction: Vector2, epsilon: float) -> Dictionary:
	var preview_loop := current_outer_loop if current_outer_loop.size() >= 3 else _get_guide_boundary_loop()
	var ray_end := _build_guide_ray_end(start, direction, epsilon)
	return _find_guide_loop_hit(start, ray_end, preview_loop, epsilon)


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
	for index in range(claimed_polygons.size()):
		if index < claimed_polygon_aabbs.size() and !_point_overlaps_rect(point, claimed_polygon_aabbs[index], epsilon):
			continue
		var polygon := claimed_polygons[index]
		if polygon.size() < 3:
			continue
		if Geometry2D.is_point_in_polygon(point, polygon) or PlayfieldBoundary.is_point_on_loop(polygon, point, epsilon):
			return true
	return false


func _is_point_on_inactive_border(point: Vector2, epsilon: float) -> bool:
	for index in range(inactive_border_segments.size()):
		if index < inactive_border_segment_aabbs.size() and !_point_overlaps_rect(point, inactive_border_segment_aabbs[index], epsilon):
			continue
		var segment := inactive_border_segments[index]
		for segment_index in range(segment.size() - 1):
			if _is_point_on_segment(point, segment[segment_index], segment[segment_index + 1], epsilon):
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


func _cleanup_pending_guides_outside_capture() -> void:
	if !_has_pending_guides():
		return
	if capture_preview_active:
		return
	_remove_pending_guides()
	queue_redraw()


func _has_pending_guides() -> bool:
	for guide_segment in guide_segments:
		if _is_pending_guide_segment(guide_segment):
			return true
	return false


func _remove_pending_guides() -> void:
	var kept_segments: Array[Dictionary] = []
	for guide_segment in guide_segments:
		if _is_pending_guide_segment(guide_segment):
			continue
		kept_segments.append(guide_segment)
	guide_segments = kept_segments
	_rebuild_guide_axis_indices()


func _sync_debug_guide_visibility() -> void:
	var debug_manager := get_node_or_null("/root/DebugManager")
	if !is_instance_valid(debug_manager):
		return
	if debug_manager.has_method("is_vertical_guides_enabled"):
		show_vertical_guides = bool(debug_manager.call("is_vertical_guides_enabled"))
	if debug_manager.has_method("is_horizontal_guides_enabled"):
		show_horizontal_guides = bool(debug_manager.call("is_horizontal_guides_enabled"))
	if debug_manager.has_method("is_area_fills_enabled"):
		show_area_fills = bool(debug_manager.call("is_area_fills_enabled"))
	if debug_manager.has_method("is_area_percent_labels_enabled"):
		show_area_percent_labels = bool(debug_manager.call("is_area_percent_labels_enabled"))


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


func _sync_hud_status(status: Dictionary) -> void:
	if game_over or get_tree().paused or !is_instance_valid(base_player):
		_sync_hud()
		return

	var mode_text := str(status.get("mode_text", "BORDER"))
	state_label.text = "MODE: %s" % mode_text
	result_label.text = ""
	help_label.text = "MOVE: ARROWS/WASD DRAW: SHIFT/PAD-A ESC: TITLE"


func _sync_hud_position(current_position: Vector2) -> void:
	position_label.text = "POS: (%d, %d)" % [int(round(current_position.x)), int(round(current_position.y))]


func _on_player_hp_changed(_current_hp: int, _max_hp: int) -> void:
	_sync_hud()


func _on_player_defeated() -> void:
	game_over = true
	get_tree().paused = true
	_sync_hud()


func _on_player_debug_status_changed(status: Dictionary) -> void:
	_sync_hud_status(status)


func _on_player_debug_position_changed(world_position: Vector2) -> void:
	if game_over or get_tree().paused or !is_instance_valid(base_player):
		_sync_hud()
		return
	_sync_hud_position(world_position)


func _on_player_capture_preview_changed(active: bool) -> void:
	capture_preview_active = active
	if !capture_preview_active:
		_cleanup_pending_guides_outside_capture()


func _on_bbos_position_changed(_world_position: Vector2) -> void:
	_sync_boss_marker()
