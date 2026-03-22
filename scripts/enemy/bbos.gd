extends Node2D

const PlayfieldBoundary = preload("res://scripts/game/playfield_boundary.gd")
const MAX_REFLECTIONS_PER_FRAME := 2
const VIEWPORT_HEIGHT_RATIO := 0.5

signal position_changed(world_position: Vector2)

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
var active_inner_loop_cache_ready := false
var rng := RandomNumberGenerator.new()
var has_spawned := false
var velocity := Vector2.ZERO
var direction_change_timer := 0.0
var base_scale := Vector2.ONE
var base_collision_radius := 0.0
var last_reported_position := Vector2(INF, INF)
var corner_stuck_score := 0.0
var corner_escape_cooldown := 0.0
var last_corner_hit_position := Vector2(INF, INF)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	rng.randomize()
	if is_instance_valid(pick_area):
		pick_area.set_meta(&"debug_pick_owner", self)
	base_scale = scale
	base_collision_radius = maxf(collision_radius, maxf(min_collision_radius, 0.0))
	_sync_size_to_viewport()
	var viewport := get_viewport()
	if is_instance_valid(viewport) and !viewport.size_changed.is_connected(_on_viewport_size_changed):
		viewport.size_changed.connect(_on_viewport_size_changed)
	_reset_direction_change_timer()
	_pick_new_velocity()
	_emit_position_changed_if_needed(true)


func _process(delta: float) -> void:
	if is_instance_valid(body):
		body.rotation += deg_to_rad(body_rotation_speed_deg) * delta

	if active_outer_loop.size() < 3:
		return

	if corner_escape_cooldown > 0.0:
		corner_escape_cooldown = maxf(corner_escape_cooldown - delta, 0.0)
	corner_stuck_score = maxf(corner_stuck_score - delta * 2.0, 0.0)

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
				safe_epsilon,
				active_inner_loop,
				active_inner_loop_cache_ready
			)
		)
		if !bool(boundary_hit.get("hit", false)):
			position = _ensure_position_inside_active_boundary(next_position, safe_radius, safe_epsilon)
			_attempt_player_hit(segment_start, position, safe_radius)
			_emit_position_changed_if_needed()
			return

		position = boundary_hit["point"]
		_attempt_player_hit(segment_start, position, safe_radius)
		if _should_escape_corner(boundary_hit, safe_epsilon):
			_perform_corner_escape(safe_radius, safe_epsilon)
			remaining_time = 0.0
			break
		velocity = _reflect_velocity(velocity, Vector2(boundary_hit.get("normal", Vector2.ZERO)))
		position += Vector2(boundary_hit.get("normal", Vector2.ZERO)) * maxf(bounce_epsilon, 0.05)
		position = _ensure_position_inside_active_boundary(position, safe_radius, safe_epsilon)
		var travel_ratio := clampf(float(boundary_hit.get("travel_ratio", 1.0)), 0.0, 1.0)
		remaining_time *= maxf(0.0, 1.0 - travel_ratio)
		reflection_count += 1

	if remaining_time > 0.0:
		var segment_start := position
		position = _ensure_position_inside_active_boundary(position + velocity * remaining_time, safe_radius, safe_epsilon)
		_attempt_player_hit(segment_start, position, safe_radius)
	_emit_position_changed_if_needed()


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
	_emit_position_changed_if_needed()


func set_active_outer_loop(loop: PackedVector2Array) -> void:
	var sanitized_loop := PlayfieldBoundary.sanitize_loop(loop)
	if sanitized_loop.size() < 3:
		return

	active_outer_loop = sanitized_loop
	_rebuild_active_inner_loop()
	_reset_corner_stuck_state()

	if !has_spawned and playfield_rect.size.x > 0.0 and playfield_rect.size.y > 0.0:
		position = _pick_random_point(_get_spawnable_rect(playfield_rect))
		has_spawned = true

	if has_spawned:
		position = _ensure_position_inside_active_boundary(
			position,
			_get_effective_collision_radius(),
			maxf(bounce_epsilon, 0.001)
		)
	_emit_position_changed_if_needed()


func set_collision_radius(radius: float) -> void:
	collision_radius = maxf(radius, maxf(min_collision_radius, 0.0))
	_rebuild_active_inner_loop()
	_reset_corner_stuck_state()

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
	_emit_position_changed_if_needed()


