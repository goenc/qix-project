extends SceneTree

const MAIN_SCENE = preload("res://scenes/base_main.tscn")
const PlayfieldBoundary = preload("res://scripts/game/playfield_boundary.gd")
const EPSILON := 2.0


func _initialize() -> void:
	var failures: Array[String] = []
	var main = MAIN_SCENE.instantiate()
	root.add_child(main)
	await process_frame

	_verify_state(main.base_player, main.current_outer_loop, main.playfield_rect.get_center(), "initial rectangle", failures)

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
	_verify_state(main.base_player, main.current_outer_loop, main.bbos.position, "first L capture", failures)

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
	_verify_state(main.base_player, main.current_outer_loop, main.bbos.position, "second jagged capture", failures)

	if failures.is_empty():
		print("Player border verification passed for initial, L, and jagged states.")
		quit(0)
		return

	for failure in failures:
		printerr(failure)
	quit(1)


func _verify_state(player, loop: PackedVector2Array, interior_point: Vector2, label: String, failures: Array[String]) -> void:
	_assert(loop.size() >= 4, "%s loop is not ready for player verification." % label, failures)
	_assert(player.debug_is_border_state_consistent(), "%s player border state was inconsistent after sync." % label, failures)
	_assert_player_border_motion(player, loop, label, failures)
	_assert_player_corner_preinput(player, loop, label, failures)
	_assert_draw_start_safety(player, loop, interior_point, label, failures)


func _assert_player_border_motion(player, loop: PackedVector2Array, label: String, failures: Array[String]) -> void:
	for vertex_index in range(loop.size()):
		var vertex: Vector2 = loop[vertex_index]
		var clockwise_direction: Vector2 = Vector2(PlayfieldBoundary.choose_segment_at_vertex(
			loop,
			vertex_index,
			PlayfieldBoundary.get_segment_direction(loop, vertex_index, EPSILON),
			int(PlayfieldBoundary.get_vertex_connected_segment_indices(loop, vertex_index).get("previous", -1)),
			EPSILON,
			player.outer_loop_metrics
		).get("direction", Vector2.ZERO))
		var counterclockwise_direction: Vector2 = Vector2(PlayfieldBoundary.choose_segment_at_vertex(
			loop,
			vertex_index,
			-PlayfieldBoundary.get_segment_direction(loop, int(PlayfieldBoundary.get_vertex_connected_segment_indices(loop, vertex_index).get("previous", -1)), EPSILON),
			int(PlayfieldBoundary.get_vertex_connected_segment_indices(loop, vertex_index).get("next", -1)),
			EPSILON,
			player.outer_loop_metrics
		).get("direction", Vector2.ZERO))
		_assert(
			_move_player_from_vertex(player, loop, vertex, clockwise_direction),
			"%s player movement stalled at vertex %d in the clockwise direction." % [label, vertex_index],
			failures
		)
		_assert(
			_move_player_from_vertex(player, loop, vertex, counterclockwise_direction),
			"%s player movement stalled at vertex %d in the counterclockwise direction." % [label, vertex_index],
			failures
		)


func _move_player_from_vertex(player, loop: PackedVector2Array, vertex: Vector2, direction: Vector2) -> bool:
	if direction == Vector2.ZERO:
		return false
	player.state = player.PlayerState.BORDER
	player._sync_border_state_from_position(vertex)
	var before: Vector2 = player.position
	player._move_along_border(direction, 0.25)
	return (
		before.distance_to(player.position) > 1.0
		and PlayfieldBoundary.is_point_on_loop(loop, player.position, EPSILON)
		and player.debug_is_border_state_consistent()
	)


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


func _assert_draw_start_safety(
	player,
	loop: PackedVector2Array,
	interior_point: Vector2,
	label: String,
	failures: Array[String]
) -> void:
	var safe_interior_point := PlayfieldBoundary.ensure_point_inside(loop, interior_point, EPSILON)
	if PlayfieldBoundary.is_point_on_loop(loop, safe_interior_point, EPSILON):
		failures.append("%s could not build a non-border draw-start test point." % label)
		return

	player.state = player.PlayerState.BORDER
	player.position = safe_interior_point
	_assert(
		!player.debug_can_start_drawing_from_border(),
		"%s draw start accepted a non-border point while in BORDER state." % label,
		failures
	)


func _assert(condition: bool, message: String, failures: Array[String]) -> void:
	if !condition:
		failures.append(message)
