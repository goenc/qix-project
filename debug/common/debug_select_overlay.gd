extends Node2D
class_name DebugSelectOverlay

signal world_point_clicked(world_position: Vector2, screen_position: Vector2)

const DEBUG_INSPECT_UTILS := preload("res://debug/common/debug_inspect_utils.gd")
const HIGHLIGHT_COLOR := Color8(255, 168, 48)
const CROSS_COLOR := Color8(255, 220, 120)
const LINE_WIDTH := 3.0
const CROSS_SIZE := 10.0

var _selected_target: Node = null
var _monitoring_enabled := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	top_level = true
	z_as_relative = false
	z_index = 4096
	visible = false
	set_process_input(false)
	set_process_unhandled_input(false)


func set_monitoring_enabled(enabled: bool) -> void:
	_monitoring_enabled = enabled
	set_process_input(enabled)
	set_process_unhandled_input(false)
	visible = enabled and is_instance_valid(_selected_target)
	queue_redraw()


func set_selected_target(target: Node) -> void:
	_selected_target = target if is_instance_valid(target) else null
	visible = _monitoring_enabled and is_instance_valid(_selected_target)
	queue_redraw()


func clear_selected_target() -> void:
	_selected_target = null
	visible = false
	queue_redraw()


func _process(_delta: float) -> void:
	if _monitoring_enabled and is_instance_valid(_selected_target):
		queue_redraw()


func _input(event: InputEvent) -> void:
	if !_monitoring_enabled:
		return
	if !(event is InputEventMouseButton):
		return
	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT or !mouse_event.pressed:
		return
	var screen_position: Vector2 = mouse_event.position
	if mouse_event.window_id != get_window().get_window_id():
		return
	world_point_clicked.emit(DEBUG_INSPECT_UTILS.viewport_position_to_world(get_viewport(), screen_position), screen_position)


func _draw() -> void:
	if !is_instance_valid(_selected_target):
		return
	var geometry := DEBUG_INSPECT_UTILS.build_highlight_geometry(_selected_target)
	if bool(geometry.get("has_rect", false)):
		var rect: Rect2 = geometry.get("rect", Rect2())
		draw_rect(rect, HIGHLIGHT_COLOR, false, LINE_WIDTH)
	var anchor := geometry.get("anchor", Vector2.ZERO) as Vector2
	draw_line(anchor + Vector2(-CROSS_SIZE, 0.0), anchor + Vector2(CROSS_SIZE, 0.0), CROSS_COLOR, LINE_WIDTH)
	draw_line(anchor + Vector2(0.0, -CROSS_SIZE), anchor + Vector2(0.0, CROSS_SIZE), CROSS_COLOR, LINE_WIDTH)
