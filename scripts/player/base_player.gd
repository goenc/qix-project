extends Node2D
class_name BasePlayer

const PlayfieldBoundary = preload("res://scripts/game/playfield_boundary.gd")
const ACTION_QIX_DRAW := &"qix_draw"

signal capture_closed(trail_points: PackedVector2Array)
signal guide_turn_created(turn_point: Vector2, previous_direction: Vector2, new_direction: Vector2)
signal hp_changed(current_hp: int, max_hp: int)
signal defeated()
signal debug_status_changed(status: Dictionary)
signal debug_position_changed(world_position: Vector2)
signal capture_preview_changed(active: bool)

@export var move_speed := 240.0
@export var border_epsilon := 2.0
@export var trail_min_point_distance := 8.0
@export var border_color := Color(1.0, 1.0, 1.0, 1.0)
@export var drawing_color := Color(1.0, 0.45, 0.2, 1.0)
@export var start_edge_ratio := 0.18
@export var max_hp := 3
@export var invincibility_duration := 0.75

@onready var body: Polygon2D = $Body
@onready var pick_area: Area2D = $PickArea
@onready var pick_collision_shape: CollisionShape2D = $PickArea/CollisionShape2D
@onready var trail_line: Line2D = $TrailLine

enum PlayerState {
	BORDER,
	DRAWING,
	REWINDING
}

enum BossHitRisk {
	NONE,
	PLAYER_ONLY,
	PLAYER_AND_TRAIL
}

var playfield_rect: Rect2 = Rect2()
var active_outer_loop: PackedVector2Array = PackedVector2Array()
var outer_loop_metrics: Dictionary = {}
var outer_loop_lengths: PackedFloat32Array = PackedFloat32Array()
var outer_loop_starts: PackedFloat32Array = PackedFloat32Array()
var outer_loop_total_length := 0.0
var remaining_polygon: PackedVector2Array = PackedVector2Array()
var state: int = PlayerState.BORDER
var trail_points: PackedVector2Array = PackedVector2Array()
var has_left_border := false
var border_progress := 0.0
var current_border_segment_index: int = 0
var border_distance_on_segment := 0.0
var queued_border_segment_index: int = -1
var queued_border_vertex_index: int = -1
var queued_border_distance_on_segment := 0.0
var rewind_speed := move_speed
var rewind_index: int = -1
var drawing_input_sequence := 0
var drawing_input_order: Dictionary = {
	&"move_left": 0,
	&"move_right": 0,
	&"move_up": 0,
	&"move_down": 0
}
var drawing_move_direction := Vector2.ZERO
var drawing_segment_direction := Vector2.ZERO
var current_hp := 0
var invincibility_timer := 0.0
var is_defeated := false
var is_draw_action_configured := true
var last_debug_status_snapshot: Dictionary = {}
var last_debug_position_snapshot := Vector2.ZERO
var has_last_debug_position_snapshot := false
var last_capture_preview_active := false
var active_damage_trail_segments: Array[PackedVector2Array] = []
var active_damage_trail_aabbs: Array[Rect2] = []
var last_visible_trail_cache_points: PackedVector2Array = PackedVector2Array()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	current_hp = get_max_hp()
	is_draw_action_configured = InputMap.has_action(ACTION_QIX_DRAW)
	if !is_draw_action_configured:
		push_error("Missing InputMap action '%s'. Register Shift and PAD-A to '%s' before starting gameplay." % [String(ACTION_QIX_DRAW), String(ACTION_QIX_DRAW)])
		set_process(false)
	if is_instance_valid(pick_area):
		pick_area.set_meta(&"debug_pick_owner", self)
	if is_instance_valid(trail_line):
		trail_line.top_level = true
		trail_line.global_position = Vector2.ZERO
		trail_line.points = PackedVector2Array()
	_refresh_damage_trail_cache(PackedVector2Array())
	_apply_state_visuals()
	_update_damage_hitboxes()
	_refresh_debug_notifications(true)


