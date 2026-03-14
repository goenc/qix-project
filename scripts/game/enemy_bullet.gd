extends Area2D
class_name EnemyBullet

var stage = null
var active := false
var velocity := Vector2.ZERO
var damage := 1

@onready var collider: CollisionShape2D = $CollisionShape2D
@onready var body: Polygon2D = $Body


func _ready() -> void:
	_apply_size(Vector2(8, 8))
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	deactivate()


func activate(stage_ref, origin: Vector2, direction: Vector2, speed: float, damage_amount: int) -> void:
	stage = stage_ref
	global_position = origin
	velocity = direction.normalized() * speed
	damage = damage_amount
	active = true
	show()
	collider.disabled = false
	monitoring = true
	monitorable = true
	set_meta("touch_damage", damage)


func deactivate() -> void:
	active = false
	velocity = Vector2.ZERO
	hide()
	call_deferred("_disable_collision")
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)


func _disable_collision() -> void:
	if has_node("CollisionShape2D"):
		collider.disabled = true


func is_active() -> bool:
	return active


func _physics_process(delta: float) -> void:
	if !active or stage == null or !stage.is_gameplay_active():
		return
	global_position += velocity * delta
	if global_position.x < -16.0 or global_position.x > stage.get_stage_width() + 16.0:
		deactivate()
	elif global_position.y < -32.0 or global_position.y > stage.get_death_y():
		deactivate()


func _on_body_entered(body_node: Node) -> void:
	if active and body_node.is_in_group("stage_tile"):
		deactivate()


func _on_area_entered(area: Area2D) -> void:
	if !active:
		return
	if area.has_meta("player_owner"):
		var player = area.get_meta("player_owner")
		if player != null and player.has_method("apply_damage"):
			player.apply_damage(damage)
		deactivate()


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
