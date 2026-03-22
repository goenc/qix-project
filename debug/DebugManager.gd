extends Node

const MANAGER_WINDOW_ID := &"manager"
const INPUT_DEBUGGER_WINDOW_ID := &"input_debugger"
const INPUT_LOG_WINDOW_ID := &"input_log"
const OBJECT_INSPECTOR_WINDOW_ID := &"object_inspector"

const DEBUG_MANAGER_WINDOW_SCENE := preload("res://debug/manager/debug_manager_window.tscn")
const INPUT_DEBUG_WINDOW_SCENE := preload("res://debug/windows/input/input_debug_window.tscn")
const INPUT_LOG_WINDOW_SCENE := preload("res://debug/windows/log/input_log_window.tscn")
const OBJECT_INSPECTOR_WINDOW_SCENE := preload("res://debug/windows/object_inspector/object_inspector_window.tscn")
const HITBOX_DEBUG_OVERLAY_SCENE := preload("res://debug/overlays/hitbox/hitbox_debug_overlay.tscn")

var _windows: Dictionary = {}
var _hitbox_overlay_enabled := false
var _hitbox_overlay: CanvasItem = null
var _show_vertical_guides := true
var _show_horizontal_guides := true
var _show_area_fills := true
var _show_area_percent_labels := true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.gui_embed_subwindows = false
	call_deferred("open_manager_window")


func _process(_delta: float) -> void:
	if !InputMap.has_action("pause"):
		return
	if !Input.is_action_just_pressed("pause"):
		return
	if !_can_toggle_pause_from_debug_input():
		return
	set_game_paused(!get_tree().paused)


func open_manager_window() -> void:
	_show_window(MANAGER_WINDOW_ID)
	_sync_manager_window_pause_state()
	_sync_manager_window_guide_states()
	_apply_guide_visibility_to_scene()


func open_input_debugger_window() -> void:
	_show_window(INPUT_DEBUGGER_WINDOW_ID)


func open_input_log_window() -> void:
	_show_window(INPUT_LOG_WINDOW_ID)


func open_object_inspector_window() -> void:
	_show_window(OBJECT_INSPECTOR_WINDOW_ID)


func set_hitbox_overlay_enabled(enabled: bool) -> void:
	_hitbox_overlay_enabled = enabled
	_sync_hitbox_overlay_visibility()
	_sync_manager_window_hitbox_state()


func set_game_paused(enabled: bool) -> void:
	var pause_controller := _resolve_pause_controller()
	if is_instance_valid(pause_controller) and pause_controller.has_method("set_paused_from_debug"):
		pause_controller.call("set_paused_from_debug", enabled)
	_sync_manager_window_pause_state()


func set_vertical_guides_enabled(enabled: bool) -> void:
	_show_vertical_guides = enabled
	_apply_guide_visibility_to_scene()
	_sync_manager_window_vertical_guides_state()


func set_horizontal_guides_enabled(enabled: bool) -> void:
	_show_horizontal_guides = enabled
	_apply_guide_visibility_to_scene()
	_sync_manager_window_horizontal_guides_state()


func set_area_fills_enabled(enabled: bool) -> void:
	_show_area_fills = enabled
	_apply_guide_visibility_to_scene()
	_sync_manager_window_area_fills_state()


func set_area_percent_labels_enabled(enabled: bool) -> void:
	_show_area_percent_labels = enabled
	_apply_guide_visibility_to_scene()
	_sync_manager_window_area_percent_labels_state()


func is_hitbox_overlay_enabled() -> bool:
	return _hitbox_overlay_enabled


func is_game_paused() -> bool:
	return get_tree().paused


func is_vertical_guides_enabled() -> bool:
	return _show_vertical_guides


func is_horizontal_guides_enabled() -> bool:
	return _show_horizontal_guides


func is_area_fills_enabled() -> bool:
	return _show_area_fills


func is_area_percent_labels_enabled() -> bool:
	return _show_area_percent_labels


func _show_window(window_id: StringName) -> void:
	var window := _get_or_create_window(window_id)
	if !is_instance_valid(window):
		return
	window.show()
	window.grab_focus()


