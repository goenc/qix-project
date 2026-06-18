extends RefCounted
class_name PlayerBorderInputService

const PlayfieldBoundary = preload("res://scripts/game/playfield_boundary.gd")


static func resolve_move_input(
	direction: Vector2,
	point: Vector2,
	loop: PackedVector2Array,
	epsilon: float,
	metrics: Dictionary = {}
) -> Vector2:
	if direction == Vector2.ZERO or !PlayfieldBoundary.is_point_on_loop(loop, point, epsilon, metrics):
		return Vector2.ZERO

	var connected_directions := get_connected_direction_vectors(point, loop, epsilon, metrics)
	for candidate in build_input_direction_candidates(direction):
		for connected_direction in connected_directions:
			if connected_direction.is_equal_approx(candidate):
				return candidate
	return Vector2.ZERO


static func build_input_direction_candidates(direction: Vector2) -> Array[Vector2]:
	var candidates: Array[Vector2] = []
	var horizontal_direction := Vector2.ZERO
	var vertical_direction := Vector2.ZERO
	if absf(direction.x) > 0.01:
		horizontal_direction = Vector2(signf(direction.x), 0.0)
	if absf(direction.y) > 0.01:
		vertical_direction = Vector2(0.0, signf(direction.y))

	if horizontal_direction != Vector2.ZERO and vertical_direction != Vector2.ZERO:
		if absf(direction.x) >= absf(direction.y):
			candidates.append(horizontal_direction)
			candidates.append(vertical_direction)
		else:
			candidates.append(vertical_direction)
			candidates.append(horizontal_direction)
	elif horizontal_direction != Vector2.ZERO:
		candidates.append(horizontal_direction)
	elif vertical_direction != Vector2.ZERO:
		candidates.append(vertical_direction)
	return candidates


static func get_connected_directions(
	point: Vector2,
	loop: PackedVector2Array,
	epsilon: float,
	metrics: Dictionary = {}
) -> Array[Dictionary]:
	if !PlayfieldBoundary.is_point_on_loop(loop, point, epsilon, metrics):
		return [] as Array[Dictionary]
	return PlayfieldBoundary.get_connected_directions_at_point(loop, point, epsilon)


static func get_connected_direction_vectors(
	point: Vector2,
	loop: PackedVector2Array,
	epsilon: float,
	metrics: Dictionary = {}
) -> Array[Vector2]:
	var directions: Array[Vector2] = []
	for connection in get_connected_directions(point, loop, epsilon, metrics):
		var direction: Vector2 = connection.get("direction", Vector2.ZERO)
		if direction != Vector2.ZERO:
			directions.append(direction)
	return directions


static func get_connected_direction_names(
	point: Vector2,
	loop: PackedVector2Array,
	epsilon: float,
	metrics: Dictionary = {}
) -> Array[String]:
	var names: Array[String] = []
	for direction in get_connected_direction_vectors(point, loop, epsilon, metrics):
		var direction_name := get_direction_name(direction)
		if !direction_name.is_empty():
			names.append(direction_name)
	return names


static func is_corner(direction_names: Array[String]) -> bool:
	var has_horizontal := direction_names.has("left") or direction_names.has("right")
	var has_vertical := direction_names.has("up") or direction_names.has("down")
	return has_horizontal and has_vertical


static func get_direction_name(direction: Vector2) -> String:
	if direction == Vector2.LEFT:
		return "left"
	if direction == Vector2.RIGHT:
		return "right"
	if direction == Vector2.UP:
		return "up"
	if direction == Vector2.DOWN:
		return "down"
	return ""
