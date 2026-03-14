extends CharacterBody2D
class_name EnemyWalker

var stage = null
var alive := false
var gameplay_active := false
var speed := 40.0
var gravity := 900.0
var direction := -1.0
var hp := 2
var max_hp := 2
var touch_damage := 1

@onready var collider: CollisionShape2D = $CollisionShape2D
@onready var body: Polygon2D = $Body
@onready var hitbox: Area2D = $Hitbox
@onready var hitbox_shape: CollisionShape2D = $Hitbox/CollisionShape2D
@onready var touch_area: Area2D = $TouchArea
@onready var touch_shape: CollisionShape2D = $TouchArea/CollisionShape2D


func _ready() -> void:
	_apply_size(Vector2(24, 24))
	hitbox.set_meta("damageable_owner", self)
	touch_area.set_meta("touch_owner", self)
	deactivate()


func configure(stage_ref, game_config: Dictionary, data: Dictionary) -> void:
	stage = stage_ref
	var enemy_config: Dictionary = game_config.get("walker", {})
	speed = float(enemy_config.get("speed", 40.0))
	gravity = float(game_config.get("gravity", 900.0))
	max_hp = int(enemy_config.get("hp", 2))
	hp = max_hp
	touch_damage = int(enemy_config.get("contact_damage", 1))
	direction = -1.0 if int(data.get("direction", -1)) < 0 else 1.0
	var position_data: Array = data.get("position", [0, 0])
	global_position = Vector2(position_data[0], position_data[1])
	alive = true
	_enable_nodes(true)


func set_gameplay_active(active: bool) -> void:
	gameplay_active = active


func deactivate() -> void:
	alive = false
	gameplay_active = false
	velocity = Vector2.ZERO
	_enable_nodes(false)


func take_damage(amount: int) -> void:
	if !alive:
		return
	hp -= amount
	if hp <= 0:
		deactivate()


func _physics_process(delta: float) -> void:
	if !alive or !gameplay_active:
		return
	velocity.y += gravity * delta
	if is_on_floor() and _should_turn():
		direction *= -1.0
	velocity.x = direction * speed
	move_and_slide()
	if is_on_wall():
		direction *= -1.0


func _should_turn() -> bool:
	var space_state := get_world_2d().direct_space_state
	var exclude := [self]
	var wall_query := PhysicsRayQueryParameters2D.create(global_position, global_position + Vector2(direction * 18.0, 0.0), collision_mask, exclude)
	var floor_origin := global_position + Vector2(direction * 14.0, 10.0)
	var floor_query := PhysicsRayQueryParameters2D.create(floor_origin, floor_origin + Vector2(0.0, 28.0), collision_mask, exclude)
	return !space_state.intersect_ray(floor_query) or !space_state.intersect_ray(wall_query).is_empty()


func _enable_nodes(enabled: bool) -> void:
	visible = enabled
	call_deferred("_set_collision_enabled", collider, enabled)
	hitbox.set_deferred("monitoring", enabled)
	hitbox.set_deferred("monitorable", enabled)
	call_deferred("_set_collision_enabled", hitbox_shape, enabled)
	touch_area.set_deferred("monitoring", enabled)
	touch_area.set_deferred("monitorable", enabled)
	touch_area.set_meta("touch_damage", touch_damage)
	call_deferred("_set_collision_enabled", touch_shape, enabled)

func _set_collision_enabled(target: CollisionShape2D, enabled: bool) -> void:
	if is_instance_valid(target):
		target.disabled = !enabled


func _apply_size(size: Vector2) -> void:
	var shape := collider.shape as RectangleShape2D
	if shape != null:
		shape.size = size
	var hit_shape := hitbox_shape.shape as RectangleShape2D
	if hit_shape != null:
		hit_shape.size = size
	var touch_rect := touch_shape.shape as RectangleShape2D
	if touch_rect != null:
		touch_rect.size = size
	body.polygon = PackedVector2Array([
		Vector2(-size.x * 0.5, -size.y * 0.5),
		Vector2(size.x * 0.5, -size.y * 0.5),
		Vector2(size.x * 0.5, size.y * 0.5),
		Vector2(-size.x * 0.5, size.y * 0.5),
	])
	body.color = Color(0.86, 0.24, 0.24)
