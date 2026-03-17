extends RefCounted


static func ensure_action(action_name: StringName, events: Array[InputEvent]) -> void:
	if !InputMap.has_action(action_name):
		InputMap.add_action(action_name)
	if !InputMap.action_get_events(action_name).is_empty():
		return
	for event in events:
		InputMap.action_add_event(action_name, event)


static func replace_action_events(action_name: StringName, events: Array[InputEvent]) -> void:
	if !InputMap.has_action(action_name):
		InputMap.add_action(action_name)
	InputMap.action_erase_events(action_name)
	for event in events:
		InputMap.action_add_event(action_name, event)


static func replace_existing_action_events(action_name: StringName, events: Array[InputEvent]) -> void:
	if !InputMap.has_action(action_name):
		return
	replace_action_events(action_name, events)


static func key_event(
	keycode: Key,
	include_keycode: bool = true,
	include_physical_keycode: bool = true
) -> InputEventKey:
	var event := InputEventKey.new()
	if include_keycode:
		event.keycode = keycode
	if include_physical_keycode:
		event.physical_keycode = keycode
	return event


static func joypad_button(button_index: JoyButton) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.button_index = button_index
	return event
