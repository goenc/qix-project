extends RefCounted
class_name BaseMainHudService

const BaseMainCutRatingService = preload("res://scripts/game/services/base_main_cut_rating_service.gd")

var _main


func setup(main) -> void:
	_main = main


func sync() -> void:
	if _main == null:
		return

	sync_cut_rating_bar()
	sync_area_labels()
	sync_run_progress_labels()
	sync_upgrade_overlay()
	update_hp_label()

	if _main.game_over:
		_main.state_label.text = "MODE: GAME OVER"
		_main.result_label.text = "GAME OVER"
		_main.help_label.text = "ESC: TITLE"
		if is_instance_valid(_main.base_player):
			sync_position(_main.base_player.position)
		else:
			_main.position_label.text = "POS: (-, -)"
		return

	if _main.game_clear:
		_main.state_label.text = "MODE: GAME CLEAR"
		_main.result_label.text = "GAME CLEAR"
		_main.help_label.text = "ESC: TITLE"
		if is_instance_valid(_main.base_player):
			sync_position(_main.base_player.position)
		else:
			_main.position_label.text = "POS: (-, -)"
		return

	if _main.is_upgrade_draft_active():
		_main.state_label.text = "MODE: UPGRADE"
		_main.result_label.text = "SELECT AN UPGRADE"
		_main.help_label.text = "MOVE: ARROWS/WASD FAST: SHIFT/PAD-A SLOW: CTRL/PAD-X 1-3: PICK R: REROLL ESC: TITLE"
		if is_instance_valid(_main.base_player):
			sync_position(_main.base_player.position)
		else:
			_main.position_label.text = "POS: (-, -)"
		return

	if _main.get_tree().paused:
		_main.state_label.text = "MODE: PAUSED"
		_main.position_label.text = "POS: (-, -)"
		_main.result_label.text = ""
		_main.help_label.text = "MOVE: ARROWS/WASD FAST: SHIFT/PAD-A SLOW: CTRL/PAD-X ESC: TITLE"
		return

	if !is_instance_valid(_main.base_player):
		_main.state_label.text = "MODE: BORDER"
		_main.position_label.text = "POS: (-, -)"
		_main.result_label.text = ""
		_main.help_label.text = "MOVE: ARROWS/WASD FAST: SHIFT/PAD-A SLOW: CTRL/PAD-X ESC: TITLE"
		return

	var status: Dictionary = _main.base_player.get_debug_status()
	sync_status(status)
	sync_position(status.get("position", _main.base_player.position))


func sync_area_labels() -> void:
	if _main == null:
		return
	if _main.show_area_percent_labels:
		_main.claimed_label.text = "CLAIMED: %d%%" % int(round(_main.claimed_ratio_cached * 100.0))
		_main.boss_region_label.text = "BOSS REGION: %d%%" % int(round(_main.boss_region_ratio_cached * 100.0))
		return
	_main.claimed_label.text = "CLAIMED: OFF"
	_main.boss_region_label.text = "BOSS REGION: OFF"


func sync_cut_rating_bar() -> void:
	if (
		_main == null
		or !is_instance_valid(_main.cut_rating_bar)
		or !is_instance_valid(_main.cut_rating_summary_label)
		or !is_instance_valid(_main.cut_rating_bad_label)
		or !is_instance_valid(_main.cut_rating_good_label)
	):
		return

	_main.cut_rating_bar.min_value = BaseMainCutRatingService.MIN_VALUE
	_main.cut_rating_bar.max_value = BaseMainCutRatingService.MAX_VALUE
	_main.cut_rating_bar.value = _main.current_cut_rating_value
	_main.cut_rating_bad_label.text = BaseMainCutRatingService.BAD_LABEL
	_main.cut_rating_good_label.text = BaseMainCutRatingService.GOOD_LABEL
	_main.cut_rating_summary_label.text = _build_cut_rating_summary_text()


func update_hp_label() -> void:
	if _main == null or !is_instance_valid(_main.hp_label):
		return

	if !is_instance_valid(_main.base_player):
		_main.hp_label.text = "HP: -/-"
		return

	if _main.base_player.has_method("get_current_hp") and _main.base_player.has_method("get_max_hp"):
		_main.hp_label.text = "HP: %d/%d" % [
			_main.base_player.get_current_hp(),
			_main.base_player.get_max_hp()
		]
		return

	_main.hp_label.text = "HP: -/-"


