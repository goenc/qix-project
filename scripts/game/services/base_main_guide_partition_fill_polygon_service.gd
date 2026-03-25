extends RefCounted
class_name BaseMainGuidePartitionFillPolygonService

const PlayfieldBoundary = preload("res://scripts/game/playfield_boundary.gd")
const BaseMainGuidePartitionFillEntryService = preload("res://scripts/game/services/base_main_guide_partition_fill_entry_service.gd")

var _entry_service := BaseMainGuidePartitionFillEntryService.new()


func collect_guide_partition_rects(state: Dictionary) -> Array[PackedVector2Array]:
	var polygons: Array[PackedVector2Array] = []
	var epsilon := float(state.get("guide_epsilon", 0.0))
	var guide_partition_fill_entries: Array[Dictionary] = state.get("guide_partition_fill_entries", [])
	var guide_partition_fill_polygons_by_key: Dictionary = state.get("guide_partition_fill_polygons_by_key", {})
	for entry in guide_partition_fill_entries:
		var entry_key := _entry_service.extract_entry_storage_key(entry)
		if entry_key.is_empty() or !guide_partition_fill_polygons_by_key.has(entry_key):
			continue
		var fill_polygons: Array = guide_partition_fill_polygons_by_key[entry_key]
		for raw_polygon in fill_polygons:
			if typeof(raw_polygon) != TYPE_PACKED_VECTOR2_ARRAY:
				continue
			var polygon: PackedVector2Array = raw_polygon
			if !_is_guide_partition_fill_polygon_drawable(polygon, epsilon):
				continue
			polygons.append(polygon)
	return polygons


func rebuild_partition_fill_polygons(partition_state: Dictionary) -> void:
	var guide_partition_fill_polygons_by_key: Dictionary = partition_state.get("guide_partition_fill_polygons_by_key", {})
	guide_partition_fill_polygons_by_key.clear()
	var guide_partition_fill_entries: Array[Dictionary] = partition_state.get("guide_partition_fill_entries", [])
	var epsilon := float(partition_state.get("guide_epsilon", 0.0))
	for entry in guide_partition_fill_entries:
		_refresh_guide_partition_fill_result_for_entry(partition_state, entry, epsilon)


func _refresh_guide_partition_fill_result_for_entry(
	partition_state: Dictionary,
	entry: Dictionary,
	epsilon: float
) -> void:
	var guide_partition_fill_polygons_by_key: Dictionary = partition_state.get("guide_partition_fill_polygons_by_key", {})
	var storage_key := _entry_service.extract_entry_storage_key(entry)
	if storage_key.is_empty():
		return
	var rect = entry.get("rect", Rect2())
	if typeof(rect) != TYPE_RECT2:
		guide_partition_fill_polygons_by_key.erase(storage_key)
		return
	var entry_rect: Rect2 = rect
	if !_entry_service.has_valid_base_rect(entry, epsilon):
		guide_partition_fill_polygons_by_key.erase(storage_key)
		return

	var remaining_polygon: PackedVector2Array = partition_state.get("remaining_polygon", PackedVector2Array())
	if remaining_polygon.size() < 3:
		guide_partition_fill_polygons_by_key.erase(storage_key)
		return

	var rect_polygon := PlayfieldBoundary.build_rect_polygon(entry_rect)
	var intersected: Array = Geometry2D.intersect_polygons(rect_polygon, remaining_polygon)
	if intersected.is_empty():
		guide_partition_fill_polygons_by_key.erase(storage_key)
		return

	var fill_polygons: Array[PackedVector2Array] = []
	for raw_polygon in intersected:
		if typeof(raw_polygon) != TYPE_PACKED_VECTOR2_ARRAY:
			continue
		var fill_polygon: PackedVector2Array = raw_polygon
		if !_is_guide_partition_fill_polygon_drawable(fill_polygon, epsilon):
			continue
		fill_polygons.append(fill_polygon)
	if fill_polygons.is_empty():
		guide_partition_fill_polygons_by_key.erase(storage_key)
		return
	guide_partition_fill_polygons_by_key[storage_key] = fill_polygons


func _is_guide_partition_fill_polygon_drawable(polygon: PackedVector2Array, epsilon: float) -> bool:
	if polygon.size() < 3:
		return false
	var aabb := PlayfieldBoundary.build_points_aabb(polygon)
	if aabb.size.x <= epsilon or aabb.size.y <= epsilon:
		return false
	return absf(PlayfieldBoundary.polygon_area(polygon)) > epsilon * epsilon
