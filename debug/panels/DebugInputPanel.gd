extends Control

const EMPTY_MAIN_INPUT_TEXT := "入力 : なし"
const EMPTY_PRESSED_KEYS_TEXT := "押下中キー : なし"

@onready var _current_input_label: Label = $InputGroup/CurrentInputLabel
@onready var _press_count_label: Label = $InputGroup/PressCountLabel
@onready var _pressed_keys_label: Label = $InputGroup/PressedKeysLabel


func update_input_state(pressed_inputs: Dictionary) -> void:
	var pressed_keys := _sorted_pressed_keys(pressed_inputs)
	_current_input_label.text = _format_main_input(pressed_keys)
	_press_count_label.text = "同時押し数 : %d" % pressed_keys.size()
	_pressed_keys_label.text = _format_pressed_keys(pressed_keys)


func _sorted_pressed_keys(pressed_inputs: Dictionary) -> Array[String]:
	var keys: Array[String] = []
	for input_name in pressed_inputs.keys():
		keys.append(str(input_name))
	keys.sort()
	return keys


func _format_main_input(pressed_keys: Array[String]) -> String:
	if pressed_keys.is_empty():
		return EMPTY_MAIN_INPUT_TEXT
	var top_keys: Array[String] = []
	var limit := mini(3, pressed_keys.size())
	for index in range(limit):
		top_keys.append(pressed_keys[index])
	return "入力 : %s" % " + ".join(top_keys)


func _format_pressed_keys(pressed_keys: Array[String]) -> String:
	if pressed_keys.is_empty():
		return EMPTY_PRESSED_KEYS_TEXT
	return "押下中キー : %s" % ", ".join(pressed_keys)
