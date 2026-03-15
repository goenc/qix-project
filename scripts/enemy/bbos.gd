extends Node2D

const HALF_SIZE := Vector2(32.0, 32.0)

@export var move_speed: float = 140.0
@export var direction_change_interval_min: float = 1.5
@export var direction_change_interval_max: float = 3.0
@export var bounce_epsilon: float = 0.5

@onready var pick_area: Area2D = $PickArea

var playfield_rect: Rect2 = Rect2()
var rng := RandomNumberGenerator.new()
var has_spawned := false
var velocity := Vector2.ZERO
var direction_change_timer := 0.0


func _ready() -> void:
	rng.randomize()
	if is_instance_valid(pick_area):
		pick_area.set_meta(&"debug_pick_owner", self)
	_reset_direction_change_timer()
	_pick_new_velocity()


func _process(delta: float) -> void:
	if playfield_rect.size.x <= 0.0 or playfield_rect.size.y <= 0.0:
		return

	direction_change_timer -= delta
	if direction_change_timer <= 0.0:
		_pick_new_velocity()
		_reset_direction_change_timer()

	position += velocity * delta
	var spawnable_rect := _get_spawnable_rect(playfield_rect)
	var reflected_state := _reflect_in_rect(position, velocity, spawnable_rect)
	position = reflected_state["position"]
	velocity = reflected_state["velocity"]


func set_playfield_rect(rect: Rect2) -> void:
	playfield_rect = rect.abs()
	if playfield_rect.size.x <= 0.0 or playfield_rect.size.y <= 0.0:
		return

	var spawnable_rect := _get_spawnable_rect(playfield_rect)
	if !has_spawned:
		position = _pick_random_point(spawnable_rect)
		has_spawned = true
		return

	if !_rect_has_point(spawnable_rect, position):
		position = _clamp_point_to_rect(position, spawnable_rect)


func _get_spawnable_rect(rect: Rect2) -> Rect2:
	var min_x := rect.position.x + HALF_SIZE.x
	var max_x := rect.end.x - HALF_SIZE.x
	var min_y := rect.position.y + HALF_SIZE.y
	var max_y := rect.end.y - HALF_SIZE.y

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


func _reflect_in_rect(point: Vector2, current_velocity: Vector2, rect: Rect2) -> Dictionary:
	var reflected_point := point
	var reflected_velocity := current_velocity

	if reflected_point.x < rect.position.x:
		reflected_point.x = _push_inside_rect_axis(rect.position.x, rect.end.x, true)
		reflected_velocity.x = absf(reflected_velocity.x)
	elif reflected_point.x > rect.end.x:
		reflected_point.x = _push_inside_rect_axis(rect.position.x, rect.end.x, false)
		reflected_velocity.x = -absf(reflected_velocity.x)

	if reflected_point.y < rect.position.y:
		reflected_point.y = _push_inside_rect_axis(rect.position.y, rect.end.y, true)
		reflected_velocity.y = absf(reflected_velocity.y)
	elif reflected_point.y > rect.end.y:
		reflected_point.y = _push_inside_rect_axis(rect.position.y, rect.end.y, false)
		reflected_velocity.y = -absf(reflected_velocity.y)

	reflected_point = _clamp_point_to_rect(reflected_point, rect)

	return {
		"position": reflected_point,
		"velocity": reflected_velocity
	}


func _push_inside_rect_axis(min_value: float, max_value: float, from_min_side: bool) -> float:
	if min_value >= max_value:
		return min_value
	if from_min_side:
		return minf(min_value + bounce_epsilon, max_value)
	return maxf(max_value - bounce_epsilon, min_value)
