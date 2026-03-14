extends Node

const DEFAULT_STAGE_PATH := "res://scenes/stages/stage_01.tscn"

var next_stage_path := ""


func set_next_stage(path: String) -> void:
	next_stage_path = _resolve_stage_path(path)


func consume_next_stage() -> String:
	var path := _resolve_stage_path(next_stage_path)
	next_stage_path = ""
	return path


func _resolve_stage_path(path: String) -> String:
	if _is_valid_stage_path(path):
		return path
	return DEFAULT_STAGE_PATH


func _is_valid_stage_path(path: String) -> bool:
	if path.is_empty():
		return false
	return ResourceLoader.exists(path, "PackedScene")
