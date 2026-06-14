extends RefCounted
class_name UpgradeDraftService

const UPGRADE_POOL := [
	{
		"id": "fast_speed",
		"title": "速描き強化",
		"description": "速描き速度+12%、得点+10%",
		"max_rank": 3
	},
	{
		"id": "slow_power",
		"title": "遅描き強化",
		"description": "遅描き速度+8%、ボス領域を削った時の得点+20%、遅描き得点+5%",
		"max_rank": 3
	},
	{
		"id": "guard_charge",
		"title": "接触ガード",
		"description": "ボス接触を1回だけ防ぐガード+1",
		"max_rank": 3
	},
	{
		"id": "growth_discount",
		"title": "必要経験値軽減",
		"description": "次のレベルアップに必要な経験値-10%",
		"max_rank": 2
	},
	{
		"id": "top_outline_boost",
		"title": "外周上辺タイマー延長",
		"description": "外周上辺にいる時の安全時間+4秒",
		"max_rank": 3
	},
	{
		"id": "small_chain_bonus",
		"title": "小取り強化",
		"description": "小さい確保で得る得点と経験値が増加",
		"max_rank": 3
	},
	{
		"id": "large_cut_bonus",
		"title": "大取り強化",
		"description": "大きい確保で得る得点と陣取り点が増加",
		"max_rank": 3
	},
	{
		"id": "reroll_charge",
		"title": "再抽選追加",
		"description": "強化選択の再抽選回数+1",
		"max_rank": 2
	},
	{
		"id": "streak_bonus",
		"title": "無傷連続ボーナス",
		"description": "無傷で連続確保した時の得点と経験値が増加",
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
