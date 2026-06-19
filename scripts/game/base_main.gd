extends Node2D

const TITLE_SCENE_PATH := "res://scenes/title_main.tscn"
const InputActionUtils = preload("res://scripts/common/input_action_utils.gd")
const PlayfieldBoundary = preload("res://scripts/game/playfield_boundary.gd")
const BaseMainCaptureService = preload("res://scripts/game/services/base_main_capture_service.gd")
const BaseMainGuideService = preload("res://scripts/game/services/base_main_guide_service.gd")
const BaseMainBossRegionService = preload("res://scripts/game/services/base_main_boss_region_service.gd")
const BaseMainHudService = preload("res://scripts/game/services/base_main_hud_service.gd")
const BaseMainCutRatingService = preload("res://scripts/game/services/base_main_cut_rating_service.gd")
const RunProgressService = preload("res://scripts/game/services/run_progress_service.gd")
const UpgradeDraftService = preload("res://scripts/game/services/upgrade_draft_service.gd")
const ACTION_QIX_DRAW := &"qix_draw"
const ACTION_QIX_DRAW_FAST := &"qix_draw_fast"
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
@onready var minor_enemy_a: Node2D = get_node_or_null("MinorEnemyA")
@onready var minor_enemy_b: Node2D = get_node_or_null("MinorEnemyB")
@onready var boss: Node2D = get_node_or_null("Boss")
@onready var help_label: Label = $Ui/Root/HelpLabel
@onready var state_label: Label = $Ui/Root/StateLabel
@onready var position_label: Label = $Ui/Root/PositionLabel
@onready var claimed_label: Label = $Ui/Root/ClaimedLabel
@onready var boss_region_label: Label = $Ui/Root/BossRegionLabel
@onready var shards_label: Label = $Ui/Root/ShardsLabel
@onready var growth_label: Label = $Ui/Root/GrowthLabel
@onready var objectives_quests_button: Button = $Ui/Root/ObjectivesQuestsButton
@onready var debug_clear_button: Button = $Ui/Root/DebugClearButton
@onready var objectives_quest_detail_overlay: Control = $Ui/Root/ObjectivesQuestDetailOverlay
@onready var detail_growth_label: Label = $Ui/Root/ObjectivesQuestDetailOverlay/DetailGrowthLabel
@onready var detail_objective_primary_label: Label = $Ui/Root/ObjectivesQuestDetailOverlay/DetailObjectivePrimaryLabel
@onready var detail_objective_optional_1_label: Label = $Ui/Root/ObjectivesQuestDetailOverlay/DetailObjectiveOptional1Label
@onready var detail_objective_optional_2_label: Label = $Ui/Root/ObjectivesQuestDetailOverlay/DetailObjectiveOptional2Label
@onready var detail_build_label: Label = $Ui/Root/ObjectivesQuestDetailOverlay/DetailBuildLabel
@onready var detail_meta_label: Label = $Ui/Root/ObjectivesQuestDetailOverlay/DetailMetaLabel
@onready var detail_quest_label: Label = $Ui/Root/ObjectivesQuestDetailOverlay/DetailQuestLabel
@onready var detail_close_button: Button = $Ui/Root/ObjectivesQuestDetailOverlay/DetailCloseButton
@onready var hp_label: Label = $Ui/Root/HpLabel
@onready var hp_icon_container: Control = $Ui/Root/HpIconContainer
@onready var result_label: Label = $Ui/Root/ResultLabel
@onready var upgrade_overlay: Control = $Ui/Root/UpgradeOverlay
@onready var upgrade_title_label: Label = $Ui/Root/UpgradeOverlay/UpgradeTitleLabel
@onready var upgrade_hint_label: Label = $Ui/Root/UpgradeOverlay/UpgradeHintLabel
@onready var upgrade_choice_1_label: Label = $Ui/Root/UpgradeOverlay/UpgradeChoice1Label
@onready var upgrade_choice_2_label: Label = $Ui/Root/UpgradeOverlay/UpgradeChoice2Label
@onready var upgrade_choice_3_label: Label = $Ui/Root/UpgradeOverlay/UpgradeChoice3Label
@onready var upgrade_meta_label: Label = $Ui/Root/UpgradeOverlay/UpgradeMetaLabel
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
var boss_region_recalculation_warning_active := false
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
var upgrade_draft_service: UpgradeDraftService
var run_progress_service: RunProgressService


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = false
	capture_service = BaseMainCaptureService.new()
	guide_service = BaseMainGuideService.new()
	boss_region_service = BaseMainBossRegionService.new()
	hud_service = BaseMainHudService.new()
	upgrade_draft_service = UpgradeDraftService.new()
	run_progress_service = RunProgressService.new()
	capture_service.setup(self)
	guide_service.setup(self)
	boss_region_service.setup(self)
	hud_service.setup(self)
	run_progress_service.setup(self, upgrade_draft_service)
	_register_input_map()
	if !_validate_required_game_nodes():
		set_process(false)
		return
	_recalculate_playfield_rect()
	_initialize_outer_loop_from_rect()
	_connect_player_signal()
	_connect_bbos_signal()
	_apply_playfield_to_player()
	_apply_playfield_to_bbos()
	if is_instance_valid(base_player) and base_player.has_method("apply_run_configuration"):
		base_player.call("apply_run_configuration", run_progress_service.build_player_run_configuration())
	run_progress_service.begin_run()
	_sync_debug_guide_visibility()
	sync_boss_marker()
	var viewport := get_viewport()
	if is_instance_valid(viewport) and !viewport.size_changed.is_connected(_on_viewport_size_changed):
		viewport.size_changed.connect(_on_viewport_size_changed)
	queue_redraw()
	_sync_hud()
	if is_instance_valid(objectives_quests_button) and !objectives_quests_button.pressed.is_connected(_on_objectives_quests_button_pressed):
		objectives_quests_button.pressed.connect(_on_objectives_quests_button_pressed)
	if is_instance_valid(debug_clear_button) and !debug_clear_button.pressed.is_connected(_on_debug_clear_button_pressed):
		debug_clear_button.pressed.connect(_on_debug_clear_button_pressed)
	if is_instance_valid(detail_close_button) and !detail_close_button.pressed.is_connected(_close_objectives_quest_detail):
		detail_close_button.pressed.connect(_close_objectives_quest_detail)