func set_playfield_rect(rect: Rect2) -> void:
	playfield_rect = rect.abs()
	if playfield_rect.size.x <= 0.0 or playfield_rect.size.y <= 0.0:
		return

	if active_outer_loop.is_empty():
		set_active_outer_loop(PlayfieldBoundary.create_rect_loop(playfield_rect))

	if position == Vector2.ZERO:
		_sync_border_state_from_position(_snap_point_to_border(_get_default_spawn_point()))
	elif state == PlayerState.DRAWING or state == PlayerState.REWINDING:
		position = _limit_point_to_allowed_area(position)
	elif !_is_inside_or_on_playfield(position):
		_sync_border_state_from_position(_snap_point_to_border(_get_default_spawn_point()))
	else:
		_sync_border_state_from_position(_snap_point_to_border(position))

	_apply_state_visuals()
	_apply_movement_constraints()
	_refresh_debug_notifications()


func set_playfield(rect: Rect2) -> void:
	set_playfield_rect(rect)


func set_active_outer_loop(loop: PackedVector2Array) -> void:
	var sanitized_loop: PackedVector2Array = PlayfieldBoundary.sanitize_loop(loop)
	if sanitized_loop.size() < 3:
		return

	_assign_active_outer_loop(sanitized_loop)
	if position == Vector2.ZERO:
		_sync_border_state_from_position(_snap_point_to_border(_get_default_spawn_point()))
	elif state == PlayerState.DRAWING or state == PlayerState.REWINDING:
		position = _limit_point_to_allowed_area(position)
	else:
		_sync_border_state_from_position(_snap_point_to_border(position))

	_apply_movement_constraints()
	_refresh_debug_notifications()


func set_active_border(border_loop: PackedVector2Array, _allowed_polygon: PackedVector2Array = PackedVector2Array()) -> void:
	set_active_outer_loop(border_loop)


func _assign_active_outer_loop(loop: PackedVector2Array) -> void:
	active_outer_loop = loop
	remaining_polygon = active_outer_loop
	outer_loop_metrics = PlayfieldBoundary.build_loop_metrics(active_outer_loop)
	outer_loop_lengths = outer_loop_metrics.get("segment_lengths", PackedFloat32Array())
	outer_loop_starts = outer_loop_metrics.get("segment_starts", PackedFloat32Array())
	outer_loop_total_length = float(outer_loop_metrics.get("total_length", 0.0))


func _process(delta: float) -> void:
	if !is_draw_action_configured:
		return
	if playfield_rect.size.x <= 0.0 or playfield_rect.size.y <= 0.0 or outer_loop_total_length <= 0.0:
		return

	if invincibility_timer > 0.0:
		var previous_timer := invincibility_timer
		invincibility_timer = maxf(0.0, invincibility_timer - delta)
		if !is_equal_approx(previous_timer, invincibility_timer):
			_apply_state_visuals()

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
	_update_damage_hitboxes()
	_refresh_debug_notifications()


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
		"trail_point_count": trail_points.size(),
		"hp": current_hp,
		"max_hp": get_max_hp(),
		"invincible": invincibility_timer > 0.0
	}


func get_current_hp() -> int:
	return current_hp


func get_max_hp() -> int:
	return max(1, max_hp)


func is_dead() -> bool:
	return is_defeated


func get_boss_hit_targets() -> Dictionary:
	var on_border := _is_on_border(position)
	var draw_pressed := _is_draw_action_pressed()
	var risk_state := BossHitRisk.NONE
	var player_target := false
	var trail_target := false

	match state:
		PlayerState.DRAWING:
			if !on_border:
				risk_state = BossHitRisk.PLAYER_AND_TRAIL
				player_target = true
				trail_target = true
			elif draw_pressed:
				risk_state = BossHitRisk.PLAYER_ONLY
				player_target = true
		PlayerState.REWINDING:
			if !on_border or draw_pressed:
				risk_state = BossHitRisk.PLAYER_ONLY
				player_target = true
		_:
			if draw_pressed:
				risk_state = BossHitRisk.PLAYER_ONLY
				player_target = true

	var damage_blocked := _is_damage_blocked()
	return {
		"risk_state": risk_state,
		"player": player_target and !damage_blocked,
		"trail": trail_target and !damage_blocked,
		"on_border": on_border,
		"draw_pressed": draw_pressed,
		"invincible": invincibility_timer > 0.0
	}


