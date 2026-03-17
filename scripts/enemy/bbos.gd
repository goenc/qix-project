extends Node2D

const PlayfieldBoundary = preload("res://scripts/game/playfield_boundary.gd")
const MAX_REFLECTIONS_PER_FRAME := 2

@export var move_speed: float = 140.0
@export var direction_change_interval_min: float = 1.5
@export var direction_change_interval_max: float = 3.0
@export var bounce_epsilon: float = 0.5
@export var collision_radius: float = 32.0
@export var min_collision_radius: float = 8.0
@export var body_rotation_speed_deg: float = 90.0

@onready var body: Node2D = $Body
@onready var pick_area: Area2D = $PickArea
@onready var base_player: Node = get_node_or_null("../BasePlayer")

var playfield_rect: Rect2 = Rect2()
var active_outer_loop: PackedVector2Array = PackedVector2Array()
var active_inner_loop: PackedVector2Array = PackedVector2Array()
var active_inner_loop_total_length := 0.0
var rng := RandomNumberGenerator.new()
var has_spawned := false
var velocity := Vector2.ZERO
var direction_change_timer := 0.0


func _ready() -> void:
	rng.randomize()
	if is_instance_valid(pick_area):
		pick_area.set_meta(&"debug_pick_owner", self)
	set_collision_radius(collision_radius)
	_reset_direction_change_timer()
	_pick_new_velocity()


func _process(delta: float) -> void:
	if is_instance_valid(body):
		body.rotation += deg_to_rad(body_rotation_speed_deg) * delta

	if active_outer_loop.size() < 3:
		return

	direction_change_timer -= delta
	if direction_change_timer <= 0.0:
		_pick_new_velocity()
		_reset_direction_change_timer()

	var safe_radius := _get_effective_collision_radius()
	var safe_epsilon := maxf(bounce_epsilon, 0.001)
	var use_inner_loop := _has_active_inner_loop()
	var remaining_time := delta
	var reflection_count := 0
	while remaining_time > 0.0 and reflection_count < MAX_REFLECTIONS_PER_FRAME:
		var segment_start := position
		var next_position := position + velocity * remaining_time
		var boundary_hit := (
			PlayfieldBoundary.find_first_boundary_hit(position, next_position, active_inner_loop, safe_epsilon)
			if use_inner_loop
			else PlayfieldBoundary.find_first_boundary_hit_for_circle(
				position,
				next_position,
				active_outer_loop,
				safe_radius,
				safe_epsilon
			)
		)
		if !bool(boundary_hit.get("hit", false)):
			position = _ensure_position_inside_active_boundary(next_position, safe_radius, safe_epsilon)
			_attempt_player_hit(segment_start, position, safe_radius)
			return

		position = boundary_hit["point"]
		_attempt_player_hit(segment_start, position, safe_radius)
		velocity = _reflect_velocity(velocity, Vector2(boundary_hit.get("normal", Vector2.ZERO)))
		position += Vector2(boundary_hit.get("normal", Vector2.ZERO)) * maxf(bounce_epsilon * 2.0, 1.0)
		position = _ensure_position_inside_active_boundary(position, safe_radius, safe_epsilon)
		var travel_ratio := clampf(float(boundary_hit.get("travel_ratio", 1.0)), 0.0, 1.0)
		remaining_time *= maxf(0.0, 1.0 - travel_ratio)
		reflection_count += 1

	if remaining_time > 0.0:
		var segment_start := position
		position = _ensure_position_inside_active_boundary(position + velocity * remaining_time, safe_radius, safe_epsilon)
		_attempt_player_hit(segment_start, position, safe_radius)


func set_playfield_rect(rect: Rect2) -> void:
	playfield_rect = rect.abs()
	if playfield_rect.size.x <= 0.0 or playfield_rect.size.y <= 0.0:
		return

	if !has_spawned:
		position = _pick_random_point(_get_spawnable_rect(playfield_rect))
		has_spawned = true
	elif active_outer_loop.is_empty():
		var spawnable_rect := _get_spawnable_rect(playfield_rect)
		if !_rect_has_point(spawnable_rect, position):
			position = _clamp_point_to_rect(position, spawnable_rect)


func set_active_outer_loop(loop: PackedVector2Array) -> void:
	var sanitized_loop := PlayfieldBoundary.sanitize_loop(loop)
	if sanitized_loop.size() < 3:
		return

	active_outer_loop = sanitized_loop
	_rebuild_active_inner_loop()

	if !has_spawned and playfield_rect.size.x > 0.0 and playfield_rect.size.y > 0.0:
		position = _pick_random_point(_get_spawnable_rect(playfield_rect))
		has_spawned = true

	if has_spawned:
		position = _ensure_position_inside_active_boundary(
			position,
			_get_effective_collision_radius(),
			maxf(bounce_epsilon, 0.001)
		)


