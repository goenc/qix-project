extends Node2D
class_name BasePlayer

@export var move_speed := 240.0
@export var half_extent := Vector2(12.0, 12.0)
@export var trail_point_min_distance := 8.0
@export var safe_color := Color(1.0, 1.0, 1.0, 1.0)
@export var drawing_color := Color(1.0, 0.45, 0.2, 1.0)

@onready var body: Polygon2D = $Body
@onready var pick_area: Area2D = $PickArea
@onready var trail_line: Line2D = $TrailLine

enum MoveState {
	SAFE,
	DRAWING
}

var playfield_rect := Rect2()
var move_state: MoveState = MoveState.SAFE
var trail_points: PackedVector2Array = PackedVector2Array()
var has_left_boundary := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	if is_instance_valid(pick_area):
		pick_area.set_meta(&"debug_pick_owner", self)
	if is_instance_valid(trail_line):
		trail_line.top_level = true
		trail_line.global_position = Vector2.ZERO
		trail_line.points = PackedVector2Array()
	_apply_state_visuals()


func set_playfield(rect: Rect2) -> void:
	playfield_rect = rect.abs()
	if playfield_rect.size.x <= 0.0 or playfield_rect.size.y <= 0.0:
		return
	if position == Vector2.ZERO:
		position = Vector2(playfield_rect.get_center().x, playfield_rect.position.y)
	else:
		position = _project_to_boundary(position)
	if move_state == MoveState.DRAWING:
		move_state = MoveState.SAFE
	_apply_state_visuals()
	_clamp_to_viewport()


func _process(delta: float) -> void:
	if playfield_rect.size.x <= 0.0 or playfield_rect.size.y <= 0.0:
		return

	var direction := Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_up", "move_down")
	)
	if direction.length_squared() > 1.0:
		direction = direction.normalized()

	match move_state:
		MoveState.SAFE:
			_process_safe(direction, delta)
		MoveState.DRAWING:
			_process_drawing(direction, delta)

	_clamp_to_viewport()


func get_state_text() -> String:
	if move_state == MoveState.DRAWING:
		return "DRAWING"
	if trail_points.size() >= 2:
		return "TRAIL_READY"
	return "SAFE"


func _process_safe(direction: Vector2, delta: float) -> void:
	position += direction * move_speed * delta
	position = _project_to_boundary(position)

	if Input.is_action_just_pressed("qix_draw") and _is_on_boundary(position):
		_start_drawing()


func _process_drawing(direction: Vector2, delta: float) -> void:
	position += direction * move_speed * delta
	position = _clamp_to_playfield(position)

	_append_trail_point_if_needed(false)
	if !has_left_boundary and !_is_on_boundary(position):
		has_left_boundary = true

	if has_left_boundary and _is_on_boundary(position):
		_finish_drawing()


func _start_drawing() -> void:
	move_state = MoveState.DRAWING
	has_left_boundary = false
	trail_points = PackedVector2Array([position])
	_update_trail_line()
	_apply_state_visuals()


func _finish_drawing() -> void:
	_append_trail_point_if_needed(true)
	move_state = MoveState.SAFE
	position = _project_to_boundary(position)
	_apply_state_visuals()


func _append_trail_point_if_needed(force_add: bool) -> void:
	if trail_points.is_empty():
		trail_points.append(position)
		_update_trail_line()
		return

	var last_point: Vector2 = trail_points[trail_points.size() - 1]
	if force_add or last_point.distance_to(position) >= trail_point_min_distance:
		trail_points.append(position)
		_update_trail_line()


func _update_trail_line() -> void:
	if is_instance_valid(trail_line):
		trail_line.points = trail_points


func _apply_state_visuals() -> void:
	if is_instance_valid(body):
		body.color = drawing_color if move_state == MoveState.DRAWING else safe_color


func _clamp_to_viewport() -> void:
	var viewport_rect := get_viewport_rect()
	position = Vector2(
		clampf(position.x, viewport_rect.position.x + half_extent.x, viewport_rect.end.x - half_extent.x),
		clampf(position.y, viewport_rect.position.y + half_extent.y, viewport_rect.end.y - half_extent.y)
	)

	if playfield_rect.size.x <= 0.0 or playfield_rect.size.y <= 0.0:
		return

	if move_state == MoveState.SAFE:
		position = _project_to_boundary(position)
	else:
		position = _clamp_to_playfield(position)


func _clamp_to_playfield(point: Vector2) -> Vector2:
	return Vector2(
		clampf(point.x, playfield_rect.position.x, playfield_rect.end.x),
		clampf(point.y, playfield_rect.position.y, playfield_rect.end.y)
	)


func _project_to_boundary(point: Vector2) -> Vector2:
	var clamped := _clamp_to_playfield(point)
	var left_dist := absf(clamped.x - playfield_rect.position.x)
	var right_dist := absf(playfield_rect.end.x - clamped.x)
	var top_dist := absf(clamped.y - playfield_rect.position.y)
	var bottom_dist := absf(playfield_rect.end.y - clamped.y)
	var nearest := minf(minf(left_dist, right_dist), minf(top_dist, bottom_dist))

	if is_equal_approx(nearest, left_dist):
		clamped.x = playfield_rect.position.x
	elif is_equal_approx(nearest, right_dist):
		clamped.x = playfield_rect.end.x
	elif is_equal_approx(nearest, top_dist):
		clamped.y = playfield_rect.position.y
	else:
		clamped.y = playfield_rect.end.y
	return clamped


func _is_on_boundary(point: Vector2) -> bool:
	var tolerance := 0.5
	return (
		absf(point.x - playfield_rect.position.x) <= tolerance
		or absf(point.x - playfield_rect.end.x) <= tolerance
		or absf(point.y - playfield_rect.position.y) <= tolerance
		or absf(point.y - playfield_rect.end.y) <= tolerance
	)
