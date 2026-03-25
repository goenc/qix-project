extends RefCounted
class_name BaseMainGuidePartitionFillEntryService

const BaseMainGuideCommon = preload("res://scripts/game/services/base_main_guide_common.gd")


func sync_entries_after_capture(
	partition_state: Dictionary,
	affected_vertical_guide_keys: Dictionary,
	capture_delta: Dictionary
) -> void:
	var epsilon := float(partition_state.get("guide_epsilon", 0.0))
	var horizontal_outer_segments := _collect_horizontal_outer_loop_segments(partition_state, epsilon)
	if horizontal_outer_segments.is_empty():
		_clear_partition_entries(partition_state)
		return

	var existing_vertical_guides := _collect_unique_active_vertical_guides(
		partition_state,
		horizontal_outer_segments,
		epsilon
	)
	if existing_vertical_guides.is_empty():
		_clear_partition_entries(partition_state)
		return

	var existing_vertical_guides_by_interval_key: Dictionary = {}
	for guide in existing_vertical_guides:
		var interval_key := BaseMainGuideCommon.stringify_value(guide.get("interval_key", ""), "")
		if interval_key.is_empty():
			continue
		existing_vertical_guides_by_interval_key[interval_key] = guide

	var update_region := _build_guide_partition_update_region(affected_vertical_guide_keys, capture_delta, epsilon)
	_prune_guide_partition_fill_entries(
		partition_state,
		existing_vertical_guides_by_interval_key,
		epsilon
	)

	if !bool(update_region.get("has_update", false)):
		return

	var guides_to_refresh := _collect_vertical_guides_for_partition_refresh(
		existing_vertical_guides,
		update_region,
		epsilon
	)
	var refreshed_interval_keys: Dictionary = {}
	for guide in guides_to_refresh:
		var interval_key := BaseMainGuideCommon.stringify_value(guide.get("interval_key", ""), "")
		if interval_key.is_empty() or refreshed_interval_keys.has(interval_key):
			continue
		refreshed_interval_keys[interval_key] = true
		_refresh_guide_partition_fill_entries_for_vertical_guide(
			partition_state,
			guide,
			existing_vertical_guides,
			horizontal_outer_segments,
			update_region,
			epsilon
		)


func extract_entry_storage_key(entry: Dictionary) -> String:
	var entry_key := BaseMainGuideCommon.stringify_value(entry.get("entry_key", ""), "")
	if !entry_key.is_empty():
		return entry_key
	return extract_entry_pair_key(entry)


func has_valid_base_rect(entry: Dictionary, epsilon: float) -> bool:
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


func _clear_partition_entries(partition_state: Dictionary) -> void:
	partition_state["guide_partition_fill_entries"] = []
	partition_state["guide_partition_fill_entry_key_sequence"] = 0


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
	for rect in _collect_capture_delta_aabbs_for_partition_update(capture_delta):
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


func _extract_capture_delta_rects(capture_delta: Dictionary, key: String) -> Array[Rect2]:
	var rects: Array[Rect2] = []
	if !capture_delta.has(key):
		return rects
	for raw_rect in capture_delta[key]:
		if typeof(raw_rect) != TYPE_RECT2:
			continue
		rects.append(raw_rect)
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


func _refresh_guide_partition_fill_entries_for_vertical_guide(
	partition_state: Dictionary,
	guide: Dictionary,
	existing_vertical_guides: Array[Dictionary],
	horizontal_outer_segments: Array[Dictionary],
	update_region: Dictionary,
	epsilon: float
) -> void:
	_remove_guide_partition_fill_entries_for_guide_interval(
		partition_state,
		guide,
		update_region,
		epsilon
	)

	var left_guide := _find_vertical_partition_guide_on_side(
		guide,
		existing_vertical_guides,
		true,
		epsilon
	)
	if !left_guide.is_empty():
		_append_guide_partition_fill_entry_between(
			partition_state,
			left_guide,
			guide,
			horizontal_outer_segments,
			epsilon
		)

	var right_guide := _find_vertical_partition_guide_on_side(
		guide,
		existing_vertical_guides,
		false,
		epsilon
	)
	if !right_guide.is_empty():
		_append_guide_partition_fill_entry_between(
			partition_state,
			guide,
			right_guide,
			horizontal_outer_segments,
			epsilon
		)


func _append_guide_partition_fill_entry_between(
	partition_state: Dictionary,
	left_guide: Dictionary,
	right_guide: Dictionary,
	horizontal_outer_segments: Array[Dictionary],
	epsilon: float
) -> void:
	if !_should_fill_guide_partition_between_vertical_guides(partition_state, left_guide, right_guide, epsilon):
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
	if !has_valid_base_rect({
		"rect": rect,
		"left_x": left_x,
		"right_x": right_x,
		"top_y": top_y,
		"bottom_y": bottom_y
	}, epsilon):
		return

	var left_guide_key := int(left_guide.get("x_key", int(round(left_x))))
	var right_guide_key := int(right_guide.get("x_key", int(round(right_x))))
	var left_interval_key := BaseMainGuideCommon.stringify_value(left_guide.get("interval_key", ""), "")
	var right_interval_key := BaseMainGuideCommon.stringify_value(right_guide.get("interval_key", ""), "")
	_upsert_guide_partition_fill_entry(partition_state, {
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
	})


