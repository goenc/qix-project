extends RefCounted
class_name BaseMainGuideResolutionService

const PlayfieldBoundary = preload("res://scripts/game/playfield_boundary.gd")
const BaseMainGuideCommon = preload("res://scripts/game/services/base_main_guide_common.gd")


func collect_guide_draw_segments(context: Dictionary, guide_segments: Array[Dictionary]) -> Array[Dictionary]:
	var draw_segments: Array[Dictionary] = []
	var epsilon := float(context.get("guide_epsilon", 0.0))
	var show_vertical_guides := bool(context.get("show_vertical_guides", true))
	var show_horizontal_guides := bool(context.get("show_horizontal_guides", true))
	for guide_segment in guide_segments:
		var draw_segment: Dictionary = guide_segment
		if _is_pending_guide_segment(guide_segment):
			draw_segment = _build_pending_guide_preview_segment(context, guide_segment)
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
		draw_segments.append({
			"start": start,
			"end": end,
			"is_vertical": is_vertical,
			"is_short": _is_guide_segment_within_short_threshold(context, guide_length, epsilon)
		})
	return draw_segments


func refresh_guide_segments(
	context: Dictionary,
	guide_segments: Array[Dictionary],
	apply_capture_correction: bool = false
) -> Array[Dictionary]:
	var refreshed_segments: Array[Dictionary] = []
	for guide_segment in guide_segments:
		if _is_pending_guide_segment(guide_segment):
			refreshed_segments.append(guide_segment)
			continue
		refreshed_segments.append(resolve_guide_segment(context, guide_segment, apply_capture_correction))
	return refreshed_segments


func resolve_guide_segment(
	context: Dictionary,
	guide_segment: Dictionary,
	apply_capture_correction: bool = false
) -> Dictionary:
	var epsilon := float(context.get("guide_epsilon", 0.0))
	var resolved_segment := guide_segment.duplicate()
	var start: Vector2 = resolved_segment.get("start", Vector2.ZERO)
	var direction := normalize_guide_direction(resolved_segment.get("dir", Vector2.ZERO))
	resolved_segment["start"] = start
	resolved_segment["end"] = start
	resolved_segment["dir"] = direction
	resolved_segment["active"] = false
	if direction == Vector2.ZERO:
		return resolved_segment

	var end_result := _resolve_guide_segment_end(context, start, direction, epsilon)
	if !bool(end_result.get("hit", false)):
		return resolved_segment

	var end_point: Vector2 = end_result.get("end", start)
	if start.distance_to(end_point) <= epsilon:
		return resolved_segment
	resolved_segment["end"] = end_point
	resolved_segment["active"] = true
	if apply_capture_correction:
		return _apply_capture_guide_segment_correction(context, resolved_segment, epsilon)
	return resolved_segment


func normalize_guide_direction(direction: Vector2) -> Vector2:
	return BaseMainGuideCommon.normalize_guide_direction(direction)


func has_pending_guides(guide_segments: Array[Dictionary]) -> bool:
	for guide_segment in guide_segments:
		if _is_pending_guide_segment(guide_segment):
			return true
	return false


func remove_pending_guides(guide_segments: Array[Dictionary]) -> Array[Dictionary]:
	var kept_segments: Array[Dictionary] = []
	for guide_segment in guide_segments:
		if _is_pending_guide_segment(guide_segment):
			continue
		kept_segments.append(guide_segment)
	return kept_segments


func _build_pending_guide_preview_segment(context: Dictionary, guide_segment: Dictionary) -> Dictionary:
	var preview_segment := _build_confirmed_guide_segment(guide_segment)
	var epsilon := float(context.get("guide_epsilon", 0.0))
	var start: Vector2 = preview_segment.get("start", Vector2.ZERO)
	var direction := normalize_guide_direction(preview_segment.get("dir", Vector2.ZERO))
	preview_segment["start"] = start
	preview_segment["end"] = start
	preview_segment["dir"] = direction
	preview_segment["active"] = false
	if direction == Vector2.ZERO:
		return preview_segment

	var end_result := _resolve_pending_guide_preview_end(context, start, direction, epsilon)
	if !bool(end_result.get("hit", false)):
		return preview_segment

	var end_point: Vector2 = end_result.get("end", start)
	if start.distance_to(end_point) <= epsilon:
		return preview_segment
	preview_segment["end"] = end_point
	preview_segment["active"] = true
	return preview_segment


func _build_confirmed_guide_segment(guide_segment: Dictionary) -> Dictionary:
	return BaseMainGuideCommon.build_confirmed_guide_segment(guide_segment)


