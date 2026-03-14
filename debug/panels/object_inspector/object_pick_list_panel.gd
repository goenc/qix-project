extends Control
class_name ObjectPickListPanel

signal candidate_selected(candidate: Dictionary)
signal cancel_requested

@onready var _count_label: Label = $CountLabel
@onready var _item_list: ItemList = $CandidateList
@onready var _select_button: Button = $SelectButton
@onready var _cancel_button: Button = $CancelButton

var _candidates: Array[Dictionary] = []


func _ready() -> void:
	_item_list.item_selected.connect(_on_item_list_item_selected)
	_item_list.item_activated.connect(_on_item_list_item_activated)
	_select_button.pressed.connect(_emit_selected_candidate)
	_cancel_button.pressed.connect(_on_cancel_button_pressed)
	_refresh_buttons()


func set_candidates(candidates: Array[Dictionary]) -> void:
	_candidates = []
	_item_list.clear()
	for candidate in candidates:
		_candidates.append(candidate)
		_item_list.add_item(_format_candidate(candidate))
	if !_candidates.is_empty():
		_item_list.select(0)
	_count_label.text = "候補 %d 件" % _candidates.size()
	_refresh_buttons()


func focus_first_candidate() -> void:
	if _candidates.is_empty():
		return
	_item_list.grab_focus()


func _format_candidate(candidate: Dictionary) -> String:
	var parts: Array[String] = [
		str(candidate.get("display_name", "Unknown")),
		str(candidate.get("class_name", "-")),
		str(candidate.get("node_path", "-")),
		str(candidate.get("world_position_text", "-")),
	]
	var owner_name := str(candidate.get("owner_name", ""))
	if !owner_name.is_empty():
		parts.append("owner=%s" % owner_name)
	return " | ".join(parts)


func _emit_selected_candidate() -> void:
	var selected_index := _selected_index()
	if selected_index < 0:
		return
	candidate_selected.emit(_candidates[selected_index])


func _selected_index() -> int:
	var selected_items := _item_list.get_selected_items()
	if selected_items.is_empty():
		return -1
	return selected_items[0]


func _refresh_buttons() -> void:
	_select_button.disabled = _selected_index() < 0


func _on_item_list_item_selected(_index: int) -> void:
	_refresh_buttons()


func _on_item_list_item_activated(_index: int) -> void:
	_emit_selected_candidate()


func _on_cancel_button_pressed() -> void:
	cancel_requested.emit()
