extends RefCounted
class_name BaseMainCaptureService

const PlayfieldBoundary = preload("res://scripts/game/playfield_boundary.gd")

var _main


func setup(main) -> void:
	_main = main


func resolve_capture_closed(trail_points: PackedVector2Array) -> Dictionary:
	if _main == null:
		return {"success": false, "warning": "Capture skipped: service is not ready."}
	if _main.current_outer_loop.size() < 3:
		return {"success": false, "warning": "Capture skipped: outer loop is not ready."}

	var epsilon := _resolve_capture_epsilon()
	var candidate_loops := _build_capture_candidate_loops(trail_points, epsilon)
	if candidate_loops.size() < 2:
		return {
			"success": false,
			"warning": "Capture skipped: candidate outer loops could not be generated."
		}

	var retained_index := _select_boss_side_loop(candidate_loops, epsilon)
	if retained_index < 0 or retained_index >= candidate_loops.size():
		return {
			"success": false,
			"warning": "Capture skipped: boss-side outer loop could not be determined."
		}

	var completed_capture_generation: int = _main.current_capture_generation
	_main.current_capture_generation += 1
	_apply_retained_capture_loop(candidate_loops[retained_index])
	var capture_delta := _append_claimed_capture_results(candidate_loops, retained_index)
	var capture_context := _build_capture_context(capture_delta, completed_capture_generation)
	_apply_claimed_area_capture_delta(capture_context)
	_append_capture_delta_aabbs(capture_delta)
	return {
		"success": true,
		"capture_delta": capture_delta,
		"capture_context": capture_context,
		"capture_generation": completed_capture_generation
	}


func _resolve_capture_epsilon() -> float:
	var epsilon := 2.0
	if is_instance_valid(_main.base_player):
		epsilon = _main.base_player.border_epsilon
	return epsilon


func _get_boss_selection_point() -> Vector2:
	if is_instance_valid(_main.bbos):
		return _main.bbos.global_position
	if is_instance_valid(_main.boss):
		return _main.boss.global_position
	return _main.current_outer_loop[0]


func _build_capture_candidate_loops(trail_points: PackedVector2Array, epsilon: float) -> Array[Dictionary]:
	return PlayfieldBoundary.split_outer_loop_by_trail(
		_main.current_outer_loop,
		trail_points,
		epsilon,
		_main.current_outer_loop_metrics
	)


func _select_boss_side_loop(candidate_loops: Array[Dictionary], epsilon: float) -> int:
	_main._sync_boss_marker()
	var selection_point := _get_boss_selection_point()
	return PlayfieldBoundary.select_loop_containing_point(candidate_loops, selection_point, epsilon)


func _apply_retained_capture_loop(retained_candidate: Dictionary) -> void:
	_main.current_outer_loop = retained_candidate.get("loop", PackedVector2Array())
	_main._refresh_current_outer_loop_metrics()
	var retained_polygon: PackedVector2Array = retained_candidate.get("polygon", PackedVector2Array())
	if retained_polygon.size() >= 3:
		_main.remaining_polygon = retained_polygon
	var stage_cover_source: PackedVector2Array = retained_polygon if retained_polygon.size() >= 3 else _main.remaining_polygon
	_main._rebuild_stage_cover_polygon_from_polygon(stage_cover_source)
	_main.inactive_border_segments.clear()
	_main.inactive_border_segment_aabbs.clear()


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
			_main.claimed_polygons.append(captured_polygon)
			captured_polygons_delta.append(captured_polygon)
			captured_polygon_aabbs.append(PlayfieldBoundary.build_points_aabb(captured_polygon))
			var captured_polygon_area := float(candidate_loops[index].get("area", -1.0))
			if captured_polygon_area < 0.0:
				captured_polygon_area = PlayfieldBoundary.polygon_area(captured_polygon)
			added_claimed_area += captured_polygon_area
		var removed_path: PackedVector2Array = candidate_loops[index].get("boundary_path", PackedVector2Array())
		var removed_segments := PlayfieldBoundary.polyline_to_segments(removed_path)
		if removed_segments.is_empty():
			continue
		_main.inactive_border_segments.append_array(removed_segments)
		inactive_segments_delta.append_array(removed_segments)
		for segment in removed_segments:
			inactive_segment_aabbs.append(PlayfieldBoundary.build_points_aabb(segment))

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
		"guide_epsilon": maxf(PlayfieldBoundary.DEFAULT_EPSILON * 10.0, _resolve_capture_epsilon() * 0.25)
	}


func _apply_claimed_area_capture_delta(capture_context: Dictionary) -> void:
	_main.claimed_area += float(capture_context.get("added_claimed_area", 0.0))
	if _main.playfield_area_cached > 0.0:
		_main.claimed_area = minf(_main.claimed_area, _main.playfield_area_cached)
	_main._refresh_claimed_ratio_cache()


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
		_main.claimed_polygon_aabbs.append_array(captured_polygon_aabbs)

	var inactive_segment_aabbs := _extract_capture_delta_rects(capture_delta, "inactive_segment_aabbs")
	if !inactive_segment_aabbs.is_empty():
		_main.inactive_border_segment_aabbs.append_array(inactive_segment_aabbs)


func _extract_captured_polygons_from_capture_delta(capture_delta: Dictionary) -> Array[PackedVector2Array]:
	var captured_polygons_delta: Array[PackedVector2Array] = []
	if capture_delta.has("captured_polygons"):
		captured_polygons_delta = capture_delta["captured_polygons"]
	return captured_polygons_delta
