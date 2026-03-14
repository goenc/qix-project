extends Window
class_name InputLogWindow

@onready var _log_panel: Control = $DebugLogPanel


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	title = "Input Log"
	close_requested.connect(hide)
	_move_near_main_window()
	DebugInputData.event_history_updated.connect(_on_event_history_updated)
	_log_panel.update_event_history(DebugInputData.get_event_history())


func _move_near_main_window() -> void:
	var main_window := get_tree().root
	if main_window == self:
		return
	position = main_window.position + Vector2i(main_window.size.x + 24, 230)


func _exit_tree() -> void:
	if DebugInputData.event_history_updated.is_connected(_on_event_history_updated):
		DebugInputData.event_history_updated.disconnect(_on_event_history_updated)


func _on_event_history_updated(event_history: Array[String]) -> void:
	_log_panel.update_event_history(event_history)
