extends Control
class_name ObjectInspectorPanel

const DEBUG_INSPECT_UTILS := preload("res://debug/common/debug_inspect_utils.gd")
const REGISTERED_IMAGE_THUMBNAIL_SIZE := Vector2(40.0, 40.0)

@onready var _status_label: Label = $StatusLabel
@onready var _summary_name_value_label: Label = $SummaryNameValueLabel
@onready var _summary_position_value_label: Label = $SummaryPositionValueLabel
@onready var _summary_velocity_value_label: Label = $SummaryVelocityValueLabel
@onready var _summary_state_value_label: Label = $SummaryStateValueLabel
@onready var _summary_animation_value_label: Label = $SummaryAnimationValueLabel
@onready var _summary_collision_value_label: Label = $SummaryCollisionValueLabel
@onready var _registered_images_scroll: ScrollContainer = $SummaryRegisteredImagesScroll
@onready var _registered_images_empty_label: Label = $SummaryRegisteredImagesScroll/Content/EmptyLabel
@onready var _registered_images_list: VBoxContainer = $SummaryRegisteredImagesScroll/Content/ImageList
@onready var _registered_image_row_template: HBoxContainer = $SummaryRegisteredImagesScroll/Content/ImageList/ImageRowTemplate
@onready var _common_text: TextEdit = $CommonInfoText

var _registered_image_keys := PackedStringArray()


func show_empty(message: String = "対象なし") -> void:
	_status_label.text = message
	_apply_summary_data(_empty_summary_data())
	_update_common_text("", true)
	_registered_image_keys = PackedStringArray()
	_clear_registered_image_rows()
	_registered_images_empty_label.visible = false
	_registered_images_scroll.scroll_vertical = 0


func show_target(target: Node) -> void:
	update_target(target)


func update_target(target: Node) -> void:
	if !is_instance_valid(target) or !target.is_inside_tree():
		show_empty()
		return
	update_target_data(
		"選択中 : %s" % DEBUG_INSPECT_UTILS.build_target_title(target),
		DEBUG_INSPECT_UTILS.build_summary_inspect_data(target),
		DEBUG_INSPECT_UTILS.build_registered_image_list(target),
		DEBUG_INSPECT_UTILS.format_dictionary(DEBUG_INSPECT_UTILS.build_common_inspect_data(target))
	)


func show_target_data(status_text: String, summary_data: Dictionary, registered_images: Array[Dictionary], common_text: String) -> void:
	_apply_target_data(status_text, summary_data, registered_images, common_text)


func update_target_data(status_text: String, summary_data: Dictionary, registered_images: Array[Dictionary], common_text: String) -> void:
	_apply_target_data(status_text, summary_data, registered_images, common_text)


func _apply_summary_data(summary_data: Dictionary) -> void:
	_summary_name_value_label.text = str(summary_data.get("name", "-"))
	_summary_position_value_label.text = str(summary_data.get("position", "-"))
	_summary_velocity_value_label.text = str(summary_data.get("velocity", "-"))
	_summary_state_value_label.text = str(summary_data.get("state", "-"))
	_summary_animation_value_label.text = str(summary_data.get("animation", "-"))
	_summary_collision_value_label.text = str(summary_data.get("collision", "-"))


func _apply_target_data(status_text: String, summary_data: Dictionary, registered_images: Array[Dictionary], common_text: String) -> void:
	_status_label.text = status_text
	_apply_summary_data(summary_data)
	_update_registered_images(registered_images)
	_update_common_text(common_text)


func _update_registered_images(image_entries: Array[Dictionary]) -> void:
	var next_keys := _build_registered_image_keys(image_entries)
	if _registered_image_keys == next_keys:
		return
	var previous_scroll_vertical := _registered_images_scroll.scroll_vertical
	_clear_registered_image_rows()
	_registered_image_keys = next_keys
	if image_entries.is_empty():
		_registered_images_empty_label.visible = true
		_registered_images_scroll.scroll_vertical = 0
		return
	_registered_images_empty_label.visible = false
	for entry in image_entries:
		_registered_images_list.add_child(_build_registered_image_row(entry))
	call_deferred("_restore_registered_images_scroll", previous_scroll_vertical)


