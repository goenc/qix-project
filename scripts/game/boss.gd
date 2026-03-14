extends CharacterBody2D
class_name Boss

signal defeated

enum BossState {
	WAIT,
	JUMP,
	SHOOT,
}

var stage = null
var configured := false
var alive := false
var engaged := false
var gameplay_active := false
var boss_state: BossState = BossState.WAIT
var gravity := 900.0
var move_speed := 110.0
var jump_velocity := -280.0
var hp := 12
var max_hp := 12
var bullet_speed := 120.0
var bullet_damage := 1
var touch_damage := 1
var shot_interval := 0.3
var shot_count := 3
var wait_after_burst := 1.0
var state_timer := 0.0
var shots_remaining := 0

@onready var collider: CollisionShape2D = $CollisionShape2D
@onready var body: Polygon2D = $Body
@onready var hitbox: Area2D = $Hitbox
@onready var hitbox_shape: CollisionShape2D = $Hitbox/CollisionShape2D
@onready var touch_area: Area2D = $TouchArea
@onready var touch_shape: CollisionShape2D = $TouchArea/CollisionShape2D


func _ready() -> void:
	_apply_size(Vector2(48, 48))
	hitbox.set_meta("damageable_owner", self)
	touch_area.set_meta("touch_owner", self)
	deactivate()


func configure(stage_ref, game_config: Dictionary, data: Dictionary) -> void:
	stage = stage_ref
	var boss_config: Dictionary = game_config.get("boss", {})
	var bullet_config: Dictionary = game_config.get("enemy_bullet", {})
	gravity = float(game_config.get("gravity", 900.0))
	move_speed = float(boss_config.get("move_speed", 110.0))
	jump_velocity = float(boss_config.get("jump_velocity", -280.0))
	max_hp = int(boss_config.get("hp", 12))
	hp = max_hp
	bullet_speed = float(bullet_config.get("speed", 120.0))
	bullet_damage = int(bullet_config.get("damage", 1))
	touch_damage = int(boss_config.get("contact_damage", 1))
	shot_interval = float(boss_config.get("shot_interval", 0.3))
	shot_count = int(boss_config.get("shot_count", 3))
	wait_after_burst = float(boss_config.get("wait_after_burst", 1.0))
	var position_data: Array = data.get("position", [0, 0])
	global_position = Vector2(position_data[0], position_data[1])
	velocity = Vector2.ZERO
	configured = true
	alive = true
	engaged = false
	gameplay_active = false
	boss_state = BossState.WAIT
	state_timer = 0.4
	shots_remaining = shot_count
	_enable_nodes(false)


func activate() -> void:
	if !configured or !alive:
		return
	engaged = true
	_enable_nodes(true)


func set_gameplay_active(active: bool) -> void:
	gameplay_active = active


func deactivate() -> void:
	configured = false
	alive = false
	engaged = false
	gameplay_active = false
	velocity = Vector2.ZERO
	_enable_nodes(false)


func take_damage(amount: int) -> void:
	if !alive:
		return
	hp -= amount
	if hp <= 0:
		alive = false
		engaged = false
		gameplay_active = false
		_enable_nodes(false)
		defeated.emit()


func _physics_process(delta: float) -> void:
	if !alive or !engaged or !gameplay_active:
		return
	var was_on_floor: bool = is_on_floor()
	velocity.y += gravity * delta
	match boss_state:
		BossState.WAIT:
			velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta)
			state_timer -= delta
			if state_timer <= 0.0 and is_on_floor():
				_start_jump()
		BossState.JUMP:
			pass
		BossState.SHOOT:
			velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta)
			state_timer -= delta
			if state_timer <= 0.0:
				_fire_shot()
				shots_remaining -= 1
				if shots_remaining > 0:
					state_timer = shot_interval
				else:
					boss_state = BossState.WAIT
					state_timer = wait_after_burst
	move_and_slide()
	if boss_state == BossState.JUMP and !was_on_floor and is_on_floor():
		boss_state = BossState.SHOOT
		shots_remaining = shot_count
		state_timer = 0.0


func _start_jump() -> void:
	var direction: float = sign(stage.get_player_position().x - global_position.x)
	if direction == 0.0:
		direction = -1.0
	velocity.x = direction * move_speed
	velocity.y = jump_velocity
	boss_state = BossState.JUMP


func _fire_shot() -> void:
	var direction: Vector2 = stage.get_player_position() - global_position
	if direction.length_squared() == 0.0:
		direction = Vector2.LEFT
	stage.spawn_enemy_bullet(global_position + Vector2(sign(direction.x) * 28.0, -8.0), direction.normalized(), bullet_speed, bullet_damage)


func _enable_nodes(enabled: bool) -> void:
	visible = enabled
	collider.set_deferred("disabled", !enabled)
	hitbox.set_deferred("monitoring", enabled)
	hitbox.set_deferred("monitorable", enabled)
	hitbox_shape.set_deferred("disabled", !enabled)
	touch_area.set_deferred("monitoring", enabled)
	touch_area.set_deferred("monitorable", enabled)
	touch_area.set_meta("touch_damage", touch_damage)
	touch_shape.set_deferred("disabled", !enabled)


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
	body.color = Color(0.22, 0.73, 0.36)
