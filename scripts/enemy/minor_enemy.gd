extends Node2D
class_name MinorEnemy

const PlayfieldBoundary = preload("res://scripts/game/playfield_boundary.gd")
const EnemyPlayerHitService = preload("res://scripts/enemy/services/enemy_player_hit_service.gd")
const MAX_REFLECTIONS_PER_FRAME := 2

@export var move_speed: float = 165.0
@export var direction_change_interval_min: float = 0.8
@export var direction_change_interval_max: float = 1.6
@export var bounce_epsilon: float = 0.5
@export var collision_radius: float = 24.0
@export var min_collision_radius: float = 12.0
@export var body_rotation_speed_deg: float = 120.0
@export var initial_spawn_ratio := Vector2(0.3, 0.35)
@export var initial_direction := Vector2(1.0, -1.0)

@onready var body: Sprite2D = $Body
@onready var pick_area: Area2D = $PickArea
@onready var base_player: Node = get_node_or_null("../BasePlayer")
@onready var base_boss: Node2D = get_node_or_null("../BBOS") as Node2D

var playfield_rect: Rect2 = Rect2()
var active_outer_loop: PackedVector2Array = PackedVector2Array()
var active_outer_loop_metrics: Dictionary = {}
var active_inner_loop: PackedVector2Array = PackedVector2Array()
var active_inner_loop_metrics: Dictionary = {}
var active_inner_loop_total_length := 0.0
var active_inner_loop_cache_ready := false
var rng := RandomNumberGenerator.new()
var has_spawned := false
var velocity := Vector2.ZERO
var direction_change_timer := 0.0
var last_reported_position := Vector2(INF, INF)
var corner_stuck_score := 0.0
var corner_escape_cooldown := 0.0
var last_corner_hit_position := Vector2(INF, INF)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	add_to_group(&"minor_enemies")
	rng.randomize()
	if is_instance_valid(pick_area):
		pick_area.set_meta(&"debug_pick_owner", self)
	_reset_direction_change_timer()
	_pick_new_velocity()


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
			PlayfieldBoundary.find_first_boundary_hit(
				position,
				next_position,
				active_inner_loop,
				safe_epsilon,
				active_inner_loop_metrics
			)
			if use_inner_loop
			else PlayfieldBoundary.find_first_boundary_hit_for_circle(
				position,
				next_position,
				active_outer_loop,
				safe_radius,
				safe_epsilon,
				active_inner_loop,
				active_inner_loop_cache_ready,
				active_inner_loop_metrics,
				active_outer_loop_metrics
			)
		)
		if !bool(boundary_hit.get("hit", false)):
			position = _ensure_position_inside_active_boundary(next_position, safe_radius, safe_epsilon)
			_resolve_boss_collision(safe_radius, safe_epsilon)
			_attempt_player_hit(segment_start, position, safe_radius)
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
		_resolve_boss_collision(safe_radius, safe_epsilon)
		var travel_ratio := clampf(float(boundary_hit.get("travel_ratio", 1.0)), 0.0, 1.0)
		remaining_time *= maxf(0.0, 1.0 - travel_ratio)
		reflection_count += 1

	if remaining_time > 0.0:
		var segment_start := position
		position = _ensure_position_inside_active_boundary(position + velocity * remaining_time, safe_radius, safe_epsilon)
		_resolve_boss_collision(safe_radius, safe_epsilon)
		_attempt_player_hit(segment_start, position, safe_radius)


func set_playfield_rect(rect: Rect2) -> void:
	playfield_rect = rect.abs()
	if playfield_rect.size.x <= 0.0 or playfield_rect.size.y <= 0.0:
		return

	var spawnable_rect := _get_spawnable_rect(playfield_rect)
	if !has_spawned:
		position = _resolve_initial_spawn_point(spawnable_rect)
		has_spawned = true
	elif !_rect_has_point(spawnable_rect, position):
		position = _clamp_point_to_rect(position, spawnable_rect)


func set_active_outer_loop(loop: PackedVector2Array) -> void:
	var sanitized_loop := PlayfieldBoundary.sanitize_loop(loop)
	if sanitized_loop.size() < 3:
		return

	active_outer_loop = sanitized_loop
	active_outer_loop_metrics = PlayfieldBoundary.build_loop_metrics(active_outer_loop)
	_rebuild_active_inner_loop()
	_reset_corner_stuck_state()
	if has_spawned:
		position = _ensure_position_inside_active_boundary(
			position,
			_get_effective_collision_radius(),
			maxf(bounce_epsilon, 0.001)
		)