func _unhandled_input(_event: InputEvent) -> void:
	if _handle_upgrade_overlay_input(_event):
		return
	if _handle_objectives_quest_detail_input(_event):
		return
	if Input.is_action_just_pressed("ui_cancel"):
		get_tree().paused = false
		get_tree().change_scene_to_file(TITLE_SCENE_PATH)


func _process(delta: float) -> void:
	if run_progress_service != null and !game_over and !game_clear and !run_progress_service.has_pending_upgrade_draft():
		run_progress_service.tick(delta)
		_sync_hud()
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
	return run_progress_service == null or !run_progress_service.has_pending_upgrade_draft()


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
	refresh_claimed_ratio_cache()
	_refresh_boss_region_ratio_cache()


func refresh_claimed_ratio_cache() -> void:
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


func _is_valid_boss_region_polygon(polygon: PackedVector2Array) -> bool:
	return polygon.size() >= 3 and PlayfieldBoundary.polygon_area(polygon) > 0.0


func _resolve_fallback_boss_region_polygon() -> PackedVector2Array:
	if _is_valid_boss_region_polygon(remaining_polygon):
		return remaining_polygon
	if _is_valid_boss_region_polygon(current_outer_loop):
		return current_outer_loop
	return PackedVector2Array()


func _warn_boss_region_recalculation_failure(message: String) -> void:
	if boss_region_recalculation_warning_active:
		return
	boss_region_recalculation_warning_active = true
	push_warning(message)


func _should_recalculate_boss_region_after_capture(
	capture_context: Dictionary,
	previous_boss_region_polygon: PackedVector2Array
) -> bool:
	if !_is_valid_boss_region_polygon(previous_boss_region_polygon):
		return true
	var captured_polygons: Array = capture_context.get("captured_polygons", [])
	if captured_polygons.is_empty():
		return true

	var captured_polygon_aabbs: Array = capture_context.get("captured_polygon_aabbs", [])
	var boss_region_aabb := PlayfieldBoundary.build_points_aabb(previous_boss_region_polygon)
	var epsilon := maxf(
		PlayfieldBoundary.DEFAULT_EPSILON,
		float(capture_context.get("guide_epsilon", PlayfieldBoundary.DEFAULT_EPSILON))
	)
	var has_valid_captured_polygon := false
	for index in range(captured_polygons.size()):
		if typeof(captured_polygons[index]) != TYPE_PACKED_VECTOR2_ARRAY:
			continue
		var captured_polygon: PackedVector2Array = captured_polygons[index]
		if captured_polygon.size() < 3:
			continue
		has_valid_captured_polygon = true
		var captured_aabb: Rect2 = (
			captured_polygon_aabbs[index]
			if index < captured_polygon_aabbs.size() and typeof(captured_polygon_aabbs[index]) == TYPE_RECT2
			else PlayfieldBoundary.build_points_aabb(captured_polygon)
		)
		if !PlayfieldBoundary.rects_overlap(boss_region_aabb, captured_aabb, epsilon):
			continue
		for overlap_variant in Geometry2D.intersect_polygons(previous_boss_region_polygon, captured_polygon):
			if typeof(overlap_variant) != TYPE_PACKED_VECTOR2_ARRAY:
				continue
			var overlap: PackedVector2Array = overlap_variant
			if PlayfieldBoundary.polygon_area(overlap) > epsilon * epsilon:
				return true
	return !has_valid_captured_polygon


