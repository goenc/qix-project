extends RefCounted
class_name TypedArrayUtils


static func dictionaries(value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if value is Array:
		for item in value:
			if item is Dictionary:
				result.append(item)
	return result


static func integers(value: Variant) -> Array[int]:
	var result: Array[int] = []
	if value is Array:
		for item in value:
			if item is int:
				result.append(item)
	return result


static func rects(value: Variant) -> Array[Rect2]:
	var result: Array[Rect2] = []
	if value is Array:
		for item in value:
			if item is Rect2:
				result.append(item)
	return result


static func polygons(value: Variant) -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array] = []
	if value is Array:
		for item in value:
			if item is PackedVector2Array:
				result.append(item)
	return result