func get_body_damage_rect() -> Rect2:
	if !is_instance_valid(pick_collision_shape):
		return Rect2(position, Vector2.ZERO)

	var rectangle_shape := pick_collision_shape.shape as RectangleShape2D
	if rectangle_shape == null:
		return Rect2(position, Vector2.ZERO)

	var center := pick_collision_shape.global_position
	var scale := pick_collision_shape.global_scale
	var size := Vector2(
		rectangle_shape.size.x * absf(scale.x),
		rectangle_shape.size.y * absf(scale.y)
	)
	return Rect2(center - size * 0.5, size)


func get_active_damage_trail_segments() -> Array[PackedVector2Array]:
	var targets := get_boss_hit_targets()
	if !bool(targets.get("trail", false)):
		var empty_segments: Array[PackedVector2Array] = []
		return empty_segments
	return active_damage_trail_segments


func get_active_damage_trail_data() -> Dictionary:
	return {
		"segments": active_damage_trail_segments,
		"aabbs": active_damage_trail_aabbs
	}


func apply_boss_damage() -> bool:
	if _is_damage_blocked():
		return false

	current_hp = max(current_hp - 1, 0)
	if current_hp <= 0:
		is_defeated = true
		invincibility_timer = 0.0
	else:
		invincibility_timer = maxf(invincibility_duration, 0.0)

	hp_changed.emit(current_hp, get_max_hp())
	_apply_state_visuals()
	_update_damage_hitboxes()
	_refresh_debug_notifications()
	if is_defeated:
		defeated.emit()
	return true


func _process_border(direction: Vector2, delta: float) -> void:
	_move_along_border(direction, delta)
	if _is_draw_action_just_pressed() and _can_start_drawing_from_border():
		_start_drawing()


func _process_drawing(direction: Vector2, delta: float) -> void:
	if !_is_draw_action_pressed():
		_start_rewinding()
		return

	var drawing_direction := _restrict_drawing_backtracking(direction)
	var current_position := position
	var next_position := _limit_drawing_position(
		current_position,
		current_position + drawing_direction * move_speed * delta
	)
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
	_clear_queued_border_transition()
	position = _snap_point_to_border(position)
	_sync_border_state_from_position(position)
	trail_points = PackedVector2Array()
	trail_points.append(position)
	_update_trail_line()
	_apply_state_visuals()


func _finish_drawing() -> void:
	position = _snap_point_to_border(position)
	_append_trail_point_if_needed(true)
	if trail_points.size() >= 2:
		capture_closed.emit(trail_points.duplicate())
	_sync_border_state_from_position(position)
	drawing_move_direction = Vector2.ZERO
	drawing_segment_direction = Vector2.ZERO
	_clear_queued_border_transition()
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
	_clear_queued_border_transition()
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
		if drawing_segment_direction != Vector2.ZERO:
			guide_turn_created.emit(current_position, drawing_segment_direction, direction)
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
	var visible_points := _build_visible_trail_points()
	if is_instance_valid(trail_line):
		trail_line.points = visible_points
	_refresh_damage_trail_cache_if_needed(visible_points)


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
	if _is_draw_action_just_pressed():
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
	_clear_queued_border_transition()
	state = PlayerState.DRAWING
	has_left_border = !_is_on_border(position)
	rewind_index = -1
	_update_drawing_segment_from_trail()
	_update_trail_line()
	_apply_state_visuals()


func _finish_rewinding() -> void:
	position = _snap_point_to_border(position)
	_sync_border_state_from_position(position)
	trail_points = PackedVector2Array()
	rewind_index = -1
	has_left_border = false
	drawing_move_direction = Vector2.ZERO
	drawing_segment_direction = Vector2.ZERO
	_clear_queued_border_transition()
	state = PlayerState.BORDER
	_update_trail_line()
	_apply_state_visuals()


