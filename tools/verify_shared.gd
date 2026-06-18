extends RefCounted
class_name VerifyShared

const PlayfieldBoundary = preload("res://scripts/game/playfield_boundary.gd")
const EPSILON := 2.0


static func assert_condition(condition: bool, message: String, failures: Array[String]) -> void:
	if !condition:
		failures.append(message)


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
			reference_point = Vector2(
				PlayfieldBoundary.project_point_to_loop(reference_loop, midpoint).get("point", midpoint)
			)
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
		var sample_a_inside := (
			Geometry2D.is_point_in_polygon(sample_a, loop)
			or PlayfieldBoundary.is_point_on_loop(loop, sample_a, EPSILON)
		)
		var sample_b_inside := (
			Geometry2D.is_point_in_polygon(sample_b, loop)
			or PlayfieldBoundary.is_point_on_loop(loop, sample_b, EPSILON)
		)
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
		var start := midpoint + inward_candidate * 12.0
		if (
			!Geometry2D.is_point_in_polygon(start, loop)
			and !PlayfieldBoundary.is_point_on_loop(loop, start, EPSILON)
		):
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
