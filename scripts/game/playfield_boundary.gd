extends RefCounted
class_name PlayfieldBoundary

const DEFAULT_EPSILON := 0.001


static func create_rect_loop(rect: Rect2) -> PackedVector2Array:
	var normalized_rect := rect.abs()
	var loop := PackedVector2Array()
	if normalized_rect.size.x <= 0.0 or normalized_rect.size.y <= 0.0:
		return loop

	loop.append(normalized_rect.position)
	loop.append(Vector2(normalized_rect.position.x, normalized_rect.end.y))
	loop.append(normalized_rect.end)
	loop.append(Vector2(normalized_rect.end.x, normalized_rect.position.y))
	return sanitize_loop(loop)


static func sanitize_loop(points: PackedVector2Array) -> PackedVector2Array:
	var sanitized := PackedVector2Array()
	for point in points:
		if sanitized.is_empty() or !sanitized[sanitized.size() - 1].is_equal_approx(point):
			sanitized.append(point)

	if sanitized.size() >= 2 and sanitized[0].is_equal_approx(sanitized[sanitized.size() - 1]):
		sanitized.resize(sanitized.size() - 1)

	if sanitized.size() >= 3 and signed_area(sanitized) > 0.0:
		sanitized = reverse_loop(sanitized)
	return sanitized


static func reverse_loop(loop: PackedVector2Array) -> PackedVector2Array:
	var reversed_loop := PackedVector2Array()
	for index in range(loop.size() - 1, -1, -1):
		reversed_loop.append(loop[index])
	return reversed_loop


static func signed_area(polygon: PackedVector2Array) -> float:
	if polygon.size() < 3:
		return 0.0

	var area := 0.0
	for index in range(polygon.size()):
		var current: Vector2 = polygon[index]
		var next: Vector2 = polygon[(index + 1) % polygon.size()]
		area += current.x * next.y - next.x * current.y
	return area * 0.5


static func polygon_area(polygon: PackedVector2Array) -> float:
	return absf(signed_area(polygon))


static func build_loop_metrics(loop: PackedVector2Array) -> Dictionary:
	var segment_lengths := PackedFloat32Array()
	var segment_starts := PackedFloat32Array()
	var total_length := 0.0

	for index in range(loop.size()):
		segment_starts.append(total_length)
		var next_index := (index + 1) % loop.size()
		var segment_length := loop[index].distance_to(loop[next_index])
		segment_lengths.append(segment_length)
		total_length += segment_length

	return {
		"segment_lengths": segment_lengths,
		"segment_starts": segment_starts,
		"total_length": total_length
	}


static func get_segment_count(loop: PackedVector2Array) -> int:
	return loop.size() if loop.size() >= 2 else 0


static func get_segment_start(loop: PackedVector2Array, segment_index: int) -> Vector2:
	var segment_count := get_segment_count(loop)
	if segment_count <= 0:
		return Vector2.ZERO
	var wrapped_index := ((segment_index % segment_count) + segment_count) % segment_count
	return loop[wrapped_index]


static func get_segment_end(loop: PackedVector2Array, segment_index: int) -> Vector2:
	var segment_count := get_segment_count(loop)
	if segment_count <= 0:
		return Vector2.ZERO
	var wrapped_index := ((segment_index % segment_count) + segment_count) % segment_count
	return loop[(wrapped_index + 1) % segment_count]


static func get_segment_length(
	loop: PackedVector2Array,
	segment_index: int,
	metrics: Dictionary = {}
) -> float:
	var segment_count := get_segment_count(loop)
	if segment_count <= 0:
		return 0.0

	var wrapped_index := ((segment_index % segment_count) + segment_count) % segment_count
	var segment_lengths: PackedFloat32Array = metrics.get("segment_lengths", PackedFloat32Array())
	if segment_lengths.size() == segment_count:
		return float(segment_lengths[wrapped_index])
	return get_segment_start(loop, wrapped_index).distance_to(get_segment_end(loop, wrapped_index))


static func get_segment_direction(
	loop: PackedVector2Array,
	segment_index: int,
	epsilon: float = DEFAULT_EPSILON
) -> Vector2:
	var segment_vector := get_segment_end(loop, segment_index) - get_segment_start(loop, segment_index)
	var safe_epsilon := maxf(epsilon, DEFAULT_EPSILON)
	if segment_vector.length_squared() <= safe_epsilon * safe_epsilon:
		return Vector2.ZERO
	return segment_vector.normalized()


static func point_at_segment_distance(
	loop: PackedVector2Array,
	segment_index: int,
	distance_on_segment: float,
	metrics: Dictionary = {}
) -> Vector2:
	var segment_start := get_segment_start(loop, segment_index)
	var segment_end := get_segment_end(loop, segment_index)
	var segment_length := get_segment_length(loop, segment_index, metrics)
	if segment_length <= DEFAULT_EPSILON:
		return segment_start

	var clamped_distance := clampf(distance_on_segment, 0.0, segment_length)
	return segment_start.lerp(segment_end, clamped_distance / segment_length)


