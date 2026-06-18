extends SceneTree

const BBOS_SCENE = preload("res://scenes/enemy/bbos.tscn")
const Boundary = preload("res://scripts/game/playfield_boundary.gd")


func _initialize() -> void:
	var failures: Array[String] = []
	_verify_inset_validation(failures)
	await _verify_narrow_motion(failures)
	await _verify_circle_fallback(failures)

	if failures.is_empty():
		print("BBOS narrow-region verification passed.")
		quit(0)
		return
	for failure in failures:
		printerr(failure)
	quit(1)


func _verify_inset_validation(failures: Array[String]) -> void:
	var valid_loop := Boundary.build_rect_polygon(Rect2(0.0, 0.0, 200.0, 17.0))
	var invalid_loop := Boundary.build_rect_polygon(Rect2(0.0, 0.0, 200.0, 15.0))
	_assert(Boundary.build_inset_loop(valid_loop, 8.0, 0.05).size() == 4,
		"A corridor wider than the collision diameter did not produce an inset loop.", failures)
	_assert(Boundary.build_inset_loop(invalid_loop, 8.0, 0.05).is_empty(),
		"A corridor narrower than the collision diameter produced a reversed inset loop.", failures)


func _verify_narrow_motion(failures: Array[String]) -> void:
	var bbos = BBOS_SCENE.instantiate()
	root.add_child(bbos)
	bbos.process_mode = Node.PROCESS_MODE_DISABLED
	await process_frame
	bbos.boundary_epsilon = 0.05
	bbos.max_reflections_per_frame = 8
	bbos.set_collision_radius(8.0)
	bbos.set_active_outer_loop(Boundary.build_rect_polygon(Rect2(0.0, 0.0, 200.0, 17.0)))
	bbos.position = Vector2(50.0, 8.5)
	bbos.velocity = Vector2(1.0, 1.0).normalized() * 140.0
	bbos.direction_change_timer = 999.0

	for frame in range(30):
		var previous_position: Vector2 = bbos.position
		bbos._process(1.0 / 60.0)
		var moved_distance := previous_position.distance_to(bbos.position)
		_assert(moved_distance >= 1.5 and moved_distance <= 2.5,
			"Narrow motion snapped or stalled on frame %d: moved=%s position=%s" % [frame, moved_distance, bbos.position], failures)
		_assert(Boundary.can_circle_center_fit(bbos.active_outer_loop, bbos.position, 8.0, 0.05),
			"BBOS left the circle-safe corridor on frame %d: position=%s" % [frame, bbos.position], failures)
	bbos.queue_free()


func _verify_circle_fallback(failures: Array[String]) -> void:
	var bbos = BBOS_SCENE.instantiate()
	root.add_child(bbos)
	bbos.process_mode = Node.PROCESS_MODE_DISABLED
	await process_frame
	var neck_loop := PackedVector2Array([
		Vector2(0, 0), Vector2(100, 0), Vector2(100, 40), Vector2(60, 40),
		Vector2(60, 60), Vector2(100, 60), Vector2(100, 100), Vector2(0, 100),
		Vector2(0, 60), Vector2(40, 60), Vector2(40, 40), Vector2(0, 40)
	])
	bbos.boundary_epsilon = 0.05
	bbos.set_active_outer_loop(neck_loop)
	bbos.set_collision_radius(10.0)
	_assert(!bbos._has_active_inner_loop(), "The zero-width neck unexpectedly produced an active inset loop.", failures)
	var unsafe_point := Vector2(39.0, 50.0)
	var resolved: Vector2 = bbos._ensure_position_inside_active_boundary(unsafe_point, 10.0, 0.05)
	_assert(resolved.distance_to(unsafe_point) > 2.0,
		"Circle fallback behaved like the old point-only correction: resolved=%s" % resolved, failures)
	_assert(Boundary.can_circle_center_fit(neck_loop, resolved, 10.0, 0.05),
		"Circle fallback did not restore collision-radius clearance: resolved=%s" % resolved, failures)
	bbos.queue_free()


func _assert(condition: bool, message: String, failures: Array[String]) -> void:
	if !condition:
		failures.append(message)
