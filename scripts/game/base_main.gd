extends Node2D

const TITLE_SCENE_PATH := "res://scenes/title_main.tscn"
const InputActionUtils = preload("res://scripts/common/input_action_utils.gd")
const PlayfieldBoundary = preload("res://scripts/game/playfield_boundary.gd")
const BBOS_SCENE = preload("res://scenes/enemy/bbos.tscn")
const BaseMainCaptureService = preload("res://scripts/game/services/base_main_capture_service.gd")
const BaseMainGuideService = preload("res://scripts/game/services/base_main_guide_service.gd")
const BaseMainBossRegionService = preload("res://scripts/game/services/base_main_boss_region_service.gd")
const BaseMainHudService = preload("res://scripts/game/services/base_main_hud_service.gd")
const BaseMainCutRatingService = preload("res://scripts/game/services/base_main_cut_rating_service.gd")
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
@onready var cut_rating_bad_label: Label = $Ui/Root/CutRatingArea/CutRatingBadLabel
@onready var cut_rating_good_label: Label = $Ui/Root/CutRatingArea/CutRatingGoodLabel
@onready var cut_rating_summary_label: Label = $Ui/Root/CutRatingArea/CutRatingSummaryLabel
@onready var cut_rating_bar: ProgressBar = $Ui/Root/CutRatingArea/CutRatingBar

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
var current_cut_rating_value := BaseMainCutRatingService.INITIAL_VALUE
var last_single_capture_percent := 0.0
var last_cut_rating_delta := 0
var has_cut_rating_update := false
var boss_region_area_cached := 0.0
var boss_region_ratio_cached := 0.0
var inactive_border_color := Color(1.0, 1.0, 1.0, 0.1)
var game_over := false
var game_clear := false
var clear_reveal_active := false
var clear_reveal_progress := 0.0
var clear_reveal_speed := 0.6
var clear_boss_hidden_done := false
var show_vertical_guides := true
var show_horizontal_guides := true
var show_area_fills := true
var show_area_percent_labels := true
var current_capture_generation := 0
var capture_preview_active := false
var last_synced_boss_marker_position := Vector2.ZERO
var has_last_synced_boss_marker_position := false
var capture_service: BaseMainCaptureService
var guide_service: BaseMainGuideService
var boss_region_service: BaseMainBossRegionService
var hud_service: BaseMainHudService


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = false
	capture_service = BaseMainCaptureService.new()
	guide_service = BaseMainGuideService.new()
	boss_region_service = BaseMainBossRegionService.new()
	hud_service = BaseMainHudService.new()
	capture_service.setup(self)
	guide_service.setup(self)
	boss_region_service.setup(self)
	hud_service.setup(self)
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


func _process(delta: float) -> void:
	if !clear_reveal_active:
		return

	var previous_progress := clear_reveal_progress
	clear_reveal_progress = clampf(clear_reveal_progress + clear_reveal_speed * delta, 0.0, 1.0)
	if clear_reveal_progress != previous_progress:
		queue_redraw()

	if clear_reveal_progress >= 1.0:
		clear_reveal_active = false
		set_process(false)
		queue_redraw()


func is_pause_toggle_allowed() -> bool:
	return true


func set_paused_from_debug(enabled: bool) -> void:
	if (game_over or game_clear) and !enabled:
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


func _get_remaining_area_ratio() -> float:
	if boss_region_service == null:
		return -1.0
	return boss_region_service.get_remaining_area_ratio()


func _set_boss_region_polygon(polygon: PackedVector2Array) -> void:
	boss_region_polygon = polygon
	boss_region_area_cached = 0.0
	if boss_region_polygon.size() >= 3:
		boss_region_area_cached = PlayfieldBoundary.polygon_area(boss_region_polygon)
	_refresh_boss_region_ratio_cache()


func _sync_hud_area_labels() -> void:
	if hud_service == null:
		return
	hud_service.sync_area_labels()


