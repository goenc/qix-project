extends CharacterBody2D
class_name Player

signal life_changed(current_life: int, max_life: int)
signal defeated

const PLAYER_BULLET_SCENE := preload("res://scenes/player/player_bullet.tscn")

var game_manager = null
var gameplay_active := false
var move_speed := 120.0
var jump_velocity := -320.0
var gravity := 900.0
var max_life := 5
var current_life := 5
var invincible_time := 1.0
var invincible_remaining := 0.0
var facing := 1.0
var bullet_config: Dictionary = {}
var current_bullet: PlayerBullet = null

@onready var collider: CollisionShape2D = $CollisionShape2D
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var hurtbox: Area2D = $Hurtbox
@onready var hurtbox_shape: CollisionShape2D = $Hurtbox/CollisionShape2D
@onready var camera: Camera2D = $Camera2D


func _ready() -> void:
	_apply_size(Vector2(24, 28))
	hurtbox.set_meta("player_owner", self)
	hurtbox.area_entered.connect(_on_hurtbox_area_entered)
	hide()
	set_gameplay_active(false)


func setup(manager, config: Dictionary) -> void:
	game_manager = manager
	bullet_config = config
	_apply_config(config)


func reset_for_stage(spawn_position: Vector2, config: Dictionary) -> void:
	bullet_config = config
	_apply_config(config)
	current_life = max_life
	global_position = spawn_position
	velocity = Vector2.ZERO
	invincible_remaining = 0.0
	modulate = Color.WHITE
	_deactivate_current_bullet()
	life_changed.emit(current_life, max_life)


func set_gameplay_active(active: bool) -> void:
	gameplay_active = active
	collider.set_deferred("disabled", !active)
	hurtbox.set_deferred("monitoring", active)
	hurtbox.set_deferred("monitorable", active)
	hurtbox_shape.set_deferred("disabled", !active)
	camera.enabled = active
	if !active:
		velocity = Vector2.ZERO
		_deactivate_current_bullet()


func is_active() -> bool:
	return gameplay_active


func get_life() -> int:
	return current_life


func get_max_life() -> int:
	return max_life


func apply_camera_limits(limits: Dictionary) -> void:
	camera.limit_left = int(limits.get("left", 0))
	camera.limit_top = int(limits.get("top", 0))
	camera.limit_right = int(limits.get("right", 2560))
	camera.limit_bottom = int(limits.get("bottom", 360))


func apply_damage(amount: int) -> void:
	if !gameplay_active or invincible_remaining > 0.0:
		return
	current_life = max(current_life - amount, 0)
	life_changed.emit(current_life, max_life)
	if current_life <= 0:
		gameplay_active = false
		defeated.emit()
		return
	invincible_remaining = invincible_time


func _physics_process(delta: float) -> void:
	if !gameplay_active:
		return
	if invincible_remaining > 0.0:
		invincible_remaining = max(invincible_remaining - delta, 0.0)
		modulate = Color(1.0, 1.0, 1.0, 0.45) if int(invincible_remaining * 12.0) % 2 == 0 else Color.WHITE
	else:
		modulate = Color.WHITE
	if !is_on_floor():
		velocity.y += gravity * delta
	var input_axis := Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	if input_axis != 0.0:
		facing = sign(input_axis)
	velocity.x = input_axis * move_speed
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity
	if Input.is_action_just_pressed("shoot"):
		_try_shoot()
	move_and_slide()
	var on_floor := is_on_floor()
	var target_animation := &"jump"
	if on_floor:
		target_animation = &"run" if absf(velocity.x) >= 1.0 else &"idle"
		if velocity.x < 0.0:
			sprite.flip_h = true
		elif velocity.x > 0.0:
			sprite.flip_h = false
	if sprite.animation != target_animation:
		sprite.play(target_animation)


func _apply_config(config: Dictionary) -> void:
	var player_config: Dictionary = config.get("player", {})
	move_speed = float(player_config.get("move_speed", 120.0))
	jump_velocity = float(player_config.get("jump_velocity", -320.0))
	max_life = int(player_config.get("max_life", 5))
	invincible_time = float(player_config.get("invincible_time", 1.0))
	gravity = float(config.get("gravity", 900.0))


func _try_shoot() -> void:
	if current_bullet != null and is_instance_valid(current_bullet):
		return
	var bullet := PLAYER_BULLET_SCENE.instantiate() as PlayerBullet
	if bullet == null:
		push_error("Failed to instantiate player bullet scene.")
		return
	var bullet_parent := _get_bullet_parent()
	if bullet_parent == null:
		push_error("Failed to resolve player bullet parent.")
		bullet.queue_free()
		return
	current_bullet = bullet
	bullet.despawned.connect(_on_current_bullet_despawned.bind(bullet), CONNECT_ONE_SHOT)
	bullet_parent.add_child(bullet)
	bullet.configure(game_manager, bullet_config)
	bullet.fire(global_position + Vector2(facing * 18.0, -4.0), facing)


func _on_hurtbox_area_entered(area: Area2D) -> void:
	if !area.has_meta("touch_damage"):
		return
	apply_damage(int(area.get_meta("touch_damage")))


func _apply_size(size: Vector2) -> void:
	var shape := collider.shape as RectangleShape2D
	if shape != null:
		shape.size = size
	var hurt_shape := hurtbox_shape.shape as RectangleShape2D
	if hurt_shape != null:
		hurt_shape.size = size


func _deactivate_current_bullet() -> void:
	if current_bullet != null and is_instance_valid(current_bullet):
		current_bullet.deactivate(false)
	current_bullet = null


func _get_bullet_parent() -> Node:
	if game_manager == null or !game_manager.has_method("get_stage"):
		return null
	var stage = game_manager.get_stage()
	if stage == null or !is_instance_valid(stage):
		return null
	if stage.has_method("get_player_bullet_parent"):
		var bullet_parent = stage.call("get_player_bullet_parent")
		if bullet_parent is Node and is_instance_valid(bullet_parent):
			return bullet_parent
	return stage


func _on_current_bullet_despawned(bullet: PlayerBullet) -> void:
	if current_bullet == bullet:
		current_bullet = null