func _get_or_create_window(window_id: StringName) -> Window:
	var existing_window := _windows.get(window_id) as Window
	if is_instance_valid(existing_window):
		return existing_window
	var scene := _scene_for_window(window_id)
	if scene == null:
		return null
	var window := scene.instantiate() as Window
	get_tree().root.add_child(window)
	_windows[window_id] = window
	window.tree_exited.connect(_on_window_tree_exited.bind(window_id))
	_configure_window(window_id, window)
	return window


func _scene_for_window(window_id: StringName) -> PackedScene:
	match window_id:
		MANAGER_WINDOW_ID:
			return DEBUG_MANAGER_WINDOW_SCENE
		INPUT_DEBUGGER_WINDOW_ID:
			return INPUT_DEBUG_WINDOW_SCENE
		INPUT_LOG_WINDOW_ID:
			return INPUT_LOG_WINDOW_SCENE
		OBJECT_INSPECTOR_WINDOW_ID:
			return OBJECT_INSPECTOR_WINDOW_SCENE
	return null


func _configure_window(window_id: StringName, window: Window) -> void:
	if window_id != MANAGER_WINDOW_ID:
		return
	_configure_manager_window(window as DebugManagerWindow)


func _on_window_tree_exited(window_id: StringName) -> void:
	_windows.erase(window_id)


func _configure_manager_window(window: DebugManagerWindow) -> void:
	if !is_instance_valid(window):
		return
	_connect_manager_window_signals(window)
	window.set_hitbox_overlay_enabled(_hitbox_overlay_enabled)
	window.set_pause_enabled(is_game_paused())
	window.set_vertical_guides_enabled(_show_vertical_guides)
	window.set_horizontal_guides_enabled(_show_horizontal_guides)
	window.set_area_fills_enabled(_show_area_fills)
	window.set_area_percent_labels_enabled(_show_area_percent_labels)


func _connect_manager_window_signals(window: DebugManagerWindow) -> void:
	if !window.open_input_debugger_requested.is_connected(open_input_debugger_window):
		window.open_input_debugger_requested.connect(open_input_debugger_window)
	if !window.open_input_log_requested.is_connected(open_input_log_window):
		window.open_input_log_requested.connect(open_input_log_window)
	if !window.open_object_inspector_requested.is_connected(open_object_inspector_window):
		window.open_object_inspector_requested.connect(open_object_inspector_window)
	if !window.hitbox_overlay_toggled.is_connected(set_hitbox_overlay_enabled):
		window.hitbox_overlay_toggled.connect(set_hitbox_overlay_enabled)
	if !window.pause_toggled.is_connected(set_game_paused):
		window.pause_toggled.connect(set_game_paused)
	if !window.vertical_guides_toggled.is_connected(set_vertical_guides_enabled):
		window.vertical_guides_toggled.connect(set_vertical_guides_enabled)
	if !window.horizontal_guides_toggled.is_connected(set_horizontal_guides_enabled):
		window.horizontal_guides_toggled.connect(set_horizontal_guides_enabled)
	if !window.area_fills_toggled.is_connected(set_area_fills_enabled):
		window.area_fills_toggled.connect(set_area_fills_enabled)
	if !window.area_percent_labels_toggled.is_connected(set_area_percent_labels_enabled):
		window.area_percent_labels_toggled.connect(set_area_percent_labels_enabled)


func _sync_hitbox_overlay_visibility() -> void:
	var hitbox_overlay := _get_or_create_hitbox_overlay() if _hitbox_overlay_enabled else _hitbox_overlay
	if !is_instance_valid(hitbox_overlay):
		return
	hitbox_overlay.visible = _hitbox_overlay_enabled


func _sync_manager_window_hitbox_state() -> void:
	var manager_window := _windows.get(MANAGER_WINDOW_ID) as DebugManagerWindow
	if !is_instance_valid(manager_window):
		return
	manager_window.set_hitbox_overlay_enabled(_hitbox_overlay_enabled)


func _sync_manager_window_pause_state() -> void:
	var manager_window := _windows.get(MANAGER_WINDOW_ID) as DebugManagerWindow
	if !is_instance_valid(manager_window):
		return
	manager_window.set_pause_enabled(is_game_paused())


