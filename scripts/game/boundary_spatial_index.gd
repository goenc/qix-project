extends RefCounted
class_name BoundarySpatialIndex

const DEFAULT_EPSILON := 0.001
const MIN_INDEXED_SEGMENTS := 12
const MAX_AXIS_CELLS := 32


static func populate(loop: PackedVector2Array, metrics: Dictionary) -> void:
	if loop.size() < MIN_INDEXED_SEGMENTS:
		return

	var bounds := _build_points_aabb(loop)
	var max_extent := maxf(bounds.size.x, bounds.size.y)
	if max_extent <= DEFAULT_EPSILON:
		return
	var target_axis_cells := clampi(int(ceil(sqrt(float(loop.size())))), 2, MAX_AXIS_CELLS)
	var cell_size := maxf(max_extent / float(target_axis_cells), DEFAULT_EPSILON)
	var columns := maxi(int(ceil(bounds.size.x / cell_size)), 1)
	var rows := maxi(int(ceil(bounds.size.y / cell_size)), 1)
	var cells: Array[PackedInt32Array] = []
	for _index in range(columns * rows):
		cells.append(PackedInt32Array())

	for segment_index in range(loop.size()):
		var segment_end := loop[(segment_index + 1) % loop.size()]
		var segment_aabb := Rect2(loop[segment_index], segment_end - loop[segment_index]).abs()
		var min_column := _cell_coordinate(segment_aabb.position.x, bounds.position.x, cell_size, columns)
		var max_column := _cell_coordinate(segment_aabb.end.x, bounds.position.x, cell_size, columns)
		var min_row := _cell_coordinate(segment_aabb.position.y, bounds.position.y, cell_size, rows)
		var max_row := _cell_coordinate(segment_aabb.end.y, bounds.position.y, cell_size, rows)
		for row in range(min_row, max_row + 1):
			for column in range(min_column, max_column + 1):
				cells[row * columns + column].append(segment_index)

	metrics["spatial_cell_size"] = cell_size
	metrics["spatial_columns"] = columns
	metrics["spatial_rows"] = rows
	metrics["spatial_cells"] = cells
	metrics["bounds"] = bounds


static func query(metrics: Dictionary, query_rect: Rect2) -> PackedInt32Array:
	var segment_count := int(metrics.get("segment_count", 0))
	if segment_count <= 0:
		return PackedInt32Array()

	var cells: Array = metrics.get("spatial_cells", [])
	var columns := int(metrics.get("spatial_columns", 0))
	var rows := int(metrics.get("spatial_rows", 0))
	var cell_size := float(metrics.get("spatial_cell_size", 0.0))
	if cells.is_empty() or columns <= 0 or rows <= 0 or cell_size <= DEFAULT_EPSILON:
		return all_segment_indices(segment_count)

	var bounds: Rect2 = metrics.get("bounds", Rect2())
	if !_rects_overlap(bounds, query_rect):
		return PackedInt32Array()
	var min_column := _cell_coordinate(query_rect.position.x, bounds.position.x, cell_size, columns)
	var max_column := _cell_coordinate(query_rect.end.x, bounds.position.x, cell_size, columns)
	var min_row := _cell_coordinate(query_rect.position.y, bounds.position.y, cell_size, rows)
	var max_row := _cell_coordinate(query_rect.end.y, bounds.position.y, cell_size, rows)
	var seen := PackedByteArray()
	seen.resize(segment_count)
	var result := PackedInt32Array()
	for row in range(min_row, max_row + 1):
		for column in range(min_column, max_column + 1):
			var cell_indices: PackedInt32Array = cells[row * columns + column]
			for segment_index in cell_indices:
				if seen[segment_index] != 0:
					continue
				seen[segment_index] = 1
				result.append(segment_index)
	result.sort()
	return result


static func has_index(metrics: Dictionary) -> bool:
	var cells: Array = metrics.get("spatial_cells", [])
	return (
		!cells.is_empty()
		and int(metrics.get("spatial_columns", 0)) > 0
		and int(metrics.get("spatial_rows", 0)) > 0
		and float(metrics.get("spatial_cell_size", 0.0)) > DEFAULT_EPSILON
	)


static func all_segment_indices(segment_count: int) -> PackedInt32Array:
	var result := PackedInt32Array()
	result.resize(segment_count)
	for index in range(segment_count):
		result[index] = index
	return result


static func _cell_coordinate(value: float, origin: float, cell_size: float, cell_count: int) -> int:
	return clampi(int(floor((value - origin) / cell_size)), 0, cell_count - 1)


static func _build_points_aabb(points: PackedVector2Array) -> Rect2:
	if points.is_empty():
		return Rect2()
	var min_point := points[0]
	var max_point := points[0]
	for index in range(1, points.size()):
		min_point = min_point.min(points[index])
		max_point = max_point.max(points[index])
	return Rect2(min_point, max_point - min_point)


static func _rects_overlap(a: Rect2, b: Rect2) -> bool:
	return a.position.x <= b.end.x and a.end.x >= b.position.x and a.position.y <= b.end.y and a.end.y >= b.position.y
