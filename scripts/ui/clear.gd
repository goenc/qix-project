extends CanvasLayer
class_name ClearScreen

@onready var root: Control = $Root
@onready var prompt: Label = $Root/Prompt


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func setup(_config: Dictionary) -> void:
	set_active(false)


func set_active(active: bool) -> void:
	visible = active
	root.visible = active
	if active:
		prompt.text = "PRESS ACCEPT TO TITLE"
