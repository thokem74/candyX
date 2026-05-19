extends RefCounted
class_name GameTypes

const BOARD_SIZE := 8
const INVALID_CELL := Vector2i(-1, -1)

enum SpecialType {
	NONE,
	STRIPED_ROW,
	STRIPED_COLUMN,
	WRAPPED,
	COLOR_BOMB,
}

enum GoalType {
	SCORE,
	CLEAR_COLOR,
	SPECIALS,
}

const PIECE_COLORS: Array[Color] = [
	Color("#ff5b7f"),
	Color("#47c3ff"),
	Color("#ffd447"),
	Color("#64d66e"),
	Color("#a778ff"),
	Color("#ff9a3d"),
]

const PIECE_LABELS: Array[String] = ["A", "B", "C", "D", "E", "F"]

static func color_for(color_id: int) -> Color:
	if color_id < 0 or color_id >= PIECE_COLORS.size():
		return Color.WHITE
	return PIECE_COLORS[color_id]

static func label_for(color_id: int) -> String:
	if color_id < 0 or color_id >= PIECE_LABELS.size():
		return "?"
	return PIECE_LABELS[color_id]

static func special_label(special_type: int) -> String:
	match special_type:
		SpecialType.STRIPED_ROW:
			return "H"
		SpecialType.STRIPED_COLUMN:
			return "V"
		SpecialType.WRAPPED:
			return "W"
		SpecialType.COLOR_BOMB:
			return "*"
		_:
			return ""

static func special_name(special_type: int) -> String:
	match special_type:
		SpecialType.STRIPED_ROW:
			return "row striped"
		SpecialType.STRIPED_COLUMN:
			return "column striped"
		SpecialType.WRAPPED:
			return "wrapped"
		SpecialType.COLOR_BOMB:
			return "color bomb"
		_:
			return "normal"