func _sync_hud() -> void:
	if hud_service == null:
		return
	hud_service.sync()


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
	_draw_stage_cover()
	var guide_draw_data := guide_service.build_draw_data() if guide_service != null else {}

	var outer_rect := playfield_rect.grow(playfield_outer_frame_padding)
	if show_area_fills:
		for polygon in claimed_polygons:
			if polygon.size() >= 3:
				draw_colored_polygon(polygon, claimed_fill_color)
		if boss_region_polygon.size() >= 3:
			draw_colored_polygon(boss_region_polygon, boss_region_fill_color)
		for polygon in guide_draw_data.get("partition_polygons", []):
			draw_colored_polygon(polygon, guide_partition_fill_color)
	if not game_clear:
		_draw_border_segments(inactive_border_segments, inactive_border_color)
		_draw_guide_segments_from_data(guide_draw_data.get("segments", []))
	if game_clear:
		if clear_reveal_progress < 1.0:
			_draw_clear_reveal_border_loop(current_outer_loop, playfield_border_color)
	else:
		_draw_border_loop(current_outer_loop, playfield_border_color)
	if not game_clear:
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
		var mode_text := str(base_player.call("get_state_text"))
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
	if guide_service != null:
		guide_service.reset_after_outer_loop_initialized()


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
	if capture_service == null:
		push_warning("Capture skipped: capture service is not ready.")
		return
	var capture_result := capture_service.resolve_capture_closed(trail_points)
	if !bool(capture_result.get("success", false)):
		push_warning(str(capture_result.get("warning", "Capture skipped.")))
		return

	_update_cut_rating_after_capture(capture_result.get("capture_context", {}))
	_apply_playfield_to_player()
	_apply_playfield_to_bbos()
	if guide_service != null:
		guide_service.handle_capture_context(capture_result.get("capture_context", {}))
	_sync_boss_marker()
	_recalculate_boss_region_polygon_after_capture()
	_sync_hud()
	queue_redraw()


func _on_player_guide_turn_created(
	turn_point: Vector2,
	previous_direction: Vector2,
	new_direction: Vector2
) -> void:
	if guide_service != null:
		guide_service.handle_turn_created(
			turn_point,
			previous_direction,
			new_direction,
			current_capture_generation
		)
	queue_redraw()


func _recalculate_boss_region_polygon_after_capture() -> void:
	var boss_region_result := boss_region_service.recalculate_after_capture() if boss_region_service != null else {
		"polygon": PackedVector2Array(),
		"remaining_area_ratio": -1.0
	}
	_set_boss_region_polygon(boss_region_result.get("polygon", PackedVector2Array()))
	_apply_boss_region_ratio_to_bbos()
	_check_game_clear_after_remaining_area_update(float(boss_region_result.get("remaining_area_ratio", -1.0)))


func _check_game_clear_after_remaining_area_update(remaining_area_ratio: float = -1.0) -> void:
	if game_over or game_clear:
		return
	if remaining_area_ratio < 0.0:
		remaining_area_ratio = _get_remaining_area_ratio()
	if remaining_area_ratio < 0.0:
		return
	if remaining_area_ratio <= 0.15:
		_begin_game_clear_reveal()


func _begin_game_clear_reveal() -> void:
	if game_over or game_clear:
		return

	game_clear = true
	clear_reveal_active = true
	clear_reveal_progress = 0.0
	clear_boss_hidden_done = false
	_hide_game_clear_bosses()
	get_tree().paused = true
	set_process(true)
	_sync_hud()
	queue_redraw()


func _hide_game_clear_bosses() -> void:
	if clear_boss_hidden_done:
		return

	_hide_game_clear_target(bbos)
	_hide_game_clear_target(boss)
	clear_boss_hidden_done = true


func _hide_game_clear_target(target: Node2D) -> void:
	if !is_instance_valid(target):
		return

	target.visible = false
	target.set_process(false)
	target.set_physics_process(false)


