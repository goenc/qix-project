extends CanvasLayer
class_name StageSelectScreen

@onready var root: Control = $Root
@onready var backdrop: ColorRect = $Root/Backdrop
@onready var title_label: Label = $Root/TitleLabel
@onready var subtitle_label: Label = $Root/SubLabel
@onready var footer_label: Label = $Root/FooterLabel
@onready var stage_cards: Array[Dictionary] = [
	{
		"root": $Root/StageCard1,
		"title": $Root/StageCard1/StageLabel,
		"status": $Root/StageCard1/StatusLabel,
		"detail": $Root/StageCard1/DetailLabel
	},
	{
		"root": $Root/StageCard2,
		"title": $Root/StageCard2/StageLabel,
		"status": $Root/StageCard2/StatusLabel,
		"detail": $Root/StageCard2/DetailLabel
	},
	{
		"root": $Root/StageCard3,
		"title": $Root/StageCard3/StageLabel,
		"status": $Root/StageCard3/StatusLabel,
		"detail": $Root/StageCard3/DetailLabel
	},
	{
		"root": $Root/StageCard4,
		"title": $Root/StageCard4/StageLabel,
		"status": $Root/StageCard4/StatusLabel,
		"detail": $Root/StageCard4/DetailLabel
	}
]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func setup(_config: Dictionary) -> void:
	set_active(true)


func set_active(active: bool) -> void:
	visible = active
	root.visible = active
	backdrop.visible = active
	title_label.visible = active
	subtitle_label.visible = active
	footer_label.visible = active


func configure(stage_entries: Array[Dictionary], selected_index: int) -> void:
	var card_count: int = min(stage_cards.size(), stage_entries.size())
	var safe_selected_index: int = clampi(selected_index, 0, max(0, card_count - 1))
	for index in range(card_count):
		_apply_stage_entry(stage_cards[index], stage_entries[index], index == safe_selected_index)


func _apply_stage_entry(card: Dictionary, entry: Dictionary, selected: bool) -> void:
	var card_root: ColorRect = card.get("root") as ColorRect
	var stage_label: Label = card.get("title") as Label
	var status_label: Label = card.get("status") as Label
	var detail_label: Label = card.get("detail") as Label
	var stage_title := str(entry.get("title", "STAGE"))
	var available := bool(entry.get("available", false))
	var detail_text := str(entry.get("detail_text", ""))

	stage_label.text = stage_title
	detail_label.text = detail_text

	if available:
		if selected:
			card_root.color = Color(0.20, 0.34, 0.20, 0.96)
			status_label.text = "SELECTED"
			status_label.add_theme_color_override("font_color", Color(0.95, 1.0, 0.75))
		else:
			card_root.color = Color(0.12, 0.22, 0.14, 0.90)
			status_label.text = "READY"
			status_label.add_theme_color_override("font_color", Color(0.78, 0.98, 0.78))
	else:
		if selected:
			card_root.color = Color(0.30, 0.16, 0.16, 0.96)
		else:
			card_root.color = Color(0.16, 0.12, 0.12, 0.88)
		status_label.text = "未実装"
		status_label.add_theme_color_override("font_color", Color(1.0, 0.72, 0.72))
