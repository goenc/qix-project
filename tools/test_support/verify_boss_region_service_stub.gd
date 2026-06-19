extends "res://scripts/game/services/base_main_boss_region_service.gd"

var responses: Array[Dictionary] = []
var call_count := 0


func recalculate_after_capture() -> Dictionary:
	if responses.is_empty():
		call_count += 1
		return {
			"polygon": PackedVector2Array(),
			"remaining_area_ratio": -1.0
		}
	var response_index := mini(call_count, responses.size() - 1)
	call_count += 1
	return responses[response_index]