func _upsert_guide_partition_fill_entry(partition_state: Dictionary, entry: Dictionary) -> void:
	var guide_partition_fill_entries: Array[Dictionary] = partition_state.get("guide_partition_fill_entries", [])
	var pair_key := extract_entry_pair_key(entry)
	if pair_key.is_empty():
		return
	entry["pair_key"] = pair_key
	if _is_guide_partition_fill_entry_persistent(entry):
		var entry_key := BaseMainGuideCommon.stringify_value(entry.get("entry_key", ""), "")
		if entry_key.is_empty():
			entry_key = _allocate_guide_partition_fill_entry_key(partition_state, pair_key)
			entry["entry_key"] = entry_key
	var entry_index := _find_guide_partition_fill_entry_index(partition_state, entry)
	if entry_index >= 0:
		guide_partition_fill_entries[entry_index] = entry
		return
	guide_partition_fill_entries.append(entry)


func _find_guide_partition_fill_entry_index(partition_state: Dictionary, entry_to_match: Dictionary) -> int:
	var guide_partition_fill_entries: Array[Dictionary] = partition_state.get("guide_partition_fill_entries", [])
	var entry_key := BaseMainGuideCommon.stringify_value(entry_to_match.get("entry_key", ""), "")
	if !entry_key.is_empty():
		for index in range(guide_partition_fill_entries.size()):
			var entry: Dictionary = guide_partition_fill_entries[index]
			if BaseMainGuideCommon.stringify_value(entry.get("entry_key", ""), "") == entry_key:
				return index
		return -1

	var pair_key := extract_entry_pair_key(entry_to_match)
	for index in range(guide_partition_fill_entries.size()):
		var entry: Dictionary = guide_partition_fill_entries[index]
		var entry_pair_key := extract_entry_pair_key(entry)
		if entry_pair_key == pair_key:
			return index
	return -1


func _build_guide_partition_pair_key(left_interval_key: String, right_interval_key: String) -> String:
	return "%s|%s" % [left_interval_key, right_interval_key]


func extract_entry_pair_key(entry: Dictionary) -> String:
	var pair_key := BaseMainGuideCommon.stringify_value(entry.get("pair_key", ""), "")
	if !pair_key.is_empty():
		return pair_key
	var left_interval_key := BaseMainGuideCommon.stringify_value(entry.get("left_interval_key", ""), "")
	var right_interval_key := BaseMainGuideCommon.stringify_value(entry.get("right_interval_key", ""), "")
	if !left_interval_key.is_empty() and !right_interval_key.is_empty():
		return _build_guide_partition_pair_key(left_interval_key, right_interval_key)
	return _build_guide_partition_pair_key(
		BaseMainGuideCommon.stringify_value(entry.get("left_guide_key", ""), ""),
		BaseMainGuideCommon.stringify_value(entry.get("right_guide_key", ""), "")
	)


func _allocate_guide_partition_fill_entry_key(partition_state: Dictionary, pair_key: String) -> String:
	partition_state["guide_partition_fill_entry_key_sequence"] = int(
		partition_state.get("guide_partition_fill_entry_key_sequence", 0)
	) + 1
	return "%s#%d" % [pair_key, int(partition_state.get("guide_partition_fill_entry_key_sequence", 0))]


func _is_guide_partition_fill_entry_persistent(entry: Dictionary) -> bool:
	return bool(entry.get("persist", true))


func _remove_guide_partition_fill_entries_for_guide_interval(
	partition_state: Dictionary,
	guide: Dictionary,
	update_region: Dictionary,
	epsilon: float
) -> void:
	var guide_partition_fill_entries: Array[Dictionary] = partition_state.get("guide_partition_fill_entries", [])
	var interval_key := BaseMainGuideCommon.stringify_value(guide.get("interval_key", ""), "")
	if interval_key.is_empty():
		return
	for index in range(guide_partition_fill_entries.size() - 1, -1, -1):
		var entry: Dictionary = guide_partition_fill_entries[index]
		if _is_guide_partition_fill_entry_persistent(entry):
			continue
		var left_interval_key := BaseMainGuideCommon.stringify_value(entry.get("left_interval_key", ""), "")
		var right_interval_key := BaseMainGuideCommon.stringify_value(entry.get("right_interval_key", ""), "")
		if left_interval_key == interval_key or right_interval_key == interval_key:
			guide_partition_fill_entries.remove_at(index)
			continue
		if !_guide_partition_entry_intersects_update_region(entry, update_region, epsilon):
			continue
		if _guide_partition_entry_touches_guide_x(entry, guide, epsilon):
			guide_partition_fill_entries.remove_at(index)


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
	partition_state: Dictionary,
	active_vertical_guides_by_interval_key: Dictionary,
	epsilon: float
) -> void:
	var guide_partition_fill_entries: Array[Dictionary] = partition_state.get("guide_partition_fill_entries", [])
	for index in range(guide_partition_fill_entries.size() - 1, -1, -1):
		var entry: Dictionary = guide_partition_fill_entries[index]
		if _is_guide_partition_fill_entry_persistent(entry):
			continue
		if !_guide_partition_entry_has_active_vertical_guides(entry, active_vertical_guides_by_interval_key):
			guide_partition_fill_entries.remove_at(index)
			continue
		if !_guide_partition_entry_lengths_within_threshold(partition_state, entry, epsilon):
			guide_partition_fill_entries.remove_at(index)
			continue
		if !has_valid_base_rect(entry, epsilon):
			guide_partition_fill_entries.remove_at(index)


