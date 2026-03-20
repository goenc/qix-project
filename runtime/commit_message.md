Optimize capture finalization with incremental metrics

Cache current_outer_loop metrics, reuse them when splitting the trail, and update claimed area plus AABB caches incrementally during capture finalization.

Validation: godot --headless --path . --check-only