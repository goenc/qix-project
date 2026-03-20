extends SceneTree

const MAIN_SCENE = preload("res://scenes/base_main.tscn")
const PlayfieldBoundary = preload("res://scripts/game/playfield_boundary.gd")
const VerifyShared = preload("res://tools/verify_shared.gd")
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
	VerifyShared.assert_player_corner_preinput(player, loop, label, failures)


func _assert_player_corner_input_priority(player, loop: PackedVector2Array, label: String, failures: Array[String]) -> void:
	VerifyShared.assert_player_corner_input_priority(player, loop, label, failures)


func _move_player_into_corner_with_preinput(
	player,
	loop: PackedVector2Array,
	vertex_index: int,
	clockwise: bool
) -> bool:
	return VerifyShared.move_player_into_corner_with_preinput(player, loop, vertex_index, clockwise)


func _latest_input_overrides_queued_corner(
	player,
	loop: PackedVector2Array,
	vertex_index: int,
	clockwise: bool
) -> bool:
	return VerifyShared.latest_input_overrides_queued_corner(player, loop, vertex_index, clockwise)


func _queued_corner_fallback_applies(
	player,
	loop: PackedVector2Array,
	vertex_index: int,
	clockwise: bool
) -> bool:
	return VerifyShared.queued_corner_fallback_applies(player, loop, vertex_index, clockwise)


func _prepare_corner_queue_state(
	player,
	loop: PackedVector2Array,
	vertex_index: int,
	clockwise: bool
) -> Dictionary:
	return VerifyShared.prepare_corner_queue_state(player, loop, vertex_index, clockwise)


func _assert_draw_start_safety(
	player,
	loop: PackedVector2Array,
	interior_point: Vector2,
	label: String,
	failures: Array[String]
) -> void:
	VerifyShared.assert_draw_start_safety(player, loop, interior_point, label, failures)


func _assert_bbos_reflection(
	bbos,
	loop: PackedVector2Array,
	rect: Rect2,
	label: String,
	require_internal_segment: bool,
	failures: Array[String]
) -> void:
	var reflection_loop := VerifyShared.get_bbos_reflection_loop(bbos, loop)
	var segment := _find_test_segment(reflection_loop, loop, rect, require_internal_segment)
	_assert(!segment.is_empty(), "%s did not expose a usable boundary segment for reflection testing." % label, failures)
	if segment.is_empty():
		return

	var collision_case := _build_collision_case(reflection_loop, segment, bbos.move_speed, bbos.bounce_epsilon)
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
		reflection_loop,
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


func _find_test_segment(
	loop: PackedVector2Array,
	reference_loop: PackedVector2Array,
	rect: Rect2,
	require_internal_segment: bool
) -> Dictionary:
	return VerifyShared.find_test_segment(loop, reference_loop, rect, require_internal_segment)


func _build_collision_case(loop: PackedVector2Array, segment: Dictionary, speed: float, epsilon: float) -> Dictionary:
	return VerifyShared.build_collision_case(loop, segment, speed, epsilon)


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
	VerifyShared.assert_condition(condition, message, failures)
