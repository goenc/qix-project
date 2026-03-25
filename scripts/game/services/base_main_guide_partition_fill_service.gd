extends RefCounted
class_name BaseMainGuidePartitionFillService

const BaseMainGuidePartitionFillEntryService = preload(
	"res://scripts/game/services/base_main_guide_partition_fill_entry_service.gd"
)
const BaseMainGuidePartitionFillPolygonService = preload(
	"res://scripts/game/services/base_main_guide_partition_fill_polygon_service.gd"
)

var _entry_service := BaseMainGuidePartitionFillEntryService.new()
var _polygon_service := BaseMainGuidePartitionFillPolygonService.new()


func collect_guide_partition_rects(state: Dictionary) -> Array[PackedVector2Array]:
	return _polygon_service.collect_guide_partition_rects(state)


func sync_guide_partition_fill_entries_after_capture(
	state: Dictionary,
	affected_vertical_guide_keys: Dictionary,
	capture_delta: Dictionary
) -> Dictionary:
	var partition_state := {
		"guide_epsilon": float(state.get("guide_epsilon", 0.0)),
		"partition_fill_target_boss_diameter": float(state.get("partition_fill_target_boss_diameter", 0.0)),
		"current_outer_loop": state.get("current_outer_loop", PackedVector2Array()),
		"remaining_polygon": state.get("remaining_polygon", PackedVector2Array()),
		"guide_segments": state.get("guide_segments", []),
		"vertical_guide_indices_by_x": state.get("vertical_guide_indices_by_x", {}),
		"vertical_guide_axis_keys": state.get("vertical_guide_axis_keys", []),
		"guide_partition_fill_entries": state.get("guide_partition_fill_entries", []).duplicate(true),
		"guide_partition_fill_polygons_by_key": state.get("guide_partition_fill_polygons_by_key", {}).duplicate(true),
		"guide_partition_fill_entry_key_sequence": int(state.get("guide_partition_fill_entry_key_sequence", 0))
	}
	_entry_service.sync_entries_after_capture(partition_state, affected_vertical_guide_keys, capture_delta)
	_polygon_service.rebuild_partition_fill_polygons(partition_state)
	return {
		"guide_partition_fill_entries": partition_state.get("guide_partition_fill_entries", []),
		"guide_partition_fill_polygons_by_key": partition_state.get("guide_partition_fill_polygons_by_key", {}),
		"guide_partition_fill_entry_key_sequence": int(
			partition_state.get("guide_partition_fill_entry_key_sequence", 0)
		)
	}