func _collect_horizontal_outer_loop_segments(partition_state: Dictionary, epsilon: float) -> Array[Dictionary]:
	var segments: Array[Dictionary] = []
	var current_outer_loop: PackedVector2Array = partition_state.get("current_outer_loop", PackedVector2Array())
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


func _collect_unique_active_vertical_guides(
	partition_state: Dictionary,
	horizontal_outer_segments: Array[Dictionary],
	epsilon: float
) -> Array[Dictionary]:
	var guides_by_interval_key: Dictionary = {}
	var guide_segments: Array[Dictionary] = partition_state.get("guide_segments", [])
	var vertical_guide_indices_by_x: Dictionary = partition_state.get("vertical_guide_indices_by_x", {})
	var vertical_guide_axis_keys: Array[int] = partition_state.get("vertical_guide_axis_keys", [])
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
			var interval_key := BaseMainGuideCommon.stringify_value(candidate.get("interval_key", ""), "")
			if interval_key.is_empty():
				continue
			guides_by_interval_key[interval_key] = candidate

	var sorted_guides: Array[Dictionary] = []
	for interval_key in guides_by_interval_key.keys():
		sorted_guides.append(guides_by_interval_key[interval_key])
	sorted_guides.sort_custom(Callable(self, "_sort_vertical_partition_guide"))
	return sorted_guides


func _build_vertical_partition_guide_candidate(
	guide_segment: Dictionary,
	_horizontal_outer_segments: Array[Dictionary],
	epsilon: float
) -> Dictionary:
	if BaseMainGuideCommon.is_pending_guide_segment(guide_segment):
		return {}
	if !bool(guide_segment.get("active", false)):
		return {}

	var direction := BaseMainGuideCommon.normalize_guide_direction(guide_segment.get("dir", Vector2.ZERO))
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
	var reference_interval_key := BaseMainGuideCommon.stringify_value(reference_guide.get("interval_key", ""), "")
	var best_candidate: Dictionary = {}
	var best_distance := INF
	var best_overlap_height := -INF
	for candidate in candidate_guides:
		if BaseMainGuideCommon.stringify_value(candidate.get("interval_key", ""), "") == reference_interval_key:
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


func _is_vertical_partition_guide_candidate_better(candidate: Dictionary, current: Dictionary) -> bool:
	var candidate_height := float(candidate.get("height", 0.0))
	var current_height := float(current.get("height", 0.0))
	if candidate_height > current_height:
		return true
	if candidate_height < current_height:
		return false
	return float(candidate.get("top_y", 0.0)) < float(current.get("top_y", 0.0))


func _should_fill_guide_partition_between_vertical_guides(
	partition_state: Dictionary,
	left_guide: Dictionary,
	right_guide: Dictionary,
	epsilon: float
) -> bool:
	var boss_diameter := float(partition_state.get("partition_fill_target_boss_diameter", 0.0))
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


func _guide_partition_entry_has_active_vertical_guides(
	entry: Dictionary,
	active_vertical_guides_by_interval_key: Dictionary
) -> bool:
	var left_interval_key := BaseMainGuideCommon.stringify_value(
		entry.get("left_interval_key", entry.get("left_guide_key", "")),
		""
	)
	var right_interval_key := BaseMainGuideCommon.stringify_value(
		entry.get("right_interval_key", entry.get("right_guide_key", "")),
		""
	)
	if left_interval_key.is_empty() or right_interval_key.is_empty():
		return false
	return (
		active_vertical_guides_by_interval_key.has(left_interval_key)
		and active_vertical_guides_by_interval_key.has(right_interval_key)
	)


func _guide_partition_entry_lengths_within_threshold(
	partition_state: Dictionary,
	entry: Dictionary,
	epsilon: float
) -> bool:
	var boss_diameter := float(partition_state.get("partition_fill_target_boss_diameter", 0.0))
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
