extends RefCounted
class_name BaseMainGuideCaptureService

const PlayfieldBoundary = preload("res://scripts/game/playfield_boundary.gd")


func rebuild_spatial_caches(
	claimed_polygons: Array[PackedVector2Array],
	inactive_border_segments: Array[PackedVector2Array]
) -> Dictionary:
	return {
		"claimed_polygon_aabbs": PlayfieldBoundary.build_polygon_aabbs(claimed_polygons),
		"inactive_border_segment_aabbs": PlayfieldBoundary.build_segment_aabbs(inactive_border_segments)
	}


func rebuild_guide_axis_indices(guide_segments: Array[Dictionary]) -> Dictionary:
	var axis_state := {
		"vertical_guide_indices_by_x": {},
		"horizontal_guide_indices_by_y": {},
		"vertical_guide_axis_keys": [],
		"horizontal_guide_axis_keys": []
	}
	for index in range(guide_segments.size()):
		_register_guide_axis_index(axis_state, index, guide_segments[index])
	axis_state["vertical_guide_axis_keys"] = _sorted_axis_keys(axis_state.get("vertical_guide_indices_by_x", {}))
	axis_state["horizontal_guide_axis_keys"] = _sorted_axis_keys(axis_state.get("horizontal_guide_indices_by_y", {}))
	return axis_state


func collect_guide_capture_actions(
	state: Dictionary,
	capture_context: Dictionary,
	resolution_context: Dictionary,
	resolution_service
) -> Dictionary:
	var actions := {
		"remove": [],
		"confirm": [],
		"reresolve": []
	}
	_collect_pending_guide_capture_actions(state, capture_context, actions, resolution_context, resolution_service)
	_collect_dirty_guide_capture_actions(state, capture_context, actions)
	return actions


func collect_affected_vertical_guide_keys_from_capture_actions(
	capture_actions: Dictionary,
	guide_segments: Array[Dictionary]
) -> Dictionary:
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
			var guide_segment: Dictionary = guide_segments[index]
			var direction := _normalize_guide_direction(guide_segment.get("dir", Vector2.ZERO))
			if absf(direction.y) <= 0.0:
				continue
			affected_vertical_guide_keys[_get_guide_axis_key(guide_segment)] = true
	return affected_vertical_guide_keys


func apply_capture_guide_actions(
	capture_actions: Dictionary,
	guide_segments: Array[Dictionary],
	resolution_context: Dictionary,
	resolution_service
) -> Array[Dictionary]:
	var updated_segments: Array[Dictionary] = []
	for guide_segment in guide_segments:
		updated_segments.append(guide_segment.duplicate())

	var confirm_updates: Array = capture_actions.get("confirm", [])
	for update in confirm_updates:
		var parsed_index := _extract_capture_action_index("confirm", update)
		if !bool(parsed_index.get("valid", false)):
			continue
		var index = parsed_index.get("index", -1)
		if typeof(index) != TYPE_INT:
			continue
		if index < 0 or index >= updated_segments.size():
			continue
		if typeof(update) != TYPE_DICTIONARY:
			continue
		updated_segments[index] = update.get("segment", updated_segments[index])

	var reresolve_indices: Array = capture_actions.get("reresolve", [])
	for raw_index in reresolve_indices:
		var parsed_index := _extract_capture_action_index("reresolve", raw_index)
		if !bool(parsed_index.get("valid", false)):
			continue
		var index = parsed_index.get("index", -1)
		if typeof(index) != TYPE_INT:
			continue
		if index < 0 or index >= updated_segments.size():
			continue
		updated_segments[index] = _reresolve_guide_segment_for_capture(
			updated_segments[index],
			resolution_context,
			resolution_service
		)

	var remove_indices := _sort_unique_descending_indices(capture_actions.get("remove", []))
	for index in remove_indices:
		if index < 0 or index >= updated_segments.size():
			continue
		updated_segments.remove_at(index)

	return updated_segments