func _draw_stage_cover() -> void:
	if stage_cover_polygon.size() < 3 or stage_cover_uvs.size() != stage_cover_polygon.size():
		return

	var cover_polygon := stage_cover_polygon
	var cover_uvs := stage_cover_uvs
	if game_clear:
		if clear_reveal_progress >= 1.0:
			return

		var reveal_data := _build_clear_reveal_stage_cover_draw_data()
		cover_polygon = reveal_data.get("polygon", PackedVector2Array())
		cover_uvs = reveal_data.get("uvs", PackedVector2Array())
		if cover_polygon.size() < 3 or cover_uvs.size() != cover_polygon.size():
			return

	var cover_colors := PackedColorArray()
	for _index in range(cover_polygon.size()):
		cover_colors.append(Color.WHITE)
	draw_polygon(cover_polygon, cover_colors, cover_uvs, STAGE_COVER_BACKGROUND_TEXTURE)


func _get_clear_reveal_cutoff_y() -> float:
	return lerpf(playfield_rect.end.y, playfield_rect.position.y, clear_reveal_progress)


func _build_clear_reveal_stage_cover_draw_data() -> Dictionary:
	var clipped_polygon := PackedVector2Array()
	var clipped_uvs := PackedVector2Array()
	if stage_cover_polygon.size() < 3 or stage_cover_uvs.size() != stage_cover_polygon.size():
		return {"polygon": clipped_polygon, "uvs": clipped_uvs}

	var cutoff_y := _get_clear_reveal_cutoff_y()
	for index in range(stage_cover_polygon.size()):
		var current_point: Vector2 = stage_cover_polygon[index]
		var current_uv: Vector2 = stage_cover_uvs[index]
		var next_index := (index + 1) % stage_cover_polygon.size()
		var next_point: Vector2 = stage_cover_polygon[next_index]
		var next_uv: Vector2 = stage_cover_uvs[next_index]
		var current_inside := current_point.y <= cutoff_y
		var next_inside := next_point.y <= cutoff_y

		if current_inside:
			_append_clear_reveal_stage_cover_vertex(clipped_polygon, clipped_uvs, current_point, current_uv)

		if current_inside == next_inside:
			continue

		var segment_delta_y := next_point.y - current_point.y
		if is_zero_approx(segment_delta_y):
			continue

		var t := clampf((cutoff_y - current_point.y) / segment_delta_y, 0.0, 1.0)
		var intersection_point := current_point.lerp(next_point, t)
		intersection_point.y = cutoff_y
		var intersection_uv := current_uv.lerp(next_uv, t)
		_append_clear_reveal_stage_cover_vertex(clipped_polygon, clipped_uvs, intersection_point, intersection_uv)

	if clipped_polygon.size() >= 2 and clipped_polygon[0].is_equal_approx(clipped_polygon[clipped_polygon.size() - 1]):
		clipped_polygon.remove_at(clipped_polygon.size() - 1)
		clipped_uvs.remove_at(clipped_uvs.size() - 1)

	return {
		"polygon": clipped_polygon,
		"uvs": clipped_uvs
	}


func _append_clear_reveal_stage_cover_vertex(
	points: PackedVector2Array,
	uvs: PackedVector2Array,
	point: Vector2,
	uv: Vector2
) -> void:
	if points.size() > 0 and points[points.size() - 1].is_equal_approx(point):
		uvs[uvs.size() - 1] = uv
		return

	points.append(point)
	uvs.append(uv)