func _sync_hud_area_labels() -> void:
	if hud_service == null:
		return
	hud_service.sync_area_labels()


func _sync_hud() -> void:
	if hud_service == null:
		return
	hud_service.sync()


func get_run_progress_hud_snapshot() -> Dictionary:
	if run_progress_service == null:
		return {}
	return run_progress_service.get_hud_snapshot()


func get_upgrade_draft_choices() -> Array[Dictionary]:
	if run_progress_service == null:
		return []
	return run_progress_service.get_pending_upgrade_choices()


func is_upgrade_draft_active() -> bool:
	return run_progress_service != null and run_progress_service.has_pending_upgrade_draft()


func is_objectives_quest_detail_open() -> bool:
	return (
		is_instance_valid(objectives_quest_detail_overlay)
		and objectives_quest_detail_overlay.visible
	)


func _open_objectives_quest_detail() -> void:
	if is_upgrade_draft_active() or !is_instance_valid(objectives_quest_detail_overlay):
		return
	objectives_quest_detail_overlay.visible = true
	_sync_hud()


func _close_objectives_quest_detail() -> void:
	if !is_instance_valid(objectives_quest_detail_overlay):
		return
	objectives_quest_detail_overlay.visible = false


func _on_objectives_quests_button_pressed() -> void:
	if is_objectives_quest_detail_open():
		_close_objectives_quest_detail()
		return
	_open_objectives_quest_detail()


func _on_debug_clear_button_pressed() -> void:
	if game_over or game_clear:
		return
	_begin_game_clear_reveal()


func _handle_objectives_quest_detail_input(_event: InputEvent) -> bool:
	if !is_objectives_quest_detail_open():
		return false
	if Input.is_action_just_pressed("ui_cancel"):
		_close_objectives_quest_detail()
		return true
	return false


func get_top_outline_countdown_bonus_seconds() -> float:
	if run_progress_service == null:
		return 0.0
	return run_progress_service.get_top_outline_countdown_bonus_seconds()


func try_consume_run_guard() -> bool:
	if run_progress_service == null:
		return false
	var blocked := run_progress_service.try_consume_guard()
	if blocked:
		_sync_hud()
	return blocked


func _register_input_map() -> void:
	_ensure_action("move_left", [_key_event(KEY_LEFT), _key_event(KEY_A), _joypad_button(JOY_BUTTON_DPAD_LEFT)])
	_ensure_action("move_right", [_key_event(KEY_RIGHT), _key_event(KEY_D), _joypad_button(JOY_BUTTON_DPAD_RIGHT)])
	_ensure_action("move_up", [_key_event(KEY_UP), _key_event(KEY_W), _joypad_button(JOY_BUTTON_DPAD_UP)])
	_ensure_action("move_down", [_key_event(KEY_DOWN), _key_event(KEY_S), _joypad_button(JOY_BUTTON_DPAD_DOWN)])
	_sync_draw_action_events([_key_event(KEY_SHIFT), _joypad_button(JOY_BUTTON_A)])
	_ensure_action(String(ACTION_QIX_DRAW_FAST), [_key_event(KEY_SHIFT), _joypad_button(JOY_BUTTON_A)])
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
	sync_boss_marker()
	_recalculate_claimed_area()
	queue_redraw()
	_sync_hud()


func _recalculate_playfield_rect() -> void:
	playfield_rect = _create_playfield_rect()
	_refresh_playfield_area_cache()
	if stage_cover_polygon.size() >= 3:
		_rebuild_stage_cover_uvs()


