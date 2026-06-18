extends RefCounted
class_name RunProgressService

const SAVE_PATH := "user://run_progress.cfg"
const DEFAULT_PRIMARY_OBJECTIVE := "ボス領域を20%未満まで圧縮する"
const DEFAULT_OPTIONAL_OBJECTIVE_TIME := "3分以内にクリアする"
const DEFAULT_OPTIONAL_OBJECTIVE_BIG_CUT := "単発15%以上の大取りを決める"
const DEFAULT_QUEST_THIRTY := "確保率30%に一度到達する"
const DEFAULT_QUEST_NO_DAMAGE_CLEAR := "ダメージを受けずにクリアする"
const DEFAULT_QUEST_STREAK := "無傷で3回連続帰還する"
const GROWTH_THRESHOLDS := [12.0, 28.0, 48.0, 72.0, 100.0, 132.0, 168.0]

var _main
var _draft_service
var _save_config := ConfigFile.new()

var territory_score := 0.0
var shards := 0
var run_level := 0
var growth_progress := 0.0
var elapsed_time := 0.0
var pending_choices: Array[Dictionary] = []
var pending_choice_seed := 0
var reroll_charges := 0
var guard_charges := 0
var no_damage_capture_streak := 0
var risk_line_time := 0.0
var took_damage_this_run := false

var current_build_summary: Array[String] = []
var applied_upgrade_ranks: Dictionary = {}
var run_modifiers := {
	"move_speed": 1.0,
	"boss_squeeze_bonus": 0.0,
	"small_capture_bonus": 0.0,
	"large_capture_bonus": 0.0,
	"streak_bonus": 0.0,
	"growth_discount": 0.0,
	"top_outline_bonus_seconds": 0.0
	}

var primary_objective_completed := false
var optional_time_completed := false
var optional_big_cut_completed := false
var quest_claimed_thirty_completed := false
var quest_no_damage_clear_completed := false
var quest_streak_completed := false

var core_data_total := 0
var total_runs_cleared := 0
var total_shards_earned := 0
var meta_hp_bonus := 0
var meta_shard_bonus := 0.0
var meta_top_outline_bonus_seconds := 0.0
var meta_reroll_bonus := 0


func setup(main, draft_service) -> void:
	_main = main
	_draft_service = draft_service
	_load_meta_progress()


func begin_run() -> void:
	territory_score = 0.0
	shards = 0
	run_level = 0
	growth_progress = 0.0
	elapsed_time = 0.0
	pending_choices.clear()
	pending_choice_seed = 0
	reroll_charges = meta_reroll_bonus
	guard_charges = 0
	no_damage_capture_streak = 0
	risk_line_time = 0.0
	took_damage_this_run = false
	current_build_summary.clear()
	applied_upgrade_ranks.clear()
	run_modifiers = {
		"move_speed": 1.0,
		"boss_squeeze_bonus": 0.0,
		"small_capture_bonus": 0.0,
		"large_capture_bonus": 0.0,
		"streak_bonus": 0.0,
		"growth_discount": 0.0,
		"top_outline_bonus_seconds": 0.0
	}
	primary_objective_completed = false
	optional_time_completed = false
	optional_big_cut_completed = false
	quest_claimed_thirty_completed = false
	quest_no_damage_clear_completed = false
	quest_streak_completed = false


func tick(delta: float) -> void:
	if delta <= 0.0:
		return
	elapsed_time += delta
	if _main != null and is_instance_valid(_main.base_player) and _main.base_player.has_method("is_drawing_interior"):
		if bool(_main.base_player.call("is_drawing_interior")):
			risk_line_time += delta