static func locate_point_on_loop_segment(
	loop: PackedVector2Array,
	point: Vector2,
	epsilon: float = DEFAULT_EPSILON,
	metrics: Dictionary = {}
) -> Dictionary:
	var projection: Dictionary = project_point_to_loop(loop, point, metrics)
	var segment_index := int(projection.get("segment_index", -1))
	if segment_index < 0:
		return {
			"point": projection.get("point", point),
			"progress": float(projection.get("progress", 0.0)),
			"distance": float(projection.get("distance", 0.0)),
			"segment_index": -1,
			"distance_on_segment": 0.0,
			"vertex_index": -1
		}

	var resolved_metrics: Dictionary = metrics if !metrics.is_empty() else build_loop_metrics(loop)
	var segment_starts: PackedFloat32Array = resolved_metrics.get("segment_starts", PackedFloat32Array())
	var segment_length := get_segment_length(loop, segment_index, resolved_metrics)
	var distance_on_segment := 0.0
	if segment_index < segment_starts.size():
		distance_on_segment = clampf(
			float(projection.get("progress", 0.0)) - float(segment_starts[segment_index]),
			0.0,
			segment_length
		)
	else:
		distance_on_segment = clampf(
			get_segment_start(loop, segment_index).distance_to(projection.get("point", point)),
			0.0,
			segment_length
		)

	var projected_point: Vector2 = projection.get("point", point)
	var safe_epsilon := maxf(epsilon, DEFAULT_EPSILON)
	var vertex_index := -1
	if projected_point.distance_to(get_segment_start(loop, segment_index)) <= safe_epsilon:
		vertex_index = segment_index
	elif projected_point.distance_to(get_segment_end(loop, segment_index)) <= safe_epsilon:
		vertex_index = (segment_index + 1) % loop.size()

	return {
		"point": projected_point,
		"progress": float(projection.get("progress", 0.0)),
		"distance": float(projection.get("distance", 0.0)),
		"segment_index": segment_index,
		"distance_on_segment": distance_on_segment,
		"vertex_index": vertex_index
	}


static func get_vertex_connected_segment_indices(loop: PackedVector2Array, vertex_index: int) -> Dictionary:
	var segment_count := get_segment_count(loop)
	if segment_count <= 0 or vertex_index < 0 or vertex_index >= loop.size():
		return {
			"previous": -1,
			"next": -1
		}

	return {
		"previous": (vertex_index - 1 + segment_count) % segment_count,
		"next": vertex_index % segment_count
	}


static func get_connected_directions_at_point(
	loop: PackedVector2Array,
	point: Vector2,
	epsilon: float = DEFAULT_EPSILON
) -> Array[Dictionary]:
	var connections: Array[Dictionary] = []
	if loop.size() < 2:
		return connections

	var safe_epsilon := maxf(DEFAULT_EPSILON, minf(epsilon, 0.25))
	for segment_index in range(loop.size()):
		var segment_start := get_segment_start(loop, segment_index)
		var segment_end := get_segment_end(loop, segment_index)
		var projected_point := Geometry2D.get_closest_point_to_segment(point, segment_start, segment_end)
		if projected_point.distance_to(point) > safe_epsilon:
			continue

		var distance_to_start := point.distance_to(segment_start)
		if distance_to_start > safe_epsilon:
			_store_connected_direction_candidate(
				connections,
				_axis_direction_from_vector(segment_start - point, safe_epsilon),
				segment_index,
				segment_start,
				distance_to_start
			)

		var distance_to_end := point.distance_to(segment_end)
		if distance_to_end > safe_epsilon:
			_store_connected_direction_candidate(
				connections,
				_axis_direction_from_vector(segment_end - point, safe_epsilon),
				segment_index,
				segment_end,
				distance_to_end
			)

	return connections


static func choose_segment_at_vertex(
	loop: PackedVector2Array,
	vertex_index: int,
	input_direction: Vector2,
	_current_segment_index: int = -1,
	epsilon: float = DEFAULT_EPSILON,
	metrics: Dictionary = {}
) -> Dictionary:
	var segment_count := get_segment_count(loop)
	if segment_count <= 0 or input_direction == Vector2.ZERO:
		return {"matched": false}
	if vertex_index < 0 or vertex_index >= loop.size():
		return {"matched": false}

	var safe_epsilon := maxf(epsilon, DEFAULT_EPSILON)
	var target_direction := _axis_direction_from_vector(input_direction)
	if target_direction == Vector2.ZERO:
		return {"matched": false}

	for connection in get_connected_directions_at_point(loop, loop[vertex_index], safe_epsilon):
		var connection_direction: Vector2 = connection.get("direction", Vector2.ZERO)
		if !connection_direction.is_equal_approx(target_direction):
			continue

		var segment_index := int(connection.get("segment_index", -1))
		if segment_index < 0 or segment_index >= segment_count:
			return {"matched": false}

		var distance_on_segment := 0.0
		var vertex_point: Vector2 = loop[vertex_index]
		if vertex_point.distance_to(get_segment_end(loop, segment_index)) <= safe_epsilon:
			distance_on_segment = get_segment_length(loop, segment_index, metrics)

		return {
			"matched": true,
			"segment_index": segment_index,
			"distance_on_segment": distance_on_segment,
			"direction": connection_direction,
			"point": vertex_point
		}

	return {"matched": false}


static func _store_connected_direction_candidate(
	connections: Array[Dictionary],
	direction: Vector2,
	segment_index: int,
	target_point: Vector2,
	distance: float
) -> void:
	if direction == Vector2.ZERO or segment_index < 0 or distance <= DEFAULT_EPSILON:
		return

	for index in range(connections.size()):
		var existing_direction: Vector2 = connections[index].get("direction", Vector2.ZERO)
		if !existing_direction.is_equal_approx(direction):
			continue
		if distance + DEFAULT_EPSILON < float(connections[index].get("distance", INF)):
			connections[index] = {
				"direction": direction,
				"segment_index": segment_index,
				"target_point": target_point,
				"distance": distance
			}
		return

	connections.append({
		"direction": direction,
		"segment_index": segment_index,
		"target_point": target_point,
		"distance": distance
	})


static func _axis_direction_from_vector(vector: Vector2, epsilon: float = DEFAULT_EPSILON) -> Vector2:
	var safe_epsilon := maxf(epsilon, DEFAULT_EPSILON)
	if absf(vector.x) >= absf(vector.y):
		if absf(vector.x) <= safe_epsilon:
			return Vector2.ZERO
		return Vector2(signf(vector.x), 0.0)
	if absf(vector.y) <= safe_epsilon:
		return Vector2.ZERO
	return Vector2(0.0, signf(vector.y))


