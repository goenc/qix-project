extends Node2D
class_name HitboxDebugOverlay

const PLAYER_GROUP := &"debug_player_collision"
const ENEMY_GROUP := &"debug_enemy_collision"
const GROUND_GROUP := &"debug_ground_collision"

const PLAYER_COLOR := Color8(64, 160, 255)
const ENEMY_COLOR := Color8(176, 96, 224)
const GROUND_COLOR := Color8(64, 208, 96)
const LINE_WIDTH := 2.0
const ARC_SEGMENT_COUNT := 24

const TILEMAP_OUTLINE_BUILDER := preload("res://debug/overlays/hitbox/tilemap_outline_builder.gd")


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	top_level = true
	z_as_relative = false
	z_index = 4096


func _process(_delta: float) -> void:
	if visible:
		queue_redraw()


func _draw() -> void:
	_draw_group(PLAYER_GROUP, PLAYER_COLOR)
	_draw_group(ENEMY_GROUP, ENEMY_COLOR)
	_draw_ground_group()


func _draw_group(group_name: StringName, color: Color) -> void:
	for target in get_tree().get_nodes_in_group(group_name):
		if target is Node:
			_draw_collision_nodes(target, color)


func _draw_ground_group() -> void:
	for target in get_tree().get_nodes_in_group(GROUND_GROUP):
		if target is TileMapLayer:
			_draw_tilemap_outline(target)
			continue
		if target is Node:
			_draw_collision_nodes(target, GROUND_COLOR)


func _draw_tilemap_outline(tile_map_layer: TileMapLayer) -> void:
	for segment in TILEMAP_OUTLINE_BUILDER.build_outline_segments(tile_map_layer):
		if segment.size() != 2:
			continue
		var global_segment := PackedVector2Array([
			tile_map_layer.to_global(segment[0]),
			tile_map_layer.to_global(segment[1]),
		])
		draw_polyline(global_segment, GROUND_COLOR, LINE_WIDTH, true)


func _draw_collision_nodes(target: Node, color: Color) -> void:
	if target is CollisionShape2D:
		_draw_collision_shape_2d(target, color)
	elif target is CollisionPolygon2D:
		_draw_collision_polygon_2d(target, color)

	for child in target.get_children():
		if child is Node:
			_draw_collision_nodes(child, color)


func _draw_collision_shape_2d(collision_shape: CollisionShape2D, color: Color) -> void:
	if collision_shape.disabled:
		return
	var shape := collision_shape.shape
	if shape == null:
		return
	var shape_transform := collision_shape.global_transform

	if shape is RectangleShape2D:
		var rectangle_shape := shape as RectangleShape2D
		var half_size: Vector2 = rectangle_shape.size * 0.5
		var points := PackedVector2Array([
			Vector2(-half_size.x, -half_size.y),
			Vector2(half_size.x, -half_size.y),
			Vector2(half_size.x, half_size.y),
			Vector2(-half_size.x, half_size.y),
		])
		_draw_closed_points(_transform_points(shape_transform, points), color)
		return

	if shape is CircleShape2D:
		var circle_shape := shape as CircleShape2D
		_draw_closed_points(_transform_points(shape_transform, _build_circle_points(circle_shape.radius)), color)
		return

	if shape is CapsuleShape2D:
		var capsule_shape := shape as CapsuleShape2D
		_draw_closed_points(_transform_points(shape_transform, _build_capsule_points(capsule_shape.radius, capsule_shape.height)), color)
		return

	if shape is ConvexPolygonShape2D:
		var convex_shape := shape as ConvexPolygonShape2D
		_draw_closed_points(_transform_points(shape_transform, convex_shape.points), color)
		return

	if shape is ConcavePolygonShape2D:
		var concave_shape := shape as ConcavePolygonShape2D
		_draw_concave_segments(shape_transform, concave_shape.segments, color)
		return

	if shape is SegmentShape2D:
		var segment_shape := shape as SegmentShape2D
		_draw_segment(shape_transform * segment_shape.a, shape_transform * segment_shape.b, color)
		return

	if shape is SeparationRayShape2D:
		var ray_shape := shape as SeparationRayShape2D
		_draw_segment(shape_transform.origin, shape_transform * Vector2(ray_shape.length, 0.0), color)


func _draw_collision_polygon_2d(collision_polygon: CollisionPolygon2D, color: Color) -> void:
	if collision_polygon.disabled or collision_polygon.polygon.is_empty():
		return
	var transformed := _transform_points(collision_polygon.global_transform, collision_polygon.polygon)
	if collision_polygon.build_mode == CollisionPolygon2D.BUILD_SEGMENTS:
		draw_polyline(transformed, color, LINE_WIDTH, true)
		return
	_draw_closed_points(transformed, color)


func _draw_concave_segments(transform_2d: Transform2D, segments: PackedVector2Array, color: Color) -> void:
	for index in range(0, segments.size(), 2):
		if index + 1 >= segments.size():
			return
		_draw_segment(transform_2d * segments[index], transform_2d * segments[index + 1], color)


func _draw_segment(global_start: Vector2, global_end: Vector2, color: Color) -> void:
	draw_polyline(PackedVector2Array([global_start, global_end]), color, LINE_WIDTH, true)


func _draw_closed_points(points: PackedVector2Array, color: Color) -> void:
	if points.size() < 2:
		return
	var closed_points := points.duplicate()
	closed_points.append(points[0])
	draw_polyline(closed_points, color, LINE_WIDTH, true)


func _transform_points(transform_2d: Transform2D, points: PackedVector2Array) -> PackedVector2Array:
	var transformed := PackedVector2Array()
	for point in points:
		transformed.append(transform_2d * point)
	return transformed


func _build_circle_points(radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(ARC_SEGMENT_COUNT):
		var angle := TAU * float(index) / float(ARC_SEGMENT_COUNT)
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points


func _build_capsule_points(radius: float, height: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	var cylinder_height := maxf(height - radius * 2.0, 0.0)
	var half_cylinder := cylinder_height * 0.5
	var half_arc_count := int(ARC_SEGMENT_COUNT / 2)

	for index in range(half_arc_count + 1):
		var angle := PI + PI * float(index) / float(half_arc_count)
		points.append(Vector2(cos(angle), sin(angle)) * radius + Vector2(0.0, -half_cylinder))

	for index in range(half_arc_count + 1):
		var angle := PI * float(index) / float(half_arc_count)
		points.append(Vector2(cos(angle), sin(angle)) * radius + Vector2(0.0, half_cylinder))

	return points
