extends SceneTree

const MAIN_SCENE = preload("res://scenes/base_main.tscn")
const PlayfieldBoundary = preload("res://scripts/game/playfield_boundary.gd")
const EPSILON := 2.0


func _initialize() -> void:
	var failures: Array[String] = []
	var main = MAIN_SCENE.instantiate()
	root.add_child(main)
	await process_frame

	_verify_initial_state(main, failures)

	var rect: Rect2 = main.playfield_rect
	var first_cut_x := rect.position.x + rect.size.x * 0.62
	var first_cut_y := rect.position.y + rect.size.y * 0.55
	var first_trail := PackedVector2Array([
		Vector2(first_cut_x, rect.position.y),
		Vector2(first_cut_x, first_cut_y),
		Vector2(rect.end.x, first_cut_y)
	])
	main.bbos.position = Vector2(rect.position.x + 48.0, rect.position.y + 48.0)
	main._on_player_capture_closed(first_trail)
	await process_frame
	_verify_captured_state(main, rect, "first L capture", true, failures)

	var second_start_y := first_cut_y + (rect.end.y - first_cut_y) * 0.35
	var second_end_x := first_cut_x + (rect.end.x - first_cut_x) * 0.28
	var second_trail := PackedVector2Array([
		Vector2(rect.position.x, second_start_y),
		Vector2(second_end_x, second_start_y),
		Vector2(second_end_x, first_cut_y)
	])
	main.bbos.position = Vector2(rect.position.x + 48.0, rect.position.y + 48.0)
	main._on_player_capture_closed(second_trail)
	await process_frame
	_verify_captured_state(main, rect, "second jagged capture", true, failures)

	if failures.is_empty():
		print("Outer loop verification passed for initial, L, and jagged states.")
		quit(0)
		return

	for failure in failures:
		printerr(failure)
	quit(1)


func _verify_initial_state(main, failures: Array[String]) -> void:
	var expected_loop := PlayfieldBoundary.create_rect_loop(main.playfield_rect)
	_assert(_loops_match(main.current_outer_loop, expected_loop), "Initial loop does not match the playfield rectangle.", failures)
	_assert_player_border_motion(main.base_player, main.current_outer_loop, main.playfield_rect, "initial rectangle", failures)
	_assert_player_corner_preinput(main.base_player, main.current_outer_loop, "initial rectangle", failures)
	_assert_player_corner_input_priority(main.base_player, main.current_outer_loop, "initial rectangle", failures)
	_assert_draw_start_safety(main.base_player, main.current_outer_loop, main.playfield_rect.get_center(), "initial rectangle", failures)
	_assert_bbos_reflection(main.bbos, main.current_outer_loop, main.playfield_rect, "initial rectangle", false, failures)


func _verify_captured_state(main, rect: Rect2, label: String, require_internal_segment: bool, failures: Array[String]) -> void:
	_assert(main.current_outer_loop.size() >= 6, "%s did not produce a non-rect outer loop." % label, failures)
	_assert(PlayfieldBoundary.polygon_area(main.current_outer_loop) > EPSILON, "%s outer loop area is empty." % label, failures)
	_assert_player_border_motion(main.base_player, main.current_outer_loop, rect, label, failures)
	_assert_player_corner_preinput(main.base_player, main.current_outer_loop, label, failures)
	_assert_player_corner_input_priority(main.base_player, main.current_outer_loop, label, failures)
	_assert_draw_start_safety(main.base_player, main.current_outer_loop, main.bbos.position, label, failures)
	_assert_bbos_reflection(main.bbos, main.current_outer_loop, rect, label, require_internal_segment, failures)


