extends RefCounted
class_name VerifyShared

const PlayfieldBoundary = preload("res://scripts/game/playfield_boundary.gd")
const EPSILON := 2.0


static func assert_condition(condition: bool, message: String, failures: Array[String]) -> void:
	if !condition:
		failures.append(message)


static func assert_player_corner_preinput(
	player,
	loop: PackedVector2Array,
	label: String,
	failures: Array[String]
) -> void:
	for vertex_index in range(loop.size()):
		assert_condition(
			move_player_into_corner_with_preinput(player, loop, vertex_index, true),
			"%s queued corner input failed at vertex %d in the clockwise direction." % [label, vertex_index],
			failures
		)
		assert_condition(
			move_player_into_corner_with_preinput(player, loop, vertex_index, false),
			"%s queued corner input failed at vertex %d in the counterclockwise direction." % [label, vertex_index],
			failures
		)


static func assert_player_corner_input_priority(
	player,
	loop: PackedVector2Array,
	label: String,
	failures: Array[String]
) -> void:
	var fallback_checked := false
	for vertex_index in range(loop.size()):
		assert_condition(
			latest_input_overrides_queued_corner(player, loop, vertex_index, true),
			"%s latest input did not override the queued corner turn at vertex %d in the clockwise direction." % [label, vertex_index],
			failures
		)
		assert_condition(
			latest_input_overrides_queued_corner(player, loop, vertex_index, false),
			"%s latest input did not override the queued corner turn at vertex %d in the counterclockwise direction." % [label, vertex_index],
			failures
		)
		if !fallback_checked:
			fallback_checked = queued_corner_fallback_applies(player, loop, vertex_index, true)
		if !fallback_checked:
			fallback_checked = queued_corner_fallback_applies(player, loop, vertex_index, false)

	assert_condition(fallback_checked, "%s queued fallback did not resolve a valid corner case." % label, failures)


static func move_player_into_corner_with_preinput(
	player,
	loop: PackedVector2Array,
	vertex_index: int,
	clockwise: bool
) -> bool:
	var connected := PlayfieldBoundary.get_vertex_connected_segment_indices(loop, vertex_index)
	var approach_segment_index := (
		int(connected.get("previous", -1))
		if clockwise
		else int(connected.get("next", -1))
	)
	var expected_segment_index := (
		int(connected.get("next", -1))
		if clockwise
		else int(connected.get("previous", -1))
	)
	if approach_segment_index < 0 or expected_segment_index < 0:
		return false

	var segment_length := PlayfieldBoundary.get_segment_length(loop, approach_segment_index, player.outer_loop_metrics)
	if segment_length <= EPSILON:
		return false

	var threshold := float(player._get_border_queue_distance_threshold(segment_length))
	var approach_distance := clampf(threshold * 0.75, 1.0, segment_length)
	var segment_direction := PlayfieldBoundary.get_segment_direction(loop, approach_segment_index, EPSILON)
	var movement_direction := segment_direction if clockwise else -segment_direction
	var turn_direction := (
		PlayfieldBoundary.get_segment_direction(loop, expected_segment_index, EPSILON)
		if clockwise
		else -PlayfieldBoundary.get_segment_direction(loop, expected_segment_index, EPSILON)
	)
	if movement_direction == Vector2.ZERO or turn_direction == Vector2.ZERO:
		return false

	var input_direction := (movement_direction + turn_direction).normalized()
	var input_alignment := maxf(0.1, input_direction.dot(movement_direction))
	var distance_on_segment := (
		maxf(0.0, segment_length - approach_distance)
		if clockwise
		else minf(segment_length, approach_distance)
	)
	var distance_to_vertex := (
		maxf(0.0, segment_length - distance_on_segment)
		if clockwise
		else maxf(0.0, distance_on_segment)
	)
	player.state = player.PlayerState.BORDER
	player.current_border_segment_index = approach_segment_index
	player.border_distance_on_segment = distance_on_segment
	player.position = PlayfieldBoundary.point_at_segment_distance(
		loop,
		approach_segment_index,
		distance_on_segment,
		player.outer_loop_metrics
	)
	player.border_progress = player._border_state_to_progress()
	player.queued_border_segment_index = -1
	player.queued_border_vertex_index = -1
	player.queued_border_distance_on_segment = 0.0

	var delta := (distance_to_vertex + maxf(EPSILON, 1.0)) / maxf(player.move_speed * input_alignment, 1.0)
	player._move_along_border(input_direction, delta)

	return (
		player.current_border_segment_index == expected_segment_index
		and PlayfieldBoundary.is_point_on_loop(loop, player.position, EPSILON)
		and player.debug_is_border_state_consistent()
	)