func get_active_reflection_loop() -> PackedVector2Array:
	if _has_active_inner_loop():
		return active_inner_loop
	return active_outer_loop


func _on_viewport_size_changed() -> void:
	_sync_size_to_viewport()


func _sync_size_to_viewport() -> void:
	var viewport_rect := get_viewport_rect()
	if viewport_rect.size.y <= 0.0:
		return

	var target_diameter := viewport_rect.size.y * VIEWPORT_HEIGHT_RATIO
	var source_diameter := base_collision_radius * 2.0
	if source_diameter <= 0.0:
		return

	scale = base_scale * (target_diameter / source_diameter)
	set_collision_radius(target_diameter * 0.5)


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
	return active_inner_loop_cache_ready and active_inner_loop.size() >= 3 and active_inner_loop_total_length > 0.0


func _ensure_position_inside_active_boundary(point: Vector2, radius: float, epsilon: float) -> Vector2:
	if _has_active_inner_loop():
		return PlayfieldBoundary.ensure_point_inside(active_inner_loop, point, epsilon)
	return PlayfieldBoundary.ensure_circle_center_inside(
		active_outer_loop,
		point,
		radius,
		epsilon,
		active_inner_loop,
		active_inner_loop_cache_ready
	)


func _rebuild_active_inner_loop() -> void:
	active_inner_loop = PackedVector2Array()
	active_inner_loop_total_length = 0.0
	active_inner_loop_cache_ready = false
	if active_outer_loop.size() < 3:
		active_inner_loop_cache_ready = true
		return

	active_inner_loop = PlayfieldBoundary.build_inset_loop(
		active_outer_loop,
		_get_effective_collision_radius(),
		maxf(bounce_epsilon, 0.001)
	)
	active_inner_loop_cache_ready = true
	if active_inner_loop.size() < 3:
		return

	var inner_loop_metrics := PlayfieldBoundary.build_loop_metrics(active_inner_loop)
	active_inner_loop_total_length = float(inner_loop_metrics.get("total_length", 0.0))


func _reset_corner_stuck_state() -> void:
	corner_stuck_score = 0.0
	corner_escape_cooldown = 0.0
	last_corner_hit_position = Vector2(INF, INF)


func _should_escape_corner(hit: Dictionary, safe_epsilon: float) -> bool:
	if corner_escape_cooldown > 0.0:
		return false

	var hit_point := Vector2(hit.get("point", position))
	var segment_start := Vector2(hit.get("segment_start", hit_point))
	var segment_end := Vector2(hit.get("segment_end", hit_point))
	var corner_tolerance := maxf(safe_epsilon * 4.0, 2.0)
	var hit_near_corner := (
		hit_point.distance_to(segment_start) <= corner_tolerance
		or hit_point.distance_to(segment_end) <= corner_tolerance
	)
	if !hit_near_corner:
		corner_stuck_score = 0.0
		last_corner_hit_position = Vector2(INF, INF)
		return false

	if last_corner_hit_position.distance_to(hit_point) <= corner_tolerance:
		corner_stuck_score += 1.0
	else:
		corner_stuck_score = 1.0
	last_corner_hit_position = hit_point
	return corner_stuck_score >= 2.0


func _perform_corner_escape(safe_radius: float, safe_epsilon: float) -> void:
	var escape_loop := get_active_reflection_loop()
	var escape_distance := maxf(safe_radius * 0.5, maxf(bounce_epsilon * 4.0, 4.0))
	var current_speed := maxf(absf(move_speed), velocity.length())
	var candidate_directions: Array[Vector2] = [
		-velocity.normalized() if velocity.length_squared() > 0.0001 else Vector2.ZERO,
		Vector2.LEFT,
		Vector2.RIGHT,
		Vector2.UP,
		Vector2.DOWN,
		Vector2(-1.0, -1.0).normalized(),
		Vector2(1.0, -1.0).normalized(),
		Vector2(-1.0, 1.0).normalized(),
		Vector2(1.0, 1.0).normalized()
	]

	var best_point := Vector2(INF, INF)
	var best_direction := Vector2.ZERO
	var best_score := -INF
	for direction in candidate_directions:
		if direction == Vector2.ZERO:
			continue

		var candidate_point := position + direction * escape_distance
		var resolved_point := _ensure_position_inside_active_boundary(candidate_point, safe_radius, safe_epsilon)
		if resolved_point.distance_to(position) <= safe_epsilon:
			continue

		var score := 0.0
		if escape_loop.size() >= 3:
			score = float(PlayfieldBoundary.project_point_to_loop(escape_loop, resolved_point).get("distance", 0.0))
		if score > best_score + 0.001:
			best_score = score
			best_point = resolved_point
			best_direction = (resolved_point - position).normalized()

	if best_direction == Vector2.ZERO:
		best_direction = -velocity.normalized() if velocity.length_squared() > 0.0001 else Vector2.RIGHT
		best_point = _ensure_position_inside_active_boundary(position + best_direction * escape_distance, safe_radius, safe_epsilon)

	position = best_point
	velocity = best_direction * maxf(current_speed, 0.001)
	corner_stuck_score = 0.0
	corner_escape_cooldown = 0.15
	last_corner_hit_position = Vector2(INF, INF)
	_reset_direction_change_timer()


