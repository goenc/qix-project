base_main.gd:
- add current_outer_loop_metrics and refresh it when the outer loop changes
- pass cached metrics into split_outer_loop_by_trail
- compute added_claimed_area and per-capture AABBs in _append_claimed_capture_results
- update claimed_area by delta and append AABB deltas during finalize

playfield_boundary.gd:
- add an optional metrics argument to split_outer_loop_by_trail
- reuse provided metrics when they match the current loop size

Validation:
- godot --headless --path . --check-only