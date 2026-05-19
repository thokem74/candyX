extends RefCounted
class_name LevelData

const Types = preload("res://scripts/game_types.gd")

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
			"colors": [0, 1, 2, 3, 4, 5],
			"goal_type": Types.GoalType.CLEAR_COLOR,
			"goal_color": 4,
			"goal_count": 22,
			"description": "Clear 22 purple pieces.",
		},
		{
			"name": "Level 5",
			"target_score": 3000,
			"moves": 28,
			"colors": [0, 1, 2, 3, 4, 5],
			"goal_type": Types.GoalType.SCORE,
			"goal_count": 3000,
			"description": "Reach 3000 points.",
		},
	]
