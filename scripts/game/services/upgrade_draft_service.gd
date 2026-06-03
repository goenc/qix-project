extends RefCounted
class_name UpgradeDraftService

const UPGRADE_POOL := [
	{
		"id": "fast_speed",
		"title": "速攻ルート",
		"description": "ファスト描画速度が12%上がり、シャード獲得量が10%増えます。",
		"max_rank": 3
	},
	{
		"id": "slow_power",
		"title": "重圧ライン",
		"description": "スロー描画速度が8%上がり、ボス圧縮報酬が20%増えます。",
		"max_rank": 3
	},
	{
		"id": "guard_charge",
		"title": "ラインガード",
		"description": "ボスの接触を1回だけ防ぐガードを1つ得ます。",
		"max_rank": 3
	},
	{
		"id": "growth_discount",
		"title": "集中維持",
		"description": "次回以降の成長に必要な量が10%軽くなります。",
		"max_rank": 2
	},
	{
		"id": "top_outline_boost",
		"title": "上辺猶予",
		"description": "上辺の安全時間が4秒伸びます。",
		"max_rank": 3
	},
	{
		"id": "small_chain_bonus",
		"title": "連続小取り",
		"description": "小さく安全な確保で得られるシャードと成長量が増えます。",
		"max_rank": 3
	},
	{
		"id": "large_cut_bonus",
		"title": "大取り報酬",
		"description": "大きな確保で得られるシャードと領域値が増えます。",
		"max_rank": 3
	},
	{
		"id": "reroll_charge",
		"title": "再抽選",
		"description": "次回以降の強化選択で使える再抽選回数を1つ得ます。",
		"max_rank": 2
	},
	{
		"id": "streak_bonus",
		"title": "無傷テンポ",
		"description": "無傷での連続確保時に成長量とシャード獲得量が増えます。",
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
