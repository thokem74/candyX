extends RefCounted
class_name GameTypes

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

const ATLAS_TILE_SIZE := 100
const CANDY_NAMES: Array[String] = ["red", "blue", "orange", "green", "purple"]
const CANDY_ATLAS_COLUMNS: Array[int] = [2, 1, 0, 3, 4]
const COLOR_BOMB_ATLAS_CELL := Vector2i(5, 0)

static func candy_count() -> int:
	return CANDY_NAMES.size()

static func candy_name_for(color_id: int) -> String:
	if color_id < 0 or color_id >= CANDY_NAMES.size():
		return "unknown"
	return CANDY_NAMES[color_id]

static func atlas_rect_for(color_id: int, special_type: int) -> Rect2:
	var cell := _atlas_cell_for(color_id, special_type)
	return Rect2(cell.x * ATLAS_TILE_SIZE, cell.y * ATLAS_TILE_SIZE, ATLAS_TILE_SIZE, ATLAS_TILE_SIZE)

static func has_atlas_region(color_id: int, special_type: int) -> bool:
	return _atlas_cell_for(color_id, special_type) != Vector2i(-1, -1)

static func _atlas_cell_for(color_id: int, special_type: int) -> Vector2i:
	if special_type == SpecialType.COLOR_BOMB:
		return COLOR_BOMB_ATLAS_CELL
	if color_id < 0 or color_id >= CANDY_ATLAS_COLUMNS.size():
		return Vector2i(-1, -1)
	var column: int = CANDY_ATLAS_COLUMNS[color_id]
	match special_type:
		SpecialType.STRIPED_ROW:
			return Vector2i(column, 1)
		SpecialType.STRIPED_COLUMN:
			return Vector2i(column, 2)
		SpecialType.WRAPPED:
			return Vector2i(2, 4)
		_:
			return Vector2i(column, 0)