func _collect_dirty_guide_indices_from_capture_context(
	state: Dictionary,
	capture_context: Dictionary
) -> Array[int]:
	var dirty_indices: Array[int] = []
	var captured_rects: Array[Rect2] = capture_context.get("captured_polygon_aabbs", [])
	var inactive_rects: Array[Rect2] = capture_context.get("inactive_segment_aabbs", [])
	if captured_rects.is_empty() and inactive_rects.is_empty():
		return dirty_indices

	var epsilon := float(capture_context.get("guide_epsilon", float(state.get("guide_epsilon", 0.0))))
	var candidate_indices := _collect_candidate_guide_indices_from_rects(state, captured_rects, inactive_rects, epsilon)
	var guide_segments: Array[Dictionary] = state.get("guide_segments", [])
	for index in candidate_indices:
		if _guide_segment_overlaps_capture_delta(guide_segments[index], captured_rects, inactive_rects, epsilon):
			dirty_indices.append(index)
	return dirty_indices


func _collect_candidate_guide_indices_from_rects(
	state: Dictionary,
	captured_rects: Array[Rect2],
	inactive_rects: Array[Rect2],
	epsilon: float
) -> Array[int]:
	var candidate_index_set: Dictionary = {}
	for rect in captured_rects:
		_append_axis_index_candidates_from_rect(state, rect, epsilon, candidate_index_set)
	for rect in inactive_rects:
		_append_axis_index_candidates_from_rect(state, rect, epsilon, candidate_index_set)

	var candidate_indices: Array[int] = []
	for index in candidate_index_set.keys():
		candidate_indices.append(int(index))
	candidate_indices.sort()
	return candidate_indices


func _append_axis_index_candidates_from_rect(
	state: Dictionary,
	rect: Rect2,
	epsilon: float,
	candidate_index_set: Dictionary
) -> void:
	var min_x := int(floor(rect.position.x - epsilon))
	var max_x := int(ceil(rect.end.x + epsilon))
	_append_axis_index_candidates_in_range(
		state.get("vertical_guide_axis_keys", []),
		state.get("vertical_guide_indices_by_x", {}),
		state.get("guide_segments", []),
		min_x,
		max_x,
		true,
		candidate_index_set
	)

	var min_y := int(floor(rect.position.y - epsilon))
	var max_y := int(ceil(rect.end.y + epsilon))
	_append_axis_index_candidates_in_range(
		state.get("horizontal_guide_axis_keys", []),
		state.get("horizontal_guide_indices_by_y", {}),
		state.get("guide_segments", []),
		min_y,
		max_y,
		false,
		candidate_index_set
	)


