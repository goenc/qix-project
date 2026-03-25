extends RefCounted
class_name BaseMainGuideService

const PlayfieldBoundary = preload("res://scripts/game/playfield_boundary.gd")
const BaseMainGuideResolutionService = preload("res://scripts/game/services/base_main_guide_resolution_service.gd")
const BaseMainGuideCaptureService = preload("res://scripts/game/services/base_main_guide_capture_service.gd")
const BaseMainGuidePartitionFillService = preload("res://scripts/game/services/base_main_guide_partition_fill_service.gd")

var _main
var _resolution_service := BaseMainGuideResolutionService.new()
var _capture_service := BaseMainGuideCaptureService.new()
var _partition_fill_service := BaseMainGuidePartitionFillService.new()


func setup(main) -> void:
	_main = main


func sync_debug_visibility() -> void:
	var debug_manager: Node = _main.get_node_or_null("/root/DebugManager")
	if !is_instance_valid(debug_manager):
		return
	if debug_manager.has_method("is_vertical_guides_enabled"):
		_main.show_vertical_guides = bool(debug_manager.call("is_vertical_guides_enabled"))
	if debug_manager.has_method("is_horizontal_guides_enabled"):
		_main.show_horizontal_guides = bool(debug_manager.call("is_horizontal_guides_enabled"))
	if debug_manager.has_method("is_area_fills_enabled"):
		_main.show_area_fills = bool(debug_manager.call("is_area_fills_enabled"))
	if debug_manager.has_method("is_area_percent_labels_enabled"):
		_main.show_area_percent_labels = bool(debug_manager.call("is_area_percent_labels_enabled"))


func reset_after_outer_loop_initialized() -> void:
	_apply_spatial_caches(
		_capture_service.rebuild_spatial_caches(_main.claimed_polygons, _main.inactive_border_segments)
	)
	_apply_axis_state(_capture_service.rebuild_guide_axis_indices(_main.guide_segments))
	_main.guide_segments = _resolution_service.refresh_guide_segments(
		_build_resolution_context(),
		_main.guide_segments
	)


func handle_turn_created(
	turn_point: Vector2,
	previous_direction: Vector2,
	new_direction: Vector2,
	capture_generation: int
) -> void:
	var guide_directions := [
		_resolution_service.normalize_guide_direction(previous_direction),
		_resolution_service.normalize_guide_direction(-new_direction)
	]

	for guide_direction in guide_directions:
		if guide_direction == Vector2.ZERO:
			continue

		_main.guide_segments.append({
			"start": turn_point,
			"end": turn_point,
			"dir": guide_direction,
			"active": false,
			"capture_generation": capture_generation,
			"pending": true
		})


func handle_capture_context(capture_context: Dictionary) -> void:
	var resolution_context := _build_resolution_context()
	var capture_actions := _capture_service.collect_guide_capture_actions(
		_build_capture_service_context(),
		capture_context,
		resolution_context,
		_resolution_service
	)
	var affected_vertical_guide_keys := _capture_service.collect_affected_vertical_guide_keys_from_capture_actions(
		capture_actions,
		_main.guide_segments
	)
	_main.guide_segments = _capture_service.apply_capture_guide_actions(
		capture_actions,
		_main.guide_segments,
		resolution_context,
		_resolution_service
	)
	_apply_axis_state(_capture_service.rebuild_guide_axis_indices(_main.guide_segments))
	_apply_partition_fill_state(
		_partition_fill_service.sync_guide_partition_fill_entries_after_capture(
			_build_partition_service_context(),
			affected_vertical_guide_keys,
			capture_context.get("capture_delta", {})
		)
	)


func build_draw_data() -> Dictionary:
	return {
		"partition_polygons": _partition_fill_service.collect_guide_partition_rects(
			_build_partition_service_context()
		),
		"segments": _resolution_service.collect_guide_draw_segments(
			_build_resolution_context(),
			_main.guide_segments
		)
	}


func cleanup_pending_guides_outside_capture() -> bool:
	if !_resolution_service.has_pending_guides(_main.guide_segments):
		return false
	if _main.capture_preview_active:
		return false
	_main.guide_segments = _resolution_service.remove_pending_guides(_main.guide_segments)
	_apply_axis_state(_capture_service.rebuild_guide_axis_indices(_main.guide_segments))
	return true


