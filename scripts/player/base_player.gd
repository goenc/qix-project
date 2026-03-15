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
	DRAWING,
	REWINDING
}

var playfield_rect: Rect2 = Rect2()
var state: int = PlayerState.BORDER
var trail_points: PackedVector2Array = PackedVector2Array()
var has_left_border: bool = false
var border_progress := 0.0
var rewind_speed := move_speed
var rewind_index: int = -1
var drawing_input_sequence: int = 0
var drawing_input_order: Dictionary = {
	&"move_left": 0,
	&"move_right": 0,
	&"move_up": 0,
	&"move_down": 0
}
var drawing_move_direction: Vector2 = Vector2.ZERO
var drawing_segment_direction: Vector2 = Vector2.ZERO


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
	elif state == PlayerState.DRAWING or state == PlayerState.REWINDING:
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

	_update_drawing_input_order()
	var direction := Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_up", "move_down")
	)
	var drawing_direction := _restrict_drawing_direction(direction)
	if direction.length_squared() > 1.0:
		direction = direction.normalized()

	match state:
		PlayerState.BORDER:
			_process_border(direction, delta)
		PlayerState.DRAWING:
			_process_drawing(drawing_direction, delta)
		PlayerState.REWINDING:
			_process_rewinding(delta)

	_apply_movement_constraints()


func get_state_text() -> String:
	match state:
		PlayerState.DRAWING:
			return "DRAWING"
		PlayerState.REWINDING:
			return "REWINDING"
		_:
			return "BORDER"


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
	if !Input.is_action_pressed("qix_draw"):
		_start_rewinding()
		return

	var drawing_direction := _restrict_drawing_backtracking(direction)
	var current_position := position
	var next_position := _clamp_to_playfield(current_position + drawing_direction * move_speed * delta)
	var is_waiting_to_leave_border := !has_left_border and _is_on_border(current_position)
	var should_block_border_movement := is_waiting_to_leave_border and _is_on_border(next_position)
	var trail_contact := {"hit": false}

	if !should_block_border_movement:
		trail_contact = _find_first_trail_contact(current_position, next_position)
		if bool(trail_contact.get("hit", false)):
			next_position = trail_contact["point"]

	if !should_block_border_movement and current_position.distance_to(next_position) > border_epsilon:
		_update_drawing_segment(drawing_direction, current_position)
		position = next_position

	_append_trail_point_if_needed(false)
	if !has_left_border and !_is_on_border(position):
		has_left_border = true

	if has_left_border and _is_on_border(position):
		_finish_drawing()


func _start_drawing() -> void:
	state = PlayerState.DRAWING
	has_left_border = false
	rewind_index = -1
	drawing_move_direction = Vector2.ZERO
	drawing_segment_direction = Vector2.ZERO
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
	drawing_move_direction = Vector2.ZERO
	drawing_segment_direction = Vector2.ZERO
	state = PlayerState.BORDER
	trail_points = PackedVector2Array()
	has_left_border = false
	rewind_index = -1
	_update_trail_line()
	_apply_state_visuals()


func _start_rewinding() -> void:
	rewind_speed = move_speed
	_ensure_trail_endpoint(position)

	drawing_move_direction = Vector2.ZERO
	drawing_segment_direction = Vector2.ZERO
	state = PlayerState.REWINDING
	position = trail_points[trail_points.size() - 1]
	rewind_index = trail_points.size() - 2
	if trail_points.size() <= 1:
		_finish_rewinding()
		return

	_update_trail_line()
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


func _update_drawing_input_order() -> void:
	_remember_drawing_input(&"move_left")
	_remember_drawing_input(&"move_right")
	_remember_drawing_input(&"move_up")
	_remember_drawing_input(&"move_down")


func _remember_drawing_input(action_name: StringName) -> void:
	if !Input.is_action_just_pressed(action_name):
		return

	drawing_input_sequence += 1
	drawing_input_order[action_name] = drawing_input_sequence


func _restrict_drawing_direction(_direction: Vector2) -> Vector2:
	var horizontal := _get_prioritized_axis(&"move_left", &"move_right")
	var vertical := _get_prioritized_axis(&"move_up", &"move_down")

	if horizontal != 0.0 and vertical != 0.0:
		if _get_axis_input_order(&"move_left", &"move_right") >= _get_axis_input_order(&"move_up", &"move_down"):
			vertical = 0.0
		else:
			horizontal = 0.0

	return Vector2(horizontal, vertical)


func _get_prioritized_axis(negative_action: StringName, positive_action: StringName) -> float:
	var negative_pressed := Input.is_action_pressed(negative_action)
	var positive_pressed := Input.is_action_pressed(positive_action)
	if negative_pressed and positive_pressed:
		if int(drawing_input_order.get(negative_action, 0)) >= int(drawing_input_order.get(positive_action, 0)):
			return -1.0
		return 1.0
	if negative_pressed:
		return -1.0
	if positive_pressed:
		return 1.0
	return 0.0


