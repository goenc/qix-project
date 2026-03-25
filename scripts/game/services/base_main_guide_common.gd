extends RefCounted
class_name BaseMainGuideCommon


static func normalize_guide_direction(direction: Vector2) -> Vector2:
	if absf(direction.x) > absf(direction.y):
		return Vector2(signf(direction.x), 0.0)
	if absf(direction.y) > 0.0:
		return Vector2(0.0, signf(direction.y))
	return Vector2.ZERO


static func build_guide_scan_bounds(start: Vector2, end: Vector2, direction: Vector2) -> Dictionary:
	if absf(direction.x) > 0.0:
		if direction.x > 0.0:
			return {
				"valid": true,
				"horizontal": true,
				"from": int(ceil(start.x)),
				"to": int(floor(end.x)),
				"fixed": int(round(start.y)),
				"step": 1
			}
		return {
			"valid": true,
			"horizontal": true,
			"from": int(floor(start.x)),
			"to": int(ceil(end.x)),
			"fixed": int(round(start.y)),
			"step": -1
		}

	if absf(direction.y) > 0.0:
		if direction.y > 0.0:
			return {
				"valid": true,
				"horizontal": false,
				"from": int(ceil(start.y)),
				"to": int(floor(end.y)),
				"fixed": int(round(start.x)),
				"step": 1
			}
		return {
			"valid": true,
			"horizontal": false,
			"from": int(floor(start.y)),
			"to": int(ceil(end.y)),
			"fixed": int(round(start.x)),
			"step": -1
		}

	return {"valid": false}


static func build_guide_scan_point(scan_bounds: Dictionary, axis_value: int) -> Vector2:
	var fixed_axis := float(scan_bounds.get("fixed", 0))
	if bool(scan_bounds.get("horizontal", false)):
		return Vector2(float(axis_value), fixed_axis)
	return Vector2(fixed_axis, float(axis_value))


static func stringify_value(value: Variant, default_text: String = "") -> String:
	if typeof(value) == TYPE_NIL:
		return default_text
	return str(value)


static func is_pending_guide_segment(guide_segment: Dictionary) -> bool:
	return bool(guide_segment.get("pending", false))


static func build_confirmed_guide_segment(guide_segment: Dictionary) -> Dictionary:
	var confirmed_segment := guide_segment.duplicate()
	confirmed_segment["pending"] = false
	return confirmed_segment