static func point_at_progress(loop: PackedVector2Array, metrics: Dictionary, progress: float) -> Vector2:
	if loop.size() < 2:
		return Vector2.ZERO

	var total_length := float(metrics.get("total_length", 0.0))
	if total_length <= DEFAULT_EPSILON:
		return loop[0]

	var wrapped_progress := wrap_progress(progress, total_length)
	var segment_lengths: PackedFloat32Array = metrics.get("segment_lengths", PackedFloat32Array())
	var segment_starts: PackedFloat32Array = metrics.get("segment_starts", PackedFloat32Array())
	for index in range(segment_lengths.size()):
		var segment_length := segment_lengths[index]
		var segment_start_progress := segment_starts[index]
		var segment_end_progress := segment_start_progress + segment_length
		var is_last_segment := index == segment_lengths.size() - 1
		if wrapped_progress < segment_end_progress - DEFAULT_EPSILON or is_last_segment:
			if segment_length <= DEFAULT_EPSILON:
				return loop[(index + 1) % loop.size()]

			var local_progress := clampf(wrapped_progress - segment_start_progress, 0.0, segment_length)
			return loop[index].lerp(loop[(index + 1) % loop.size()], local_progress / segment_length)

	return loop[0]


static func project_point_to_loop(loop: PackedVector2Array, point: Vector2, metrics: Dictionary = {}) -> Dictionary:
	if loop.size() < 2:
		return {
			"point": point,
			"progress": 0.0,
			"distance": 0.0,
			"segment_index": -1
		}

	var resolved_metrics := metrics if !metrics.is_empty() else build_loop_metrics(loop)
	var segment_lengths: PackedFloat32Array = resolved_metrics.get("segment_lengths", PackedFloat32Array())
	var segment_starts: PackedFloat32Array = resolved_metrics.get("segment_starts", PackedFloat32Array())

	var best_distance := INF
	var best_point := loop[0]
	var best_progress := 0.0
	var best_segment_index := -1
	for index in range(loop.size()):
		var segment_length := segment_lengths[index]
		if segment_length <= DEFAULT_EPSILON:
			continue

		var segment_start: Vector2 = loop[index]
		var segment_end: Vector2 = loop[(index + 1) % loop.size()]
		var projected_point := Geometry2D.get_closest_point_to_segment(point, segment_start, segment_end)
		var distance := point.distance_to(projected_point)
		if distance < best_distance - DEFAULT_EPSILON:
			best_distance = distance
			best_point = projected_point
			best_progress = segment_starts[index] + clampf(
				segment_start.distance_to(projected_point),
				0.0,
				segment_length
			)
			best_segment_index = index

	return {
		"point": best_point,
		"progress": best_progress,
		"distance": best_distance,
		"segment_index": best_segment_index
	}


static func tangent_at_progress(
	loop: PackedVector2Array,
	metrics: Dictionary,
	progress: float,
	clockwise: bool
) -> Vector2:
	if loop.size() < 2:
		return Vector2.ZERO

	var total_length := float(metrics.get("total_length", 0.0))
	if total_length <= DEFAULT_EPSILON:
		return Vector2.ZERO

	var sample_distance := minf(maxf(DEFAULT_EPSILON * 10.0, 0.5), total_length * 0.25)
	var sample_progress := progress + sample_distance if clockwise else progress - sample_distance
	var direction := _direction_at_progress(loop, metrics, sample_progress)
	return direction if clockwise else -direction


static func is_point_on_loop(
	loop: PackedVector2Array,
	point: Vector2,
	epsilon: float,
	metrics: Dictionary = {}
) -> bool:
	return float(project_point_to_loop(loop, point, metrics).get("distance", INF)) <= epsilon


static func find_vertex_index_at_point(
	loop: PackedVector2Array,
	point: Vector2,
	epsilon: float = DEFAULT_EPSILON
) -> int:
	if loop.is_empty():
		return -1

	var safe_epsilon := maxf(epsilon, DEFAULT_EPSILON)
	var max_distance_squared := safe_epsilon * safe_epsilon
	for index in range(loop.size()):
		if loop[index].distance_squared_to(point) <= max_distance_squared:
			return index
	return -1


static func get_vertex_tangent_directions(
	loop: PackedVector2Array,
	vertex_index: int,
	epsilon: float = DEFAULT_EPSILON
) -> Dictionary:
	if loop.size() < 2 or vertex_index < 0 or vertex_index >= loop.size():
		return {
			"previous": Vector2.ZERO,
			"next": Vector2.ZERO
		}

	var safe_epsilon := maxf(epsilon, DEFAULT_EPSILON)
	var current_point: Vector2 = loop[vertex_index]
	var previous_index := (vertex_index - 1 + loop.size()) % loop.size()
	var next_index := (vertex_index + 1) % loop.size()
	var previous_direction := loop[previous_index] - current_point
	var next_direction := loop[next_index] - current_point
	if previous_direction.length_squared() > safe_epsilon * safe_epsilon:
		previous_direction = previous_direction.normalized()
	else:
		previous_direction = Vector2.ZERO
	if next_direction.length_squared() > safe_epsilon * safe_epsilon:
		next_direction = next_direction.normalized()
	else:
		next_direction = Vector2.ZERO

	return {
		"previous": previous_direction,
		"next": next_direction
	}