static func latest_input_overrides_queued_corner(
	player,
	loop: PackedVector2Array,
	vertex_index: int,
	clockwise: bool
) -> bool:
	var prepared := prepare_corner_queue_state(player, loop, vertex_index, clockwise)
	if !bool(prepared.get("ready", false)):
		return false

	var latest_direction: Vector2 = -Vector2(prepared.get("movement_direction", Vector2.ZERO))
	var selection: Dictionary = player._select_border_segment_at_vertex(vertex_index, latest_direction)
	if !bool(selection.get("matched", false)):
		return false
	if int(selection.get("segment_index", -1)) != int(prepared.get("approach_segment_index", -1)):
		return false

	player._apply_selected_border_segment(selection)
	player.position = player._border_state_to_point()
	player.border_progress = player._border_state_to_progress()
	return player.queued_border_vertex_index < 0 and player.debug_is_border_state_consistent()


static func queued_corner_fallback_applies(
	player,
	loop: PackedVector2Array,
	vertex_index: int,
	clockwise: bool
) -> bool:
	var prepared := prepare_corner_queue_state(player, loop, vertex_index, clockwise)
	if !bool(prepared.get("ready", false)):
		return false

	var latest_direction: Vector2 = Vector2(prepared.get("movement_direction", Vector2.ZERO))
	var selection: Dictionary = player._select_border_segment_at_vertex(vertex_index, latest_direction)
	if !bool(selection.get("matched", false)):
		return false
	if int(selection.get("segment_index", -1)) != int(prepared.get("expected_segment_index", -1)):
		return false

	player._apply_selected_border_segment(selection)
	player.position = player._border_state_to_point()
	player.border_progress = player._border_state_to_progress()
	return player.queued_border_vertex_index < 0 and player.debug_is_border_state_consistent()


static func prepare_corner_queue_state(
	player,
	loop: PackedVector2Array,
	vertex_index: int,
	clockwise: bool
) -> Dictionary:
	var connected := PlayfieldBoundary.get_vertex_connected_segment_indices(loop, vertex_index)
	var approach_segment_index := (
		int(connected.get("previous", -1))
		if clockwise
		else int(connected.get("next", -1))
	)
	var expected_segment_index := (
		int(connected.get("next", -1))
		if clockwise
		else int(connected.get("previous", -1))
	)
	if approach_segment_index < 0 or expected_segment_index < 0:
		return {"ready": false}

	var segment_length := PlayfieldBoundary.get_segment_length(loop, approach_segment_index, player.outer_loop_metrics)
	if segment_length <= EPSILON:
		return {"ready": false}

	var threshold := float(player._get_border_queue_distance_threshold(segment_length))
	var approach_distance := clampf(threshold * 0.75, 1.0, segment_length)
	var segment_direction := PlayfieldBoundary.get_segment_direction(loop, approach_segment_index, EPSILON)
	var movement_direction := segment_direction if clockwise else -segment_direction
	var turn_direction := (
		PlayfieldBoundary.get_segment_direction(loop, expected_segment_index, EPSILON)
		if clockwise
		else -PlayfieldBoundary.get_segment_direction(loop, expected_segment_index, EPSILON)
	)
	if movement_direction == Vector2.ZERO or turn_direction == Vector2.ZERO:
		return {"ready": false}

	var distance_on_segment := (
		maxf(0.0, segment_length - approach_distance)
		if clockwise
		else minf(segment_length, approach_distance)
	)
	player.state = player.PlayerState.BORDER
	player.current_border_segment_index = approach_segment_index
	player.border_distance_on_segment = distance_on_segment
	player.position = PlayfieldBoundary.point_at_segment_distance(
		loop,
		approach_segment_index,
		distance_on_segment,
		player.outer_loop_metrics
	)
	player.border_progress = player._border_state_to_progress()
	player.queued_border_segment_index = -1
	player.queued_border_vertex_index = -1
	player.queued_border_distance_on_segment = 0.0

	var safe_epsilon := maxf(player.border_epsilon, PlayfieldBoundary.DEFAULT_EPSILON)
	player._update_queued_border_transition((movement_direction + turn_direction).normalized(), 1.0 if clockwise else -1.0, safe_epsilon)
	if player.queued_border_vertex_index != vertex_index:
		return {"ready": false}
	if player.queued_border_segment_index != expected_segment_index:
		return {"ready": false}

	player.border_distance_on_segment = segment_length if clockwise else 0.0
	player.position = loop[vertex_index]
	player.border_progress = player._border_state_to_progress()
	return {
		"ready": true,
		"approach_segment_index": approach_segment_index,
		"expected_segment_index": expected_segment_index,
		"movement_direction": movement_direction
	}