func _apply_state_visuals() -> void:
	if is_instance_valid(body):
		var next_color := drawing_color if state == PlayerState.DRAWING or state == PlayerState.REWINDING else border_color
		if invincibility_timer > 0.0 and !is_defeated:
			next_color.a = 0.45
		body.color = next_color
	if is_instance_valid(trail_line):
		trail_line.modulate = Color(1.0, 1.0, 1.0, 0.55) if invincibility_timer > 0.0 and !is_defeated else Color.WHITE


func _apply_movement_constraints() -> void:
	if outer_loop_total_length <= 0.0:
		return

	if state == PlayerState.DRAWING or state == PlayerState.REWINDING:
		position = _limit_point_to_allowed_area(position)
	else:
		_clamp_border_state()
		position = _border_state_to_point()
		border_progress = _border_state_to_progress()


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


func _find_first_allowed_boundary_contact(from_point: Vector2, to_point: Vector2) -> Dictionary:
	if remaining_polygon.size() < 2:
		return {"hit": false}

	var best_contact := {"hit": false}
	for index in range(remaining_polygon.size()):
		var segment_start: Vector2 = remaining_polygon[index]
		var segment_end: Vector2 = remaining_polygon[(index + 1) % remaining_polygon.size()]
		var contact := _find_segment_contact_point(
			from_point,
			to_point,
			segment_start,
			segment_end,
			true
		)
		if !bool(contact.get("hit", false)):
			continue
		if (
			!bool(best_contact.get("hit", false))
			or float(contact["distance"]) < float(best_contact["distance"]) - border_epsilon
		):
			best_contact = contact

	return best_contact


func _limit_drawing_position(from_point: Vector2, desired_point: Vector2) -> Vector2:
	if from_point.distance_to(desired_point) <= border_epsilon:
		return desired_point

	var boundary_contact := _find_first_allowed_boundary_contact(from_point, desired_point)
	if bool(boundary_contact.get("hit", false)):
		return boundary_contact["point"]
	if _is_inside_or_on_playfield(desired_point):
		return desired_point
	return from_point


func _limit_point_to_allowed_area(point: Vector2) -> Vector2:
	if _is_inside_or_on_playfield(point):
		return point
	return _snap_point_to_border(point)


func _clamp_to_playfield(point: Vector2) -> Vector2:
	if outer_loop_total_length > 0.0:
		return _limit_point_to_allowed_area(point)
	if playfield_rect.size.x <= 0.0 or playfield_rect.size.y <= 0.0:
		return point
	return Vector2(
		clampf(point.x, playfield_rect.position.x, playfield_rect.end.x),
		clampf(point.y, playfield_rect.position.y, playfield_rect.end.y)
	)


func _snap_point_to_border(point: Vector2) -> Vector2:
	return _get_nearest_border_projection(point).get("point", point)


func _is_on_border(point: Vector2) -> bool:
	if outer_loop_total_length <= 0.0:
		return false
	if (
		state == PlayerState.BORDER
		and point.distance_to(position) <= border_epsilon
		and position.distance_to(_border_state_to_point()) <= border_epsilon
	):
		return true
	return PlayfieldBoundary.is_point_on_loop(active_outer_loop, point, border_epsilon, outer_loop_metrics)


func _can_start_drawing_from_border() -> bool:
	return state == PlayerState.BORDER and _is_border_state_consistent(position) and _is_on_border(position)