static func split_outer_loop_by_trail(
	loop: PackedVector2Array,
	trail_points: PackedVector2Array,
	epsilon: float,
	metrics: Dictionary = {}
) -> Array[Dictionary]:
	var sanitized_loop := sanitize_loop(loop)
	var sanitized_trail := sanitize_polyline(trail_points)
	var candidates: Array[Dictionary] = []
	if sanitized_loop.size() < 3 or sanitized_trail.size() < 2:
		return candidates

	var resolved_metrics: Dictionary = metrics
	var segment_lengths: PackedFloat32Array = resolved_metrics.get("segment_lengths", PackedFloat32Array())
	if resolved_metrics.is_empty() or segment_lengths.size() != sanitized_loop.size():
		resolved_metrics = build_loop_metrics(sanitized_loop)

	var start_projection := project_point_to_loop(sanitized_loop, sanitized_trail[0], resolved_metrics)
	var end_projection := project_point_to_loop(sanitized_loop, sanitized_trail[sanitized_trail.size() - 1], resolved_metrics)
	var start_point: Vector2 = start_projection.get("point", sanitized_trail[0])
	var end_point: Vector2 = end_projection.get("point", sanitized_trail[sanitized_trail.size() - 1])
	if start_point.distance_to(end_point) <= epsilon:
		return candidates

	sanitized_trail[0] = start_point
	sanitized_trail[sanitized_trail.size() - 1] = end_point

	for clockwise in [true, false]:
		var boundary_path := build_loop_path_points(
			sanitized_loop,
			resolved_metrics,
			end_point,
			start_point,
			clockwise
		)
		var polygon := PackedVector2Array()
		for point in sanitized_trail:
			if polygon.is_empty() or !polygon[polygon.size() - 1].is_equal_approx(point):
				polygon.append(point)
		for point in boundary_path:
			if polygon.is_empty() or !polygon[polygon.size() - 1].is_equal_approx(point):
				polygon.append(point)

		polygon = sanitize_loop(polygon)
		var area := polygon_area(polygon)
		if polygon.size() < 3 or area <= epsilon:
			continue

		candidates.append({
			"loop": polygon,
			"polygon": polygon,
			"area": area,
			"trail_points": sanitized_trail,
			"boundary_path": boundary_path,
			"clockwise": clockwise
		})

	return candidates


static func select_loop_containing_point(
	candidate_loops: Array[Dictionary],
	point: Vector2,
	epsilon: float = DEFAULT_EPSILON
) -> int:
	var selected_index := -1
	var best_distance := INF
	var best_area := -INF

	for index in range(candidate_loops.size()):
		var loop: PackedVector2Array = candidate_loops[index].get("loop", PackedVector2Array())
		if loop.size() < 3:
			continue

		var contains_point := Geometry2D.is_point_in_polygon(point, loop) or is_point_on_loop(loop, point, epsilon)
		var projection := project_point_to_loop(loop, point)
		var distance := float(projection.get("distance", INF))
		var area := float(candidate_loops[index].get("area", -1.0))
		if area < 0.0:
			area = polygon_area(loop)
		if contains_point:
			if distance < best_distance - epsilon or (is_equal_approx(distance, best_distance) and area > best_area):
				selected_index = index
				best_distance = distance
				best_area = area
		elif selected_index == -1 and (distance < best_distance - epsilon or (is_equal_approx(distance, best_distance) and area > best_area)):
			best_distance = distance
			best_area = area
			selected_index = index

	return selected_index


static func build_draw_polyline(loop: PackedVector2Array) -> PackedVector2Array:
	var polyline := PackedVector2Array()
	for point in sanitize_loop(loop):
		polyline.append(point)
	if polyline.size() >= 2:
		polyline.append(polyline[0])
	return polyline


static func find_first_boundary_hit(
	current_pos: Vector2,
	next_pos: Vector2,
	loop: PackedVector2Array,
	epsilon: float
) -> Dictionary:
	var sanitized_loop := sanitize_loop(loop)
	if sanitized_loop.size() < 2:
		return {"hit": false}

	var movement := next_pos - current_pos
	if movement.length_squared() <= epsilon * epsilon:
		return {"hit": false}

	var best_hit := {"hit": false}
	var best_t := INF
	for index in range(sanitized_loop.size()):
		var segment_start: Vector2 = sanitized_loop[index]
		var segment_end: Vector2 = sanitized_loop[(index + 1) % sanitized_loop.size()]
		var hit := _intersect_motion_with_axis_segment(current_pos, movement, segment_start, segment_end, epsilon)
		if !bool(hit.get("hit", false)):
			continue

		var t := float(hit.get("t", INF))
		var hit_point: Vector2 = hit.get("point", current_pos)
		if current_pos.distance_to(hit_point) <= epsilon:
			continue
		if t < best_t - epsilon:
			best_t = t
			var inward_normal := _segment_inward_normal(sanitized_loop, segment_start, segment_end, epsilon)
			best_hit = {
				"hit": true,
				"point": hit_point,
				"segment_index": index,
				"distance": current_pos.distance_to(hit["point"]),
				"travel_ratio": t,
				"normal": inward_normal,
				"segment_start": segment_start,
				"segment_end": segment_end
			}

	return best_hit


static func build_inset_loop(
	loop: PackedVector2Array,
	inset: float,
	epsilon: float = DEFAULT_EPSILON
) -> PackedVector2Array:
	var safe_epsilon := maxf(epsilon, DEFAULT_EPSILON)
	var sanitized_loop := _simplify_orthogonal_loop(sanitize_loop(loop), safe_epsilon)
	if sanitized_loop.size() < 3:
		return PackedVector2Array()
	if inset <= safe_epsilon:
		return sanitized_loop

	var shifted_segments: Array[Dictionary] = []
	for index in range(sanitized_loop.size()):
		var segment_start: Vector2 = sanitized_loop[index]
		var segment_end: Vector2 = sanitized_loop[(index + 1) % sanitized_loop.size()]
		if segment_start.distance_to(segment_end) <= safe_epsilon:
			return PackedVector2Array()

		var inward_normal := _segment_inward_normal(sanitized_loop, segment_start, segment_end, safe_epsilon)
		if absf(segment_start.y - segment_end.y) <= safe_epsilon:
			var shifted_y := segment_start.y + inward_normal.y * inset
			shifted_segments.append({
				"horizontal": true,
				"coordinate": shifted_y
			})
		elif absf(segment_start.x - segment_end.x) <= safe_epsilon:
			var shifted_x := segment_start.x + inward_normal.x * inset
			shifted_segments.append({
				"horizontal": false,
				"coordinate": shifted_x
			})
		else:
			return PackedVector2Array()

	var inset_loop := PackedVector2Array()
	for index in range(shifted_segments.size()):
		var previous_segment: Dictionary = shifted_segments[(index - 1 + shifted_segments.size()) % shifted_segments.size()]
		var current_segment: Dictionary = shifted_segments[index]
		var intersection := _intersect_shifted_axis_lines(previous_segment, current_segment)
		if !bool(intersection.get("valid", false)):
			return PackedVector2Array()
		var intersection_point: Vector2 = intersection.get("point", Vector2.ZERO)
		inset_loop.append(intersection_point)

	inset_loop = _simplify_orthogonal_loop(sanitize_loop(inset_loop), safe_epsilon)
	if inset_loop.size() < 3 or polygon_area(inset_loop) <= safe_epsilon:
		return PackedVector2Array()
	if _loop_has_self_intersections(inset_loop, safe_epsilon):
		return PackedVector2Array()

	for index in range(inset_loop.size()):
		var current_point: Vector2 = inset_loop[index]
		var next_point: Vector2 = inset_loop[(index + 1) % inset_loop.size()]
		if !_is_point_inside_or_on_loop(sanitized_loop, current_point, safe_epsilon):
			return PackedVector2Array()
		if !_is_point_inside_or_on_loop(sanitized_loop, current_point.lerp(next_point, 0.5), safe_epsilon):
			return PackedVector2Array()

	return inset_loop


