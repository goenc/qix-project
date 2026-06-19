extends SceneTree

const EnemyPlayerHitService = preload("res://scripts/enemy/services/enemy_player_hit_service.gd")
const BossMeasurementService = preload("res://scripts/game/services/boss_measurement_service.gd")


class FakePlayer:
	extends Node

	var body_enabled := false
	var trail_enabled := false
	var damage_count := 0
	var body_rect := Rect2(40.0, 40.0, 20.0, 20.0)
	var trail_segments: Array = [
		PackedVector2Array([Vector2(70.0, 20.0), Vector2(70.0, 80.0)])
	]

	func get_boss_hit_targets() -> Dictionary:
		return {"player": body_enabled, "trail": trail_enabled}

	func is_body_damage_hitbox_enabled() -> bool:
		return body_enabled

	func is_trail_damage_hitbox_enabled() -> bool:
		return trail_enabled

	func get_body_damage_rect() -> Rect2:
		return body_rect

	func get_active_damage_trail_segments() -> Array:
		return trail_segments

	func get_active_damage_trail_data() -> Dictionary:
		return {"segments": trail_segments, "aabbs": []}

	func apply_boss_damage() -> bool:
		damage_count += 1
		return true


class FakePrimaryBoss:
	extends Node

	func get_logical_capture_radius() -> float:
		return 18.0

	func get_partition_reference_diameter() -> float:
		return 52.0


class FakeFallbackBoss:
	extends Node

	var collision_radius := 12.0


func _initialize() -> void:
	var failures: Array[String] = []
	var player := FakePlayer.new()
	root.add_child(player)

	player.body_enabled = true
	_assert(
		EnemyPlayerHitService.try_apply_hit(player, Vector2(0.0, 50.0), Vector2(100.0, 50.0), 2.0),
		"Body sweep did not register a hit.",
		failures
	)
	_assert(player.damage_count == 1, "Body sweep did not apply exactly one damage event.", failures)

	player.body_enabled = false
	player.trail_enabled = true
	_assert(
		EnemyPlayerHitService.try_apply_hit(player, Vector2(0.0, 50.0), Vector2(100.0, 50.0), 2.0),
		"Trail sweep did not register a hit.",
		failures
	)
	_assert(player.damage_count == 2, "Trail sweep did not apply exactly one damage event.", failures)

	player.trail_segments.append("invalid segment")
	_assert(
		!EnemyPlayerHitService.try_apply_hit(player, Vector2(0.0, 5.0), Vector2(30.0, 5.0), 1.0),
		"Separated sweep produced a false hit.",
		failures
	)
	_assert(player.damage_count == 2, "Miss sweep changed the damage count.", failures)

	var primary_boss := FakePrimaryBoss.new()
	var fallback_boss := FakeFallbackBoss.new()
	var propertyless_boss := Node.new()
	root.add_child(primary_boss)
	root.add_child(fallback_boss)
	root.add_child(propertyless_boss)
	_assert(
		is_equal_approx(BossMeasurementService.get_capture_radius(primary_boss, fallback_boss), 18.0),
		"Primary boss capture radius was not preferred.",
		failures
	)
	_assert(
		is_equal_approx(BossMeasurementService.get_partition_diameter(primary_boss, fallback_boss), 52.0),
		"Primary boss partition diameter was not preferred.",
		failures
	)
	_assert(
		is_equal_approx(BossMeasurementService.get_capture_radius(null, fallback_boss), 12.0),
		"Fallback boss collision radius was not resolved.",
		failures
	)
	_assert(
		is_zero_approx(BossMeasurementService.get_capture_radius(null, propertyless_boss)),
		"Missing collision radius did not resolve to zero.",
		failures
	)

	if failures.is_empty():
		print("Enemy hit and boss measurement verification passed.")
		quit(0)
		return
	for failure in failures:
		printerr(failure)
	quit(1)


func _assert(condition: bool, message: String, failures: Array[String]) -> void:
	if !condition:
		failures.append(message)