func set_collision_radius(radius: float) -> void:
	collision_radius = maxf(radius, maxf(min_collision_radius, 0.0))
	_rebuild_active_inner_loop()

	if !has_spawned:
		return

	if active_outer_loop.size() >= 3:
		position = _ensure_position_inside_active_boundary(
			position,
			collision_radius,
			maxf(bounce_epsilon, 0.001)
		)
	elif playfield_rect.size.x > 0.0 and playfield_rect.size.y > 0.0:
		position = _clamp_point_to_rect(position, _get_spawnable_rect(playfield_rect))


func _get_spawnable_rect(rect: Rect2) -> Rect2:
	var radius := _get_effective_collision_radius()
	var min_x := rect.position.x + radius
	var max_x := rect.end.x - radius
	var min_y := rect.position.y + radius
	var max_y := rect.end.y - radius

	if min_x > max_x:
		var center_x := rect.position.x + rect.size.x * 0.5
		min_x = center_x
		max_x = center_x
	if min_y > max_y:
		var center_y := rect.position.y + rect.size.y * 0.5
		min_y = center_y
		max_y = center_y

	return Rect2(
		Vector2(min_x, min_y),
		Vector2(max_x - min_x, max_y - min_y)
	)


func _pick_random_point(rect: Rect2) -> Vector2:
	var x := rect.position.x if is_zero_approx(rect.size.x) else rng.randf_range(rect.position.x, rect.end.x)
	var y := rect.position.y if is_zero_approx(rect.size.y) else rng.randf_range(rect.position.y, rect.end.y)
	return Vector2(x, y)


func _clamp_point_to_rect(point: Vector2, rect: Rect2) -> Vector2:
	return Vector2(
		clampf(point.x, rect.position.x, rect.end.x),
		clampf(point.y, rect.position.y, rect.end.y)
	)


func _rect_has_point(rect: Rect2, point: Vector2) -> bool:
	return (
		point.x >= rect.position.x
		and point.x <= rect.end.x
		and point.y >= rect.position.y
		and point.y <= rect.end.y
	)


func _reset_direction_change_timer() -> void:
	var min_interval := minf(direction_change_interval_min, direction_change_interval_max)
	var max_interval := maxf(direction_change_interval_min, direction_change_interval_max)
	direction_change_timer = min_interval if is_equal_approx(min_interval, max_interval) else rng.randf_range(min_interval, max_interval)


func _pick_new_velocity() -> void:
	var direction := Vector2(
		-1.0 if rng.randi_range(0, 1) == 0 else 1.0,
		-1.0 if rng.randi_range(0, 1) == 0 else 1.0
	)
	velocity = direction.normalized() * maxf(absf(move_speed), 0.001)


func _reflect_velocity(current_velocity: Vector2, normal: Vector2) -> Vector2:
	var safe_normal := normal.normalized()
	if safe_normal == Vector2.ZERO:
		return current_velocity

	var reflected_velocity := current_velocity - 2.0 * current_velocity.dot(safe_normal) * safe_normal
	if reflected_velocity.length_squared() <= 0.0001:
		return current_velocity
	return reflected_velocity.normalized() * maxf(current_velocity.length(), 0.001)


func _get_effective_collision_radius() -> float:
	return maxf(collision_radius, maxf(min_collision_radius, 0.0))


func _has_active_inner_loop() -> bool:
	return active_inner_loop.size() >= 3 and active_inner_loop_total_length > 0.0


func _ensure_position_inside_active_boundary(point: Vector2, radius: float, epsilon: float) -> Vector2:
	if _has_active_inner_loop():
		return PlayfieldBoundary.ensure_point_inside(active_inner_loop, point, epsilon)
	return PlayfieldBoundary.ensure_circle_center_inside(active_outer_loop, point, radius, epsilon)


func _rebuild_active_inner_loop() -> void:
	active_inner_loop = PackedVector2Array()
	active_inner_loop_total_length = 0.0
	if active_outer_loop.size() < 3:
		return

	active_inner_loop = PlayfieldBoundary.build_inset_loop(
		active_outer_loop,
		_get_effective_collision_radius(),
		maxf(bounce_epsilon, 0.001)
	)
	if active_inner_loop.size() < 3:
		return

	var inner_loop_metrics := PlayfieldBoundary.build_loop_metrics(active_inner_loop)
	active_inner_loop_total_length = float(inner_loop_metrics.get("total_length", 0.0))


func _attempt_player_hit(from_point: Vector2, to_point: Vector2, attack_radius: float) -> void:
	var player := _get_base_player()
	if !is_instance_valid(player):
		return
	if !player.has_method("get_boss_hit_targets") or !player.has_method("apply_boss_damage"):
		return

	var targets: Dictionary = player.call("get_boss_hit_targets")
	var best_hit := {"hit": false}

	if bool(targets.get("player", false)) and player.has_method("get_body_damage_rect"):
		var body_rect: Rect2 = player.call("get_body_damage_rect")
		var body_hit := _find_segment_rect_contact(from_point, to_point, body_rect, attack_radius)
		if bool(body_hit.get("hit", false)):
			best_hit = body_hit

	if bool(targets.get("trail", false)) and player.has_method("get_active_damage_trail_segments"):
		var trail_hit := _find_trail_hit(from_point, to_point, attack_radius, player.call("get_active_damage_trail_segments"))
		if bool(trail_hit.get("hit", false)):
			if (
				!bool(best_hit.get("hit", false))
				or float(trail_hit.get("distance", INF)) < float(best_hit.get("distance", INF))
			):
				best_hit = trail_hit

	if bool(best_hit.get("hit", false)):
		player.call("apply_boss_damage")