static func can_circle_center_fit(
	loop: PackedVector2Array,
	point: Vector2,
	radius: float,
	epsilon: float
) -> bool:
	var sanitized_loop := sanitize_loop(loop)
	if sanitized_loop.size() < 3:
		return false
	if !_is_point_inside_or_on_loop(sanitized_loop, point, epsilon):
		return false

	var projection := project_point_to_loop(sanitized_loop, point)
	return float(projection.get("distance", INF)) + epsilon >= maxf(radius, 0.0)


static func find_first_boundary_hit_for_circle(
	current_pos: Vector2,
	next_pos: Vector2,
	loop: PackedVector2Array,
	radius: float,
	epsilon: float,
	cached_inset_loop: PackedVector2Array = PackedVector2Array(),
	has_cached_inset_loop: bool = false
) -> Dictionary:
	var sanitized_loop := sanitize_loop(loop)
	var safe_radius := maxf(radius, 0.0)
	if has_cached_inset_loop:
		if cached_inset_loop.size() >= 3:
			return find_first_boundary_hit(current_pos, next_pos, cached_inset_loop, epsilon)
		return _find_first_boundary_hit_for_circle_without_inset(
			current_pos,
			next_pos,
			sanitized_loop,
			safe_radius,
			epsilon
		)
	var inset_loop := build_inset_loop(sanitized_loop, safe_radius, epsilon)
	if inset_loop.size() < 3:
		return _find_first_boundary_hit_for_circle_without_inset(
			current_pos,
			next_pos,
			sanitized_loop,
			safe_radius,
			epsilon
		)
	return find_first_boundary_hit(current_pos, next_pos, inset_loop, epsilon)


static func ensure_point_inside(loop: PackedVector2Array, point: Vector2, epsilon: float) -> Vector2:
	var sanitized_loop := sanitize_loop(loop)
	if sanitized_loop.size() < 3:
		return point
	if Geometry2D.is_point_in_polygon(point, sanitized_loop) and !is_point_on_loop(sanitized_loop, point, epsilon):
		return point

	var metrics := build_loop_metrics(sanitized_loop)
	var projection := project_point_to_loop(sanitized_loop, point, metrics)
	var segment_index := int(projection.get("segment_index", -1))
	if segment_index < 0:
		return point

	var segment_start: Vector2 = sanitized_loop[segment_index]
	var segment_end: Vector2 = sanitized_loop[(segment_index + 1) % sanitized_loop.size()]
	var inward_normal := _segment_inward_normal(sanitized_loop, segment_start, segment_end, epsilon)
	var pushed_point := Vector2(projection.get("point", point)) + inward_normal * maxf(epsilon * 4.0, 2.0)
	if Geometry2D.is_point_in_polygon(pushed_point, sanitized_loop) or is_point_on_loop(sanitized_loop, pushed_point, epsilon):
		return pushed_point

	return Vector2(projection.get("point", point))


static func ensure_circle_center_inside(
	loop: PackedVector2Array,
	point: Vector2,
	radius: float,
	epsilon: float,
	cached_inset_loop: PackedVector2Array = PackedVector2Array(),
	has_cached_inset_loop: bool = false
) -> Vector2:
	var sanitized_loop := sanitize_loop(loop)
	var safe_radius := maxf(radius, 0.0)
	if has_cached_inset_loop:
		if cached_inset_loop.size() >= 3:
			return ensure_point_inside(cached_inset_loop, point, epsilon)
		return _ensure_circle_center_inside_without_inset(
			sanitized_loop,
			point,
			safe_radius,
			epsilon
		)
	var inset_loop := build_inset_loop(sanitized_loop, safe_radius, epsilon)
	if inset_loop.size() < 3:
		return _ensure_circle_center_inside_without_inset(
			sanitized_loop,
			point,
			safe_radius,
			epsilon
		)
	return ensure_point_inside(inset_loop, point, epsilon)


static func sanitize_polyline(points: PackedVector2Array) -> PackedVector2Array:
	var sanitized := PackedVector2Array()
	for point in points:
		if sanitized.is_empty() or !sanitized[sanitized.size() - 1].is_equal_approx(point):
			sanitized.append(point)
	return sanitized


static func wrap_progress(progress: float, total_length: float) -> float:
	if total_length <= DEFAULT_EPSILON:
		return 0.0
	var wrapped := fmod(progress, total_length)
	if wrapped < 0.0:
		wrapped += total_length
	return wrapped


