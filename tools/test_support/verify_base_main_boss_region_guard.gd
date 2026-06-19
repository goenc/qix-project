extends "res://scripts/game/base_main.gd"


func _begin_game_clear_reveal() -> void:
	if game_over or game_clear:
		return
	game_clear = true
