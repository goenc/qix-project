extends RefCounted
class_name EnemyPlayerHitService


static func try_apply_hit(
	player: Node,
	from_point: Vector2,
	to_point: Vector2,
	attack_radius: float
) -> bool:
	if !is_instance_valid(player):
		return false
	if !player.has_method("get_boss_hit_targets") or !player.has_method("apply_boss_damage"):
		return false

	var targets: Dictionary = player.call("get_boss_hit_targets")
	var body_enabled := bool(targets.get("player", false))
	var trail_enabled := bool(targets.get("trail", false))
	if player.has_method("is_body_damage_hitbox_enabled"):
		body_enabled = bool(player.call("is_body_damage_hitbox_enabled"))
	if player.has_method("is_trail_damage_hitbox_enabled"):
		trail_enabled = bool(player.call("is_trail_damage_hitbox_enabled"))

	var swept_aabb := build_swept_aabb(from_point, to_point, attack_radius)
	var best_hit := {"hit": false}
	if body_enabled and player.has_method("get_body_damage_rect"):
		var body_rect: Rect2 = player.call("get_body_damage_rect")
		if rects_overlap(swept_aabb, body_rect):
			best_hit = find_segment_rect_contact(from_point, to_point, body_rect, attack_radius)

	if trail_enabled and player.has_method("get_active_damage_trail_segments"):
		var trail_segments: Array = []
		var trail_segment_aabbs: Array = []
		if player.has_method("get_active_damage_trail_data"):
			var trail_data: Dictionary = player.call("get_active_damage_trail_data")
			trail_segments = trail_data.get("segments", [])
			trail_segment_aabbs = trail_data.get("aabbs", [])
		else:
			trail_segments = player.call("get_active_damage_trail_segments")
		var trail_hit := find_trail_hit(
			from_point,
			to_point,
			attack_radius,
			trail_segments,
			trail_segment_aabbs,
			swept_aabb
		)
		if (
			bool(trail_hit.get("hit", false))
			and (
				!bool(best_hit.get("hit", false))
				or float(trail_hit.get("distance", INF)) < float(best_hit.get("distance", INF))
			)
		):
			best_hit = trail_hit

	if !bool(best_hit.get("hit", false)):
		return false
	player.call("apply_boss_damage")
	return true


static func find_trail_hit(
	from_point: Vector2,
	to_point: Vector2,
	attack_radius: float,
	trail_segments: Array,
	trail_segment_aabbs: Array,
	swept_aabb: Rect2
) -> Dictionary:
	var best_hit := {"hit": false}
	for index in range(trail_segments.size()):
		if typeof(trail_segments[index]) != TYPE_PACKED_VECTOR2_ARRAY:
			continue
		var segment: PackedVector2Array = trail_segments[index]
		if segment.size() < 2:
			continue

		var segment_aabb := build_swept_aabb(segment[0], segment[1], 0.0)
		if index < trail_segment_aabbs.size() and typeof(trail_segment_aabbs[index]) == TYPE_RECT2:
			segment_aabb = trail_segment_aabbs[index]
		if !rects_overlap(swept_aabb, segment_aabb):
			continue

		var contact := find_segment_segment_contact(
			from_point,
			to_point,
			segment[0],
			segment[1],
			attack_radius
		)
		if (
			bool(contact.get("hit", false))
			and (
				!bool(best_hit.get("hit", false))
				or float(contact.get("distance", INF)) < float(best_hit.get("distance", INF))
			)
		):
			best_hit = contact
	return best_hit


static func find_segment_rect_contact(
	from_point: Vector2,
	to_point: Vector2,
	rect: Rect2,
	padding: float
) -> Dictionary:
	var expanded_rect := rect.grow(maxf(padding, 0.0))
	var delta := to_point - from_point
	if delta.is_zero_approx():
		if expanded_rect.has_point(from_point):
			return {"hit": true, "distance": 0.0, "point": from_point}
		return {"hit": false}

	var t_min := 0.0
	var t_max := 1.0
	for axis in [
		Vector2(-delta.x, from_point.x - expanded_rect.position.x),
		Vector2(delta.x, expanded_rect.end.x - from_point.x),
		Vector2(-delta.y, from_point.y - expanded_rect.position.y),
		Vector2(delta.y, expanded_rect.end.y - from_point.y)
	]:
		var clip_result := _clip_segment_axis(axis.x, axis.y, t_min, t_max)
		if !bool(clip_result.get("hit", false)):
			return {"hit": false}
		t_min = float(clip_result.get("t_min", t_min))
		t_max = float(clip_result.get("t_max", t_max))

	var contact_point := from_point + delta * t_min
	return {
		"hit": true,
		"distance": from_point.distance_to(contact_point),
		"point": contact_point
	}


static func find_segment_segment_contact(
	a0: Vector2,
	a1: Vector2,
	b0: Vector2,
	b1: Vector2,
	radius: float
) -> Dictionary:
	var d1 := a1 - a0
	var d2 := b1 - b0
	var offset := a0 - b0
	var a := d1.dot(d1)
	var e := d2.dot(d2)
	var f := d2.dot(offset)
	var s := 0.0
	var t := 0.0

	if a <= 0.0001 and e <= 0.0001:
		if a0.distance_to(b0) <= radius:
			return {"hit": true, "distance": 0.0, "point": a0}
		return {"hit": false}

	if a <= 0.0001:
		t = clampf(f / e, 0.0, 1.0)
	elif e <= 0.0001:
		s = clampf(-d1.dot(offset) / a, 0.0, 1.0)
	else:
		var c := d1.dot(offset)
		var b := d1.dot(d2)
		var denominator := a * e - b * b
		if !is_zero_approx(denominator):
			s = clampf((b * f - c * e) / denominator, 0.0, 1.0)
		t = (b * s + f) / e
		if t < 0.0:
			t = 0.0
			s = clampf(-c / a, 0.0, 1.0)
		elif t > 1.0:
			t = 1.0
			s = clampf((b - c) / a, 0.0, 1.0)

	var closest_a := a0 + d1 * s
	var closest_b := b0 + d2 * t
	if closest_a.distance_to(closest_b) > maxf(radius, 0.0):
		return {"hit": false}
	return {
		"hit": true,
		"distance": a0.distance_to(closest_a),
		"point": closest_a
	}


static func build_swept_aabb(from_point: Vector2, to_point: Vector2, padding: float) -> Rect2:
	var min_point := Vector2(minf(from_point.x, to_point.x), minf(from_point.y, to_point.y))
	var max_point := Vector2(maxf(from_point.x, to_point.x), maxf(from_point.y, to_point.y))
	return Rect2(min_point, max_point - min_point).grow(maxf(padding, 0.0))


static func rects_overlap(a: Rect2, b: Rect2) -> bool:
	return (
		a.position.x <= b.end.x
		and a.end.x >= b.position.x
		and a.position.y <= b.end.y
		and a.end.y >= b.position.y
	)


static func _clip_segment_axis(p: float, q: float, t_min: float, t_max: float) -> Dictionary:
	if is_zero_approx(p):
		return {"hit": q >= 0.0, "t_min": t_min, "t_max": t_max}

	var ratio := q / p
	if p < 0.0:
		if ratio > t_max:
			return {"hit": false}
		t_min = maxf(t_min, ratio)
	else:
		if ratio < t_min:
			return {"hit": false}
		t_max = minf(t_max, ratio)
	return {"hit": t_min <= t_max, "t_min": t_min, "t_max": t_max}
