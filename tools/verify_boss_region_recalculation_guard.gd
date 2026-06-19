extends SceneTree

const BaseMain = preload("res://tools/test_support/verify_base_main_boss_region_guard.gd")
const Boundary = preload("res://scripts/game/playfield_boundary.gd")
const BossRegionServiceStub = preload("res://tools/test_support/verify_boss_region_service_stub.gd")

class FakeBossRegionOwner:
	extends Node2D

	var partition_diameter := 40.0
	var capture_radius := 12.0

	func get_partition_reference_diameter() -> float:
		return partition_diameter

	func get_logical_capture_radius() -> float:
		return capture_radius


func _initialize() -> void:
	var failures: Array[String] = []
	_verify_previous_polygon_is_preserved(failures)
	_verify_fallback_polygon_is_restored(failures)
	_verify_remaining_area_ratio_still_drives_clear(failures)
	_verify_non_boss_capture_skips_recalculation(failures)
	_verify_boss_capture_requires_recalculation(failures)
	_verify_corridor_polygon_is_rejected(failures)
	_verify_room_polygon_is_adopted_after_switch(failures)

	if failures.is_empty():
		print("Boss region recalculation guard verification passed.")
		quit(0)
		return
	for failure in failures:
		printerr(failure)
	quit(1)


func _verify_previous_polygon_is_preserved(failures: Array[String]) -> void:
	var main: Variant = _build_main()
	var previous_polygon := Boundary.build_rect_polygon(Rect2(10.0, 10.0, 30.0, 30.0))
	main._set_boss_region_polygon(previous_polygon)
	var previous_ratio: float = main.boss_region_ratio_cached

	var service := BossRegionServiceStub.new()
	service.responses = [{
		"polygon": PackedVector2Array(),
		"remaining_area_ratio": 0.5
	}]
	main.boss_region_service = service
	main._recalculate_boss_region_polygon_after_capture()

	_assert(_loops_equal(main.boss_region_polygon, previous_polygon),
		"Invalid boss-region recalculation overwrote the previous polygon.", failures)
	_assert(is_equal_approx(main.boss_region_ratio_cached, previous_ratio),
		"Invalid boss-region recalculation changed the cached ratio.", failures)
	_assert(main.boss_region_recalculation_warning_active,
		"Failure warning state was not enabled after preserving the previous polygon.", failures)
	main.free()


func _verify_fallback_polygon_is_restored(failures: Array[String]) -> void:
	var main: Variant = _build_main()
	var fallback_polygon := Boundary.build_rect_polygon(Rect2(0.0, 0.0, 100.0, 100.0))
	main.remaining_polygon = fallback_polygon

	var service := BossRegionServiceStub.new()
	service.responses = [{
		"polygon": PackedVector2Array(),
		"remaining_area_ratio": 0.5
	}]
	main.boss_region_service = service
	main._recalculate_boss_region_polygon_after_capture()

	_assert(_loops_equal(main.boss_region_polygon, fallback_polygon),
		"Fallback boss-region polygon was not restored from the remaining polygon.", failures)
	_assert(main.boss_region_ratio_cached > 0.0,
		"Fallback restoration did not rebuild the boss-region ratio cache.", failures)
	main.free()


func _verify_remaining_area_ratio_still_drives_clear(failures: Array[String]) -> void:
	var main: Variant = _build_main()
	var previous_polygon := Boundary.build_rect_polygon(Rect2(10.0, 10.0, 30.0, 30.0))
	main._set_boss_region_polygon(previous_polygon)

	var service := BossRegionServiceStub.new()
	service.responses = [{
		"polygon": PackedVector2Array(),
		"remaining_area_ratio": 0.1
	}]
	main.boss_region_service = service
	main._recalculate_boss_region_polygon_after_capture()

	_assert(main.game_clear,
		"Game clear no longer followed the remaining-area ratio after an invalid boss-region recalculation.", failures)
	main.free()


func _verify_non_boss_capture_skips_recalculation(failures: Array[String]) -> void:
	var main: Variant = _build_main()
	var previous_polygon := Boundary.build_rect_polygon(Rect2(10.0, 10.0, 30.0, 30.0))
	var captured_polygon := Boundary.build_rect_polygon(Rect2(60.0, 60.0, 20.0, 20.0))
	var capture_context := _build_capture_context(captured_polygon)
	main._set_boss_region_polygon(previous_polygon)
	var previous_ratio: float = main.boss_region_ratio_cached
	var service := BossRegionServiceStub.new()
	service.responses = [{
		"polygon": Boundary.build_rect_polygon(Rect2(0.0, 0.0, 10.0, 10.0)),
		"remaining_area_ratio": 1.0
	}]
	main.boss_region_service = service

	_assert(!main._should_recalculate_boss_region_after_capture(capture_context, previous_polygon),
		"A capture outside the boss region incorrectly requested recalculation.", failures)
	main._update_boss_region_after_capture(capture_context, previous_polygon)
	_assert(service.call_count == 0,
		"A capture outside the boss region called the recalculation service.", failures)
	_assert(_loops_equal(main.boss_region_polygon, previous_polygon),
		"A capture outside the boss region changed the boss-region polygon.", failures)
	_assert(is_equal_approx(main.boss_region_ratio_cached, previous_ratio),
		"A capture outside the boss region changed the cached ratio.", failures)
	main.free()