static func build_loop_path_points(
	loop: PackedVector2Array,
	metrics: Dictionary,
	from_point: Vector2,
	to_point: Vector2,
	clockwise: bool
) -> PackedVector2Array:
	var path := PackedVector2Array()
	if loop.size() < 2:
		return path

	var from_projection := project_point_to_loop(loop, from_point, metrics)
	var to_projection := project_point_to_loop(loop, to_point, metrics)
	var snapped_from: Vector2 = from_projection.get("point", from_point)
	var snapped_to: Vector2 = to_projection.get("point", to_point)
	var from_progress := float(from_projection.get("progress", 0.0))
	var to_progress := float(to_projection.get("progress", 0.0))
	var total_length := float(metrics.get("total_length", 0.0))
	var total_distance := travel_distance(total_length, from_progress, to_progress, clockwise)
	if total_distance <= DEFAULT_EPSILON:
		return path

	path.append(snapped_from)

	var corners: Array[Dictionary] = []
	for vertex in _build_vertex_infos(loop, metrics):
		var distance := travel_distance(
			total_length,
			from_progress,
			float(vertex["progress"]),
			clockwise
		)
		if distance > DEFAULT_EPSILON and distance < total_distance - DEFAULT_EPSILON:
			corners.append({
				"distance": distance,
				"point": vertex["point"]
			})

	corners.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["distance"]) < float(b["distance"])
	)

	for corner in corners:
		path.append(corner["point"])

	if path.is_empty() or !path[path.size() - 1].is_equal_approx(snapped_to):
		path.append(snapped_to)
	return sanitize_polyline(path)


static func travel_distance(total_length: float, from_progress: float, to_progress: float, clockwise: bool) -> float:
	if total_length <= DEFAULT_EPSILON:
		return 0.0
	if clockwise:
		return wrap_progress(to_progress - from_progress, total_length)
	return wrap_progress(from_progress - to_progress, total_length)


static func _build_vertex_infos(loop: PackedVector2Array, metrics: Dictionary) -> Array[Dictionary]:
	var infos: Array[Dictionary] = []
	var segment_starts: PackedFloat32Array = metrics.get("segment_starts", PackedFloat32Array())
	for index in range(loop.size()):
		infos.append({
			"progress": float(segment_starts[index]) if index < segment_starts.size() else 0.0,
			"point": loop[index]
		})
	return infos


static func _direction_at_progress(loop: PackedVector2Array, metrics: Dictionary, progress: float) -> Vector2:
	var total_length := float(metrics.get("total_length", 0.0))
	if loop.size() < 2 or total_length <= DEFAULT_EPSILON:
		return Vector2.ZERO

	var wrapped_progress := wrap_progress(progress, total_length)
	var segment_lengths: PackedFloat32Array = metrics.get("segment_lengths", PackedFloat32Array())
	var segment_starts: PackedFloat32Array = metrics.get("segment_starts", PackedFloat32Array())
	for index in range(segment_lengths.size()):
		var segment_length := segment_lengths[index]
		if segment_length <= DEFAULT_EPSILON:
			continue

		var segment_start_progress := segment_starts[index]
		var segment_end_progress := segment_start_progress + segment_length
		var is_last_segment := index == segment_lengths.size() - 1
		if wrapped_progress < segment_end_progress - DEFAULT_EPSILON or is_last_segment:
			return (loop[(index + 1) % loop.size()] - loop[index]).normalized()

	return Vector2.ZERO


static func _find_first_boundary_hit_for_circle_without_inset(
	current_pos: Vector2,
	next_pos: Vector2,
	loop: PackedVector2Array,
	radius: float,
	epsilon: float
) -> Dictionary:
	if loop.size() < 3:
		return {"hit": false}

	var movement := next_pos - current_pos
	if movement.length_squared() <= epsilon * epsilon:
		return {"hit": false}
	if can_circle_center_fit(loop, next_pos, radius, epsilon):
		return {"hit": false}

	var safe_current_pos := current_pos
	if !can_circle_center_fit(loop, safe_current_pos, radius, epsilon):
		safe_current_pos = _ensure_circle_center_inside_without_inset(loop, safe_current_pos, radius, epsilon)
		if !can_circle_center_fit(loop, safe_current_pos, radius, epsilon):
			return {"hit": false}
		movement = next_pos - safe_current_pos
		if movement.length_squared() <= epsilon * epsilon:
			return {"hit": false}

	var low := 0.0
	var high := 1.0
	for _index in range(12):
		var mid := (low + high) * 0.5
		var sample_point := safe_current_pos.lerp(next_pos, mid)
		if can_circle_center_fit(loop, sample_point, radius, epsilon):
			low = mid
		else:
			high = mid

	var hit_point := safe_current_pos.lerp(next_pos, low)
	var blocked_point := safe_current_pos.lerp(next_pos, high)
	var blocking_boundary := _find_circle_blocking_boundary(loop, blocked_point, movement, epsilon)
	var hit_normal := Vector2(blocking_boundary.get("normal", Vector2.ZERO))
	hit_normal = _resolve_circle_hit_normal(loop, blocked_point, radius, movement, epsilon, hit_normal)
	if hit_normal == Vector2.ZERO:
		hit_normal = _fallback_normal_for_motion(movement)

	return {
		"hit": true,
		"point": hit_point,
		"distance": safe_current_pos.distance_to(hit_point),
		"travel_ratio": low,
		"normal": hit_normal,
		"segment_index": int(blocking_boundary.get("segment_index", -1)),
		"segment_start": Vector2(blocking_boundary.get("segment_start", Vector2.ZERO)),
		"segment_end": Vector2(blocking_boundary.get("segment_end", Vector2.ZERO))
	}


