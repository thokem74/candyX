extends RefCounted
class_name LevelData

const Types = preload("res://scripts/game_types.gd")

static func level_for(index: int) -> Dictionary:
	var starter_levels := levels()
	if index >= 0 and index < starter_levels.size():
		return starter_levels[index]
	return _generated_level(max(5, index))

static func levels() -> Array[Dictionary]:
	return [
		{
			"name": "Level 1",
			"target_score": 900,
			"moves": 22,
			"colors": [0, 1, 2, 3],
			"goal_type": Types.GoalType.SCORE,
			"goal_count": 900,
			"description": "Reach 900 points.",
		},
		{
			"name": "Level 2",
			"target_score": 1300,
			"moves": 24,
			"colors": [0, 1, 2, 3, 4],
			"goal_type": Types.GoalType.CLEAR_COLOR,
			"goal_color": 0,
			"goal_count": 18,
			"description": "Clear 18 red pieces.",
		},
		{
			"name": "Level 3",
			"target_score": 1700,
			"moves": 25,
			"colors": [0, 1, 2, 3, 4],
			"goal_type": Types.GoalType.SPECIALS,
			"goal_count": 3,
			"description": "Trigger 3 special pieces.",
		},
		{
			"name": "Level 4",
			"target_score": 2200,
			"moves": 26,
			"colors": [0, 1, 2, 3, 4],
			"goal_type": Types.GoalType.CLEAR_COLOR,
			"goal_color": 4,
			"goal_count": 22,
			"description": "Clear 22 purple pieces.",
		},
		{
			"name": "Level 5",
			"target_score": 3000,
			"moves": 28,
			"colors": [0, 1, 2, 3, 4],
			"goal_type": Types.GoalType.SCORE,
			"goal_count": 3000,
			"description": "Reach 3000 points.",
		},
	]

static func _generated_level(index: int) -> Dictionary:
	var level_number := index + 1
	var tier := index - 4
	var color_count := mini(5, 4 + floori(float(tier) / 3.0))
	var colors: Array[int] = []
	for color_id in color_count:
		colors.append(color_id)
	var moves := clampi(22 + floori(float(tier) / 4.0), 22, 32)
	var target_score := 1000 + tier * 260 + color_count * 180
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
			var goal_count := mini(42, 14 + tier * 2)
			data["goal_type"] = Types.GoalType.CLEAR_COLOR
			data["goal_color"] = goal_color
			data["goal_count"] = goal_count
			data["description"] = "Clear %d %s pieces." % [goal_count, Types.label_for(goal_color)]
		_:
			var goal_count := mini(10, 2 + floori(float(tier) / 3.0))
			data["goal_type"] = Types.GoalType.SPECIALS
			data["goal_count"] = goal_count
			data["description"] = "Trigger %d special pieces." % goal_count
	return data
