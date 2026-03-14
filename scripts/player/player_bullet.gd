extends Area2D
class_name PlayerBullet

signal despawned

var game_manager = null
var active := false
var speed := 220.0
var damage := 1
var direction := 1.0

@onready var collider: CollisionShape2D = $CollisionShape2D
@onready var body: Polygon2D = $Body


func _ready() -> void:
	_apply_size(Vector2(8, 8))
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)


func configure(manager, config: Dictionary) -> void:
	game_manager = manager
	var player_config: Dictionary = config.get("player", {})
	speed = float(player_config.get("bullet_speed", 220.0))


func can_fire() -> bool:
	return !active


func fire(origin: Vector2, facing: float) -> void:
	active = true
	direction = -1.0 if facing < 0.0 else 1.0
	global_position = origin
	show()
	collider.disabled = false
	monitoring = true
	monitorable = true


func deactivate(emit_signal: bool = true) -> void:
	var was_active := active
	active = false
	hide()
	call_deferred("_disable_collision")
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	if was_active and emit_signal:
		despawned.emit()
	if was_active:
		queue_free()


func _physics_process(delta: float) -> void:
	if !active or game_manager == null:
		return
	global_position.x += direction * speed * delta
	var stage = game_manager.get_stage()
	if global_position.x < -16.0 or global_position.x > stage.get_stage_width() + 16.0:
		deactivate()


func _on_body_entered(body_node: Node) -> void:
	if active and body_node.is_in_group("stage_tile"):
		deactivate()


func _on_area_entered(area: Area2D) -> void:
	if !active or !area.has_meta("damageable_owner"):
		return
	var target = area.get_meta("damageable_owner")
	if target != null and target.has_method("take_damage"):
		target.take_damage(damage)
	deactivate()


func _disable_collision() -> void:
	if is_instance_valid(collider):
		collider.disabled = true


func _apply_size(size: Vector2) -> void:
	var shape := collider.shape as RectangleShape2D
	if shape != null:
		shape.size = size
	body.polygon = PackedVector2Array([
		Vector2(-size.x * 0.5, -size.y * 0.5),
		Vector2(size.x * 0.5, -size.y * 0.5),
		Vector2(size.x * 0.5, size.y * 0.5),
		Vector2(-size.x * 0.5, size.y * 0.5),
	])
	body.color = Color(0.96, 0.84, 0.25)