static func assert_draw_start_safety(
	player,
	loop: PackedVector2Array,
	interior_point: Vector2,
	label: String,
	failures: Array[String],
	require_non_border_point := false
) -> void:
	var safe_interior_point := PlayfieldBoundary.ensure_point_inside(loop, interior_point, EPSILON)
	if PlayfieldBoundary.is_point_on_loop(loop, safe_interior_point, EPSILON):
		if require_non_border_point:
			failures.append("%s could not build a non-border draw-start test point." % label)
		return

	player.state = player.PlayerState.BORDER
	player.position = safe_interior_point
	assert_condition(
		!player.debug_can_start_drawing_from_border(),
		"%s draw start accepted a non-border point while in BORDER state." % label,
		failures
	)


static func get_bbos_reflection_loop(bbos, fallback_outer_loop: PackedVector2Array) -> PackedVector2Array:
	if is_instance_valid(bbos) and bbos.has_method("get_active_reflection_loop"):
		var reflection_loop: PackedVector2Array = bbos.call("get_active_reflection_loop")
		if reflection_loop.size() >= 3:
			return reflection_loop
	return fallback_outer_loop


static func find_test_segment(
	loop: PackedVector2Array,
	reference_loop: PackedVector2Array,
	rect: Rect2,
	require_internal_segment: bool
) -> Dictionary:
	for index in range(loop.size()):
		var segment_start: Vector2 = loop[index]
		var segment_end: Vector2 = loop[(index + 1) % loop.size()]
		if segment_start.distance_to(segment_end) <= 8.0:
			continue

		var midpoint := segment_start.lerp(segment_end, 0.5)
		var reference_point := midpoint
		if reference_loop.size() >= 3:
			reference_point = Vector2(PlayfieldBoundary.project_point_to_loop(reference_loop, midpoint).get("point", midpoint))
		var is_internal := (
			absf(reference_point.x - rect.position.x) > EPSILON
			and absf(reference_point.x - rect.end.x) > EPSILON
			and absf(reference_point.y - rect.position.y) > EPSILON
			and absf(reference_point.y - rect.end.y) > EPSILON
		)
		if require_internal_segment and !is_internal:
			continue

		var tangent := (segment_end - segment_start).normalized()
		var normal_a := Vector2(-tangent.y, tangent.x)
		var inward_normal := normal_a
		var sample_a := midpoint + normal_a * 18.0
		var sample_b := midpoint - normal_a * 18.0
		var sample_a_inside := Geometry2D.is_point_in_polygon(sample_a, loop) or PlayfieldBoundary.is_point_on_loop(loop, sample_a, EPSILON)
		var sample_b_inside := Geometry2D.is_point_in_polygon(sample_b, loop) or PlayfieldBoundary.is_point_on_loop(loop, sample_b, EPSILON)
		if !sample_a_inside and sample_b_inside:
			inward_normal = -normal_a

		return {
			"midpoint": midpoint,
			"inward_normal": inward_normal,
			"tangent": tangent
		}
	return {}


static func build_collision_case(
	loop: PackedVector2Array,
	segment: Dictionary,
	speed: float,
	epsilon: float
) -> Dictionary:
	var midpoint: Vector2 = segment["midpoint"]
	var tangent: Vector2 = segment["tangent"]
	var base_normal := Vector2(-tangent.y, tangent.x)

	for direction_sign in [1.0, -1.0]:
		var inward_candidate: Vector2 = base_normal * direction_sign
		var start: Vector2 = midpoint + inward_candidate * 12.0
		if !Geometry2D.is_point_in_polygon(start, loop) and !PlayfieldBoundary.is_point_on_loop(loop, start, EPSILON):
			continue

		for tangent_scale in [0.0, 0.25, -0.25]:
			var velocity: Vector2 = (-inward_candidate + tangent * tangent_scale).normalized() * speed
			var hit := PlayfieldBoundary.find_first_boundary_hit(
				start,
				start + velocity * 0.35,
				loop,
				maxf(epsilon, 0.001)
			)
			if !bool(hit.get("hit", false)):
				continue

			return {
				"start": start,
				"velocity": velocity,
				"hit_normal": hit["normal"]
			}

	return {}