static func _ensure_circle_center_inside_without_inset(
	loop: PackedVector2Array,
	point: Vector2,
	radius: float,
	epsilon: float
) -> Vector2:
	if loop.size() < 3:
		return point
	if can_circle_center_fit(loop, point, radius, epsilon):
		return point

	var adjusted_point := ensure_point_inside(loop, point, epsilon)
	for _index in range(6):
		if can_circle_center_fit(loop, adjusted_point, radius, epsilon):
			return adjusted_point

		var blocking_boundary := _find_circle_blocking_boundary(loop, adjusted_point, Vector2.ZERO, epsilon)
		if !bool(blocking_boundary.get("valid", false)):
			return adjusted_point

		var inward_normal := Vector2(blocking_boundary.get("normal", Vector2.ZERO))
		if inward_normal == Vector2.ZERO:
			return adjusted_point

		var boundary_distance := float(blocking_boundary.get("distance", 0.0))
		var push_distance := maxf(radius - boundary_distance, 0.0) + maxf(epsilon * 4.0, 1.0)
		adjusted_point += inward_normal * push_distance
		adjusted_point = ensure_point_inside(loop, adjusted_point, epsilon)

	return adjusted_point


static func _find_circle_blocking_boundary(
	loop: PackedVector2Array,
	point: Vector2,
	movement: Vector2,
	epsilon: float
) -> Dictionary:
	if loop.size() < 2:
		return {"valid": false}

	var movement_direction := movement.normalized()
	var best_distance := INF
	var best_alignment := -INF
	var best_boundary := {"valid": false}
	for index in range(loop.size()):
		var segment_start: Vector2 = loop[index]
		var segment_end: Vector2 = loop[(index + 1) % loop.size()]
		var projected_point := Geometry2D.get_closest_point_to_segment(point, segment_start, segment_end)
		var distance := point.distance_to(projected_point)
		var inward_normal := _segment_inward_normal(loop, segment_start, segment_end, epsilon)
		var alignment := 0.0 if movement_direction == Vector2.ZERO else absf(inward_normal.dot(movement_direction))
		if distance < best_distance - epsilon or (is_equal_approx(distance, best_distance) and alignment > best_alignment):
			best_distance = distance
			best_alignment = alignment
			best_boundary = {
				"valid": true,
				"segment_index": index,
				"point": projected_point,
				"distance": distance,
				"normal": inward_normal,
				"segment_start": segment_start,
				"segment_end": segment_end
			}

	return best_boundary


static func _resolve_circle_hit_normal(
	loop: PackedVector2Array,
	point: Vector2,
	radius: float,
	movement: Vector2,
	epsilon: float,
	fallback_normal: Vector2
) -> Vector2:
	var resolved_normal := fallback_normal
	if resolved_normal.length_squared() > DEFAULT_EPSILON * DEFAULT_EPSILON:
		return resolved_normal.normalized()
	if loop.size() < 2:
		return resolved_normal

	var has_left_blocker := false
	var has_right_blocker := false
	var has_up_blocker := false
	var has_down_blocker := false
	for index in range(loop.size()):
		var segment_start: Vector2 = loop[index]
		var segment_end: Vector2 = loop[(index + 1) % loop.size()]
		var projected_point := Geometry2D.get_closest_point_to_segment(point, segment_start, segment_end)
		if point.distance_to(projected_point) > radius + epsilon:
			continue

		var inward_normal := _segment_inward_normal(loop, segment_start, segment_end, epsilon)
		if absf(inward_normal.x) > 0.5:
			has_left_blocker = has_left_blocker or inward_normal.x < 0.0
			has_right_blocker = has_right_blocker or inward_normal.x > 0.0
		elif absf(inward_normal.y) > 0.5:
			has_up_blocker = has_up_blocker or inward_normal.y < 0.0
			has_down_blocker = has_down_blocker or inward_normal.y > 0.0

	var horizontal_entry_score := absf(movement.x) if has_up_blocker and has_down_blocker else -1.0
	var vertical_entry_score := absf(movement.y) if has_left_blocker and has_right_blocker else -1.0
	if horizontal_entry_score >= vertical_entry_score and horizontal_entry_score > epsilon:
		return Vector2.RIGHT if movement.x >= 0.0 else Vector2.LEFT
	if vertical_entry_score > epsilon:
		return Vector2.DOWN if movement.y >= 0.0 else Vector2.UP
	return resolved_normal


static func _fallback_normal_for_motion(movement: Vector2) -> Vector2:
	if absf(movement.x) >= absf(movement.y):
		if movement.x > DEFAULT_EPSILON:
			return Vector2.RIGHT
		if movement.x < -DEFAULT_EPSILON:
			return Vector2.LEFT
	if movement.y > DEFAULT_EPSILON:
		return Vector2.DOWN
	if movement.y < -DEFAULT_EPSILON:
		return Vector2.UP
	return Vector2.RIGHT


static func _intersect_motion_with_axis_segment(
	current_pos: Vector2,
	movement: Vector2,
	segment_start: Vector2,
	segment_end: Vector2,
	epsilon: float
) -> Dictionary:
	var segment_min_x := minf(segment_start.x, segment_end.x) - epsilon
	var segment_max_x := maxf(segment_start.x, segment_end.x) + epsilon
	var segment_min_y := minf(segment_start.y, segment_end.y) - epsilon
	var segment_max_y := maxf(segment_start.y, segment_end.y) + epsilon

	if absf(segment_start.y - segment_end.y) <= epsilon:
		if absf(movement.y) <= epsilon:
			return {"hit": false}
		var t_horizontal := (segment_start.y - current_pos.y) / movement.y
		if t_horizontal < -DEFAULT_EPSILON or t_horizontal > 1.0 + DEFAULT_EPSILON:
			return {"hit": false}
		var x_at_hit := current_pos.x + movement.x * t_horizontal
		if x_at_hit < segment_min_x or x_at_hit > segment_max_x:
			return {"hit": false}
		return {
			"hit": true,
			"t": clampf(t_horizontal, 0.0, 1.0),
			"point": Vector2(x_at_hit, segment_start.y)
		}

	if absf(segment_start.x - segment_end.x) <= epsilon:
		if absf(movement.x) <= epsilon:
			return {"hit": false}
		var t_vertical := (segment_start.x - current_pos.x) / movement.x
		if t_vertical < -DEFAULT_EPSILON or t_vertical > 1.0 + DEFAULT_EPSILON:
			return {"hit": false}
		var y_at_hit := current_pos.y + movement.y * t_vertical
		if y_at_hit < segment_min_y or y_at_hit > segment_max_y:
			return {"hit": false}
		return {
			"hit": true,
			"t": clampf(t_vertical, 0.0, 1.0),
			"point": Vector2(segment_start.x, y_at_hit)
		}

	return {"hit": false}