func _validate_required_game_nodes() -> bool:
	var missing_nodes: Array[String] = []
	if !is_instance_valid(base_player):
		missing_nodes.append("BasePlayer")
	if !is_instance_valid(bbos):
		missing_nodes.append("BBOS")
	if !is_instance_valid(minor_enemy_a):
		missing_nodes.append("MinorEnemyA")
	if !is_instance_valid(minor_enemy_b):
		missing_nodes.append("MinorEnemyB")
	if missing_nodes.is_empty():
		return true
	push_error("BaseMain is missing required scene nodes: %s" % ", ".join(missing_nodes))
	return false


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
	refresh_current_outer_loop_metrics()
	remaining_polygon = _create_playfield_cover_polygon()
	var initial_stage_cover_source := remaining_polygon if remaining_polygon.size() >= 3 else _create_playfield_cover_polygon()
	rebuild_stage_cover_polygon_from_polygon(initial_stage_cover_source)
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
		refresh_claimed_ratio_cache()
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
		_apply_playfield_to_minor_enemies()
		return
	if bbos.has_method("set_playfield_rect"):
		bbos.call("set_playfield_rect", playfield_rect)
	if bbos.has_method("set_active_outer_loop"):
		bbos.call("set_active_outer_loop", current_outer_loop)
	_apply_playfield_to_minor_enemies()
	_apply_boss_region_ratio_to_bbos()


func _apply_playfield_to_minor_enemies() -> void:
	for enemy in _get_minor_enemies():
		if enemy.has_method("set_playfield_rect"):
			enemy.call("set_playfield_rect", playfield_rect)
		if enemy.has_method("set_active_outer_loop"):
			enemy.call("set_active_outer_loop", current_outer_loop)


func _apply_boss_region_ratio_to_bbos() -> void:
	if !is_instance_valid(bbos):
		return
	if bbos.has_method("set_boss_region_ratio"):
		bbos.call("set_boss_region_ratio", boss_region_ratio_cached)


func _on_player_capture_closed(trail_points: PackedVector2Array) -> void:
	if capture_service == null:
		push_warning("Capture skipped: capture service is not ready.")
		return
	var capture_snapshot := {}
	if is_instance_valid(base_player) and base_player.has_method("build_capture_snapshot"):
		capture_snapshot = base_player.call("build_capture_snapshot")
	var previous_boss_region_polygon := boss_region_polygon.duplicate()
	var pre_boss_region_ratio := boss_region_ratio_cached
	var capture_result := capture_service.resolve_capture_closed(trail_points)
	if !bool(capture_result.get("success", false)):
		push_warning(str(capture_result.get("warning", "Capture skipped.")))
		return

	var capture_context: Dictionary = capture_result.get("capture_context", {})
	_update_cut_rating_after_capture(capture_context)
	_remove_captured_minor_enemies(capture_context)
	_apply_playfield_to_player()
	_apply_playfield_to_bbos()
	if guide_service != null:
		guide_service.handle_capture_context(capture_context)
	sync_boss_marker()
	_update_boss_region_after_capture(capture_context, previous_boss_region_polygon)
	_register_run_capture(capture_context, capture_snapshot, pre_boss_region_ratio)
	_sync_hud()
	queue_redraw()


func _update_boss_region_after_capture(
	capture_context: Dictionary,
	previous_boss_region_polygon: PackedVector2Array
) -> void:
	if _should_recalculate_boss_region_after_capture(capture_context, previous_boss_region_polygon):
		_recalculate_boss_region_polygon_after_capture()
		return
	_apply_boss_region_ratio_to_bbos()
	_check_game_clear_after_remaining_area_update()


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
	var recalculated_polygon: PackedVector2Array = boss_region_result.get("polygon", PackedVector2Array())
	if _is_valid_boss_region_polygon(recalculated_polygon):
		_set_boss_region_polygon(recalculated_polygon)
		boss_region_recalculation_warning_active = false
	else:
		if _is_valid_boss_region_polygon(boss_region_polygon):
			_warn_boss_region_recalculation_failure("Boss region recalculation failed; keeping previous polygon.")
		else:
			var fallback_polygon := _resolve_fallback_boss_region_polygon()
			if _is_valid_boss_region_polygon(fallback_polygon):
				_set_boss_region_polygon(fallback_polygon)
				_warn_boss_region_recalculation_failure("Boss region recalculation failed; restored fallback polygon.")
			else:
				_set_boss_region_polygon(PackedVector2Array())
				_warn_boss_region_recalculation_failure("Boss region recalculation failed; no valid polygon was available.")
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
	if run_progress_service != null:
		run_progress_service.register_stage_clear()
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
	for enemy in _get_minor_enemies():
		_hide_game_clear_target(enemy)
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
	if game_clear and clear_reveal_progress > 0.0 and clear_reveal_progress < 1.0:
		_draw_clear_reveal_curtain_edge(_get_clear_reveal_cutoff_y())


