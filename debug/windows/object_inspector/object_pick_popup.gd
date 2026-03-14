extends Window
class_name ObjectPickPopup

signal candidate_selected(candidate: Dictionary)

@onready var _pick_panel = $ObjectPickListPanel


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	title = "Object Pick"
	close_requested.connect(hide)
	hide()
	if _pick_panel != null and _pick_panel.has_signal("candidate_selected"):
		_pick_panel.candidate_selected.connect(_on_pick_panel_candidate_selected)
	if _pick_panel != null and _pick_panel.has_signal("cancel_requested"):
		_pick_panel.cancel_requested.connect(_on_pick_panel_cancel_requested)


func present_candidates(candidates: Array[Dictionary], popup_position: Vector2i) -> void:
	if _pick_panel == null or !_pick_panel.has_method("set_candidates"):
		return
	if candidates.size() < 2:
		hide()
		return
	_pick_panel.call("set_candidates", candidates)
	position = popup_position
	show()
	grab_focus()
	if _pick_panel.has_method("focus_first_candidate"):
		_pick_panel.call("focus_first_candidate")


func _on_pick_panel_candidate_selected(candidate: Dictionary) -> void:
	hide()
	candidate_selected.emit(candidate)


func _on_pick_panel_cancel_requested() -> void:
	hide()