func _move_along_border(direction: Vector2, delta: float) -> void:
	if active_outer_loop.size() < 2:
		_clear_queued_border_transition()
		return

	_clamp_border_state()
	if direction == Vector2.ZERO:
		_clear_queued_border_transition()
		position = _border_state_to_point()
		border_progress = _border_state_to_progress()
		return

	var current_vertex_index: int = _get_current_border_vertex_index()
	if current_vertex_index >= 0:
		var selected_segment := _select_border_segment_at_vertex(current_vertex_index, direction)
		if bool(selected_segment.get("matched", false)):
			_apply_selected_border_segment(selected_segment)

	var segment_direction: Vector2 = PlayfieldBoundary.get_segment_direction(
		active_outer_loop,
		current_border_segment_index,
		border_epsilon
	)
	var forward_amount := maxf(0.0, direction.dot(segment_direction))
	var backward_amount := maxf(0.0, direction.dot(-segment_direction))
	if forward_amount <= 0.0 and backward_amount <= 0.0:
		_clear_queued_border_transition()
		position = _border_state_to_point()
		border_progress = _border_state_to_progress()
		return

	var move_sign := 1.0 if forward_amount >= backward_amount else -1.0
	var remaining_distance := move_speed * delta * (forward_amount if move_sign > 0.0 else backward_amount)
	var safe_epsilon := maxf(border_epsilon, PlayfieldBoundary.DEFAULT_EPSILON)
	var iteration_limit: int = maxi(32, active_outer_loop.size() * 8)
	var iteration: int = 0
	_update_queued_border_transition(direction, move_sign, safe_epsilon)
	while remaining_distance > safe_epsilon and iteration < iteration_limit:
		iteration += 1

		if _get_current_border_segment_length() <= safe_epsilon:
			var degenerate_vertex_index := _get_upcoming_border_vertex_index(move_sign)
			if degenerate_vertex_index < 0:
				break
			var degenerate_segment := _select_border_segment_at_vertex(degenerate_vertex_index, direction)
			if !bool(degenerate_segment.get("matched", false)):
				break
			_apply_selected_border_segment(degenerate_segment)
			_update_queued_border_transition(direction, move_sign, safe_epsilon)
			continue

		var move_result := _consume_current_border_segment(move_sign, remaining_distance, safe_epsilon)
		remaining_distance = float(move_result.get("remaining_distance", 0.0))
		if !bool(move_result.get("reached_vertex", false)):
			break

		var vertex_index := int(move_result.get("vertex_index", -1))
		if vertex_index < 0:
			break

		var next_segment := _select_border_segment_at_vertex(vertex_index, direction)
		if !bool(next_segment.get("matched", false)):
			break

		_apply_selected_border_segment(next_segment)
		_update_queued_border_transition(direction, move_sign, safe_epsilon)

	_clamp_border_state()
	position = _border_state_to_point()
	border_progress = _border_state_to_progress()


func _point_to_border_progress(point: Vector2) -> float:
	return float(_get_nearest_border_projection(point).get("progress", 0.0))


func _border_progress_to_point(progress: float) -> Vector2:
	return PlayfieldBoundary.point_at_progress(active_outer_loop, outer_loop_metrics, progress)


func _perimeter_length() -> float:
	return outer_loop_total_length


func _wrap_border_progress(progress: float) -> float:
	return PlayfieldBoundary.wrap_progress(progress, _perimeter_length())


func _sync_border_state_from_position(point: Vector2) -> void:
	if active_outer_loop.size() < 2:
		position = point
		current_border_segment_index = 0
		border_distance_on_segment = 0.0
		border_progress = 0.0
		_clear_queued_border_transition()
		return

	var location: Dictionary = PlayfieldBoundary.locate_point_on_loop_segment(
		active_outer_loop,
		point,
		border_epsilon,
		outer_loop_metrics
	)
	_apply_border_location(location)
	if !_is_border_state_consistent(Vector2(location.get("point", point))):
		var corrected_point: Vector2 = location.get("point", point)
		location = PlayfieldBoundary.locate_point_on_loop_segment(
			active_outer_loop,
			corrected_point,
			border_epsilon,
			outer_loop_metrics
		)
		_apply_border_location(location)
	position = _border_state_to_point()
	border_progress = _border_state_to_progress()
	_clear_queued_border_transition()


func _clamp_border_state() -> void:
	if active_outer_loop.size() < 2:
		current_border_segment_index = 0
		border_distance_on_segment = 0.0
		return

	current_border_segment_index = posmod(current_border_segment_index, active_outer_loop.size())
	var segment_length: float = _get_current_border_segment_length()
	border_distance_on_segment = clampf(border_distance_on_segment, 0.0, segment_length)