func _build_registered_image_keys(image_entries: Array[Dictionary]) -> PackedStringArray:
	var keys := PackedStringArray()
	for entry in image_entries:
		var texture := entry.get("texture") as Texture2D
		var texture_key := ""
		if texture != null:
			texture_key = texture.resource_path if !texture.resource_path.is_empty() else str(texture.get_instance_id())
		keys.append("%s|%s|%s|%s" % [
			str(entry.get("node_path", "")),
			str(entry.get("animation_name", "")),
			str(entry.get("frame_index", -1)),
			texture_key,
		])
	return keys


func _build_registered_image_row(entry: Dictionary) -> HBoxContainer:
	var row := _registered_image_row_template.duplicate() as HBoxContainer
	row.name = "ImageRow"
	row.visible = true

	var thumbnail := row.get_node("Thumbnail") as TextureRect
	thumbnail.custom_minimum_size = REGISTERED_IMAGE_THUMBNAIL_SIZE
	thumbnail.texture = entry.get("texture") as Texture2D

	var separator_label := row.get_node("SeparatorLabel") as Label
	var file_name_label := row.get_node("FileNameLabel") as Label
	file_name_label.text = _format_registered_image_label(entry)

	var texture := entry.get("texture") as Texture2D
	var resource_path := texture.resource_path if texture != null else ""
	var tooltip_lines := PackedStringArray()
	var node_path := str(entry.get("node_path", ""))
	if !node_path.is_empty():
		tooltip_lines.append("Node: %s" % node_path)
	tooltip_lines.append("File: %s" % str(entry.get("file_name", "(embedded)")))
	var animation_name := str(entry.get("animation_name", ""))
	var frame_index := int(entry.get("frame_index", -1))
	if !animation_name.is_empty():
		tooltip_lines.append("Animation: %s" % animation_name)
	if frame_index >= 0:
		tooltip_lines.append("Frame: %d" % frame_index)
	if !resource_path.is_empty():
		tooltip_lines.append("Resource: %s" % resource_path)
	row.tooltip_text = "\n".join(tooltip_lines)
	file_name_label.tooltip_text = row.tooltip_text
	separator_label.tooltip_text = row.tooltip_text
	thumbnail.tooltip_text = row.tooltip_text
	return row


func _clear_registered_image_rows() -> void:
	for child in _registered_images_list.get_children():
		if child == _registered_image_row_template:
			continue
		_registered_images_list.remove_child(child)
		child.queue_free()


func _restore_registered_images_scroll(scroll_vertical: int) -> void:
	_registered_images_scroll.scroll_vertical = scroll_vertical


func _format_registered_image_label(entry: Dictionary) -> String:
	var label := str(entry.get("file_name", "(embedded)"))
	var animation_name := str(entry.get("animation_name", ""))
	var frame_index := int(entry.get("frame_index", -1))
	if !animation_name.is_empty() and frame_index >= 0:
		return "%s (%s / %d)" % [label, animation_name, frame_index]
	return label


func _update_common_text(common_text: String, reset_scroll: bool = false) -> void:
	if _common_text.text != common_text:
		var common_scroll_vertical: int = 0 if reset_scroll else _common_text.scroll_vertical
		_common_text.text = common_text
		_common_text.scroll_vertical = common_scroll_vertical
		return
	if reset_scroll:
		_common_text.scroll_vertical = 0


func _empty_summary_data() -> Dictionary:
	return {
		"name": "-",
		"position": "-",
		"velocity": "-",
		"state": "-",
		"animation": "-",
		"collision": "-",
	}