func _get_axis_input_order(negative_action: StringName, positive_action: StringName) -> int:
	var order := 0
	if Input.is_action_pressed(negative_action):
		order = max(order, int(drawing_input_order.get(negative_action, 0)))
	if Input.is_action_pressed(positive_action):
		order = max(order, int(drawing_input_order.get(positive_action, 0)))
	return order


func _restrict_drawing_backtracking(direction: Vector2) -> Vector2:
	if direction == Vector2.ZERO or drawing_move_direction == Vector2.ZERO:
		return direction
	if direction.dot(drawing_move_direction) < 0.0:
		return Vector2.ZERO
	return direction


func _update_drawing_segment(direction: Vector2, current_position: Vector2) -> void:
	if direction == Vector2.ZERO:
		return
	drawing_move_direction = direction
	if drawing_segment_direction == Vector2.ZERO:
		drawing_segment_direction = direction
		return

	var axis_changed := (
		(direction.x != 0.0 and drawing_segment_direction.y != 0.0)
		or (direction.y != 0.0 and drawing_segment_direction.x != 0.0)
	)
	if axis_changed:
		_append_trail_corner_point(current_position)

	drawing_segment_direction = direction


func _append_trail_corner_point(point: Vector2) -> void:
	if trail_points.is_empty():
		trail_points.append(point)
		_update_trail_line()
		return

	var last_point: Vector2 = trail_points[trail_points.size() - 1]
	if !last_point.is_equal_approx(point):
		trail_points.append(point)
		_update_trail_line()


func _update_trail_line() -> void:
	if is_instance_valid(trail_line):
		trail_line.points = _build_visible_trail_points()


func _build_visible_trail_points() -> PackedVector2Array:
	var visible_points := PackedVector2Array()
	for point in trail_points:
		visible_points.append(point)

	if state == PlayerState.REWINDING:
		visible_points = PackedVector2Array()
		for i in range(rewind_index + 1):
			visible_points.append(trail_points[i])

	if (
		(state == PlayerState.DRAWING or state == PlayerState.REWINDING)
		and (visible_points.is_empty() or !visible_points[visible_points.size() - 1].is_equal_approx(position))
	):
		visible_points.append(position)

	return visible_points


func _process_rewinding(delta: float) -> void:
	if Input.is_action_just_pressed("qix_draw"):
		_interrupt_rewinding()
		return

	_process_rewinding_step(delta)
	_update_trail_line()


func _process_rewinding_step(delta: float) -> void:
	var target_point: Vector2 = trail_points[rewind_index]
	position = position.move_toward(target_point, rewind_speed * delta)
	if position.distance_to(target_point) <= border_epsilon:
		position = target_point
		rewind_index -= 1
		if rewind_index < 0:
			_finish_rewinding()
			return


func _interrupt_rewinding() -> void:
	var rebuilt_trail := PackedVector2Array()
	for i in range(rewind_index + 1):
		rebuilt_trail.append(trail_points[i])
	if rebuilt_trail.is_empty() or !rebuilt_trail[rebuilt_trail.size() - 1].is_equal_approx(position):
		rebuilt_trail.append(position)

	trail_points = rebuilt_trail
	state = PlayerState.DRAWING
	has_left_border = !_is_on_border(position)
	rewind_index = -1
	_update_drawing_segment_from_trail()
	_update_trail_line()
	_apply_state_visuals()


func _finish_rewinding() -> void:
	position = _snap_point_to_border(position)
	border_progress = _point_to_border_progress(position)
	trail_points = PackedVector2Array()
	rewind_index = -1
	has_left_border = false
	drawing_move_direction = Vector2.ZERO
	drawing_segment_direction = Vector2.ZERO
	state = PlayerState.BORDER
	_update_trail_line()
	_apply_state_visuals()


func _apply_state_visuals() -> void:
	if is_instance_valid(body):
		body.color = drawing_color if state == PlayerState.DRAWING or state == PlayerState.REWINDING else border_color


func _apply_movement_constraints() -> void:
	if playfield_rect.size.x <= 0.0 or playfield_rect.size.y <= 0.0:
		return

	if state == PlayerState.DRAWING or state == PlayerState.REWINDING:
		position = _clamp_to_playfield(position)
	else:
		position = _snap_point_to_border(position)
		border_progress = _point_to_border_progress(position)


func _ensure_trail_endpoint(point: Vector2) -> void:
	if trail_points.is_empty():
		trail_points.append(point)
		return

	var last_index := trail_points.size() - 1
	if trail_points[last_index].is_equal_approx(point):
		trail_points[last_index] = point
		return

	trail_points.append(point)


func _update_drawing_segment_from_trail() -> void:
	drawing_move_direction = Vector2.ZERO
	drawing_segment_direction = Vector2.ZERO
	if trail_points.size() < 2:
		return

	var last_segment := trail_points[trail_points.size() - 1] - trail_points[trail_points.size() - 2]
	if absf(last_segment.x) > absf(last_segment.y):
		drawing_segment_direction = Vector2(signf(last_segment.x), 0.0)
		drawing_move_direction = drawing_segment_direction
	elif absf(last_segment.y) > 0.0:
		drawing_segment_direction = Vector2(0.0, signf(last_segment.y))
		drawing_move_direction = drawing_segment_direction