func _resolve_pending_guide_preview_end(
	context: Dictionary,
	start: Vector2,
	direction: Vector2,
	epsilon: float
) -> Dictionary:
	var hit := _find_pending_guide_preview_hit(context, start, direction, epsilon)
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


func _resolve_guide_segment_end(
	context: Dictionary,
	start: Vector2,
	direction: Vector2,
	epsilon: float
) -> Dictionary:
	var hit := _find_first_guide_boundary_hit(context, start, direction, epsilon)
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


func _apply_capture_guide_segment_correction(
	context: Dictionary,
	guide_segment: Dictionary,
	epsilon: float
) -> Dictionary:
	var corrected_segment := guide_segment.duplicate()
	if !bool(corrected_segment.get("active", false)):
		return corrected_segment

	var start: Vector2 = corrected_segment.get("start", Vector2.ZERO)
	var end: Vector2 = corrected_segment.get("end", start)
	var direction := normalize_guide_direction(corrected_segment.get("dir", Vector2.ZERO))
	var correction_result := _find_first_valid_guide_region_end_on_segment(
		context,
		start,
		end,
		direction,
		epsilon
	)
	if !bool(correction_result.get("found", false)):
		corrected_segment["end"] = start
		corrected_segment["active"] = false
		return corrected_segment

	var boundary_search_start: Vector2 = correction_result.get("first_valid_point", start)
	var boundary_line := _find_first_orthogonal_guide_boundary_segment_on_segment(
		context,
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
	context: Dictionary,
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
		var is_valid_point := _is_point_in_valid_guide_region(context, sample_point, epsilon)
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
	context: Dictionary,
	start: Vector2,
	search_start: Vector2,
	end: Vector2,
	direction: Vector2,
	epsilon: float
) -> Dictionary:
	if direction == Vector2.ZERO:
		return {"found": false}

	var claimed_polygons: Array[PackedVector2Array] = context.get("claimed_polygons", [])
	var claimed_polygon_aabbs: Array[Rect2] = context.get("claimed_polygon_aabbs", [])
	var search_rect := PlayfieldBoundary.build_segment_aabb_from_points(search_start, end)
	var best_line := _find_first_orthogonal_guide_boundary_segment_on_loop(
		start,
		search_start,
		end,
		direction,
		_get_guide_boundary_loop(context),
		epsilon
	)
	for index in range(claimed_polygons.size()):
		if index < claimed_polygon_aabbs.size() and !PlayfieldBoundary.rects_overlap(
			search_rect,
			claimed_polygon_aabbs[index],
			epsilon
		):
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


func _pick_nearest_orthogonal_guide_boundary_segment(
	current_best: Dictionary,
	candidate: Dictionary,
	epsilon: float
) -> Dictionary:
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
	return BaseMainGuideCommon.build_guide_scan_bounds(start, end, direction)


func _build_guide_scan_point(scan_bounds: Dictionary, axis_value: int) -> Vector2:
	return BaseMainGuideCommon.build_guide_scan_point(scan_bounds, axis_value)


func _find_first_guide_boundary_hit(
	context: Dictionary,
	start: Vector2,
	direction: Vector2,
	epsilon: float
) -> Dictionary:
	var ray_end := _build_guide_ray_end(context, start, direction, epsilon)
	return _find_first_guide_boundary_hit_on_segment(context, start, ray_end, epsilon)


func _find_first_guide_boundary_hit_on_segment(
	context: Dictionary,
	start: Vector2,
	ray_end: Vector2,
	epsilon: float
) -> Dictionary:
	if start.distance_to(ray_end) <= epsilon:
		return {"hit": false}
	var claimed_polygons: Array[PackedVector2Array] = context.get("claimed_polygons", [])
	var claimed_polygon_aabbs: Array[Rect2] = context.get("claimed_polygon_aabbs", [])
	var ray_rect := PlayfieldBoundary.build_segment_aabb_from_points(start, ray_end)
	var best_hit := {"hit": false}
	best_hit = _pick_nearest_guide_hit(
		best_hit,
		_find_guide_loop_hit(start, ray_end, _get_guide_boundary_loop(context), epsilon),
		epsilon
	)
	for index in range(claimed_polygons.size()):
		if index < claimed_polygon_aabbs.size() and !PlayfieldBoundary.rects_overlap(
			ray_rect,
			claimed_polygon_aabbs[index],
			epsilon
		):
			continue
		best_hit = _pick_nearest_guide_hit(
			best_hit,
			_find_guide_loop_hit(start, ray_end, claimed_polygons[index], epsilon),
			epsilon
		)
	return best_hit


