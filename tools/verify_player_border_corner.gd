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
	_assert_player_corner_input_priority(player, loop, label, failures)
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
	VerifyShared.assert_draw_start_safety(player, loop, interior_point, label, failures, true)


func _assert(condition: bool, message: String, failures: Array[String]) -> void:
	VerifyShared.assert_condition(condition, message, failures)