func _get_current_border_segment_length() -> float:
	return PlayfieldBoundary.get_segment_length(
		active_outer_loop,
		current_border_segment_index,
		outer_loop_metrics
	)


func _border_state_to_point() -> Vector2:
	if active_outer_loop.size() < 2:
		return position
	return PlayfieldBoundary.point_at_segment_distance(
		active_outer_loop,
		current_border_segment_index,
		border_distance_on_segment,
		outer_loop_metrics
	)


func _border_state_to_progress() -> float:
	if outer_loop_starts.size() != active_outer_loop.size():
		return 0.0
	if current_border_segment_index < 0 or current_border_segment_index >= outer_loop_starts.size():
		return 0.0
	return _wrap_border_progress(float(outer_loop_starts[current_border_segment_index]) + border_distance_on_segment)


func _get_current_border_vertex_index() -> int:
	if active_outer_loop.size() < 2:
		return -1

	var safe_epsilon := maxf(border_epsilon, PlayfieldBoundary.DEFAULT_EPSILON)
	if border_distance_on_segment <= safe_epsilon:
		return current_border_segment_index

	var segment_length := _get_current_border_segment_length()
	if absf(segment_length - border_distance_on_segment) <= safe_epsilon:
		return (current_border_segment_index + 1) % active_outer_loop.size()

	return -1


func _get_upcoming_border_vertex_index(move_sign: float) -> int:
	if active_outer_loop.size() < 2:
		return -1
	if move_sign < 0.0:
		return current_border_segment_index
	return (current_border_segment_index + 1) % active_outer_loop.size()


func _get_border_queue_distance_threshold(segment_length: float) -> float:
	var minimum_threshold := maxf(border_epsilon * 2.0, 4.0)
	var maximum_threshold := maxf(border_epsilon * 5.0, minimum_threshold)
	return clampf(segment_length * 0.2, minimum_threshold, maximum_threshold)


func _update_queued_border_transition(direction: Vector2, move_sign: float, safe_epsilon: float) -> void:
	if direction == Vector2.ZERO:
		_clear_queued_border_transition()
		return

	var segment_length := _get_current_border_segment_length()
	if segment_length <= safe_epsilon:
		_clear_queued_border_transition()
		return

	var vertex_index := _get_upcoming_border_vertex_index(move_sign)
	if vertex_index < 0:
		_clear_queued_border_transition()
		return

	var distance_to_vertex := (
		maxf(0.0, segment_length - border_distance_on_segment)
		if move_sign > 0.0
		else maxf(0.0, border_distance_on_segment)
	)
	if distance_to_vertex > _get_border_queue_distance_threshold(segment_length) + safe_epsilon:
		_clear_queued_border_transition()
		return

	var queued_segment: Dictionary = PlayfieldBoundary.choose_segment_at_vertex(
		active_outer_loop,
		vertex_index,
		direction,
		current_border_segment_index,
		border_epsilon,
		outer_loop_metrics
	)
	if !bool(queued_segment.get("matched", false)):
		_clear_queued_border_transition()
		return

	queued_border_vertex_index = vertex_index
	queued_border_segment_index = int(queued_segment.get("segment_index", -1))
	queued_border_distance_on_segment = float(queued_segment.get("distance_on_segment", 0.0))


func _select_border_segment_at_vertex(vertex_index: int, direction: Vector2) -> Dictionary:
	if queued_border_vertex_index == vertex_index and queued_border_segment_index >= 0:
		var queued_segment := {
			"matched": true,
			"segment_index": queued_border_segment_index,
			"distance_on_segment": queued_border_distance_on_segment,
			"point": active_outer_loop[vertex_index]
		}
		_clear_queued_border_transition()
		return queued_segment

	_clear_queued_border_transition()
	return PlayfieldBoundary.choose_segment_at_vertex(
		active_outer_loop,
		vertex_index,
		direction,
		current_border_segment_index,
		border_epsilon,
		outer_loop_metrics
	)