func _sync_manager_window_guide_states() -> void:
	_sync_manager_window_vertical_guides_state()
	_sync_manager_window_horizontal_guides_state()
	_sync_manager_window_area_fills_state()
	_sync_manager_window_area_percent_labels_state()


func _sync_manager_window_vertical_guides_state() -> void:
	var manager_window := _windows.get(MANAGER_WINDOW_ID) as DebugManagerWindow
	if !is_instance_valid(manager_window):
		return
	manager_window.set_vertical_guides_enabled(_show_vertical_guides)


func _sync_manager_window_horizontal_guides_state() -> void:
	var manager_window := _windows.get(MANAGER_WINDOW_ID) as DebugManagerWindow
	if !is_instance_valid(manager_window):
		return
	manager_window.set_horizontal_guides_enabled(_show_horizontal_guides)


func _sync_manager_window_area_fills_state() -> void:
	var manager_window := _windows.get(MANAGER_WINDOW_ID) as DebugManagerWindow
	if !is_instance_valid(manager_window):
		return
	manager_window.set_area_fills_enabled(_show_area_fills)


func _sync_manager_window_area_percent_labels_state() -> void:
	var manager_window := _windows.get(MANAGER_WINDOW_ID) as DebugManagerWindow
	if !is_instance_valid(manager_window):
		return
	manager_window.set_area_percent_labels_enabled(_show_area_percent_labels)


func _can_toggle_pause_from_debug_input() -> bool:
	var pause_controller := _resolve_pause_controller()
	if !is_instance_valid(pause_controller):
		return false
	if !pause_controller.has_method("is_pause_toggle_allowed"):
		return false
	return bool(pause_controller.call("is_pause_toggle_allowed"))

func _resolve_pause_controller() -> Node:
	var current_scene := get_tree().current_scene
	if _is_pause_controller(current_scene):
		return current_scene
	if !is_instance_valid(current_scene):
		return null
	var nodes_to_visit: Array[Node] = [current_scene]
	while !nodes_to_visit.is_empty():
		var node: Node = nodes_to_visit.pop_back()
		if _is_pause_controller(node):
			return node
		for child in node.get_children():
			nodes_to_visit.append(child)
	return null


func _is_pause_controller(node: Node) -> bool:
	return is_instance_valid(node) \
		and node.has_method("set_paused_from_debug") \
		and node.has_method("is_pause_toggle_allowed")


func _apply_guide_visibility_to_scene() -> void:
	var guide_controller := _resolve_debug_method_target(
		PackedStringArray([
			"set_show_vertical_guides_from_debug",
			"set_show_horizontal_guides_from_debug",
			"set_show_area_fills_from_debug",
			"set_show_area_percent_labels_from_debug"
		])
	)
	if !is_instance_valid(guide_controller):
		return
	guide_controller.call("set_show_vertical_guides_from_debug", _show_vertical_guides)
	guide_controller.call("set_show_horizontal_guides_from_debug", _show_horizontal_guides)
	guide_controller.call("set_show_area_fills_from_debug", _show_area_fills)
	guide_controller.call("set_show_area_percent_labels_from_debug", _show_area_percent_labels)


func _resolve_debug_method_target(method_names: PackedStringArray) -> Node:
	var current_scene := get_tree().current_scene
	if _node_has_methods(current_scene, method_names):
		return current_scene
	if !is_instance_valid(current_scene):
		return null
	var nodes_to_visit: Array[Node] = [current_scene]
	while !nodes_to_visit.is_empty():
		var node: Node = nodes_to_visit.pop_back()
		if _node_has_methods(node, method_names):
			return node
		for child in node.get_children():
			nodes_to_visit.append(child)
	return null


func _node_has_methods(node: Node, method_names: PackedStringArray) -> bool:
	if !is_instance_valid(node):
		return false
	for method_name in method_names:
		if !node.has_method(method_name):
			return false
	return true


func _get_or_create_hitbox_overlay() -> CanvasItem:
	if is_instance_valid(_hitbox_overlay):
		return _hitbox_overlay
	var overlay := HITBOX_DEBUG_OVERLAY_SCENE.instantiate() as CanvasItem
	get_tree().root.add_child(overlay)
	overlay.visible = _hitbox_overlay_enabled
	_hitbox_overlay = overlay
	return overlay
