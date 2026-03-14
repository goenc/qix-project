extends Control

const EMPTY_EVENT_TEXT := "Raw input event is empty."

@onready var _event_log_label: Label = $MarginContainer/ScrollContainer/EventLogLabel


func update_event_history(event_history: Array[String]) -> void:
	_event_log_label.text = _format_event_history(event_history)


func _format_event_history(event_history: Array[String]) -> String:
	if event_history.is_empty():
		return EMPTY_EVENT_TEXT
	return "\n".join(event_history)