func _apply_selected_border_segment(selection: Dictionary) -> void:
	current_border_segment_index = int(selection.get("segment_index", current_border_segment_index))
	border_distance_on_segment = float(selection.get("distance_on_segment", border_distance_on_segment))
	_clamp_border_state()


func _consume_current_border_segment(move_sign: float, remaining_distance: float, safe_epsilon: float) -> Dictionary:
	var segment_length := _get_current_border_segment_length()
	if segment_length <= safe_epsilon:
		return {
			"remaining_distance": remaining_distance,
			"reached_vertex": true,
			"vertex_index": _get_current_border_vertex_index()
		}

	if move_sign > 0.0:
		var distance_to_segment_end := maxf(0.0, segment_length - border_distance_on_segment)
		if remaining_distance < distance_to_segment_end - safe_epsilon:
			border_distance_on_segment += remaining_distance
			return {
				"remaining_distance": 0.0,
				"reached_vertex": false,
				"vertex_index": -1
			}

		border_distance_on_segment = segment_length
		remaining_distance = maxf(0.0, remaining_distance - distance_to_segment_end)
	else:
		var distance_to_segment_start := maxf(0.0, border_distance_on_segment)
		if remaining_distance < distance_to_segment_start - safe_epsilon:
			border_distance_on_segment -= remaining_distance
			return {
				"remaining_distance": 0.0,
				"reached_vertex": false,
				"vertex_index": -1
			}

		border_distance_on_segment = 0.0
		remaining_distance = maxf(0.0, remaining_distance - distance_to_segment_start)

	return {
		"remaining_distance": remaining_distance,
		"reached_vertex": true,
		"vertex_index": _get_current_border_vertex_index()
	}


func _apply_border_location(location: Dictionary) -> void:
	current_border_segment_index = max(0, int(location.get("segment_index", 0)))
	border_distance_on_segment = float(location.get("distance_on_segment", 0.0))
	_clamp_border_state()


func _clear_queued_border_transition() -> void:
	queued_border_segment_index = -1
	queued_border_vertex_index = -1
	queued_border_distance_on_segment = 0.0


func _is_border_state_consistent(reference_point: Vector2) -> bool:
	if active_outer_loop.size() < 2:
		return true
	if current_border_segment_index < 0 or current_border_segment_index >= active_outer_loop.size():
		return false

	var safe_epsilon := maxf(border_epsilon, PlayfieldBoundary.DEFAULT_EPSILON)
	var segment_length := _get_current_border_segment_length()
	if border_distance_on_segment < -safe_epsilon:
		return false
	if border_distance_on_segment > segment_length + safe_epsilon:
		return false

	var state_point := _border_state_to_point()
	if !PlayfieldBoundary.is_point_on_loop(active_outer_loop, state_point, safe_epsilon, outer_loop_metrics):
		return false
	return reference_point.distance_to(state_point) <= maxf(safe_epsilon * 2.0, 4.0)


func debug_is_border_state_consistent() -> bool:
	return _is_border_state_consistent(position)


func debug_can_start_drawing_from_border() -> bool:
	return _can_start_drawing_from_border()


func _is_inside_or_on_playfield(point: Vector2) -> bool:
	if _is_on_border(point):
		return true
	if remaining_polygon.size() >= 3:
		return Geometry2D.is_point_in_polygon(point, remaining_polygon)
	if playfield_rect.size.x <= 0.0 or playfield_rect.size.y <= 0.0:
		return false
	var clamped := Vector2(
		clampf(point.x, playfield_rect.position.x, playfield_rect.end.x),
		clampf(point.y, playfield_rect.position.y, playfield_rect.end.y)
	)
	return clamped.distance_to(point) <= border_epsilon


func _get_nearest_border_projection(point: Vector2) -> Dictionary:
	if outer_loop_total_length <= 0.0:
		var clamped_point := _clamp_to_playfield(point)
		return {
			"point": clamped_point,
			"progress": 0.0,
			"distance": point.distance_to(clamped_point),
			"segment_index": -1
		}
	return PlayfieldBoundary.project_point_to_loop(active_outer_loop, point, outer_loop_metrics)


