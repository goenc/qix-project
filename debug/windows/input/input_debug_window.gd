extends Window
class_name InputDebugWindow

@onready var _input_panel: Control = $DebugInputPanel


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	title = "Input Debugger"
	close_requested.connect(hide)
	_move_near_main_window()
	DebugInputData.input_state_updated.connect(_on_input_state_updated)
	_input_panel.update_input_state(DebugInputData.get_pressed_inputs())


func _move_near_main_window() -> void:
	var main_window := get_tree().root
	if main_window == self:
		return
	position = main_window.position + Vector2i(main_window.size.x + 24, 134)


func _exit_tree() -> void:
	if DebugInputData.input_state_updated.is_connected(_on_input_state_updated):
		DebugInputData.input_state_updated.disconnect(_on_input_state_updated)


func _on_input_state_updated(pressed_inputs: Dictionary) -> void:
	_input_panel.update_input_state(pressed_inputs)
