extends CanvasLayer
class_name Hud

@onready var root: Control = $Root
@onready var value_label: Label = $Root/LifeValue
@onready var pause_label: Label = $Root/PauseLabel
@onready var bars := [
	$Root/LifeBar01,
	$Root/LifeBar02,
	$Root/LifeBar03,
	$Root/LifeBar04,
	$Root/LifeBar05,
]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func setup(_config: Dictionary) -> void:
	set_active(false)
	set_paused(false)


func set_active(active: bool) -> void:
	visible = active
	root.visible = active


func update_life(current_life: int, max_life: int) -> void:
	value_label.text = "%d / %d" % [current_life, max_life]
	for index in range(bars.size()):
		bars[index].color = Color(0.2, 0.8, 0.4) if index < current_life else Color(0.18, 0.18, 0.18)


func set_paused(paused: bool) -> void:
	pause_label.visible = paused
