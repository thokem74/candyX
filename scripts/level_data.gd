extends RefCounted
class_name LevelData

const Types = preload("res://scripts/game_types.gd")

static func level_for(index: int) -> Dictionary:
	return _generated_level(maxi(0, index))

static func _generated_level(index: int) -> Dictionary:
	var level_number := index + 1
	var tier := maxi(0, index)
	var color_count := mini(5, 4 + floori(float(tier) / 3.0))
	var colors: Array[int] = []
	for color_id in color_count:
		colors.append(color_id)
	var moves := clampi(22 + floori(float(tier) / 4.0), 22, 32)
	var target_score := 900 + tier * 300 + maxi(0, color_count - 4) * 200
	var data := {
		"name": "Level %d" % level_number,
		"target_score": target_score,
		"moves": moves,
		"colors": colors,
	}
	match tier % 3:
		0:
			data["goal_type"] = Types.GoalType.SCORE
			data["goal_count"] = target_score
			data["description"] = "Reach %d points." % target_score
		1:
			var goal_color := tier % color_count
			var goal_count := mini(42, 16 + tier * 2)
			data["goal_type"] = Types.GoalType.CLEAR_COLOR
			data["goal_color"] = goal_color
			data["goal_count"] = goal_count
			data["description"] = "Clear %d %s pieces." % [goal_count, Types.label_for(goal_color)]
		_:
			var goal_count := mini(10, 3 + floori(float(tier) / 3.0))
			data["goal_type"] = Types.GoalType.SPECIALS
			data["goal_count"] = goal_count
			data["description"] = "Trigger %d special pieces." % goal_count
	return data