func _attempt_player_hit(from_point: Vector2, to_point: Vector2, attack_radius: float) -> void:
	var player := _get_base_player()
	if !is_instance_valid(player):
		return
	if !player.has_method("get_boss_hit_targets") or !player.has_method("apply_boss_damage"):
		return

	var targets: Dictionary = player.call("get_boss_hit_targets")
	var body_hitbox_enabled := bool(targets.get("player", false))
	var trail_hitbox_enabled := bool(targets.get("trail", false))
	if player.has_method("is_body_damage_hitbox_enabled"):
		body_hitbox_enabled = bool(player.call("is_body_damage_hitbox_enabled"))
	if player.has_method("is_trail_damage_hitbox_enabled"):
		trail_hitbox_enabled = bool(player.call("is_trail_damage_hitbox_enabled"))
	var best_hit := {"hit": false}
	var swept_aabb := _build_swept_aabb(from_point, to_point, attack_radius)

	if body_hitbox_enabled and player.has_method("get_body_damage_rect"):
		var body_rect: Rect2 = player.call("get_body_damage_rect")
		if _rects_overlap(swept_aabb, body_rect):
			var body_hit := _find_segment_rect_contact(from_point, to_point, body_rect, attack_radius)
			if bool(body_hit.get("hit", false)):
				best_hit = body_hit

	if trail_hitbox_enabled and player.has_method("get_active_damage_trail_segments"):
		var trail_segments: Array = []
		var trail_segment_aabbs: Array = []
		if player.has_method("get_active_damage_trail_data"):
			var trail_data: Dictionary = player.call("get_active_damage_trail_data")
			trail_segments = trail_data.get("segments", [])
			trail_segment_aabbs = trail_data.get("aabbs", [])
		else:
			trail_segments = player.call("get_active_damage_trail_segments")
		var trail_hit := _find_trail_hit(
			from_point,
			to_point,
			attack_radius,
			trail_segments,
			trail_segment_aabbs,
			swept_aabb
		)
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
	trail_segments: Array,
	trail_segment_aabbs: Array,
	swept_aabb: Rect2
) -> Dictionary:
	var best_hit := {"hit": false}
	for index in range(trail_segments.size()):
		var segment_variant = trail_segments[index]
		var segment: PackedVector2Array = segment_variant
		if segment.size() < 2:
			continue
		var segment_aabb := Rect2()
		if index < trail_segment_aabbs.size():
			segment_aabb = trail_segment_aabbs[index]
		else:
			segment_aabb = _build_swept_aabb(segment[0], segment[1], 0.0)
		if !_rects_overlap(swept_aabb, segment_aabb):
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


func _build_swept_aabb(from_point: Vector2, to_point: Vector2, padding: float) -> Rect2:
	var min_point := Vector2(minf(from_point.x, to_point.x), minf(from_point.y, to_point.y))
	var max_point := Vector2(maxf(from_point.x, to_point.x), maxf(from_point.y, to_point.y))
	return Rect2(min_point, max_point - min_point).grow(maxf(padding, 0.0))


func _rects_overlap(a: Rect2, b: Rect2) -> bool:
	return (
		a.position.x <= b.end.x
		and a.end.x >= b.position.x
		and a.position.y <= b.end.y
		and a.end.y >= b.position.y
	)


func _emit_position_changed_if_needed(force := false) -> void:
	if force or position.distance_to(last_reported_position) > 0.001:
		last_reported_position = position
		position_changed.emit(global_position)