func _draw_clear_reveal_curtain_edge(cutoff_y: float) -> void:
	var pf_left := playfield_rect.position.x
	var pf_right := playfield_rect.end.x
	var pf_top := playfield_rect.position.y
	var pf_bottom := playfield_rect.end.y
	var pf_width := playfield_rect.size.x

	var fold_height := 18.0
	var shadow_height := 28.0

	cutoff_y = clampf(cutoff_y, pf_top, pf_bottom)

	var fold_bottom := cutoff_y
	var fold_top := fold_bottom - fold_height
	if fold_top < pf_top:
		fold_height = fold_bottom - pf_top
		fold_top = pf_top
	if fold_height <= 0.0:
		return

	var shadow_end_y := minf(fold_bottom + shadow_height, pf_bottom)
	var shadow_span := shadow_end_y - fold_bottom
	if shadow_span > 0.0:
		const SHADOW_STEPS := 6
		var step_height := shadow_span / float(SHADOW_STEPS)
		for step_index in range(SHADOW_STEPS):
			var step_y := fold_bottom + step_height * float(step_index)
			var alpha := lerpf(
				0.38,
				0.06,
				float(step_index) / maxf(float(SHADOW_STEPS - 1), 1.0)
			)
			draw_rect(Rect2(pf_left, step_y, pf_width, step_height + 0.5), Color(0.0, 0.0, 0.0, alpha), true)

	const WAVE_SEGMENTS := 16
	const WAVE_AMPLITUDE := 2.5
	var fold_points := PackedVector2Array()
	fold_points.append(Vector2(pf_left, fold_top))
	fold_points.append(Vector2(pf_right, fold_top))
	var segment_width := pf_width / float(WAVE_SEGMENTS)
	for segment_index in range(WAVE_SEGMENTS, -1, -1):
		var x := pf_left + segment_width * float(segment_index)
		var wave := sin(float(segment_index) * 1.15) * WAVE_AMPLITUDE
		var y := clampf(fold_bottom + wave, pf_top, pf_bottom)
		fold_points.append(Vector2(x, y))
	draw_colored_polygon(fold_points, Color(0.06, 0.02, 0.10, 0.62))

	draw_line(
		Vector2(pf_left, fold_top),
		Vector2(pf_right, fold_top),
		Color(1.0, 1.0, 1.0, 0.50),
		1.5
	)
	draw_line(
		Vector2(pf_left, fold_bottom),
		Vector2(pf_right, fold_bottom),
		Color(0.0, 0.0, 0.0, 0.78),
		1.0
	)


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
	refresh_claimed_ratio_cache()


func refresh_current_outer_loop_metrics() -> void:
	if current_outer_loop.size() < 3:
		current_outer_loop_metrics = {}
		return

	current_outer_loop_metrics = PlayfieldBoundary.build_loop_metrics(current_outer_loop)


func sync_boss_marker() -> void:
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


func rebuild_stage_cover_polygon_from_polygon(source_polygon: PackedVector2Array) -> void:
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
	if run_progress_service != null:
		run_progress_service.register_damage_taken()
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


func _register_run_capture(capture_context: Dictionary, capture_snapshot: Dictionary, pre_boss_region_ratio: float) -> void:
	if run_progress_service == null:
		return
	var enriched_context := capture_context.duplicate(true)
	enriched_context["single_capture_percent"] = _calculate_single_capture_percent(capture_context)
	enriched_context["claimed_ratio"] = claimed_ratio_cached
	enriched_context["pre_boss_region_ratio"] = pre_boss_region_ratio
	enriched_context["post_boss_region_ratio"] = boss_region_ratio_cached
	enriched_context["boss_region_reduction_percent"] = maxf(0.0, (pre_boss_region_ratio - boss_region_ratio_cached) * 100.0)
	enriched_context["draw_duration"] = float(capture_snapshot.get("draw_duration", 0.0))
	enriched_context["trail_point_count"] = int(capture_snapshot.get("trail_point_count", 0))
	enriched_context["top_outline_remaining"] = float(capture_snapshot.get("top_outline_remaining", 0.0))
	enriched_context["risk_grade"] = _resolve_capture_risk_grade(enriched_context)
	enriched_context["capture_size_band"] = _resolve_capture_size_band(float(enriched_context["single_capture_percent"]))
	enriched_context["streak_state"] = "clean"
	var _reward_result := run_progress_service.register_capture(enriched_context)
	if run_progress_service.has_pending_upgrade_draft():
		get_tree().paused = true


