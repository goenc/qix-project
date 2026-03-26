extends RefCounted
class_name BaseMainCutRatingService

const INITIAL_VALUE := 50
const MIN_VALUE := 0
const MAX_VALUE := 100
const BAR_BAND_HEIGHT := 56.0
const BAD_LABEL := "BAD"
const GOOD_LABEL := "GOOD"
const CUT_DELTA_RULES := [
	{"min_percent": 0.0, "max_percent": 5.0, "delta": 2},
	{"min_percent": 5.0, "max_percent": 10.0, "delta": 1},
	{"min_percent": 10.0, "max_percent": 15.0, "delta": 0},
	{"min_percent": 15.0, "max_percent": 20.0, "delta": -10},
	{"min_percent": 20.0, "max_percent": 25.0, "delta": -15},
	{"min_percent": 25.0, "max_percent": null, "delta": -20}
]


static func resolve_delta(single_capture_percent: float) -> int:
	for rule in CUT_DELTA_RULES:
		var min_percent := float(rule.get("min_percent", 0.0))
		if single_capture_percent < min_percent:
			continue

		var max_percent = rule.get("max_percent", null)
		if max_percent != null and single_capture_percent >= float(max_percent):
			continue

		return int(rule.get("delta", 0))

	return 0


static func clamp_value(value: int) -> int:
	return clampi(value, MIN_VALUE, MAX_VALUE)