func _assert_player_border_motion(player, loop: PackedVector2Array, rect: Rect2, label: String, failures: Array[String]) -> void:
	_assert(player.debug_is_border_state_consistent(), "%s player border state was inconsistent after sync." % label, failures)
	var vertex_index := _find_internal_vertex_index(loop, rect)
	if vertex_index < 0:
		vertex_index = 0
	var vertex: Vector2 = loop[vertex_index]
	var progress: float = player._point_to_border_progress(vertex)
	var cw_input := PlayfieldBoundary.tangent_at_progress(loop, player.outer_loop_metrics, progress, true)
	var ccw_input := PlayfieldBoundary.tangent_at_progress(loop, player.outer_loop_metrics, progress, false)
	var moved_cw := _move_player_from_vertex(player, loop, vertex, progress, cw_input)
	var moved_ccw := _move_player_from_vertex(player, loop, vertex, progress, ccw_input)

	_assert(moved_cw, "%s player movement stalled on the outer loop vertex in the clockwise direction." % label, failures)
	_assert(moved_ccw, "%s player movement stalled on the outer loop vertex in the counterclockwise direction." % label, failures)
	_assert(PlayfieldBoundary.is_point_on_loop(loop, player.position, EPSILON), "%s player left the outer loop during border travel." % label, failures)
	_assert(player.debug_is_border_state_consistent(), "%s player border state drifted during border travel." % label, failures)


func _move_player_from_vertex(player, loop: PackedVector2Array, vertex: Vector2, progress: float, direction: Vector2) -> bool:
	if direction == Vector2.ZERO:
		return false
	player.state = player.PlayerState.BORDER
	player._sync_border_state_from_position(vertex)
	player.border_progress = progress
	var before: Vector2 = player.position
	player._move_along_border(direction, 0.25)
	return before.distance_to(player.position) > 1.0 and PlayfieldBoundary.is_point_on_loop(loop, player.position, EPSILON)


func _assert_player_corner_preinput(player, loop: PackedVector2Array, label: String, failures: Array[String]) -> void:
	for vertex_index in range(loop.size()):
		_assert(
			_move_player_into_corner_with_preinput(player, loop, vertex_index, true),
			"%s queued corner input failed at vertex %d in the clockwise direction." % [label, vertex_index],
			failures
		)
		_assert(
			_move_player_into_corner_with_preinput(player, loop, vertex_index, false),
			"%s queued corner input failed at vertex %d in the counterclockwise direction." % [label, vertex_index],
			failures
		)


func _assert_player_corner_input_priority(player, loop: PackedVector2Array, label: String, failures: Array[String]) -> void:
	var fallback_checked := false
	for vertex_index in range(loop.size()):
		_assert(
			_latest_input_overrides_queued_corner(player, loop, vertex_index, true),
			"%s latest input did not override the queued corner turn at vertex %d in the clockwise direction." % [label, vertex_index],
			failures
		)
		_assert(
			_latest_input_overrides_queued_corner(player, loop, vertex_index, false),
			"%s latest input did not override the queued corner turn at vertex %d in the counterclockwise direction." % [label, vertex_index],
			failures
		)
		if !fallback_checked:
			fallback_checked = _queued_corner_fallback_applies(player, loop, vertex_index, true)
		if !fallback_checked:
			fallback_checked = _queued_corner_fallback_applies(player, loop, vertex_index, false)

	_assert(fallback_checked, "%s queued fallback did not resolve a valid corner case." % label, failures)