func _resolve_initial_spawn_point(spawnable_rect: Rect2) -> Vector2:
	var ratio := Vector2(
		clampf(initial_spawn_ratio.x, 0.0, 1.0),
		clampf(initial_spawn_ratio.y, 0.0, 1.0)
	)
	return Vector2(
		lerpf(spawnable_rect.position.x, spawnable_rect.end.x, ratio.x),
		lerpf(spawnable_rect.position.y, spawnable_rect.end.y, ratio.y)
	)


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
	var direction := initial_direction
	if direction == Vector2.ZERO or rng.randf() < 0.7:
		direction = Vector2(
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
		return PlayfieldBoundary.ensure_point_inside_with_metrics(
			active_inner_loop,
			point,
			epsilon,
			active_inner_loop_metrics
		)
	return PlayfieldBoundary.ensure_circle_center_inside(
		active_outer_loop,
		point,
		radius,
		epsilon,
		active_inner_loop,
		active_inner_loop_cache_ready,
		active_inner_loop_metrics,
		active_outer_loop_metrics
	)


func _rebuild_active_inner_loop() -> void:
	active_inner_loop = PackedVector2Array()
	active_inner_loop_metrics = {}
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
		active_inner_loop_metrics = {}
		active_inner_loop_total_length = 0.0
		return
	active_inner_loop_metrics = PlayfieldBoundary.build_loop_metrics(active_inner_loop)
	active_inner_loop_total_length = float(active_inner_loop_metrics.get("total_length", 0.0))


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
	var escape_distance := maxf(safe_radius * 0.5, maxf(bounce_epsilon * 4.0, 4.0))
	for direction in candidate_directions:
		if direction == Vector2.ZERO:
			continue
		var candidate_point := position + direction * escape_distance
		var resolved_point := _ensure_position_inside_active_boundary(candidate_point, safe_radius, safe_epsilon)
		if resolved_point.distance_to(position) <= safe_epsilon:
			continue
		var resolved_direction := (resolved_point - position).normalized()
		position = resolved_point
		velocity = resolved_direction * maxf(current_speed, 0.001)
		corner_stuck_score = 0.0
		corner_escape_cooldown = 0.15
		last_corner_hit_position = Vector2(INF, INF)
		_reset_direction_change_timer()
		return


func _attempt_player_hit(from_point: Vector2, to_point: Vector2, attack_radius: float) -> void:
	EnemyPlayerHitService.try_apply_hit(_get_base_player(), from_point, to_point, attack_radius)


func _get_base_player() -> Node:
	if is_instance_valid(base_player):
		return base_player
	base_player = get_node_or_null("../BasePlayer")
	return base_player


func _get_base_boss() -> Node2D:
	if is_instance_valid(base_boss):
		return base_boss
	base_boss = get_node_or_null("../BBOS") as Node2D
	return base_boss

func _resolve_boss_collision(safe_radius: float, safe_epsilon: float) -> void:
	var boss := _get_base_boss()
	if !is_instance_valid(boss):
		return

	var minor_radius := _get_effective_collision_radius()
	var boss_radius := 32.0
	if boss.has_method("get_enemy_collision_radius"):
		boss_radius = maxf(float(boss.call("get_enemy_collision_radius")), 0.0)
	elif boss.has_method("get_logical_capture_radius"):
		boss_radius = maxf(float(boss.call("get_logical_capture_radius")), 0.0)

	var boss_position := boss.position
	var offset := position - boss_position
	var distance := offset.length()
	var contact_distance := minor_radius + boss_radius
	if distance >= contact_distance:
		return

	var normal := Vector2.ZERO
	if distance <= 0.0001:
		if velocity.length_squared() > 0.0001:
			normal = -velocity.normalized()
		else:
			normal = Vector2.RIGHT
	else:
		normal = offset / distance

	position = boss_position + normal * contact_distance
	position = _ensure_position_inside_active_boundary(position, safe_radius, safe_epsilon)
	velocity = _reflect_velocity(velocity, normal)
	_reset_direction_change_timer()
