extends Node2D
class_name BasePlayer

@export var move_speed := 240.0
@export var border_epsilon := 2.0
@export var trail_min_point_distance := 8.0
@export var border_color := Color(1.0, 1.0, 1.0, 1.0)
@export var drawing_color := Color(1.0, 0.45, 0.2, 1.0)
@export var start_edge_ratio := 0.18

@onready var body: Polygon2D = $Body
@onready var pick_area: Area2D = $PickArea
@onready var trail_line: Line2D = $TrailLine

enum PlayerState {
	BORDER,
	DRAWING
}

var playfield_rect: Rect2 = Rect2()
var state: int = PlayerState.BORDER
var trail_points: PackedVector2Array = PackedVector2Array()
var has_left_border: bool = false
var border_progress := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	if is_instance_valid(pick_area):
		pick_area.set_meta(&"debug_pick_owner", self)
	if is_instance_valid(trail_line):
		trail_line.top_level = true
		trail_line.global_position = Vector2.ZERO
		trail_line.points = PackedVector2Array()
	_apply_state_visuals()


func set_playfield_rect(rect: Rect2) -> void:
	playfield_rect = rect.abs()
	if playfield_rect.size.x <= 0.0 or playfield_rect.size.y <= 0.0:
		return
	if position == Vector2.ZERO or !_is_inside_or_on_playfield(position):
		position = Vector2(
			playfield_rect.position.x + playfield_rect.size.x * start_edge_ratio,
			playfield_rect.position.y
		)
		position = _snap_point_to_border(position)
	elif state == PlayerState.DRAWING:
		position = _clamp_to_playfield(position)
	else:
		position = _snap_point_to_border(position)
	border_progress = _point_to_border_progress(position)
	_apply_state_visuals()
	_apply_movement_constraints()


func set_playfield(rect: Rect2) -> void:
	set_playfield_rect(rect)


func _process(delta: float) -> void:
	if playfield_rect.size.x <= 0.0 or playfield_rect.size.y <= 0.0:
		return

	var direction := Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_up", "move_down")
	)
	if direction.length_squared() > 1.0:
		direction = direction.normalized()

	match state:
		PlayerState.BORDER:
			_process_border(direction, delta)
		PlayerState.DRAWING:
			_process_drawing(direction, delta)

	_apply_movement_constraints()


func get_state_text() -> String:
	return "DRAWING" if state == PlayerState.DRAWING else "BORDER"


func get_debug_status() -> Dictionary:
	return {
		"mode_text": get_state_text(),
		"state": get_state_text(),
		"position": position,
		"is_on_border": _is_on_border(position),
		"trail_point_count": trail_points.size()
	}


func _process_border(direction: Vector2, delta: float) -> void:
	_move_along_border(direction, delta)
	if Input.is_action_just_pressed("qix_draw") and _is_on_border(position):
		_start_drawing()


func _process_drawing(direction: Vector2, delta: float) -> void:
	var current_position := position
	var next_position := _clamp_to_playfield(position + direction * move_speed * delta)
	var is_waiting_to_leave_border := !has_left_border and _is_on_border(current_position)
	var should_block_border_movement := is_waiting_to_leave_border and _is_on_border(next_position)

	if !should_block_border_movement:
		position = next_position

	_append_trail_point_if_needed(false)
	if !has_left_border and !_is_on_border(position):
		has_left_border = true

	if has_left_border and _is_on_border(position):
		_finish_drawing()


func _start_drawing() -> void:
	state = PlayerState.DRAWING
	has_left_border = false
	position = _snap_point_to_border(position)
	border_progress = _point_to_border_progress(position)
	trail_points = PackedVector2Array()
	trail_points.append(position)
	_update_trail_line()
	_apply_state_visuals()


func _finish_drawing() -> void:
	position = _snap_point_to_border(position)
	_append_trail_point_if_needed(true)
	border_progress = _point_to_border_progress(position)
	state = PlayerState.BORDER
	_apply_state_visuals()


func _append_trail_point_if_needed(force_add: bool) -> void:
	if trail_points.is_empty():
		trail_points.append(position)
		_update_trail_line()
		return

	var last_point: Vector2 = trail_points[trail_points.size() - 1]
	if force_add or last_point.distance_to(position) >= trail_min_point_distance:
		trail_points.append(position)
		_update_trail_line()


func _update_trail_line() -> void:
	if is_instance_valid(trail_line):
		trail_line.points = trail_points


