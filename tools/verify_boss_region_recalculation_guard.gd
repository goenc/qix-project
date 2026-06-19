extends SceneTree

const BaseMain = preload("res://tools/test_support/verify_base_main_boss_region_guard.gd")
const Boundary = preload("res://scripts/game/playfield_boundary.gd")
const BossRegionServiceStub = preload("res://tools/test_support/verify_boss_region_service_stub.gd")


func _initialize() -> void:
	var failures: Array[String] = []
	_verify_previous_polygon_is_preserved(failures)
	_verify_fallback_polygon_is_restored(failures)
	_verify_remaining_area_ratio_still_drives_clear(failures)

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