func _move_player_into_corner_with_preinput(
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


func _latest_input_overrides_queued_corner(
	player,
	loop: PackedVector2Array,
	vertex_index: int,
	clockwise: bool
) -> bool:
	var prepared := _prepare_corner_queue_state(player, loop, vertex_index, clockwise)
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


func _queued_corner_fallback_applies(
	player,
	loop: PackedVector2Array,
	vertex_index: int,
	clockwise: bool
) -> bool:
	var prepared := _prepare_corner_queue_state(player, loop, vertex_index, clockwise)
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


func _prepare_corner_queue_state(
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


func _assert_draw_start_safety(
	player,
	loop: PackedVector2Array,
	interior_point: Vector2,
	label: String,
	failures: Array[String]
) -> void:
	var safe_interior_point := PlayfieldBoundary.ensure_point_inside(loop, interior_point, EPSILON)
	if PlayfieldBoundary.is_point_on_loop(loop, safe_interior_point, EPSILON):
		return

	player.state = player.PlayerState.BORDER
	player.position = safe_interior_point
	_assert(
		!player.debug_can_start_drawing_from_border(),
		"%s draw start accepted a non-border point while in BORDER state." % label,
		failures
	)


func _assert_bbos_reflection(
	bbos,
	loop: PackedVector2Array,
	rect: Rect2,
	label: String,
	require_internal_segment: bool,
	failures: Array[String]
) -> void:
	var segment := _find_test_segment(loop, rect, require_internal_segment)
	_assert(!segment.is_empty(), "%s did not expose a usable boundary segment for reflection testing." % label, failures)
	if segment.is_empty():
		return

	var collision_case := _build_collision_case(loop, segment, bbos.move_speed, bbos.bounce_epsilon)
	_assert(!collision_case.is_empty(), "%s could not build a deterministic BBOS collision case." % label, failures)
	if collision_case.is_empty():
		return

	var inward_normal: Vector2 = collision_case["hit_normal"]
	bbos.position = collision_case["start"]
	bbos.velocity = collision_case["velocity"]
	bbos.direction_change_timer = 999.0
	var before_dot: float = bbos.velocity.dot(inward_normal)
	var expected_reflection: Vector2 = bbos._reflect_velocity(bbos.velocity, inward_normal)
	var direct_hit := PlayfieldBoundary.find_first_boundary_hit(
		bbos.position,
		bbos.position + bbos.velocity * 0.35,
		bbos.active_outer_loop,
		maxf(bbos.bounce_epsilon, 0.001)
	)
	bbos._process(0.35)

	var inside_after := Geometry2D.is_point_in_polygon(bbos.position, loop) or PlayfieldBoundary.is_point_on_loop(loop, bbos.position, EPSILON)
	_assert(inside_after, "%s BBOS moved outside the retained outer loop." % label, failures)
	_assert(
		bbos.velocity.dot(inward_normal) > 0.0,
		"%s BBOS velocity did not reflect back toward the interior. before=%s after=%s pos=%s expected=%s direct_hit=%s" % [
			label,
			str(before_dot),
			str(bbos.velocity.dot(inward_normal)),
			str(bbos.position),
			str(expected_reflection),
			str(direct_hit)
		],
		failures
	)


func _find_test_segment(loop: PackedVector2Array, rect: Rect2, require_internal_segment: bool) -> Dictionary:
	for index in range(loop.size()):
		var segment_start: Vector2 = loop[index]
		var segment_end: Vector2 = loop[(index + 1) % loop.size()]
		if segment_start.distance_to(segment_end) <= 8.0:
			continue

		var midpoint := segment_start.lerp(segment_end, 0.5)
		var is_internal := (
			absf(midpoint.x - rect.position.x) > EPSILON
			and absf(midpoint.x - rect.end.x) > EPSILON
			and absf(midpoint.y - rect.position.y) > EPSILON
			and absf(midpoint.y - rect.end.y) > EPSILON
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


func _build_collision_case(loop: PackedVector2Array, segment: Dictionary, speed: float, epsilon: float) -> Dictionary:
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


func _find_internal_vertex_index(loop: PackedVector2Array, rect: Rect2) -> int:
	for index in range(loop.size()):
		var point: Vector2 = loop[index]
		var on_left_or_right := absf(point.x - rect.position.x) <= EPSILON or absf(point.x - rect.end.x) <= EPSILON
		var on_top_or_bottom := absf(point.y - rect.position.y) <= EPSILON or absf(point.y - rect.end.y) <= EPSILON
		if !(on_left_or_right and on_top_or_bottom):
			return index
	return -1


func _loops_match(a: PackedVector2Array, b: PackedVector2Array) -> bool:
	if a.size() != b.size():
		return false
	for index in range(a.size()):
		if a[index].distance_to(b[index]) > EPSILON:
			return false
	return true


func _assert(condition: bool, message: String, failures: Array[String]) -> void:
	if !condition:
		failures.append(message)
