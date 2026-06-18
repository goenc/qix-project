extends SceneTree

const Boundary = preload("res://scripts/game/playfield_boundary.gd")


func _initialize() -> void:
	var failures: Array[String] = []
	var loop := _build_jagged_loop()
	var metrics := Boundary.build_loop_metrics(loop)
	_assert(loop.size() >= 40, "The verification loop is not complex enough.", failures)
	_assert(!Array(metrics.get("spatial_cells", [])).is_empty(), "The spatial index was not built.", failures)

	var total_candidates := 0
	var query_count := 0
	for x in range(10, 391, 10):
		var start := Vector2(float(x), 40.0)
		var finish := Vector2(float(x), 240.0)
		var query_rect := Rect2(start, finish - start).abs().grow(0.05)
		var candidates := Boundary.query_segment_indices(metrics, query_rect)
		total_candidates += candidates.size()
		query_count += 1
		var indexed_hit := Boundary.find_first_boundary_hit(start, finish, loop, 0.05, metrics)
		var full_hit := Boundary.find_first_boundary_hit(start, finish, loop, 0.05)
		_assert(_hits_match(indexed_hit, full_hit),
			"Indexed boundary hit differs at x=%d: indexed=%s full=%s" % [x, indexed_hit, full_hit], failures)

	for y in range(10, 211, 10):
		for x in range(10, 391, 10):
			var point := Vector2(float(x), float(y))
			var indexed_fit := Boundary.can_circle_center_fit(loop, point, 6.0, 0.05, metrics)
			var full_fit := Boundary.can_circle_center_fit(loop, point, 6.0, 0.05)
			_assert(indexed_fit == full_fit,
				"Indexed circle fit differs at %s: indexed=%s full=%s" % [point, indexed_fit, full_fit], failures)

	var average_candidates := float(total_candidates) / maxf(float(query_count), 1.0)
	_assert(average_candidates < float(loop.size()) * 0.5,
		"The spatial index did not reduce candidates enough: average=%s segments=%d" % [average_candidates, loop.size()], failures)
	var benchmark := _benchmark_hits(loop, metrics)
	if failures.is_empty():
		print("Boundary spatial-index verification passed. average_candidates=%.2f segments=%d indexed_usec=%d full_usec=%d" % [
			average_candidates,
			loop.size(),
			int(benchmark.get("indexed_usec", 0)),
			int(benchmark.get("full_usec", 0))
		])
		quit(0)
		return
	for failure in failures:
		printerr(failure)
	quit(1)


func _build_jagged_loop() -> PackedVector2Array:
	var loop := PackedVector2Array([Vector2(0, 0), Vector2(400, 0), Vector2(400, 200)])
	var current_y := 200.0
	for x in range(380, -1, -20):
		loop.append(Vector2(float(x), current_y))
		if x > 0:
			current_y = 180.0 if is_equal_approx(current_y, 200.0) else 200.0
			loop.append(Vector2(float(x), current_y))
	if !is_equal_approx(current_y, 200.0):
		loop.append(Vector2(0, 200))
	loop.append(Vector2(0, 0))
	return Boundary.sanitize_loop(loop)


func _hits_match(a: Dictionary, b: Dictionary) -> bool:
	if bool(a.get("hit", false)) != bool(b.get("hit", false)):
		return false
	if !bool(a.get("hit", false)):
		return true
	return (
		Vector2(a.get("point", Vector2.ZERO)).distance_to(Vector2(b.get("point", Vector2.ZERO))) <= 0.001
		and int(a.get("segment_index", -1)) == int(b.get("segment_index", -1))
	)


func _benchmark_hits(loop: PackedVector2Array, metrics: Dictionary) -> Dictionary:
	var starts: Array[Vector2] = []
	for index in range(2000):
		starts.append(Vector2(10.0 + float((index * 37) % 380), 40.0))
	var started_at := Time.get_ticks_usec()
	for start in starts:
		Boundary.find_first_boundary_hit(start, start + Vector2(0, 200), loop, 0.05, metrics)
	var indexed_usec := Time.get_ticks_usec() - started_at
	started_at = Time.get_ticks_usec()
	for start in starts:
		Boundary.find_first_boundary_hit(start, start + Vector2(0, 200), loop, 0.05)
	return {
		"indexed_usec": indexed_usec,
		"full_usec": Time.get_ticks_usec() - started_at
	}


func _assert(condition: bool, message: String, failures: Array[String]) -> void:
	if !condition:
		failures.append(message)