func _get_default_spawn_point() -> Vector2:
	return Vector2(
		playfield_rect.position.x + playfield_rect.size.x * start_edge_ratio,
		playfield_rect.position.y
	)


func _update_damage_hitboxes() -> void:
	if !is_instance_valid(pick_area):
		return

	var targets := get_boss_hit_targets()
	var enable_player_hitbox := bool(targets.get("player", false))
	pick_area.monitoring = enable_player_hitbox
	pick_area.monitorable = enable_player_hitbox
	if is_instance_valid(pick_collision_shape):
		pick_collision_shape.disabled = !enable_player_hitbox


func _is_damage_blocked() -> bool:
	return is_defeated or invincibility_timer > 0.0


func _is_draw_action_pressed() -> bool:
	return is_draw_action_configured and Input.is_action_pressed(ACTION_QIX_DRAW)


func _is_draw_action_just_pressed() -> bool:
	return is_draw_action_configured and Input.is_action_just_pressed(ACTION_QIX_DRAW)


func _refresh_damage_trail_cache(visible_points: PackedVector2Array) -> void:
	active_damage_trail_segments.clear()
	active_damage_trail_aabbs.clear()
	for i in range(visible_points.size() - 1):
		var segment_start: Vector2 = visible_points[i]
		var segment_end: Vector2 = visible_points[i + 1]
		if segment_start.is_equal_approx(segment_end):
			continue
		var segment := PackedVector2Array()
		segment.append(segment_start)
		segment.append(segment_end)
		active_damage_trail_segments.append(segment)
		active_damage_trail_aabbs.append(_build_segment_aabb(segment_start, segment_end))


func _build_segment_aabb(segment_start: Vector2, segment_end: Vector2) -> Rect2:
	var min_point := Vector2(minf(segment_start.x, segment_end.x), minf(segment_start.y, segment_end.y))
	var max_point := Vector2(maxf(segment_start.x, segment_end.x), maxf(segment_start.y, segment_end.y))
	return Rect2(min_point, max_point - min_point)


func _refresh_debug_notifications(force := false) -> void:
	var status_changed := _refresh_debug_status_notification(force)
	_refresh_debug_position_notification(force or status_changed)
	_refresh_capture_preview_notification(force)


func _refresh_damage_trail_cache_if_needed(visible_points: PackedVector2Array) -> void:
	if _visible_trail_points_match(last_visible_trail_cache_points, visible_points):
		return

	last_visible_trail_cache_points = visible_points.duplicate()
	_refresh_damage_trail_cache(visible_points)


func _visible_trail_points_match(lhs: PackedVector2Array, rhs: PackedVector2Array) -> bool:
	if lhs.size() != rhs.size():
		return false

	for i in range(lhs.size()):
		if !lhs[i].is_equal_approx(rhs[i]):
			return false
	return true


func _refresh_debug_status_notification(force := false) -> bool:
	var status_snapshot := _build_debug_status_snapshot()
	if !force and status_snapshot == last_debug_status_snapshot:
		return false

	last_debug_status_snapshot = status_snapshot
	debug_status_changed.emit(get_debug_status())
	return true


func _refresh_debug_position_notification(force := false) -> void:
	var notify_distance := maxf(trail_min_point_distance, border_epsilon)
	if (
		!force
		and has_last_debug_position_snapshot
		and position.distance_to(last_debug_position_snapshot) < notify_distance
	):
		return

	last_debug_position_snapshot = position
	has_last_debug_position_snapshot = true
	debug_position_changed.emit(position)


func _refresh_capture_preview_notification(force := false) -> void:
	var preview_active := _is_capture_preview_active_state()
	if force or preview_active != last_capture_preview_active:
		last_capture_preview_active = preview_active
		capture_preview_changed.emit(preview_active)


func _build_debug_status_snapshot() -> Dictionary:
	return {
		"mode_text": get_state_text(),
		"hp": current_hp,
		"max_hp": get_max_hp()
	}


func _is_capture_preview_active_state() -> bool:
	return state == PlayerState.DRAWING or state == PlayerState.REWINDING
