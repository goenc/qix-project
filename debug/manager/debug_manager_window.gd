extends Window
class_name DebugManagerWindow

signal open_input_debugger_requested
signal open_input_log_requested
signal open_object_inspector_requested
signal hitbox_overlay_toggled(enabled: bool)
signal pause_toggled(enabled: bool)

@onready var _open_input_debugger_button: Button = $FeatureButtons/OpenInputDebuggerButton
@onready var _open_input_log_button: Button = $FeatureButtons/OpenInputLogButton
@onready var _open_object_inspector_button: Button = $FeatureButtons/OpenObjectInspectorButton
@onready var _toggle_hitbox_overlay_button: CheckButton = $FeatureButtons/ToggleHitboxOverlayButton
@onready var _toggle_pause_button: CheckButton = $FeatureButtons/TogglePauseButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	title = "Debug Manager"
	close_requested.connect(hide)
	_connect_feature_buttons()
	_move_near_main_window()


func _connect_feature_buttons() -> void:
	_open_input_debugger_button.pressed.connect(_on_open_input_debugger_button_pressed)
	_open_input_log_button.pressed.connect(_on_open_input_log_button_pressed)
	_open_object_inspector_button.pressed.connect(_on_open_object_inspector_button_pressed)
	_toggle_hitbox_overlay_button.toggled.connect(_on_toggle_hitbox_overlay_button_toggled)
	_toggle_pause_button.toggled.connect(_on_toggle_pause_button_toggled)


func _move_near_main_window() -> void:
	var main_window := get_tree().root
	if main_window == self:
		return
	position = main_window.position + Vector2i(main_window.size.x + 24, 0)


func _on_open_input_debugger_button_pressed() -> void:
	open_input_debugger_requested.emit()


func _on_open_input_log_button_pressed() -> void:
	open_input_log_requested.emit()


func _on_open_object_inspector_button_pressed() -> void:
	open_object_inspector_requested.emit()


func set_hitbox_overlay_enabled(enabled: bool) -> void:
	_toggle_hitbox_overlay_button.set_pressed_no_signal(enabled)


func set_pause_enabled(enabled: bool) -> void:
	_toggle_pause_button.set_pressed_no_signal(enabled)


func _on_toggle_hitbox_overlay_button_toggled(enabled: bool) -> void:
	hitbox_overlay_toggled.emit(enabled)


func _on_toggle_pause_button_toggled(enabled: bool) -> void:
	pause_toggled.emit(enabled)
