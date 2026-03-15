extends Node2D

const HALF_SIZE := Vector2(32.0, 32.0)

@onready var pick_area: Area2D = $PickArea

var playfield_rect: Rect2 = Rect2()
var rng := RandomNumberGenerator.new()
var has_spawned := false


func _ready() -> void:
	rng.randomize()
	if is_instance_valid(pick_area):
		pick_area.set_meta(&"debug_pick_owner", self)


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