func _resolve_capture_risk_grade(capture_context: Dictionary) -> String:
	var draw_duration := float(capture_context.get("draw_duration", 0.0))
	var trail_point_count := int(capture_context.get("trail_point_count", 0))
	var reduction_percent := float(capture_context.get("boss_region_reduction_percent", 0.0))
	if draw_duration >= 2.2 or trail_point_count >= 4 or reduction_percent >= 8.0:
		return "high"
	if draw_duration >= 1.1 or trail_point_count >= 3:
		return "medium"
	return "safe"


func _resolve_capture_size_band(single_capture_percent: float) -> String:
	if single_capture_percent >= 15.0:
		return "large"
	if single_capture_percent >= 6.0:
		return "medium"
	return "small"


func _handle_upgrade_overlay_input(event: InputEvent) -> bool:
	if !is_upgrade_draft_active():
		return false
	if event is InputEventKey and event.pressed and !event.echo:
		match event.keycode:
			KEY_1, KEY_KP_1:
				return _apply_upgrade_choice(0)
			KEY_2, KEY_KP_2:
				return _apply_upgrade_choice(1)
			KEY_3, KEY_KP_3:
				return _apply_upgrade_choice(2)
			KEY_R:
				if run_progress_service != null and run_progress_service.reroll_upgrade_choices():
					_sync_hud()
					return true
	return false


func _apply_upgrade_choice(index: int) -> bool:
	if run_progress_service == null or !run_progress_service.apply_upgrade_choice(index):
		return false
	if is_instance_valid(base_player) and base_player.has_method("apply_run_configuration"):
		base_player.call("apply_run_configuration", run_progress_service.build_player_run_configuration())
	get_tree().paused = false
	_sync_hud()
	return true


func _remove_captured_minor_enemies(capture_context: Dictionary) -> void:
	var captured_polygons: Array = capture_context.get("captured_polygons", [])
	if captured_polygons.is_empty():
		return
	var epsilon := float(capture_context.get("guide_epsilon", PlayfieldBoundary.DEFAULT_EPSILON))
	for enemy in _get_minor_enemies():
		if !_is_minor_enemy_captured(enemy, captured_polygons, epsilon):
			continue
		if enemy == minor_enemy_a:
			minor_enemy_a = null
		if enemy == minor_enemy_b:
			minor_enemy_b = null
		enemy.queue_free()


func _is_minor_enemy_captured(enemy: Node2D, captured_polygons: Array, epsilon: float) -> bool:
	if !is_instance_valid(enemy):
		return false
	var enemy_position := enemy.global_position
	for raw_polygon in captured_polygons:
		var polygon: PackedVector2Array = raw_polygon
		if polygon.size() < 3:
			continue
		if (
			Geometry2D.is_point_in_polygon(enemy_position, polygon)
			or PlayfieldBoundary.is_point_on_loop(polygon, enemy_position, epsilon)
		):
			return true
	return false


func _get_minor_enemies() -> Array[Node2D]:
	var enemies: Array[Node2D] = []
	_append_minor_enemy_if_valid(enemies, minor_enemy_a)
	_append_minor_enemy_if_valid(enemies, minor_enemy_b)
	var tree := get_tree()
	if !is_instance_valid(tree):
		return enemies
	for node in tree.get_nodes_in_group(&"minor_enemies"):
		_append_minor_enemy_if_valid(enemies, node)
	return enemies


func _append_minor_enemy_if_valid(enemies: Array[Node2D], node: Node) -> void:
	if !is_instance_valid(node):
		return
	if !(node is Node2D):
		return
	if node != self and !is_ancestor_of(node):
		return
	var enemy := node as Node2D
	if enemies.has(enemy):
		return
	enemies.append(enemy)


func _on_bbos_position_changed(_world_position: Vector2) -> void:
	sync_boss_marker()
