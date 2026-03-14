extends Window

const DEBUG_INSPECT_UTILS := preload("res://debug/common/debug_inspect_utils.gd")
const DEBUG_SELECT_OVERLAY := preload("res://debug/common/debug_select_overlay.gd")
const OBJECT_PICK_POPUP_SCENE := preload("res://debug/windows/object_inspector/object_pick_popup.tscn")
const REFRESH_INTERVAL := 0.1

@onready var _inspector_panel: ObjectInspectorPanel = $ObjectInspectorPanel

var _pick_popup: ObjectPickPopup = null
var _select_overlay: DebugSelectOverlay = null
var _selected_target: Node = null
var _refresh_accumulator := 0.0
var _last_visible_state := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	title = "Object Inspector"
	close_requested.connect(hide)
	_move_near_main_window()
	_ensure_overlay()
	_ensure_pick_popup()
	_show_empty_panel()
	_last_visible_state = visible
	_sync_active_state()


func _process(delta: float) -> void:
	_sync_visibility_state()
	if !_should_refresh_selected_target(delta):
		return
	_update_panel_target(_selected_target)


func _exit_tree() -> void:
	_disconnect_selected_target()
	if is_instance_valid(_select_overlay):
		if _select_overlay.world_point_clicked.is_connected(_on_world_point_clicked):
			_select_overlay.world_point_clicked.disconnect(_on_world_point_clicked)
		_select_overlay.queue_free()
	if is_instance_valid(_pick_popup):
		_pick_popup.queue_free()


func _move_near_main_window() -> void:
	var main_window := get_tree().root
	if main_window == self:
		return
	position = main_window.position + Vector2i(main_window.size.x + 260, 0)


func _ensure_overlay() -> void:
	if is_instance_valid(_select_overlay):
		return
	_select_overlay = DEBUG_SELECT_OVERLAY.new() as DebugSelectOverlay
	get_tree().root.add_child(_select_overlay)
	_select_overlay.set_monitoring_enabled(false)
	_select_overlay.clear_selected_target()
	_select_overlay.world_point_clicked.connect(_on_world_point_clicked)


func _ensure_pick_popup() -> void:
	if is_instance_valid(_pick_popup):
		return
	_pick_popup = OBJECT_PICK_POPUP_SCENE.instantiate() as ObjectPickPopup
	get_tree().root.add_child(_pick_popup)
	_hide_pick_popup()
	_pick_popup.candidate_selected.connect(_on_pick_popup_candidate_selected)


func _sync_active_state() -> void:
	if is_instance_valid(_select_overlay):
		_select_overlay.set_monitoring_enabled(visible)
	if visible and _has_valid_selection():
		_set_overlay_target(_selected_target)
	else:
		_clear_overlay_target()
	if !visible and is_instance_valid(_pick_popup):
		_pick_popup.hide()


func _on_world_point_clicked(world_position: Vector2, screen_position: Vector2) -> void:
	if !visible:
		return
	var pick_viewport := _get_pick_viewport()
	var candidates: Array[Dictionary] = DEBUG_INSPECT_UTILS.collect_pick_candidates(pick_viewport, world_position)
	if candidates.is_empty():
		_hide_pick_popup()
		return
	if candidates.size() == 1:
		_select_candidate(candidates[0])
		return
	if is_instance_valid(_pick_popup):
		_pick_popup.present_candidates(candidates, _build_popup_position(screen_position))


func _select_candidate(candidate: Dictionary) -> void:
	var target := candidate.get("target") as Node
	if !is_instance_valid(target):
		return
	_set_selected_target(target)


func _set_selected_target(target: Node) -> void:
	_disconnect_selected_target()
	_selected_target = target
	_selected_target.tree_exited.connect(_on_selected_target_tree_exited)
	_refresh_accumulator = 0.0
	_show_panel_target(_selected_target)
	_hide_pick_popup()
	_set_overlay_target(_selected_target)


func _clear_selection() -> void:
	_disconnect_selected_target()
	_selected_target = null
	_refresh_accumulator = 0.0
	_hide_pick_popup()
	_show_empty_panel()
	_clear_overlay_target()


func _disconnect_selected_target() -> void:
	if !is_instance_valid(_selected_target):
		return
	if _selected_target.tree_exited.is_connected(_on_selected_target_tree_exited):
		_selected_target.tree_exited.disconnect(_on_selected_target_tree_exited)


func _has_valid_selection() -> bool:
	return is_instance_valid(_selected_target) and _selected_target.is_inside_tree()


func _build_popup_position(screen_position: Vector2) -> Vector2i:
	var main_window := _get_pick_window()
	var base_position := main_window.position + Vector2i(screen_position)
	return base_position + Vector2i(16, 16)


func _on_pick_popup_candidate_selected(candidate: Dictionary) -> void:
	_select_candidate(candidate)


func _on_selected_target_tree_exited() -> void:
	_clear_selection()


func _show_empty_panel() -> void:
	if _inspector_panel != null:
		_inspector_panel.show_empty()


func _show_panel_target(target: Node) -> void:
	_apply_panel_target(target, false)


func _update_panel_target(target: Node) -> void:
	_apply_panel_target(target, true)


func _apply_panel_target(target: Node, update_existing: bool) -> void:
	if _inspector_panel == null:
		return
	var status_text := "選択中 : %s" % DEBUG_INSPECT_UTILS.build_target_title(target)
	var summary_data := DEBUG_INSPECT_UTILS.build_summary_inspect_data(target)
	var registered_images := DEBUG_INSPECT_UTILS.build_registered_image_list(target)
	var common_text := DEBUG_INSPECT_UTILS.format_dictionary(DEBUG_INSPECT_UTILS.build_common_inspect_data(target))
	if update_existing:
		_inspector_panel.update_target_data(status_text, summary_data, registered_images, common_text)
		return
	_inspector_panel.show_target_data(status_text, summary_data, registered_images, common_text)


func _set_overlay_target(target: Node) -> void:
	if is_instance_valid(_select_overlay):
		_select_overlay.set_selected_target(target)


func _clear_overlay_target() -> void:
	if is_instance_valid(_select_overlay):
		_select_overlay.clear_selected_target()


func _hide_pick_popup() -> void:
	if is_instance_valid(_pick_popup):
		_pick_popup.hide()


func _sync_visibility_state() -> void:
	if visible == _last_visible_state:
		return
	_last_visible_state = visible
	_sync_active_state()


func _should_refresh_selected_target(delta: float) -> bool:
	if !visible:
		return false
	if !_has_valid_selection():
		if _selected_target != null:
			_clear_selection()
		return false
	_refresh_accumulator += delta
	if _refresh_accumulator < REFRESH_INTERVAL:
		return false
	_refresh_accumulator = 0.0
	return true


func _get_pick_viewport() -> Viewport:
	var pick_window := _get_pick_window()
	if is_instance_valid(pick_window):
		return pick_window.get_viewport()
	if is_instance_valid(_select_overlay):
		return _select_overlay.get_viewport()
	return get_tree().root


func _get_pick_window() -> Window:
	if is_instance_valid(_select_overlay):
		return _select_overlay.get_window()
	return get_tree().root
