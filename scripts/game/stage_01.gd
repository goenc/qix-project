extends Node2D
class_name Stage01

signal boss_defeated
signal player_out_of_bounds

const STAGE_CONFIG_PATH := "res://data/config/stage_01.json"

var game_manager = null
var game_config: Dictionary = {}
var stage_data: Dictionary = {}
var player = null
var gameplay_active := false
var boss_started := false
var out_of_bounds_reported := false

@onready var walkers_root: Node = $Enemies/Walkers
@onready var turrets_root: Node = $Enemies/Turrets
@onready var boss = $Enemies/Boss
@onready var enemy_bullets_root: Node = $EnemyBullets
@onready var player_bullets_root: Node = $PlayerBullets


func _ready() -> void:
	set_physics_process(false)


func setup(manager, config: Dictionary) -> void:
	game_manager = manager
	game_config = config
	stage_data = _load_json(STAGE_CONFIG_PATH)
	_configure_enemies()
	_reset_enemy_bullets()
	boss.defeated.connect(_on_boss_defeated)


func attach_player(player_node) -> void:
	player = player_node


func reset_stage() -> void:
	stage_data = _load_json(STAGE_CONFIG_PATH)
	boss_started = false
	out_of_bounds_reported = false
	_configure_enemies()
	_reset_enemy_bullets()


func set_gameplay_active(active: bool) -> void:
	gameplay_active = active
	set_physics_process(active)
	for walker in walkers_root.get_children():
		walker.set_gameplay_active(active)
	for turret in turrets_root.get_children():
		turret.set_gameplay_active(active)
	boss.set_gameplay_active(active)
	if !active:
		_reset_enemy_bullets()


func is_gameplay_active() -> bool:
	return gameplay_active


func get_spawn_position() -> Vector2:
	var values: Array = stage_data.get("spawn_position", [96, 306])
	return Vector2(values[0], values[1])


func get_camera_limits() -> Dictionary:
	return stage_data.get("camera_limits", {})


func get_stage_width() -> float:
	return float(stage_data.get("stage_width", 2560))


func get_stage_height() -> float:
	return float(stage_data.get("stage_height", 384))


func get_death_y() -> float:
	return float(stage_data.get("death_y", 520))


func get_player_position() -> Vector2:
	if player == null:
		return Vector2.ZERO
	return player.global_position


func has_active_player() -> bool:
	return player != null and player.is_active()


func get_player_bullet_parent() -> Node:
	return player_bullets_root if is_instance_valid(player_bullets_root) else self


func spawn_enemy_bullet(origin: Vector2, direction: Vector2, speed: float, damage: int) -> void:
	for bullet in enemy_bullets_root.get_children():
		if !bullet.is_active():
			bullet.activate(self, origin, direction, speed, damage)
			return


func _physics_process(_delta: float) -> void:
	if player == null:
		return
	if !boss_started and player.global_position.x >= float(stage_data.get("boss_trigger_x", 1920)):
		boss_started = true
		boss.activate()
	if !out_of_bounds_reported and player.global_position.y > get_death_y():
		out_of_bounds_reported = true
		player_out_of_bounds.emit()


func _configure_enemies() -> void:
	var walkers: Array = stage_data.get("walkers", [])
	var walker_nodes := walkers_root.get_children()
	for index in range(walker_nodes.size()):
		if index < walkers.size():
			walker_nodes[index].configure(self, game_config, walkers[index])
		else:
			walker_nodes[index].deactivate()

	var turrets: Array = stage_data.get("turrets", [])
	var turret_nodes := turrets_root.get_children()
	for index in range(turret_nodes.size()):
		if index < turrets.size():
			turret_nodes[index].configure(self, game_config, turrets[index])
		else:
			turret_nodes[index].deactivate()

	var boss_data: Dictionary = stage_data.get("boss", {})
	boss.configure(self, game_config, boss_data)


func _reset_enemy_bullets() -> void:
	for bullet in enemy_bullets_root.get_children():
		bullet.deactivate()


func _on_boss_defeated() -> void:
	boss_defeated.emit()


func _load_json(path: String) -> Dictionary:
	if !FileAccess.file_exists(path):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Dictionary:
		return parsed
	return {}
