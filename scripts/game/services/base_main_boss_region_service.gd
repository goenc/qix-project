extends RefCounted
class_name BaseMainBossRegionService

const PlayfieldBoundary = preload("res://scripts/game/playfield_boundary.gd")

var _main


func setup(main) -> void:
	_main = main


func recalculate_after_capture() -> Dictionary:
	if _main == null:
		return {
			"polygon": PackedVector2Array(),
			"remaining_area_ratio": -1.0
		}

	var boss_region_context := _build_boss_region_capture_context()
	var polygon := PackedVector2Array()
	if !boss_region_context.is_empty():
		var epsilon := float(boss_region_context.get("epsilon", _get_guide_epsilon()))
		var selection_point: Vector2 = boss_region_context.get("selection_point", Vector2.ZERO)
		var graph := _build_boss_region_graph_from_capture_context(boss_region_context)
		if !graph.is_empty():
			var traced_loop := _trace_boss_region_loop_clockwise(graph, epsilon)
			if _is_valid_traced_boss_region_loop(traced_loop, selection_point, epsilon):
				polygon = traced_loop

	return {
		"polygon": polygon,
		"remaining_area_ratio": _get_remaining_area_ratio()
	}


func get_remaining_area_ratio() -> float:
	if _main == null:
		return -1.0
	return _get_remaining_area_ratio()


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


func _build_boss_region_boundary_segments(epsilon: float) -> Array[Dictionary]:
	var boundary_segments: Array[Dictionary] = []
	if _main.current_outer_loop.size() >= 2:
		for index in range(_main.current_outer_loop.size()):
			_append_boss_region_boundary_segment(
				boundary_segments,
				"outer_%d" % index,
				"outer",
				_main.current_outer_loop[index],
				_main.current_outer_loop[(index + 1) % _main.current_outer_loop.size()],
				epsilon
			)

	for index in range(_main.guide_segments.size()):
		var guide_segment: Dictionary = _main.guide_segments[index]
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
			if (
				PlayfieldBoundary.is_point_on_segment(candidate_point, a_start, a_end, epsilon)
				and PlayfieldBoundary.is_point_on_segment(candidate_point, b_start, b_end, epsilon)
			):
				_append_unique_boss_region_point(intersections, candidate_point, epsilon)
		return intersections

	if !a_horizontal and absf(a_start.x - b_start.x) <= epsilon:
		for candidate_point in [a_start, a_end, b_start, b_end]:
			if (
				PlayfieldBoundary.is_point_on_segment(candidate_point, a_start, a_end, epsilon)
				and PlayfieldBoundary.is_point_on_segment(candidate_point, b_start, b_end, epsilon)
			):
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


func _get_remaining_area_ratio() -> float:
	if _main.playfield_area_cached <= 0.0:
		return -1.0
	if _main.remaining_polygon.size() < 3:
		return -1.0
	var remaining_area := PlayfieldBoundary.polygon_area(_main.remaining_polygon)
	return clampf(remaining_area / _main.playfield_area_cached, 0.0, 1.0)


func _get_boss_selection_point() -> Vector2:
	if is_instance_valid(_main.bbos):
		return _main.bbos.global_position
	if is_instance_valid(_main.boss):
		return _main.boss.global_position
	return _main.current_outer_loop[0]


func _resolve_capture_epsilon() -> float:
	var epsilon := 2.0
	if is_instance_valid(_main.base_player):
		epsilon = _main.base_player.border_epsilon
	return epsilon


func _get_guide_epsilon() -> float:
	return maxf(PlayfieldBoundary.DEFAULT_EPSILON * 10.0, _resolve_capture_epsilon() * 0.25)


func _is_pending_guide_segment(guide_segment: Dictionary) -> bool:
	return bool(guide_segment.get("pending", false))


func _normalize_guide_direction(direction: Vector2) -> Vector2:
	if absf(direction.x) > absf(direction.y):
		return Vector2(signf(direction.x), 0.0)
	if absf(direction.y) > 0.0:
		return Vector2(0.0, signf(direction.y))
	return Vector2.ZERO


func _get_guide_segment_axis_length(start: Vector2, end: Vector2, is_vertical: bool) -> float:
	if is_vertical:
		return absf(end.y - start.y)
	return absf(end.x - start.x)


func _is_guide_segment_within_short_threshold(guide_length: float, epsilon: float) -> bool:
	var boss_diameter := _get_partition_fill_target_boss_diameter()
	if boss_diameter <= epsilon:
		return false
	return guide_length <= boss_diameter * 1.2 + epsilon


func _get_partition_fill_target_boss_diameter() -> float:
	if is_instance_valid(_main.bbos):
		if _main.bbos.has_method("_get_effective_collision_radius"):
			return maxf(float(_main.bbos.call("_get_effective_collision_radius")), 0.0) * 2.0
		if _main.bbos.has_method("get"):
			return maxf(float(_main.bbos.get("collision_radius")), 0.0) * 2.0
	if is_instance_valid(_main.boss) and _main.boss.has_method("get"):
		return maxf(float(_main.boss.get("collision_radius")), 0.0) * 2.0
	return 0.0


func _stringify_value(value: Variant, default_text: String = "") -> String:
	if typeof(value) == TYPE_NIL:
		return default_text
	return str(value)