func register_capture(capture_context: Dictionary) -> Dictionary:
	var single_capture_percent := float(capture_context.get("single_capture_percent", 0.0))
	var claimed_ratio := float(capture_context.get("claimed_ratio", 0.0))
	var streak_before_damage := no_damage_capture_streak
	var shards_gained := _calculate_shards(single_capture_percent, capture_context)
	var territory_gained := maxf(1.0, single_capture_percent * 10.0)
	var growth_gained := _calculate_growth(single_capture_percent, capture_context, streak_before_damage)
	var boss_region_ratio := float(capture_context.get("post_boss_region_ratio", 1.0))

	territory_score += territory_gained
	shards += shards_gained
	total_shards_earned += shards_gained
	growth_progress += growth_gained
	no_damage_capture_streak += 1

	if claimed_ratio >= 0.30 and !quest_claimed_thirty_completed:
		quest_claimed_thirty_completed = true
		_award_core_data(1)

	if single_capture_percent >= 15.0 and !optional_big_cut_completed:
		optional_big_cut_completed = true
		_award_core_data(1)

	if no_damage_capture_streak >= 3 and !quest_streak_completed:
		quest_streak_completed = true
		_award_core_data(1)

	if boss_region_ratio <= 0.20 and !primary_objective_completed:
		primary_objective_completed = true
		_award_core_data(2)

	var leveled_up := _check_for_growth_level()
	return {
		"shards_gained": shards_gained,
		"territory_gained": territory_gained,
		"growth_gained": growth_gained,
		"leveled_up": leveled_up,
		"streak": no_damage_capture_streak
	}


func register_damage_taken() -> void:
	no_damage_capture_streak = 0
	took_damage_this_run = true


func register_stage_clear() -> void:
	total_runs_cleared += 1
	if elapsed_time <= 180.0 and !optional_time_completed:
		optional_time_completed = true
		_award_core_data(1)
	if !took_damage_this_run and !quest_no_damage_clear_completed:
		quest_no_damage_clear_completed = true
		_award_core_data(2)
	_save_meta_progress()


func try_consume_guard() -> bool:
	if guard_charges <= 0:
		return false
	guard_charges -= 1
	return true


func has_pending_upgrade_draft() -> bool:
	return !pending_choices.is_empty()


func get_pending_upgrade_choices() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for choice in pending_choices:
		result.append(choice.duplicate(true))
	return result


func apply_upgrade_choice(index: int) -> bool:
	if index < 0 or index >= pending_choices.size():
		return false
	var choice: Dictionary = pending_choices[index]
	var upgrade_id := str(choice.get("id", ""))
	if upgrade_id.is_empty():
		return false
	_apply_upgrade(upgrade_id)
	pending_choices.clear()
	return true


func reroll_upgrade_choices() -> bool:
	if reroll_charges <= 0 or pending_choices.is_empty() or _draft_service == null:
		return false
	reroll_charges -= 1
	pending_choice_seed += 1
	pending_choices = _draft_service.build_choices(applied_upgrade_ranks, pending_choice_seed)
	return !pending_choices.is_empty()


func build_player_run_configuration() -> Dictionary:
	return {
		"max_hp_bonus": meta_hp_bonus,
		"move_speed_multiplier": maxf(0.5, float(run_modifiers.get("move_speed", 1.0)))
	}


func get_top_outline_countdown_bonus_seconds() -> float:
	return meta_top_outline_bonus_seconds + float(run_modifiers.get("top_outline_bonus_seconds", 0.0))


func get_hud_snapshot() -> Dictionary:
	return {
		"territory": int(round(territory_score)),
		"shards": shards,
		"core_data_total": core_data_total,
		"run_level": run_level,
		"growth_progress": growth_progress,
		"next_growth_threshold": _get_next_growth_threshold(),
		"build_summary": _build_summary_text(),
		"primary_objective": _format_objective_text(primary_objective_completed, DEFAULT_PRIMARY_OBJECTIVE),
		"optional_objective_1": _format_objective_text(optional_time_completed, DEFAULT_OPTIONAL_OBJECTIVE_TIME),
		"optional_objective_2": _format_objective_text(optional_big_cut_completed, DEFAULT_OPTIONAL_OBJECTIVE_BIG_CUT),
		"meta_summary": _build_meta_summary_text(),
		"pending_upgrade": has_pending_upgrade_draft(),
		"guard_charges": guard_charges,
		"reroll_charges": reroll_charges,
		"quest_summary": _build_quest_summary_text()
	}