func _build_resolution_context() -> Dictionary:
	return {
		"guide_epsilon": _get_guide_epsilon(),
		"partition_fill_target_boss_diameter": _get_partition_fill_target_boss_diameter(),
		"playfield_rect": _main.playfield_rect,
		"current_outer_loop": _main.current_outer_loop,
		"remaining_polygon": _main.remaining_polygon,
		"claimed_polygons": _main.claimed_polygons,
		"claimed_polygon_aabbs": _main.claimed_polygon_aabbs,
		"inactive_border_segments": _main.inactive_border_segments,
		"inactive_border_segment_aabbs": _main.inactive_border_segment_aabbs,
		"show_vertical_guides": _main.show_vertical_guides,
		"show_horizontal_guides": _main.show_horizontal_guides
	}


func _build_capture_service_context() -> Dictionary:
	return {
		"guide_epsilon": _get_guide_epsilon(),
		"guide_segments": _main.guide_segments,
		"vertical_guide_indices_by_x": _main.vertical_guide_indices_by_x,
		"horizontal_guide_indices_by_y": _main.horizontal_guide_indices_by_y,
		"vertical_guide_axis_keys": _main.vertical_guide_axis_keys,
		"horizontal_guide_axis_keys": _main.horizontal_guide_axis_keys
	}


func _build_partition_service_context() -> Dictionary:
	return {
		"guide_epsilon": _get_guide_epsilon(),
		"partition_fill_target_boss_diameter": _get_partition_fill_target_boss_diameter(),
		"current_outer_loop": _main.current_outer_loop,
		"remaining_polygon": _main.remaining_polygon,
		"guide_segments": _main.guide_segments,
		"vertical_guide_indices_by_x": _main.vertical_guide_indices_by_x,
		"vertical_guide_axis_keys": _main.vertical_guide_axis_keys,
		"guide_partition_fill_entries": _main.guide_partition_fill_entries,
		"guide_partition_fill_polygons_by_key": _main.guide_partition_fill_polygons_by_key,
		"guide_partition_fill_entry_key_sequence": _main.guide_partition_fill_entry_key_sequence
	}


func _apply_spatial_caches(spatial_caches: Dictionary) -> void:
	_main.claimed_polygon_aabbs = spatial_caches.get("claimed_polygon_aabbs", [])
	_main.inactive_border_segment_aabbs = spatial_caches.get("inactive_border_segment_aabbs", [])


func _apply_axis_state(axis_state: Dictionary) -> void:
	_main.vertical_guide_indices_by_x = axis_state.get("vertical_guide_indices_by_x", {})
	_main.horizontal_guide_indices_by_y = axis_state.get("horizontal_guide_indices_by_y", {})
	_main.vertical_guide_axis_keys = axis_state.get("vertical_guide_axis_keys", [])
	_main.horizontal_guide_axis_keys = axis_state.get("horizontal_guide_axis_keys", [])


func _apply_partition_fill_state(partition_fill_state: Dictionary) -> void:
	_main.guide_partition_fill_entries = partition_fill_state.get("guide_partition_fill_entries", [])
	_main.guide_partition_fill_polygons_by_key = partition_fill_state.get("guide_partition_fill_polygons_by_key", {})
	_main.guide_partition_fill_entry_key_sequence = int(
		partition_fill_state.get("guide_partition_fill_entry_key_sequence", 0)
	)


func _resolve_capture_epsilon() -> float:
	var epsilon := 2.0
	if is_instance_valid(_main.base_player):
		epsilon = _main.base_player.border_epsilon
	return epsilon


func _get_guide_epsilon() -> float:
	return maxf(PlayfieldBoundary.DEFAULT_EPSILON * 10.0, _resolve_capture_epsilon() * 0.25)


func _get_partition_fill_target_boss_diameter() -> float:
	if is_instance_valid(_main.bbos):
		if _main.bbos.has_method("_get_effective_collision_radius"):
			return maxf(float(_main.bbos.call("_get_effective_collision_radius")), 0.0) * 2.0
		if _main.bbos.has_method("get"):
			return maxf(float(_main.bbos.get("collision_radius")), 0.0) * 2.0
	if is_instance_valid(_main.boss) and _main.boss.has_method("get"):
		return maxf(float(_main.boss.get("collision_radius")), 0.0) * 2.0
	return 0.0
