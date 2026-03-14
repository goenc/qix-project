extends RefCounted
class_name TileMapOutlineBuilder


static func build_outline_segments(tile_map_layer: TileMapLayer) -> Array[PackedVector2Array]:
	var segments: Array[PackedVector2Array] = []
	if tile_map_layer == null or tile_map_layer.tile_set == null:
		return segments

	var tile_size := Vector2(tile_map_layer.tile_set.tile_size)
	if tile_size == Vector2.ZERO:
		return segments

	var used_cells := tile_map_layer.get_used_cells()
	if used_cells.is_empty():
		return segments

	var used_cell_lookup := {}
	for cell in used_cells:
		used_cell_lookup[cell] = true

	var half_size := tile_size * 0.5
	for cell in used_cells:
		var cell_center := tile_map_layer.map_to_local(cell)
		var top_left := cell_center + Vector2(-half_size.x, -half_size.y)
		var top_right := cell_center + Vector2(half_size.x, -half_size.y)
		var bottom_right := cell_center + Vector2(half_size.x, half_size.y)
		var bottom_left := cell_center + Vector2(-half_size.x, half_size.y)

		if !used_cell_lookup.has(cell + Vector2i.UP):
			segments.append(PackedVector2Array([top_left, top_right]))
		if !used_cell_lookup.has(cell + Vector2i.RIGHT):
			segments.append(PackedVector2Array([top_right, bottom_right]))
		if !used_cell_lookup.has(cell + Vector2i.DOWN):
			segments.append(PackedVector2Array([bottom_right, bottom_left]))
		if !used_cell_lookup.has(cell + Vector2i.LEFT):
			segments.append(PackedVector2Array([bottom_left, top_left]))

	return segments