func _find_pending_guide_preview_hit(
	context: Dictionary,
	start: Vector2,
	direction: Vector2,
	epsilon: float
) -> Dictionary:
	var current_outer_loop: PackedVector2Array = context.get("current_outer_loop", PackedVector2Array())
	var preview_loop: PackedVector2Array = current_outer_loop if current_outer_loop.size() >= 3 else _get_guide_boundary_loop(context)
	var ray_end := _build_guide_ray_end(context, start, direction, epsilon)
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


func _build_guide_ray_end(
	context: Dictionary,
	start: Vector2,
	direction: Vector2,
	epsilon: float
) -> Vector2:
	var playfield_rect: Rect2 = context.get("playfield_rect", Rect2())
	var margin := maxf(epsilon * 8.0, 8.0)
	if absf(direction.x) > 0.0:
		var target_x: float = playfield_rect.end.x + margin if direction.x > 0.0 else playfield_rect.position.x - margin
		return Vector2(target_x, start.y)
	if absf(direction.y) > 0.0:
		var target_y: float = playfield_rect.end.y + margin if direction.y > 0.0 else playfield_rect.position.y - margin
		return Vector2(start.x, target_y)
	return start


func _get_guide_boundary_loop(context: Dictionary) -> PackedVector2Array:
	var remaining_polygon: PackedVector2Array = context.get("remaining_polygon", PackedVector2Array())
	if remaining_polygon.size() >= 3:
		return remaining_polygon
	return context.get("current_outer_loop", PackedVector2Array())


func _is_point_in_valid_guide_region(context: Dictionary, point: Vector2, epsilon: float) -> bool:
	if _is_point_in_claimed_region(context, point, epsilon):
		return false
	if _is_point_on_inactive_border(context, point, epsilon):
		return false
	return _is_point_in_remaining_region(context, point, epsilon)


func _is_point_in_claimed_region(context: Dictionary, point: Vector2, epsilon: float) -> bool:
	var claimed_polygons: Array[PackedVector2Array] = context.get("claimed_polygons", [])
	var claimed_polygon_aabbs: Array[Rect2] = context.get("claimed_polygon_aabbs", [])
	for index in range(claimed_polygons.size()):
		if index < claimed_polygon_aabbs.size() and !PlayfieldBoundary.point_overlaps_rect(
			point,
			claimed_polygon_aabbs[index],
			epsilon
		):
			continue
		var polygon: PackedVector2Array = claimed_polygons[index]
		if polygon.size() < 3:
			continue
		if Geometry2D.is_point_in_polygon(point, polygon) or PlayfieldBoundary.is_point_on_loop(polygon, point, epsilon):
			return true
	return false


func _is_point_on_inactive_border(context: Dictionary, point: Vector2, epsilon: float) -> bool:
	var inactive_border_segments: Array[PackedVector2Array] = context.get("inactive_border_segments", [])
	var inactive_border_segment_aabbs: Array[Rect2] = context.get("inactive_border_segment_aabbs", [])
	for index in range(inactive_border_segments.size()):
		if index < inactive_border_segment_aabbs.size() and !PlayfieldBoundary.point_overlaps_rect(
			point,
			inactive_border_segment_aabbs[index],
			epsilon
		):
			continue
		var segment: PackedVector2Array = inactive_border_segments[index]
		for segment_index in range(segment.size() - 1):
			if PlayfieldBoundary.is_point_on_segment(point, segment[segment_index], segment[segment_index + 1], epsilon):
				return true
	return false


func _is_point_in_remaining_region(context: Dictionary, point: Vector2, epsilon: float) -> bool:
	var boundary_loop := _get_guide_boundary_loop(context)
	if boundary_loop.size() >= 3:
		return Geometry2D.is_point_in_polygon(point, boundary_loop) or PlayfieldBoundary.is_point_on_loop(boundary_loop, point, epsilon)
	var playfield_rect: Rect2 = context.get("playfield_rect", Rect2())
	if playfield_rect.size.x <= 0.0 or playfield_rect.size.y <= 0.0:
		return false
	return playfield_rect.has_point(point)


func _is_pending_guide_segment(guide_segment: Dictionary) -> bool:
	return BaseMainGuideCommon.is_pending_guide_segment(guide_segment)


func _get_guide_segment_axis_length(start: Vector2, end: Vector2, is_vertical: bool) -> float:
	if is_vertical:
		return absf(end.y - start.y)
	return absf(end.x - start.x)


func _is_guide_segment_within_short_threshold(
	context: Dictionary,
	guide_length: float,
	epsilon: float
) -> bool:
	var boss_diameter := float(context.get("partition_fill_target_boss_diameter", 0.0))
	if boss_diameter <= epsilon:
		return false
	return guide_length <= boss_diameter * 1.2 + epsilon
