extends RefCounted
class_name BaseMainHudService

const BaseMainCutRatingService = preload("res://scripts/game/services/base_main_cut_rating_service.gd")
const HELP_TEXT_BASE := "移動: 矢印/WASD 線引き: Shift/A Esc: タイトル"
const HELP_TEXT_UPGRADE := "移動: 矢印/WASD 線引き: Shift/A 1-3: 決定 R: 再抽選 Esc: タイトル"

var _main


func setup(main) -> void:
	_main = main


func sync() -> void:
	if _main == null:
		return

	sync_cut_rating_bar()
	sync_area_labels()
	sync_run_progress_labels()
	sync_objectives_quest_detail()
	sync_upgrade_overlay()
	update_hp_label()

	if _main.game_over:
		_main.state_label.text = "状態: ゲームオーバー"
		_main.result_label.text = "ゲームオーバー"
		_main.help_label.text = "Esc: タイトルへ戻る"
		if is_instance_valid(_main.base_player):
			sync_position(_main.base_player.position)
		else:
			_main.position_label.text = "座標: (-, -)"
		return

	if _main.game_clear:
		_main.state_label.text = "状態: クリア"
		_main.result_label.text = "ゲームクリア"
		_main.help_label.text = "Esc: タイトルへ戻る"
		if is_instance_valid(_main.base_player):
			sync_position(_main.base_player.position)
		else:
			_main.position_label.text = "座標: (-, -)"
		return

	if _main.is_upgrade_draft_active():
		_main.state_label.text = "状態: 強化選択"
		_main.result_label.text = "強化を1つ選択"
		_main.help_label.text = HELP_TEXT_UPGRADE
		if is_instance_valid(_main.base_player):
			sync_position(_main.base_player.position)
		else:
			_main.position_label.text = "座標: (-, -)"
		return

	if _main.get_tree().paused:
		_main.state_label.text = "状態: 一時停止"
		_main.position_label.text = "座標: (-, -)"
		_main.result_label.text = ""
		_main.help_label.text = HELP_TEXT_BASE
		return

	if !is_instance_valid(_main.base_player):
		_main.state_label.text = "状態: 外周"
		_main.position_label.text = "座標: (-, -)"
		_main.result_label.text = ""
		_main.help_label.text = HELP_TEXT_BASE
		return

	var status: Dictionary = _main.base_player.get_debug_status()
	sync_status(status)
	sync_position(status.get("position", _main.base_player.position))


func sync_area_labels() -> void:
	if _main == null:
		return
	if _main.show_area_percent_labels:
		_main.claimed_label.text = "確保率: %d%%" % int(round(_main.claimed_ratio_cached * 100.0))
		_main.boss_region_label.text = "ボス領域: %d%%" % int(round(_main.boss_region_ratio_cached * 100.0))
		return
	_main.claimed_label.text = "確保率: 非表示"
	_main.boss_region_label.text = "ボス領域: 非表示"


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

	_main.hp_label.text = "HP"
	if !is_instance_valid(_main.hp_icon_container):
		return

	if !is_instance_valid(_main.base_player):
		_update_hp_icons(0, 0)
		return

	if !_main.base_player.has_method("get_current_hp") or !_main.base_player.has_method("get_max_hp"):
		_update_hp_icons(0, 0)
		return

	_update_hp_icons(
		int(_main.base_player.get_current_hp()),
		int(_main.base_player.get_max_hp())
	)


func _update_hp_icons(current_hp: int, max_hp: int) -> void:
	var safe_max_hp := maxi(0, max_hp)
	var safe_current_hp := clampi(current_hp, 0, safe_max_hp)
	var icons: Array[Node] = _main.hp_icon_container.get_children()
	for index in range(icons.size()):
		var icon := icons[index] as TextureRect
		if icon == null:
			continue
		icon.visible = index < safe_max_hp
		icon.modulate.a = 1.0 if index < safe_current_hp else 0.35


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

	var mode_text := _localize_mode_text(str(status.get("mode_text", "BORDER")))
	_main.state_label.text = "状態: %s" % mode_text
	_main.result_label.text = ""
	_main.help_label.text = HELP_TEXT_BASE


func sync_position(current_position: Vector2) -> void:
	if _main == null:
		return
	_main.position_label.text = "座標: (%d, %d)" % [
		int(round(current_position.x)),
		int(round(current_position.y))
	]


func sync_run_progress_labels() -> void:
	if _main == null:
		return
	var snapshot: Dictionary = _main.get_run_progress_hud_snapshot()
	_main.shards_label.text = "得点: %d  陣取り点: %d" % [
		int(snapshot.get("shards", 0)),
		int(snapshot.get("territory", 0))
	]
	_main.growth_label.text = "Lv.%d" % int(snapshot.get("run_level", 0))


func sync_objectives_quest_detail(snapshot: Dictionary = {}) -> void:
	if _main == null or !_main.is_objectives_quest_detail_open():
		return
	if snapshot.is_empty():
		snapshot = _main.get_run_progress_hud_snapshot()
	_main.detail_growth_label.text = "経験値: Lv.%d  %.1f / %.1f" % [
		int(snapshot.get("run_level", 0)),
		float(snapshot.get("growth_progress", 0.0)),
		float(snapshot.get("next_growth_threshold", 0.0))
	]
	_main.detail_objective_primary_label.text = "主目標: %s" % str(snapshot.get("primary_objective", "未達成: ボス領域を20%未満まで圧縮する"))
	_main.detail_objective_optional_1_label.text = "任意目標: %s" % str(snapshot.get("optional_objective_1", "未達成: 3分以内にクリアする"))
	_main.detail_objective_optional_2_label.text = "任意目標: %s" % str(snapshot.get("optional_objective_2", "未達成: 単発15%以上の大取りを決める"))
	_main.detail_build_label.text = str(snapshot.get("build_summary", "ビルド: バランス型"))
	_main.detail_meta_label.text = "%s" % str(snapshot.get("meta_summary", "恒久強化: 恒久ポイント 0  ガード 0  再抽選 0"))
	_main.detail_quest_label.text = "課題: %s" % str(snapshot.get("quest_summary", ""))


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
				str(choice.get("title", "強化")),
				str(choice.get("description", ""))
			]
		else:
			label.text = "%d. --" % [index + 1]
	_main.upgrade_title_label.text = "強化選択"
	_main.upgrade_hint_label.text = "1つ選ぶとプレイに戻ります。"
	var snapshot: Dictionary = _main.get_run_progress_hud_snapshot()
	_main.upgrade_meta_label.text = "再抽選: %d  ガード: %d" % [
		int(snapshot.get("reroll_charges", 0)),
		int(snapshot.get("guard_charges", 0))
	]


func _build_cut_rating_summary_text() -> String:
	var rate_text := "%d%%" % _main.current_cut_rating_value
	if !_main.has_cut_rating_update:
		return "直近確保 -- / 変動 -- / 傾向 %s" % rate_text

	return "直近確保 %.1f%% / 変動 %s / 傾向 %s" % [
		_main.last_single_capture_percent,
		_format_cut_rating_delta(_main.last_cut_rating_delta),
		rate_text
	]


func _localize_mode_text(mode_text: String) -> String:
	match mode_text:
		"DRAWING":
			return "描画中"
		"REWINDING":
			return "巻き戻し"
		_:
			return "外周移動"


func _format_cut_rating_delta(delta: int) -> String:
	if delta > 0:
		return "+%d" % delta
	return "%d" % delta