func _calculate_shards(single_capture_percent: float, capture_context: Dictionary) -> int:
	var base_amount := maxf(1.0, floorf(single_capture_percent * 0.55))
	var risk_grade := str(capture_context.get("risk_grade", "safe"))
	var size_band := str(capture_context.get("capture_size_band", "small"))
	var bonus := meta_shard_bonus

	if size_band == "small":
		bonus += float(run_modifiers.get("small_capture_bonus", 0.0))
	elif size_band == "large":
		bonus += float(run_modifiers.get("large_capture_bonus", 0.0))

	if risk_grade == "high":
		base_amount += 2.0
	elif risk_grade == "medium":
		base_amount += 1.0

	var boss_reduction := float(capture_context.get("boss_region_reduction_percent", 0.0))
	base_amount += floorf(boss_reduction * (0.08 + float(run_modifiers.get("boss_squeeze_bonus", 0.0))))

	if no_damage_capture_streak > 0:
		base_amount += floorf(float(no_damage_capture_streak) * float(run_modifiers.get("streak_bonus", 0.0)))

	return maxi(1, int(round(base_amount * (1.0 + bonus))))


func _calculate_growth(single_capture_percent: float, capture_context: Dictionary, streak_before_damage: int) -> float:
	var growth := maxf(1.0, single_capture_percent * 0.45)
	var size_band := str(capture_context.get("capture_size_band", "small"))
	var risk_grade := str(capture_context.get("risk_grade", "safe"))

	if size_band == "small":
		growth += 1.0 + float(run_modifiers.get("small_capture_bonus", 0.0)) * 2.0
	elif size_band == "large":
		growth += 2.0 + float(run_modifiers.get("large_capture_bonus", 0.0)) * 2.0

	if risk_grade == "high":
		growth += 3.0
	elif risk_grade == "medium":
		growth += 1.5

	growth += minf(risk_line_time, 8.0) * 0.25
	growth += float(streak_before_damage) * float(run_modifiers.get("streak_bonus", 0.0))
	risk_line_time = 0.0
	return growth


func _check_for_growth_level() -> bool:
	var threshold := _get_next_growth_threshold()
	if threshold <= 0.0 or growth_progress < threshold or _draft_service == null:
		return false
	run_level += 1
	pending_choice_seed += 1
	pending_choices = _draft_service.build_choices(applied_upgrade_ranks, pending_choice_seed)
	return has_pending_upgrade_draft()


func _get_next_growth_threshold() -> float:
	var index := mini(run_level, GROWTH_THRESHOLDS.size() - 1)
	var threshold: float = GROWTH_THRESHOLDS[index]
	var discount := clampf(float(run_modifiers.get("growth_discount", 0.0)), 0.0, 0.4)
	return threshold * (1.0 - discount)


func _apply_upgrade(upgrade_id: String) -> void:
	var next_rank := int(applied_upgrade_ranks.get(upgrade_id, 0)) + 1
	applied_upgrade_ranks[upgrade_id] = next_rank
	match upgrade_id:
		"move_speed":
			run_modifiers["move_speed"] = float(run_modifiers.get("move_speed", 1.0)) + 0.12
		"guard_charge":
			guard_charges += 1
		"growth_discount":
			run_modifiers["growth_discount"] = float(run_modifiers.get("growth_discount", 0.0)) + 0.10
		"top_outline_boost":
			run_modifiers["top_outline_bonus_seconds"] = float(run_modifiers.get("top_outline_bonus_seconds", 0.0)) + 4.0
		"small_chain_bonus":
			run_modifiers["small_capture_bonus"] = float(run_modifiers.get("small_capture_bonus", 0.0)) + 0.12
		"large_cut_bonus":
			run_modifiers["large_capture_bonus"] = float(run_modifiers.get("large_capture_bonus", 0.0)) + 0.15
		"reroll_charge":
			reroll_charges += 1
		"streak_bonus":
			run_modifiers["streak_bonus"] = float(run_modifiers.get("streak_bonus", 0.0)) + 0.40
	_update_build_summary(upgrade_id, next_rank)


