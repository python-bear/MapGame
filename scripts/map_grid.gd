@tool
class_name MapGrid
extends RefCounted
## Grid-based terrain for the top-down map levels.
##
## Reads two ASCII layers (TERRAIN and HEIGHT) from a data script such as
## levels/level1/level1_data.gd and answers movement questions:
## how fast can you walk here, and may you step there from where you stand?
##
## Reusable for any top-down level that wants the same rules.

const CELL := 32.0

## Walk-speed multiplier for each walkable terrain character.
## Anything not listed is solid (river, rock, broken bridge, off-map).
const SPEED := {
	".": 1.0,   # open ground
	"p": 1.3,   # cut trail
	"f": 0.5,   # jungle
	"m": 0.42,  # marsh
	"s": 0.8,   # stairs / slope
	"=": 1.15,  # bridge
	"S": 1.0,   # start
	"G": 1.0,   # goal
}

## Per-level override: which characters can be entered, and how fast.
var speeds: Dictionary = SPEED
var width := 0
var height := 0
var _t := PackedStringArray()    # one String per row
var _h := PackedByteArray()      # height per cell


func _init(data: Script = null) -> void:
	if data:
		var consts := data.get_script_constant_map()
		load_layers(consts["TERRAIN"], consts.get("HEIGHT", []))


func load_layers(terrain_rows: Array, height_rows: Array) -> void:
	height = terrain_rows.size()
	width = String(terrain_rows[0]).length()
	_t = PackedStringArray()
	_h = PackedByteArray()
	_h.resize(width * height)
	for y in height:
		var row := String(terrain_rows[y])
		if row.length() != width:
			push_error("MapGrid: terrain row %d is %d wide, expected %d" % [y, row.length(), width])
			row = row.rpad(width, "#").substr(0, width)
		_t.append(row)
		var hrow: String = String(height_rows[y]) if y < height_rows.size() else ""
		for x in width:
			_h[y * width + x] = int(hrow[x]) if x < hrow.length() else 0


## An independent copy (used to render how the map *will* look, in advance).
func clone() -> MapGrid:
	var g := MapGrid.new()
	g.speeds = speeds
	g.width = width
	g.height = height
	g._t = _t.duplicate()
	g._h = _h.duplicate()
	return g


# ------------------------------------------------------------------ queries
func in_bounds(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < width and c.y < height


func tile(c: Vector2i) -> String:
	if not in_bounds(c):
		return "X"
	return _t[c.y][c.x]


func tile_xy(x: int, y: int) -> String:
	return tile(Vector2i(x, y))


func elevation(c: Vector2i) -> int:
	if not in_bounds(c):
		return 0
	return _h[c.y * width + c.x]


func elevation_xy(x: int, y: int) -> int:
	return elevation(Vector2i(clampi(x, 0, width - 1), clampi(y, 0, height - 1)))


## Change a cell at runtime (e.g. a bridge he inks into being).
func set_tile(c: Vector2i, ch: String) -> void:
	if not in_bounds(c):
		return
	var row := _t[c.y]
	_t[c.y] = row.substr(0, c.x) + ch + row.substr(c.x + 1)


func is_walkable(c: Vector2i) -> bool:
	return speeds.has(tile(c))


func is_slope(c: Vector2i) -> bool:
	return tile(c) == "s"


func speed_at(pos: Vector2) -> float:
	return speeds.get(tile(cell_of(pos)), 0.0)


func cell_of(pos: Vector2) -> Vector2i:
	return Vector2i(floori(pos.x / CELL), floori(pos.y / CELL))


func cell_center(c: Vector2i) -> Vector2:
	return (Vector2(c) + Vector2(0.5, 0.5)) * CELL


func pixel_size() -> Vector2:
	return Vector2(width, height) * CELL


func find(ch: String) -> Vector2i:
	for y in height:
		var x := _t[y].find(ch)
		if x >= 0:
			return Vector2i(x, y)
	return Vector2i(-1, -1)


## May you set foot on cell `c` while standing on cell `from`?
## Same height: yes. One level apart: only via stairs — either cell is stairs,
## or `on_stairs` says the body is already touching a stairs cell.
func can_enter(c: Vector2i, from: Vector2i, on_stairs: bool = false) -> bool:
	if not is_walkable(c):
		return false
	var dh := absi(elevation(c) - elevation(from))
	if dh == 0:
		return true
	return dh == 1 and (on_stairs or is_slope(c) or is_slope(from))


## Can a square body of half-size `half` centred at `pos` stand there,
## given it is currently standing on cell `from`?
##
## While any part of the body touches stairs, one-level steps are allowed
## for every corner. (Checking corners one by one used to create spots at
## the ends of diagonal stairs you could walk into but not back out of.)
func body_fits(pos: Vector2, half: float, from: Vector2i) -> bool:
	var cells: Array[Vector2i] = []
	var on_stairs := is_slope(from)
	for off in [Vector2(-half, -half), Vector2(half, -half), Vector2(-half, half), Vector2(half, half)]:
		var c := cell_of(pos + off)
		cells.append(c)
		if is_slope(c):
			on_stairs = true
	for c in cells:
		if not can_enter(c, from, on_stairs):
			return false
	return true
