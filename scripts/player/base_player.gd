extends Node2D
class_name BasePlayer

@export var move_speed := 240.0
@export var spawn_position := Vector2(320.0, 180.0)
@export var half_extent := Vector2(12.0, 12.0)

@onready var pick_area: Area2D = $PickArea


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	if is_instance_valid(pick_area):
		pick_area.set_meta(&"debug_pick_owner", self)
	position = spawn_position


func _process(delta: float) -> void:
	var direction := Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_up", "move_down")
	)
	if direction.length_squared() > 1.0:
		direction = direction.normalized()
	position += direction * move_speed * delta
	_clamp_to_viewport()


func _clamp_to_viewport() -> void:
	var viewport_size := get_viewport_rect().size
	position = Vector2(
		clampf(position.x, half_extent.x, viewport_size.x - half_extent.x),
		clampf(position.y, half_extent.y, viewport_size.y - half_extent.y)
	)