func sync_status(status: Dictionary) -> void:
	if (
		_main == null
		or _main.game_over
		or _main.game_clear
		or _main.get_tree().paused
		or !is_instance_valid(_main.base_player)
	):
		sync()
		return

	var mode_text := str(status.get("mode_text", "BORDER"))
	var draw_mode := str(status.get("draw_mode", "FAST"))
	_main.state_label.text = "MODE: %s / %s" % [mode_text, draw_mode]
	_main.result_label.text = ""
	_main.help_label.text = "MOVE: ARROWS/WASD FAST: SHIFT/PAD-A SLOW: CTRL/PAD-X ESC: TITLE"


func sync_position(current_position: Vector2) -> void:
	if _main == null:
		return
	_main.position_label.text = "POS: (%d, %d)" % [
		int(round(current_position.x)),
		int(round(current_position.y))
	]


func sync_run_progress_labels() -> void:
	if _main == null:
		return
	var snapshot: Dictionary = _main.get_run_progress_hud_snapshot()
	_main.shards_label.text = "SHARDS: %d  TERRITORY: %d" % [
		int(snapshot.get("shards", 0)),
		int(snapshot.get("territory", 0))
	]
	_main.growth_label.text = "GROWTH: Lv.%d  %.1f / %.1f" % [
		int(snapshot.get("run_level", 0)),
		float(snapshot.get("growth_progress", 0.0)),
		float(snapshot.get("next_growth_threshold", 0.0))
	]
	_main.objective_primary_label.text = "PRIMARY: %s" % str(snapshot.get("primary_objective", "[ ] Compress boss region below 20%."))
	_main.objective_optional_1_label.text = "OPTIONAL: %s" % str(snapshot.get("optional_objective_1", "[ ] Clear under 3:00."))
	_main.objective_optional_2_label.text = "OPTIONAL: %s" % str(snapshot.get("optional_objective_2", "[ ] Land a single 15% cut."))
	_main.build_label.text = str(snapshot.get("build_summary", "BUILD: FAST/Slow hybrid"))
	_main.meta_label.text = "%s" % str(snapshot.get("meta_summary", "META: Core 0  Guard 0  Reroll 0"))
	_main.quest_label.text = "QUESTS: %s" % str(snapshot.get("quest_summary", ""))


func sync_upgrade_overlay() -> void:
	if _main == null or !is_instance_valid(_main.upgrade_overlay):
		return
	var active: bool = _main.is_upgrade_draft_active()
	_main.upgrade_overlay.visible = active
	if !active:
		return
	var choices: Array[Dictionary] = _main.get_upgrade_draft_choices()
	var choice_labels := [
		_main.upgrade_choice_1_label,
		_main.upgrade_choice_2_label,
		_main.upgrade_choice_3_label
	]
	for index in range(choice_labels.size()):
		var label: Label = choice_labels[index]
		if !is_instance_valid(label):
			continue
		if index < choices.size():
			var choice: Dictionary = choices[index]
			label.text = "%d. %s\n%s" % [
				index + 1,
				str(choice.get("title", "UPGRADE")),
				str(choice.get("description", ""))
			]
		else:
			label.text = "%d. --" % [index + 1]
	_main.upgrade_title_label.text = "UPGRADE DRAFT"
	_main.upgrade_hint_label.text = "Pick one to keep the run moving."
	var snapshot: Dictionary = _main.get_run_progress_hud_snapshot()
	_main.upgrade_meta_label.text = "REROLL: %d  GUARD: %d" % [
		int(snapshot.get("reroll_charges", 0)),
		int(snapshot.get("guard_charges", 0))
	]


func _build_cut_rating_summary_text() -> String:
	var rate_text := "%d%%" % _main.current_cut_rating_value
	if !_main.has_cut_rating_update:
		return "CUT -- / DELTA -- / RATE %s" % rate_text

	return "CUT %.1f%% / DELTA %s / RATE %s" % [
		_main.last_single_capture_percent,
		_format_cut_rating_delta(_main.last_cut_rating_delta),
		rate_text
	]


func _format_cut_rating_delta(delta: int) -> String:
	if delta > 0:
		return "+%d" % delta
	return "%d" % delta
