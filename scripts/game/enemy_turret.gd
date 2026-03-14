extends Node2D
class_name EnemyTurret

var stage = null
var alive := false
var gameplay_active := false
var hp := 3
var max_hp := 3
var shoot_interval := 2.0
var shot_timer := 0.0
var bullet_speed := 120.0
var bullet_damage := 1
var touch_damage := 1

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
	var turret_config: Dictionary = game_config.get("turret", {})
	var bullet_config: Dictionary = game_config.get("enemy_bullet", {})
	max_hp = int(turret_config.get("hp", 3))
	hp = max_hp
	shoot_interval = float(turret_config.get("shoot_interval", 2.0))
	bullet_speed = float(bullet_config.get("speed", 120.0))
	bullet_damage = int(bullet_config.get("damage", 1))
	touch_damage = int(turret_config.get("contact_damage", 1))
	shot_timer = shoot_interval
	var position_data: Array = data.get("position", [0, 0])
	global_position = Vector2(position_data[0], position_data[1])
	alive = true
	_enable_nodes(true)


func set_gameplay_active(active: bool) -> void:
	gameplay_active = active


func deactivate() -> void:
	alive = false
	gameplay_active = false
	_enable_nodes(false)


func take_damage(amount: int) -> void:
	if !alive:
		return
	hp -= amount
	if hp <= 0:
		deactivate()


func _process(delta: float) -> void:
	if !alive or !gameplay_active or stage == null or !stage.has_active_player():
		return
	shot_timer -= delta
	if shot_timer > 0.0:
		return
	shot_timer = shoot_interval
	var direction: Vector2 = stage.get_player_position() - global_position
	if direction.length_squared() == 0.0:
		direction = Vector2.LEFT
	stage.spawn_enemy_bullet(global_position, direction.normalized(), bullet_speed, bullet_damage)


func _enable_nodes(enabled: bool) -> void:
	visible = enabled
	hitbox.monitoring = enabled
	hitbox.monitorable = enabled
	hitbox_shape.disabled = !enabled
	touch_area.monitoring = enabled
	touch_area.monitorable = enabled
	touch_area.set_meta("touch_damage", touch_damage)
	touch_shape.disabled = !enabled


func _apply_size(size: Vector2) -> void:
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
	body.color = Color(0.58, 0.26, 0.74)