func _verify_boss_capture_requires_recalculation(failures: Array[String]) -> void:
	var main: Variant = _build_main()
	var boss_owner := FakeBossRegionOwner.new()
	main.add_child(boss_owner)
	main.bbos = boss_owner
	boss_owner.partition_diameter = 20.0
	boss_owner.global_position = Vector2(18.0, 18.0)
	var previous_polygon := Boundary.build_rect_polygon(Rect2(10.0, 10.0, 30.0, 30.0))
	var captured_polygon := Boundary.build_rect_polygon(Rect2(25.0, 25.0, 30.0, 30.0))
	var capture_context := _build_capture_context(captured_polygon)
	var recalculated_polygon := Boundary.build_rect_polygon(Rect2(10.0, 10.0, 20.0, 20.0))
	main._set_boss_region_polygon(previous_polygon)
	var service := BossRegionServiceStub.new()
	service.responses = [{
		"polygon": recalculated_polygon,
		"remaining_area_ratio": 1.0
	}]
	main.boss_region_service = service

	_assert(main._should_recalculate_boss_region_after_capture(capture_context, previous_polygon),
		"A capture overlapping the boss region did not request recalculation.", failures)
	main._update_boss_region_after_capture(capture_context, previous_polygon)
	_assert(service.call_count == 1,
		"A capture overlapping the boss region skipped the recalculation service.", failures)
	_assert(_loops_equal(main.boss_region_polygon, recalculated_polygon),
		"A capture overlapping the boss region did not apply the recalculated polygon.", failures)
	main.free()


func _verify_corridor_polygon_is_rejected(failures: Array[String]) -> void:
	var main: Variant = _build_main()
	var boss_owner := FakeBossRegionOwner.new()
	main.add_child(boss_owner)
	main.bbos = boss_owner
	boss_owner.global_position = Vector2(70.0, 25.0)
	var previous_polygon := Boundary.build_rect_polygon(Rect2(10.0, 10.0, 30.0, 30.0))
	var corridor_polygon := Boundary.build_rect_polygon(Rect2(60.0, 10.0, 20.0, 30.0))
	main._set_boss_region_polygon(previous_polygon)
	var previous_ratio: float = main.boss_region_ratio_cached

	var service := BossRegionServiceStub.new()
	service.responses = [{
		"polygon": corridor_polygon,
		"remaining_area_ratio": 1.0
	}]
	main.boss_region_service = service
	main._recalculate_boss_region_polygon_after_capture()

	_assert(_loops_equal(main.boss_region_polygon, previous_polygon),
		"A corridor-only boss-region polygon was adopted.", failures)
	_assert(is_equal_approx(main.boss_region_ratio_cached, previous_ratio),
		"A corridor-only boss-region polygon changed the cached ratio.", failures)
	main.free()


func _verify_room_polygon_is_adopted_after_switch(failures: Array[String]) -> void:
	var main: Variant = _build_main()
	var boss_owner := FakeBossRegionOwner.new()
	main.add_child(boss_owner)
	main.bbos = boss_owner
	boss_owner.global_position = Vector2(90.0, 40.0)
	var previous_polygon := Boundary.build_rect_polygon(Rect2(10.0, 10.0, 30.0, 30.0))
	var switched_room_polygon := Boundary.build_rect_polygon(Rect2(60.0, 10.0, 60.0, 60.0))
	main._set_boss_region_polygon(previous_polygon)

	var service := BossRegionServiceStub.new()
	service.responses = [{
		"polygon": switched_room_polygon,
		"remaining_area_ratio": 1.0
	}]
	main.boss_region_service = service
	main._recalculate_boss_region_polygon_after_capture()

	_assert(_loops_equal(main.boss_region_polygon, switched_room_polygon),
		"A room polygon containing the moved boss was not adopted.", failures)
	main.free()


func _build_capture_context(captured_polygon: PackedVector2Array) -> Dictionary:
	return {
		"captured_polygons": [captured_polygon],
		"captured_polygon_aabbs": [Boundary.build_points_aabb(captured_polygon)],
		"guide_epsilon": 0.5
	}


func _build_main() -> Variant:
	var main: Variant = BaseMain.new()
	main.playfield_area_cached = 10000.0
	main.remaining_polygon = Boundary.build_rect_polygon(Rect2(0.0, 0.0, 100.0, 100.0))
	main.current_outer_loop = main.remaining_polygon
	return main


func _loops_equal(a: PackedVector2Array, b: PackedVector2Array) -> bool:
	if a.size() != b.size():
		return false
	for index in range(a.size()):
		if a[index].distance_to(b[index]) > 0.001:
			return false
	return true


func _assert(condition: bool, message: String, failures: Array[String]) -> void:
	if !condition:
		failures.append(message)
