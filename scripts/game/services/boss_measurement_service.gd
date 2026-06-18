extends RefCounted
class_name BossMeasurementService


static func get_capture_radius(primary_boss: Node, fallback_boss: Node = null) -> float:
	if is_instance_valid(primary_boss):
		if primary_boss.has_method("get_logical_capture_radius"):
			return maxf(float(primary_boss.call("get_logical_capture_radius")), 0.0)
		if primary_boss.has_method("get_enemy_collision_radius"):
			return maxf(float(primary_boss.call("get_enemy_collision_radius")), 0.0)
		var primary_radius := _get_nonnegative_float_property(primary_boss, &"collision_radius")
		if primary_radius >= 0.0:
			return primary_radius

	if is_instance_valid(fallback_boss):
		return maxf(_get_nonnegative_float_property(fallback_boss, &"collision_radius"), 0.0)
	return 0.0


static func get_partition_diameter(primary_boss: Node, fallback_boss: Node = null) -> float:
	if is_instance_valid(primary_boss) and primary_boss.has_method("get_partition_reference_diameter"):
		return maxf(float(primary_boss.call("get_partition_reference_diameter")), 0.0)
	return get_capture_radius(primary_boss, fallback_boss) * 2.0


static func _get_nonnegative_float_property(target: Object, property_name: StringName) -> float:
	for property in target.get_property_list():
		if StringName(property.get("name", &"")) == property_name:
			return maxf(float(target.get(property_name)), 0.0)
	return -1.0