func _append_axis_index_candidates_in_range(
	axis_keys: Array[int],
	axis_indices: Dictionary,
	guide_segments: Array[Dictionary],
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
		_append_axis_index_bucket_candidates(
			axis_indices,
			guide_segments,
			axis_key,
			expect_vertical,
			candidate_index_set
		)


func _append_axis_index_bucket_candidates(
	axis_indices: Dictionary,
	guide_segments: Array[Dictionary],
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

		var guide_segment: Dictionary = guide_segments[index]
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


func _sorted_axis_keys(axis_indices: Dictionary) -> Array[int]:
	var sorted_keys: Array[int] = []
	for axis_key in axis_indices.keys():
		sorted_keys.append(int(axis_key))
	sorted_keys.sort()
	return sorted_keys


func _register_guide_axis_index(axis_state: Dictionary, index: int, guide_segment: Dictionary) -> void:
	if _is_pending_guide_segment(guide_segment):
		return
	var direction := _normalize_guide_direction(guide_segment.get("dir", Vector2.ZERO))
	if direction == Vector2.ZERO:
		return

	var axis_key := _get_guide_axis_key(guide_segment)
	if absf(direction.y) > 0.0:
		_append_guide_axis_index(axis_state.get("vertical_guide_indices_by_x", {}), axis_key, index)
		return
	if absf(direction.x) > 0.0:
		_append_guide_axis_index(axis_state.get("horizontal_guide_indices_by_y", {}), axis_key, index)


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
		if index < polygon_aabbs.size() and !PlayfieldBoundary.point_overlaps_rect(point, polygon_aabbs[index], epsilon):
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
		if !PlayfieldBoundary.is_point_on_segment(sample_point, start, end, epsilon):
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
	return _guide_body_is_inside_capture_delta(
		guide_segment,
		captured_polygons_delta,
		captured_polygon_aabbs,
		epsilon
	)


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
		if !PlayfieldBoundary.is_point_on_segment(sample_point, start, end, epsilon):
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
	return _guide_segment_touches_capture_delta(
		guide_segment,
		captured_polygons_delta,
		captured_polygon_aabbs,
		epsilon
	)


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


func _collect_pending_guide_indices_for_capture(
	guide_segments: Array[Dictionary],
	capture_generation: int
) -> Array[int]:
	var pending_indices: Array[int] = []
	for index in range(guide_segments.size()):
		var guide_segment: Dictionary = guide_segments[index]
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


func _resolve_pending_guide_segment_for_capture(
	guide_segment: Dictionary,
	resolution_context: Dictionary,
	resolution_service
) -> Dictionary:
	return resolution_service.resolve_guide_segment(
		resolution_context,
		_build_confirmed_guide_segment(guide_segment),
		true
	)


func _reresolve_guide_segment_for_capture(
	guide_segment: Dictionary,
	resolution_context: Dictionary,
	resolution_service
) -> Dictionary:
	return resolution_service.resolve_guide_segment(
		resolution_context,
		_reset_guide_segment_for_reresolve(guide_segment),
		true
	)


func _collect_pending_guide_capture_actions(
	state: Dictionary,
	capture_context: Dictionary,
	actions: Dictionary,
	resolution_context: Dictionary,
	resolution_service
) -> void:
	var captured_polygons_delta: Array[PackedVector2Array] = capture_context.get("captured_polygons", [])
	var captured_polygon_aabbs: Array[Rect2] = capture_context.get("captured_polygon_aabbs", [])
	var capture_generation := int(capture_context.get("capture_generation", -1))
	var epsilon := float(capture_context.get("guide_epsilon", float(state.get("guide_epsilon", 0.0))))
	var guide_segments: Array[Dictionary] = state.get("guide_segments", [])
	var pending_indices := _collect_pending_guide_indices_for_capture(guide_segments, capture_generation)
	for index in pending_indices:
		var resolved_segment := _resolve_pending_guide_segment_for_capture(
			guide_segments[index],
			resolution_context,
			resolution_service
		)
		if _is_pending_guide_captured(resolved_segment, captured_polygons_delta, captured_polygon_aabbs, epsilon):
			actions["remove"].append(index)
			continue
		actions["confirm"].append({
			"index": index,
			"segment": resolved_segment
		})


func _collect_dirty_guide_capture_actions(
	state: Dictionary,
	capture_context: Dictionary,
	actions: Dictionary
) -> void:
	var captured_polygons_delta: Array[PackedVector2Array] = capture_context.get("captured_polygons", [])
	if captured_polygons_delta.is_empty():
		return

	var captured_polygon_aabbs: Array[Rect2] = capture_context.get("captured_polygon_aabbs", [])
	var capture_generation := int(capture_context.get("capture_generation", -1))
	var epsilon := float(capture_context.get("guide_epsilon", float(state.get("guide_epsilon", 0.0))))
	var guide_segments: Array[Dictionary] = state.get("guide_segments", [])
	var candidate_indices := _collect_dirty_guide_indices_from_capture_context(state, capture_context)
	for index in candidate_indices:
		if index < 0 or index >= guide_segments.size():
			continue
		var guide_segment: Dictionary = guide_segments[index]
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


func _stringify_value(value: Variant, default_text: String = "") -> String:
	if typeof(value) == TYPE_NIL:
		return default_text
	return str(value)


func _normalize_guide_direction(direction: Vector2) -> Vector2:
	if absf(direction.x) > absf(direction.y):
		return Vector2(signf(direction.x), 0.0)
	if absf(direction.y) > 0.0:
		return Vector2(0.0, signf(direction.y))
	return Vector2.ZERO


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