func _apply_state_visuals() -> void:
	if is_instance_valid(body):
		body.color = drawing_color if state == PlayerState.DRAWING else border_color


func _apply_movement_constraints() -> void:
	if playfield_rect.size.x <= 0.0 or playfield_rect.size.y <= 0.0:
		return

	if state == PlayerState.DRAWING:
		position = _clamp_to_playfield(position)
	else:
		position = _snap_point_to_border(position)
		border_progress = _point_to_border_progress(position)


func _clamp_to_playfield(point: Vector2) -> Vector2:
	return Vector2(
		clampf(point.x, playfield_rect.position.x, playfield_rect.end.x),
		clampf(point.y, playfield_rect.position.y, playfield_rect.end.y)
	)


func _snap_point_to_border(point: Vector2) -> Vector2:
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


func _is_on_border(point: Vector2) -> bool:
	var clamped := _clamp_to_playfield(point)
	if clamped.distance_to(point) > border_epsilon:
		return false
	return (
		absf(clamped.x - playfield_rect.position.x) <= border_epsilon
		or absf(clamped.x - playfield_rect.end.x) <= border_epsilon
		or absf(clamped.y - playfield_rect.position.y) <= border_epsilon
		or absf(clamped.y - playfield_rect.end.y) <= border_epsilon
	)


func _move_along_border(direction: Vector2, delta: float) -> void:
	var cw_dir := _border_tangent_cw(border_progress + 0.01)
	var ccw_dir := _border_tangent_ccw(border_progress - 0.01)
	var cw_amount := maxf(0.0, direction.dot(cw_dir))
	var ccw_amount := maxf(0.0, direction.dot(ccw_dir))

	if cw_amount <= 0.0 and ccw_amount <= 0.0:
		position = _border_progress_to_point(border_progress)
		return

	var step := move_speed * delta
	if cw_amount >= ccw_amount:
		border_progress = _wrap_border_progress(border_progress + step * cw_amount)
	else:
		border_progress = _wrap_border_progress(border_progress - step * ccw_amount)
	position = _border_progress_to_point(border_progress)


func _point_to_border_progress(point: Vector2) -> float:
	var snapped := _snap_point_to_border(point)
	var left := playfield_rect.position.x
	var top := playfield_rect.position.y
	var width := playfield_rect.size.x
	var height := playfield_rect.size.y
	var right := playfield_rect.end.x
	var bottom := playfield_rect.end.y

	if absf(snapped.y - top) <= border_epsilon:
		return clampf(snapped.x - left, 0.0, width)
	if absf(snapped.x - right) <= border_epsilon:
		return width + clampf(snapped.y - top, 0.0, height)
	if absf(snapped.y - bottom) <= border_epsilon:
		return width + height + clampf(right - snapped.x, 0.0, width)
	return width + height + width + clampf(bottom - snapped.y, 0.0, height)


func _border_progress_to_point(progress: float) -> Vector2:
	var left := playfield_rect.position.x
	var top := playfield_rect.position.y
	var width := playfield_rect.size.x
	var height := playfield_rect.size.y
	var right := playfield_rect.end.x
	var bottom := playfield_rect.end.y
	var t := _wrap_border_progress(progress)

	if t <= width:
		return Vector2(left + t, top)
	t -= width
	if t <= height:
		return Vector2(right, top + t)
	t -= height
	if t <= width:
		return Vector2(right - t, bottom)
	t -= width
	return Vector2(left, bottom - minf(t, height))


func _border_tangent_cw(progress: float) -> Vector2:
	var width := playfield_rect.size.x
	var height := playfield_rect.size.y
	var t := _wrap_border_progress(progress)

	if t < width:
		return Vector2.RIGHT
	t -= width
	if t < height:
		return Vector2.DOWN
	t -= height
	if t < width:
		return Vector2.LEFT
	return Vector2.UP


func _border_tangent_ccw(progress: float) -> Vector2:
	return -_border_tangent_cw(progress)


func _perimeter_length() -> float:
	return playfield_rect.size.x * 2.0 + playfield_rect.size.y * 2.0


func _wrap_border_progress(progress: float) -> float:
	var perimeter := _perimeter_length()
	if perimeter <= 0.0:
		return 0.0
	var wrapped := fmod(progress, perimeter)
	if wrapped < 0.0:
		wrapped += perimeter
	return wrapped


func _is_inside_or_on_playfield(point: Vector2) -> bool:
	var clamped := _clamp_to_playfield(point)
	return clamped.distance_to(point) <= border_epsilon