func _draw_clear_reveal_border_loop(loop: PackedVector2Array, color: Color) -> void:
	if loop.size() < 2:
		return

	var cutoff_y := _get_clear_reveal_cutoff_y()
	for index in range(loop.size()):
		var start_point: Vector2 = loop[index]
		var end_point: Vector2 = loop[(index + 1) % loop.size()]
		var start_visible := start_point.y <= cutoff_y
		var end_visible := end_point.y <= cutoff_y

		if start_visible and end_visible:
			draw_line(start_point, end_point, color, playfield_border_width)
			continue

		if start_visible == end_visible:
			continue

		var delta_y := end_point.y - start_point.y
		if is_zero_approx(delta_y):
			continue

		var t := clampf((cutoff_y - start_point.y) / delta_y, 0.0, 1.0)
		var intersection_point := start_point.lerp(end_point, t)
		intersection_point.y = cutoff_y

		if start_visible:
			if !start_point.is_equal_approx(intersection_point):
				draw_line(start_point, intersection_point, color, playfield_border_width)
		elif !intersection_point.is_equal_approx(end_point):
			draw_line(intersection_point, end_point, color, playfield_border_width)


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


func _create_playfield_rect() -> Rect2:
	var viewport_rect := get_viewport_rect()
	var top_margin := playfield_margin.y + BaseMainCutRatingService.BAR_BAND_HEIGHT
	return Rect2(
		Vector2(viewport_rect.position.x + playfield_margin.x, viewport_rect.position.y + top_margin),
		PLAYFIELD_SIZE
	)


func _update_cut_rating_after_capture(capture_context: Dictionary) -> void:
	var single_capture_percent := _calculate_single_capture_percent(capture_context)
	var delta := BaseMainCutRatingService.resolve_delta(single_capture_percent)
	last_single_capture_percent = single_capture_percent
	last_cut_rating_delta = delta
	current_cut_rating_value = BaseMainCutRatingService.clamp_value(current_cut_rating_value + delta)
	has_cut_rating_update = true


func _calculate_single_capture_percent(capture_context: Dictionary) -> float:
	if playfield_area_cached <= 0.0:
		return 0.0
	var added_claimed_area := float(capture_context.get("added_claimed_area", 0.0))
	return maxf(0.0, added_claimed_area / playfield_area_cached * 100.0)


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


func _draw_guide_segments_from_data(draw_segments: Array) -> void:
	for raw_segment in draw_segments:
		if typeof(raw_segment) != TYPE_DICTIONARY:
			continue
		var draw_segment: Dictionary = raw_segment
		var start: Vector2 = draw_segment.get("start", Vector2.ZERO)
		var end: Vector2 = draw_segment.get("end", start)
		if start.is_equal_approx(end):
			continue
		var is_vertical := bool(draw_segment.get("is_vertical", false))
		var is_short := bool(draw_segment.get("is_short", false))
		var guide_color := guide_vertical_color if is_vertical else guide_segment_color
		if is_short:
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


func _sync_debug_guide_visibility() -> void:
	if guide_service == null:
		return
	guide_service.sync_debug_visibility()

func _update_hp_label() -> void:
	if hud_service == null:
		return
	hud_service.update_hp_label()

func _sync_hud_status(status: Dictionary) -> void:
	if hud_service == null:
		return
	hud_service.sync_status(status)

func _sync_hud_position(current_position: Vector2) -> void:
	if hud_service == null:
		return
	hud_service.sync_position(current_position)

func _on_player_hp_changed(_current_hp: int, _max_hp: int) -> void:
	_sync_hud()


func _on_player_defeated() -> void:
	if game_over or game_clear:
		return
	game_over = true
	get_tree().paused = true
	_sync_hud()


func _on_player_debug_status_changed(status: Dictionary) -> void:
	_sync_hud_status(status)


func _on_player_debug_position_changed(world_position: Vector2) -> void:
	if game_over or game_clear or get_tree().paused or !is_instance_valid(base_player):
		_sync_hud()
		return
	_sync_hud_position(world_position)


func _on_player_capture_preview_changed(active: bool) -> void:
	capture_preview_active = active
	if !capture_preview_active and guide_service != null and guide_service.cleanup_pending_guides_outside_capture():
		queue_redraw()

func _on_bbos_position_changed(_world_position: Vector2) -> void:
	_sync_boss_marker()