static func _segment_inward_normal(
	loop: PackedVector2Array,
	segment_start: Vector2,
	segment_end: Vector2,
	epsilon: float
) -> Vector2:
	var axis_direction := (segment_end - segment_start).normalized()
	var normal_a := Vector2(-axis_direction.y, axis_direction.x)
	if normal_a == Vector2.ZERO:
		normal_a = Vector2.RIGHT
	var midpoint := segment_start.lerp(segment_end, 0.5)
	var sample_distance := maxf(epsilon * 4.0, 2.0)
	var sample_a := midpoint + normal_a * sample_distance
	if Geometry2D.is_point_in_polygon(sample_a, loop) or is_point_on_loop(loop, sample_a, epsilon):
		return normal_a
	return -normal_a


static func _simplify_orthogonal_loop(loop: PackedVector2Array, epsilon: float) -> PackedVector2Array:
	var simplified := sanitize_loop(loop)
	if simplified.size() < 3:
		return simplified

	var changed := true
	while changed and simplified.size() >= 3:
		changed = false
		var next_loop := PackedVector2Array()
		for index in range(simplified.size()):
			var previous_point: Vector2 = simplified[(index - 1 + simplified.size()) % simplified.size()]
			var current_point: Vector2 = simplified[index]
			var next_point: Vector2 = simplified[(index + 1) % simplified.size()]
			if _points_are_axis_collinear(previous_point, current_point, next_point, epsilon):
				changed = true
				continue
			next_loop.append(current_point)
		simplified = sanitize_loop(next_loop)

	return simplified


static func _points_are_axis_collinear(previous_point: Vector2, current_point: Vector2, next_point: Vector2, epsilon: float) -> bool:
	return (
		(absf(previous_point.x - current_point.x) <= epsilon and absf(current_point.x - next_point.x) <= epsilon)
		or (absf(previous_point.y - current_point.y) <= epsilon and absf(current_point.y - next_point.y) <= epsilon)
	)


static func _intersect_shifted_axis_lines(previous_segment: Dictionary, current_segment: Dictionary) -> Dictionary:
	var previous_horizontal := bool(previous_segment.get("horizontal", false))
	var current_horizontal := bool(current_segment.get("horizontal", false))
	if previous_horizontal == current_horizontal:
		return {"valid": false}

	if previous_horizontal:
		return {
			"valid": true,
			"point": Vector2(
				float(current_segment.get("coordinate", 0.0)),
				float(previous_segment.get("coordinate", 0.0))
			)
		}

	return {
		"valid": true,
		"point": Vector2(
			float(previous_segment.get("coordinate", 0.0)),
			float(current_segment.get("coordinate", 0.0))
		)
	}


static func _is_point_inside_or_on_loop(loop: PackedVector2Array, point: Vector2, epsilon: float) -> bool:
	return Geometry2D.is_point_in_polygon(point, loop) or is_point_on_loop(loop, point, epsilon)


static func _loop_has_self_intersections(loop: PackedVector2Array, epsilon: float) -> bool:
	if loop.size() < 4:
		return false

	for index in range(loop.size()):
		var a_start: Vector2 = loop[index]
		var a_end: Vector2 = loop[(index + 1) % loop.size()]
		for other_index in range(index + 1, loop.size()):
			if other_index == index:
				continue
			if other_index == (index + 1) % loop.size():
				continue
			if index == 0 and other_index == loop.size() - 1:
				continue

			var b_start: Vector2 = loop[other_index]
			var b_end: Vector2 = loop[(other_index + 1) % loop.size()]
			if _segments_intersect_or_overlap(a_start, a_end, b_start, b_end, epsilon):
				return true

	return false


static func _segments_intersect_or_overlap(
	a_start: Vector2,
	a_end: Vector2,
	b_start: Vector2,
	b_end: Vector2,
	epsilon: float
) -> bool:
	var a_horizontal := absf(a_start.y - a_end.y) <= epsilon
	var b_horizontal := absf(b_start.y - b_end.y) <= epsilon
	if a_horizontal and b_horizontal:
		if absf(a_start.y - b_start.y) > epsilon:
			return false
		var overlap_start_x := maxf(minf(a_start.x, a_end.x), minf(b_start.x, b_end.x))
		var overlap_end_x := minf(maxf(a_start.x, a_end.x), maxf(b_start.x, b_end.x))
		return overlap_end_x - overlap_start_x > epsilon

	if !a_horizontal and !b_horizontal:
		if absf(a_start.x - b_start.x) > epsilon:
			return false
		var overlap_start_y := maxf(minf(a_start.y, a_end.y), minf(b_start.y, b_end.y))
		var overlap_end_y := minf(maxf(a_start.y, a_end.y), maxf(b_start.y, b_end.y))
		return overlap_end_y - overlap_start_y > epsilon

	var horizontal_start: Vector2 = a_start if a_horizontal else b_start
	var horizontal_end: Vector2 = a_end if a_horizontal else b_end
	var vertical_start: Vector2 = b_start if a_horizontal else a_start
	var vertical_end: Vector2 = b_end if a_horizontal else a_end
	var horizontal_min_x := minf(horizontal_start.x, horizontal_end.x) - epsilon
	var horizontal_max_x := maxf(horizontal_start.x, horizontal_end.x) + epsilon
	var vertical_min_y := minf(vertical_start.y, vertical_end.y) - epsilon
	var vertical_max_y := maxf(vertical_start.y, vertical_end.y) + epsilon
	return (
		vertical_start.x >= horizontal_min_x
		and vertical_start.x <= horizontal_max_x
		and horizontal_start.y >= vertical_min_y
		and horizontal_start.y <= vertical_max_y
	)