func _get_base_player() -> Node:
	if is_instance_valid(base_player):
		return base_player
	base_player = get_node_or_null("../BasePlayer")
	return base_player


func _find_trail_hit(
	from_point: Vector2,
	to_point: Vector2,
	attack_radius: float,
	trail_segments: Array
) -> Dictionary:
	var best_hit := {"hit": false}
	for segment_variant in trail_segments:
		var segment: PackedVector2Array = segment_variant
		if segment.size() < 2:
			continue
		var contact := _find_segment_segment_contact(
			from_point,
			to_point,
			segment[0],
			segment[1],
			attack_radius
		)
		if !bool(contact.get("hit", false)):
			continue
		if (
			!bool(best_hit.get("hit", false))
			or float(contact.get("distance", INF)) < float(best_hit.get("distance", INF))
		):
			best_hit = contact
	return best_hit


func _find_segment_rect_contact(
	from_point: Vector2,
	to_point: Vector2,
	rect: Rect2,
	padding: float
) -> Dictionary:
	var expanded_rect := rect.grow(maxf(padding, 0.0))
	var delta := to_point - from_point
	if delta.is_zero_approx():
		if expanded_rect.has_point(from_point):
			return {"hit": true, "distance": 0.0, "point": from_point}
		return {"hit": false}

	var t_min := 0.0
	var t_max := 1.0
	var clip_result := _clip_segment_axis(-delta.x, from_point.x - expanded_rect.position.x, t_min, t_max)
	if !bool(clip_result.get("hit", false)):
		return {"hit": false}
	t_min = float(clip_result.get("t_min", t_min))
	t_max = float(clip_result.get("t_max", t_max))
	clip_result = _clip_segment_axis(delta.x, expanded_rect.end.x - from_point.x, t_min, t_max)
	if !bool(clip_result.get("hit", false)):
		return {"hit": false}
	t_min = float(clip_result.get("t_min", t_min))
	t_max = float(clip_result.get("t_max", t_max))
	clip_result = _clip_segment_axis(-delta.y, from_point.y - expanded_rect.position.y, t_min, t_max)
	if !bool(clip_result.get("hit", false)):
		return {"hit": false}
	t_min = float(clip_result.get("t_min", t_min))
	t_max = float(clip_result.get("t_max", t_max))
	clip_result = _clip_segment_axis(delta.y, expanded_rect.end.y - from_point.y, t_min, t_max)
	if !bool(clip_result.get("hit", false)):
		return {"hit": false}
	t_min = float(clip_result.get("t_min", t_min))

	var contact_point := from_point + delta * t_min
	return {
		"hit": true,
		"distance": from_point.distance_to(contact_point),
		"point": contact_point
	}


func _clip_segment_axis(p: float, q: float, t_min: float, t_max: float) -> Dictionary:
	if is_zero_approx(p):
		return {
			"hit": q >= 0.0,
			"t_min": t_min,
			"t_max": t_max
		}

	var ratio := q / p
	if p < 0.0:
		if ratio > t_max:
			return {"hit": false}
		t_min = maxf(t_min, ratio)
	else:
		if ratio < t_min:
			return {"hit": false}
		t_max = minf(t_max, ratio)

	return {
		"hit": t_min <= t_max,
		"t_min": t_min,
		"t_max": t_max
	}


func _find_segment_segment_contact(
	a0: Vector2,
	a1: Vector2,
	b0: Vector2,
	b1: Vector2,
	radius: float
) -> Dictionary:
	var d1 := a1 - a0
	var d2 := b1 - b0
	var r := a0 - b0
	var a := d1.dot(d1)
	var e := d2.dot(d2)
	var f := d2.dot(r)
	var s := 0.0
	var t := 0.0

	if a <= 0.0001 and e <= 0.0001:
		if a0.distance_to(b0) <= radius:
			return {"hit": true, "distance": 0.0, "point": a0}
		return {"hit": false}

	if a <= 0.0001:
		t = clampf(f / e, 0.0, 1.0)
	elif e <= 0.0001:
		s = clampf(-d1.dot(r) / a, 0.0, 1.0)
	else:
		var c := d1.dot(r)
		var b := d1.dot(d2)
		var denominator := a * e - b * b
		if !is_zero_approx(denominator):
			s = clampf((b * f - c * e) / denominator, 0.0, 1.0)
		t = (b * s + f) / e
		if t < 0.0:
			t = 0.0
			s = clampf(-c / a, 0.0, 1.0)
		elif t > 1.0:
			t = 1.0
			s = clampf((b - c) / a, 0.0, 1.0)

	var closest_a := a0 + d1 * s
	var closest_b := b0 + d2 * t
	if closest_a.distance_to(closest_b) > radius:
		return {"hit": false}

	return {
		"hit": true,
		"distance": a0.distance_to(closest_a),
		"point": closest_a
	}
