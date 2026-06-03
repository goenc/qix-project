extends RefCounted
class_name UpgradeDraftService

const UPGRADE_POOL := [
	{
		"id": "fast_speed",
		"title": "FAST ROUTE",
		"description": "Fast Draw speed +12% and shard gain +10%.",
		"max_rank": 3
	},
	{
		"id": "slow_power",
		"title": "SLOW PRESSURE",
		"description": "Slow Draw speed +8% and boss squeeze reward +20%.",
		"max_rank": 3
	},
	{
		"id": "guard_charge",
		"title": "LINE GUARD",
		"description": "Gain 1 guard charge that blocks one boss hit.",
		"max_rank": 3
	},
	{
		"id": "growth_discount",
		"title": "FLOW STATE",
		"description": "Next growth thresholds become 10% cheaper.",
		"max_rank": 2
	},
	{
		"id": "top_outline_boost",
		"title": "TOP WINDOW",
		"description": "Top border grace +4 seconds.",
		"max_rank": 3
	},
	{
		"id": "small_chain_bonus",
		"title": "CHAIN CUTS",
		"description": "Small safe captures gain more shards and growth.",
		"max_rank": 3
	},
	{
		"id": "large_cut_bonus",
		"title": "BIG CLAIM",
		"description": "Large captures gain more shards and territory.",
		"max_rank": 3
	},
	{
		"id": "reroll_charge",
		"title": "SIGNAL RESET",
		"description": "Gain 1 reroll for future upgrade drafts.",
		"max_rank": 2
	},
	{
		"id": "streak_bonus",
		"title": "NO HIT RHYTHM",
		"description": "No-damage capture streaks give more growth and shards.",
		"max_rank": 3
	}
]


func build_choices(applied_upgrade_ranks: Dictionary, level_seed: int = 0) -> Array[Dictionary]:
	var eligible: Array[Dictionary] = []
	for entry in UPGRADE_POOL:
		var max_rank := int(entry.get("max_rank", 1))
		var current_rank := int(applied_upgrade_ranks.get(entry["id"], 0))
		if current_rank >= max_rank:
			continue
		eligible.append(entry)

	if eligible.is_empty():
		return []

	var rotation := 0
	if eligible.size() > 0:
		rotation = posmod(level_seed, eligible.size())

	var ordered: Array[Dictionary] = []
	for index in range(eligible.size()):
		ordered.append(eligible[(rotation + index) % eligible.size()])

	var result: Array[Dictionary] = []
	for index in range(mini(3, ordered.size())):
		var source: Dictionary = ordered[index]
		result.append({
			"id": source.get("id", ""),
			"title": source.get("title", ""),
			"description": source.get("description", "")
		})
	return result