func _update_build_summary(upgrade_id: String, rank: int) -> void:
	var upgrade_name := _get_upgrade_display_name(upgrade_id)
	var summary_line := "%s Lv.%d" % [upgrade_name, rank]
	for index in range(current_build_summary.size()):
		if current_build_summary[index].begins_with(upgrade_name):
			current_build_summary[index] = summary_line
			return
	current_build_summary.append(summary_line)
	if current_build_summary.size() > 3:
		current_build_summary.remove_at(0)


func _build_summary_text() -> String:
	if current_build_summary.is_empty():
		return "ビルド: バランス型"
	return "ビルド: %s" % _join_summary_lines(current_build_summary)


func _build_meta_summary_text() -> String:
	return "恒久強化: 恒久ポイント %d  ガード %d  再抽選 %d" % [core_data_total, guard_charges, reroll_charges]


func _build_quest_summary_text() -> String:
	var streak_text := _format_objective_text(quest_streak_completed, DEFAULT_QUEST_STREAK)
	var no_damage_clear_text := _format_objective_text(quest_no_damage_clear_completed, DEFAULT_QUEST_NO_DAMAGE_CLEAR)
	var claim_text := _format_objective_text(quest_claimed_thirty_completed, DEFAULT_QUEST_THIRTY)
	return "%s / %s / %s" % [claim_text, no_damage_clear_text, streak_text]


func _format_objective_text(completed: bool, label: String) -> String:
	return "達成: %s" % label if completed else "未達成: %s" % label


func _award_core_data(amount: int) -> void:
	if amount <= 0:
		return
	core_data_total += amount
	_apply_meta_unlocks()
	_save_meta_progress()


func _load_meta_progress() -> void:
	core_data_total = 0
	total_runs_cleared = 0
	total_shards_earned = 0
	if _save_config.load(SAVE_PATH) != OK:
		_apply_meta_unlocks()
		return
	core_data_total = int(_save_config.get_value("meta", "core_data_total", 0))
	total_runs_cleared = int(_save_config.get_value("meta", "runs_cleared", 0))
	total_shards_earned = int(_save_config.get_value("meta", "total_shards_earned", 0))
	_apply_meta_unlocks()


func _save_meta_progress() -> void:
	_save_config.set_value("meta", "core_data_total", core_data_total)
	_save_config.set_value("meta", "runs_cleared", total_runs_cleared)
	_save_config.set_value("meta", "total_shards_earned", total_shards_earned)
	_save_config.save(SAVE_PATH)


func _apply_meta_unlocks() -> void:
	meta_hp_bonus = 1 if core_data_total >= 5 else 0
	meta_shard_bonus = 0.10 if core_data_total >= 10 else 0.0
	meta_top_outline_bonus_seconds = 3.0 if core_data_total >= 15 else 0.0
	meta_reroll_bonus = 1 if core_data_total >= 25 else 0


func _join_summary_lines(lines: Array[String]) -> String:
	var result := ""
	for index in range(lines.size()):
		if index > 0:
			result += " / "
		result += lines[index]
	return result


func _get_upgrade_display_name(upgrade_id: String) -> String:
	match upgrade_id:
		"move_speed":
			return "移動速度アップ"
		"guard_charge":
			return "接触ガード"
		"growth_discount":
			return "必要経験値軽減"
		"top_outline_boost":
			return "外周上辺タイマー延長"
		"small_chain_bonus":
			return "小取り強化"
		"large_cut_bonus":
			return "大取り強化"
		"reroll_charge":
			return "再抽選追加"
		"streak_bonus":
			return "無傷連続ボーナス"
		_:
			return "強化"