func _find_first_trail_contact(from_point: Vector2, to_point: Vector2) -> Dictionary:
	if from_point.distance_to(to_point) <= border_epsilon:
		return {"hit": false}

	var visible_points := _build_visible_trail_points()
	if visible_points.size() < 2:
		return {"hit": false}

	var last_segment_index := visible_points.size() - 2
	var best_contact := {"hit": false}
	for i in range(visible_points.size() - 1):
		var segment_start: Vector2 = visible_points[i]
		var segment_end: Vector2 = visible_points[i + 1]
		var allow_shared_start := (
			i == last_segment_index
			and (segment_start.distance_to(from_point) <= border_epsilon or segment_end.distance_to(from_point) <= border_epsilon)
		)
		var contact := _find_segment_contact_point(
			from_point,
			to_point,
			segment_start,
			segment_end,
			allow_shared_start
		)
		if !bool(contact.get("hit", false)):
			continue
		if (
			!bool(best_contact.get("hit", false))
			or float(contact["distance"]) < float(best_contact["distance"]) - border_epsilon
		):
			best_contact = contact

	return best_contact


func _would_cross_existing_trail(from_point: Vector2, to_point: Vector2) -> bool:
	return bool(_find_first_trail_contact(from_point, to_point).get("hit", false))


func _find_segment_contact_point(
	a0: Vector2,
	a1: Vector2,
	b0: Vector2,
	b1: Vector2,
	allow_shared_start := false
) -> Dictionary:
	var a_is_horizontal := absf(a0.y - a1.y) <= border_epsilon
	var a_is_vertical := absf(a0.x - a1.x) <= border_epsilon
	var b_is_horizontal := absf(b0.y - b1.y) <= border_epsilon
	var b_is_vertical := absf(b0.x - b1.x) <= border_epsilon

	if (a_is_horizontal and b_is_horizontal) or (a_is_vertical and b_is_vertical):
		var a_fixed := a0.y if a_is_horizontal else a0.x
		var b_fixed := b0.y if b_is_horizontal else b0.x
		if absf(a_fixed - b_fixed) > border_epsilon:
			return {"hit": false}

		var a_start := a0.x if a_is_horizontal else a0.y
		var a_end := a1.x if a_is_horizontal else a1.y
		var b_min := minf(b0.x, b1.x) if b_is_horizontal else minf(b0.y, b1.y)
		var b_max := maxf(b0.x, b1.x) if b_is_horizontal else maxf(b0.y, b1.y)
		var a_min := minf(a_start, a_end)
		var a_max := maxf(a_start, a_end)
		var overlap_start := maxf(a_min, b_min)
		var overlap_end := minf(a_max, b_max)

		if overlap_end < overlap_start - border_epsilon:
			return {"hit": false}

		if allow_shared_start:
			var shared_value := a_start
			if absf(overlap_end - overlap_start) <= border_epsilon and absf(overlap_start - shared_value) <= border_epsilon:
				return {"hit": false}

		var contact_axis := overlap_start if a_end >= a_start else overlap_end
		var contact_point := (
			Vector2(contact_axis, a0.y)
			if a_is_horizontal
			else Vector2(a0.x, contact_axis)
		)
		return _make_trail_contact(a0, contact_point)

	if !(a_is_horizontal and b_is_vertical) and !(a_is_vertical and b_is_horizontal):
		return {"hit": false}

	var horizontal_start := a0 if a_is_horizontal else b0
	var horizontal_end := a1 if a_is_horizontal else b1
	var vertical_start := b0 if a_is_horizontal else a0
	var vertical_end := b1 if a_is_horizontal else a1
	var intersection_point := Vector2(vertical_start.x, horizontal_start.y)

	if !_is_value_in_axis_range(intersection_point.x, horizontal_start.x, horizontal_end.x):
		return {"hit": false}
	if !_is_value_in_axis_range(intersection_point.y, vertical_start.y, vertical_end.y):
		return {"hit": false}

	if allow_shared_start and intersection_point.distance_to(a0) <= border_epsilon:
		return {"hit": false}

	return _make_trail_contact(a0, intersection_point)


func _segments_intersect_or_touch(
	a0: Vector2,
	a1: Vector2,
	b0: Vector2,
	b1: Vector2,
	allow_shared_start := false
) -> bool:
	return bool(_find_segment_contact_point(a0, a1, b0, b1, allow_shared_start).get("hit", false))


func _make_trail_contact(from_point: Vector2, point: Vector2) -> Dictionary:
	return {
		"hit": true,
		"point": point,
		"distance": from_point.distance_to(point)
	}


func _is_value_in_axis_range(value: float, range_start: float, range_end: float) -> bool:
	var minimum := minf(range_start, range_end) - border_epsilon
	var maximum := maxf(range_start, range_end) + border_epsilon
	return value >= minimum and value <= maximum


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
