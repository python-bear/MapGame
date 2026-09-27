@tool
extends Node2D
## Draws a MapGrid as a hand-inked survey map: hypsometric tints, contour
## lines with cliff hachures, rivers, jungle, marsh, trails, stairs, rocks,
## bridges, plus the sheet furniture (neat line, survey grid, compass rose,
## scale bar, cartouche).
##
## It's a @tool script, so the map renders live in the editor while you edit
## the ASCII in the data script — press "Redraw" in the inspector after edits.

@export var data_script: Script:
	set(v):
		data_script = v
		_rebuild()
@export var title := "A SURVEY OF THE UPPER SOMBRA BASIN"
@export var subtitle := "surveyed on foot · Anno Domini MCCCXLVIII · sheet I"
## The drawing fades out towards this cell, as if the pen hadn't got there yet.
@export var unfinished_radius_cells := 6.0
@export var redraw := false:
	set(v):
		_rebuild()

const C := MapGrid.CELL
const MARGIN := 140.0

const TINT_1 := Color(0.78, 0.64, 0.40, 0.22)
const TINT_2 := Color(0.70, 0.50, 0.28, 0.26)
const CONTOUR := Color(0.47, 0.29, 0.15, 0.75)
const WATER_FILL := Color(0.45, 0.63, 0.70, 0.62)
const WATER_EDGE := Color(0.14, 0.28, 0.40, 0.95)
const WATER_SHORE := Color(0.18, 0.33, 0.44, 0.45)
const FOREST_FILL := Color(0.40, 0.50, 0.26, 0.30)
const CROWN_FILL := Color(0.30, 0.40, 0.19, 0.55)
const MARSH_FILL := Color(0.52, 0.58, 0.38, 0.28)
const TRAIL_FILL := Color(0.96, 0.88, 0.68, 0.6)
const TRAIL_EDGE := Color(0.52, 0.24, 0.12, 0.85)
const ROCK_FILL := Color(0.56, 0.50, 0.43, 0.95)

var grid: MapGrid
var _goal := Vector2(-99999, -99999)
var _serif: Font = preload("res://assets/fonts/IMFellEnglish.ttf")
var _italic: Font = preload("res://assets/fonts/IMFellEnglish-Italic.ttf")
var _hand: Font = preload("res://assets/fonts/Caveat.ttf")


func _ready() -> void:
	_rebuild()


func _rebuild() -> void:
	if data_script == null:
		return
	grid = MapGrid.new(data_script)
	var g := grid.find("G")
	if g.x >= 0:
		_goal = grid.cell_center(g)
	queue_redraw()


## World-space rectangle of the whole paper sheet (map + margins).
func sheet_rect() -> Rect2:
	return Rect2(Vector2(-MARGIN, -MARGIN), grid.pixel_size() + Vector2(MARGIN, MARGIN) * 2.0)


# =============================================================== drawing
func _draw() -> void:
	if grid == null:
		return
	# --- washes -------------------------------------------------------
	var h1 := _field(func(x, y): return grid.elevation_xy(x, y) >= 1)
	var h2 := _field(func(x, y): return grid.elevation_xy(x, y) >= 2)
	var water := _field(func(x, y): return grid.tile_xy(x, y) in ["~", "=", "b"])
	var forest := _field(func(x, y): return grid.tile_xy(x, y) == "f")
	var marsh := _field(func(x, y): return grid.tile_xy(x, y) == "m")
	var trail := _field(func(x, y): return grid.tile_xy(x, y) in ["p", "S", "G", "="])

	_fill(h1, 0.5, TINT_1)
	_fill(h2, 0.5, TINT_2)
	_fill(forest, 0.45, FOREST_FILL)
	_fill(marsh, 0.45, MARSH_FILL)
	_fill(trail, 0.5, TRAIL_FILL)
	_fill(water, 0.5, WATER_FILL)

	# --- lines --------------------------------------------------------
	for iso in [0.22, 0.5, 0.78]:
		_contour(h1, iso, CONTOUR, 1.1 if iso != 0.5 else 1.7, iso == 0.5)
		_contour(h2, iso, CONTOUR, 1.1 if iso != 0.5 else 1.7, iso == 0.5)
	_contour(water, 0.78, WATER_SHORE, 1.0)
	_contour(water, 0.5, WATER_EDGE, 1.8)
	_trail_edges(trail)

	# --- symbols ------------------------------------------------------
	_draw_ground_marks()
	_draw_water_ripples()
	_draw_marsh()
	_draw_stairs()
	_draw_trees()
	_draw_rocks()
	_draw_bridges()
	_draw_camp()
	_draw_sheet()


# =============================================================== fields
## A smoothed 0..1 field sampled at cell centres, padded by one cell.
func _field(pred: Callable) -> PackedFloat32Array:
	var w := grid.width + 2
	var h := grid.height + 2
	var raw := PackedFloat32Array()
	raw.resize(w * h)
	for sy in h:
		for sx in w:
			var cx := clampi(sx - 1, 0, grid.width - 1)
			var cy := clampi(sy - 1, 0, grid.height - 1)
			raw[sy * w + sx] = 1.0 if pred.call(cx, cy) else 0.0
	var out := PackedFloat32Array()
	out.resize(w * h)
	var k := [1.0, 2.0, 1.0]
	for sy in h:
		for sx in w:
			var acc := 0.0
			for dy in 3:
				var ny := clampi(sy + dy - 1, 0, h - 1)
				for dx in 3:
					var nx := clampi(sx + dx - 1, 0, w - 1)
					acc += raw[ny * w + nx] * k[dx] * k[dy]
			out[sy * w + sx] = acc / 16.0
	return out


func _sample_pos(sx: int, sy: int) -> Vector2:
	return Vector2(sx - 0.5, sy - 0.5) * C


## How "finished" the drawing is at a point (fades near the goal).
func _ink(p: Vector2) -> float:
	var r := unfinished_radius_cells * C
	return clampf(0.15 + (p.distance_to(_goal) - r * 0.35) / (r * 0.65) * 0.85, 0.15, 1.0)


func _cross(pa: Vector2, va: float, pb: Vector2, vb: float, iso: float) -> Vector2:
	# canonical order so neighbouring squares produce the identical point
	if pb.x < pa.x or (pb.x == pa.x and pb.y < pa.y):
		var tp := pa; pa = pb; pb = tp
		var tv := va; va = vb; vb = tv
	var t := clampf((iso - va) / (vb - va), 0.0, 1.0)
	return pa + (pb - pa) * t


## Marching-squares fill, batched into one triangle array.
func _fill(f: PackedFloat32Array, iso: float, col: Color) -> void:
	var w := grid.width + 2
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	for sy in grid.height + 1:
		for sx in grid.width + 1:
			var v := [f[sy * w + sx], f[sy * w + sx + 1], f[(sy + 1) * w + sx + 1], f[(sy + 1) * w + sx]]
			var p := [_sample_pos(sx, sy), _sample_pos(sx + 1, sy), _sample_pos(sx + 1, sy + 1), _sample_pos(sx, sy + 1)]
			var poly := PackedVector2Array()
			for i in 4:
				var j := (i + 1) % 4
				var ins: bool = v[i] >= iso
				if ins:
					poly.append(p[i])
				if ins != (v[j] >= iso):
					poly.append(_cross(p[i], v[i], p[j], v[j], iso))
			if poly.size() < 3:
				continue
			var base := pts.size()
			for q in poly:
				pts.append(q)
				cols.append(Color(col, col.a * _ink(q)))
			for i in range(1, poly.size() - 1):
				idx.append(base)
				idx.append(base + i)
				idx.append(base + i + 1)
	if idx.size() > 0:
		RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), idx, pts, cols)


## Marching-squares iso-line. With `hachure`, cliff edges get downhill ticks
## (but not where the square touches stairs).
func _contour(f: PackedFloat32Array, iso: float, col: Color, width: float, hachure: bool = false) -> void:
	var w := grid.width + 2
	var seg := PackedVector2Array()
	var segc := PackedColorArray()
	var ticks := PackedVector2Array()
	var tickc := PackedColorArray()
	for sy in grid.height + 1:
		for sx in grid.width + 1:
			var v := [f[sy * w + sx], f[sy * w + sx + 1], f[(sy + 1) * w + sx + 1], f[(sy + 1) * w + sx]]
			var p := [_sample_pos(sx, sy), _sample_pos(sx + 1, sy), _sample_pos(sx + 1, sy + 1), _sample_pos(sx, sy + 1)]
			var hits := PackedVector2Array()
			for i in 4:
				var j := (i + 1) % 4
				if (v[i] >= iso) != (v[j] >= iso):
					hits.append(Ink.wobble(_cross(p[i], v[i], p[j], v[j], iso), 1.3))
			for k in range(0, hits.size() - 1, 2):
				var a := hits[k]
				var b := hits[k + 1]
				var fade := _ink((a + b) * 0.5)
				seg.append(a); seg.append(b)
				segc.append(Color(col, col.a * fade))
				if hachure and not _square_has_slope(sx, sy):
					var down := -Vector2(v[1] + v[2] - v[0] - v[3], v[2] + v[3] - v[0] - v[1]).normalized()
					var n := int(a.distance_to(b) / 6.0) + 1
					for t in n:
						var q := a.lerp(b, (t + 0.5) / n)
						var tip := q + down * (4.0 + Ink.hash2(q.x, q.y) * 3.0)
						ticks.append(q); ticks.append(tip)
						tickc.append(Color(col, col.a * fade * 0.7))
	if seg.size() > 0:
		draw_multiline_colors(seg, segc, width)
	if ticks.size() > 0:
		draw_multiline_colors(ticks, tickc, 1.0)


func _square_has_slope(sx: int, sy: int) -> bool:
	for dy in 2:
		for dx in 2:
			var cx := clampi(sx - 1 + dx, 0, grid.width - 1)
			var cy := clampi(sy - 1 + dy, 0, grid.height - 1)
			if grid.tile_xy(cx, cy) == "s":
				return true
	return false


## Trails get a dotted edge, like a footpath on an old survey sheet.
func _trail_edges(f: PackedFloat32Array) -> void:
	var w := grid.width + 2
	var dots := PackedVector2Array()
	var cols := PackedColorArray()
	for sy in grid.height + 1:
		for sx in grid.width + 1:
			var v := [f[sy * w + sx], f[sy * w + sx + 1], f[(sy + 1) * w + sx + 1], f[(sy + 1) * w + sx]]
			var p := [_sample_pos(sx, sy), _sample_pos(sx + 1, sy), _sample_pos(sx + 1, sy + 1), _sample_pos(sx, sy + 1)]
			var hits := PackedVector2Array()
			for i in 4:
				var j := (i + 1) % 4
				if (v[i] >= 0.5) != (v[j] >= 0.5):
					hits.append(_cross(p[i], v[i], p[j], v[j], 0.5))
			for k in range(0, hits.size() - 1, 2):
				var a := hits[k]
				var b := hits[k + 1]
				var n := int(a.distance_to(b) / 7.0) + 1
				for t in n:
					var q := a.lerp(b, (t + 0.5) / n)
					var d := (b - a).normalized() * 1.6
					dots.append(q - d); dots.append(q + d)
					var c := Color(TRAIL_EDGE, TRAIL_EDGE.a * _ink(q))
					cols.append(c)
	if dots.size() > 0:
		draw_multiline_colors(dots, cols, 2.0)


# =============================================================== symbols
func _rng_for(x: int, y: int, salt: int = 0) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = hash(Vector3i(x, y, salt))
	return r


func _draw_ground_marks() -> void:
	var lines := PackedVector2Array()
	var cols := PackedColorArray()
	for y in grid.height:
		for x in grid.width:
			if grid.tile_xy(x, y) != ".":
				continue
			var r := _rng_for(x, y, 1)
			if r.randf() > 0.22:
				continue
			var p := Vector2(x + r.randf_range(0.2, 0.8), y + r.randf_range(0.3, 0.9)) * C
			var c := Color(Ink.INK, 0.35 * _ink(p))
			for s in [-1.0, 0.0, 1.0]:
				lines.append(p + Vector2(s * 2.5, 0)); lines.append(p + Vector2(s * 3.5, -4.0 - absf(s) * -1.0))
				cols.append(c)
	if lines.size() > 0:
		draw_multiline_colors(lines, cols, 1.0)


func _draw_water_ripples() -> void:
	for y in grid.height:
		for x in grid.width:
			if grid.tile_xy(x, y) != "~":
				continue
			var r := _rng_for(x, y, 2)
			if r.randf() > 0.35:
				continue
			var p := Vector2(x + r.randf_range(0.25, 0.75), y + r.randf_range(0.25, 0.75)) * C
			var pts := PackedVector2Array()
			for i in 7:
				var t := i / 6.0
				pts.append(p + Vector2((t - 0.5) * 14.0, sin(t * TAU) * 1.8))
			draw_polyline(pts, Color(WATER_EDGE, 0.45 * _ink(p)), 1.0, true)


func _draw_marsh() -> void:
	var lines := PackedVector2Array()
	var cols := PackedColorArray()
	for y in grid.height:
		for x in grid.width:
			if grid.tile_xy(x, y) != "m":
				continue
			var r := _rng_for(x, y, 3)
			for n in 1 + int(r.randf() > 0.5):
				var p := Vector2(x + r.randf_range(0.2, 0.8), y + r.randf_range(0.35, 0.85)) * C
				var c := Color(0.25, 0.3, 0.18, 0.8 * _ink(p))
				for s in [-1.0, -0.4, 0.4, 1.0]:
					lines.append(p + Vector2(s * 1.5, 0)); lines.append(p + Vector2(s * 4.0, -7.0 + absf(s) * 2.0))
					cols.append(c)
				lines.append(p + Vector2(-6, 2.5)); lines.append(p + Vector2(6, 2.5))
				cols.append(Color(WATER_EDGE, 0.5))
	if lines.size() > 0:
		draw_multiline_colors(lines, cols, 1.1)


func _draw_stairs() -> void:
	for y in grid.height:
		for x in grid.width:
			if grid.tile_xy(x, y) != "s":
				continue
			var me := grid.elevation_xy(x, y)
			var down := Vector2.ZERO
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var c := Vector2i(x, y) + d
				if grid.in_bounds(c) and grid.elevation(c) < me:
					down += Vector2(d)
			if down == Vector2.ZERO:
				down = Vector2(0, 1)
			down = down.normalized()
			var across := Vector2(-down.y, down.x)
			var centre := grid.cell_center(Vector2i(x, y))
			var col := Color(Ink.INK, 0.75 * _ink(centre))
			for k in 4:
				var o := centre + down * (-10.0 + k * 6.5)
				var half := 11.0 - k * 1.0
				draw_line(o - across * half, o + across * half, col, 1.3, true)


func _draw_trees() -> void:
	var trees := []
	for y in grid.height:
		for x in grid.width:
			if grid.tile_xy(x, y) != "f":
				continue
			var r := _rng_for(x, y, 4)
			for n in 1 + int(r.randf() > 0.45):
				trees.append({
					"p": Vector2(x + r.randf_range(0.15, 0.85), y + r.randf_range(0.2, 0.9)) * C,
					"r": r.randf_range(6.0, 9.5),
					"palm": r.randf() < 0.22,
					"a": r.randf() * TAU,
				})
	# keep every tree's crown (and trunk) clear of the water
	trees = trees.filter(func(t): return _clear_of_water(t.p, t.r + 4.0))
	trees.sort_custom(func(a, b): return a.p.y < b.p.y)
	for t in trees:
		var p: Vector2 = t.p
		var tr: float = t.r
		var fade := _ink(p)
		var ink := Color(Ink.INK, 0.72 * fade)
		if t.palm:
			draw_line(p + Vector2(0, 7), p, Color(ink, ink.a * 0.8), 1.3, true)
			for i in 5:
				var a: float = t.a + TAU * i / 5.0
				var tip := p + Vector2.from_angle(a) * tr
				var mid := p + Vector2.from_angle(a + 0.3) * tr * 0.55 + Vector2(0, -2)
				draw_polyline(PackedVector2Array([p, mid, tip]), ink, 1.3, true)
		else:
			draw_line(p + Vector2(0, t.r * 0.9), p + Vector2(0, t.r + 4.0), ink, 1.2, true)
			draw_circle(p, t.r, Color(CROWN_FILL, CROWN_FILL.a * fade))
			draw_arc(p, t.r, PI * 0.85, PI * 2.2, 12, ink, 1.2, true)
			draw_arc(p + Vector2(t.r * 0.3, -t.r * 0.2), t.r * 0.45, PI, PI * 1.8, 6, Color(ink, ink.a * 0.6), 1.0, true)


func _clear_of_water(p: Vector2, r: float) -> bool:
	for i in 12:
		var q := p + Vector2.from_angle(TAU * i / 12.0) * r
		if grid.tile(grid.cell_of(q)) in ["~", "=", "b"]:
			return false
	return not grid.tile(grid.cell_of(p + Vector2(0, r))) in ["~", "=", "b"]


func _draw_rocks() -> void:
	for y in grid.height:
		for x in grid.width:
			if grid.tile_xy(x, y) != "#":
				continue
			var r := _rng_for(x, y, 5)
			var c := grid.cell_center(Vector2i(x, y))
			var poly := PackedVector2Array()
			for i in 7:
				poly.append(c + Vector2.from_angle(TAU * i / 7.0 + r.randf() * 0.4) * r.randf_range(9.0, 14.0))
			var fade := _ink(c)
			draw_colored_polygon(poly, Color(ROCK_FILL, ROCK_FILL.a * fade))
			var outline := poly.duplicate()
			outline.append(poly[0])
			draw_polyline(outline, Color(Ink.INK, 0.9 * fade), 1.5, true)
			draw_line(c + Vector2(-3, -4), c + Vector2(4, 2), Color(Ink.INK, 0.5 * fade), 1.0, true)
			draw_line(c + Vector2(-5, 1), c + Vector2(1, 6), Color(Ink.INK, 0.5 * fade), 1.0, true)


func _is_bridge(x: int, y: int) -> bool:
	return grid.tile_xy(x, y) in ["=", "b"]


func _draw_bridges() -> void:
	var seen := {}
	for y in grid.height:
		for x in grid.width:
			if not _is_bridge(x, y) or seen.has(Vector2i(x, y)):
				continue
			var horizontal := _is_bridge(x + 1, y) or _is_bridge(x - 1, y)
			if not (_is_bridge(x, y + 1) or _is_bridge(x, y - 1)) and not horizontal:
				horizontal = grid.is_walkable(Vector2i(x - 1, y)) or grid.is_walkable(Vector2i(x + 1, y))
			var d := Vector2i(1, 0) if horizontal else Vector2i(0, 1)
			var cells := []
			var c := Vector2i(x, y)
			while _is_bridge(c.x, c.y):
				cells.append(c)
				seen[c] = true
				c += d
			_draw_bridge_run(cells, horizontal, grid.tile(cells[0]) == "b")


func _draw_bridge_run(cells: Array, horizontal: bool, broken: bool) -> void:
	var a := grid.cell_center(cells[0])
	var b := grid.cell_center(cells[-1])
	var along := Vector2(1, 0) if horizontal else Vector2(0, 1)
	var across := Vector2(0, 1) if horizontal else Vector2(1, 0)
	a -= along * (C * 0.85)
	b += along * (C * 0.85)
	var half_w := C * 0.36
	var length := a.distance_to(b)
	var plank_col := Color(0.55, 0.38, 0.22, 0.95)
	var n := int(length / 5.0)
	for i in n + 1:
		var t := float(i) / n
		if broken and t > 0.22 and t < 0.8:
			continue
		var p := a.lerp(b, t)
		var jig := (Ink.hash2(p.x, p.y) - 0.5) * 2.0
		draw_line(p - across * half_w + along * jig * 0.5, p + across * half_w - along * jig * 0.5, plank_col, 3.0, true)
	for s: float in [-1.0, 1.0]:
		var off := across * (half_w + 2.0) * s
		if broken:
			draw_line(a + off, a.lerp(b, 0.3) + off + across * 6.0 * s, Ink.INK, 1.4, true)
			draw_line(b + off, b.lerp(a, 0.25) + off + across * 8.0 * s, Ink.INK, 1.4, true)
		else:
			Ink.line(self, a + off, b + off, Ink.INK, 1.5, 0.6)
		draw_circle(a + off, 3.0, Ink.INK)
		draw_circle(b + off, 3.0, Ink.INK)
	if broken:
		# a couple of planks drifting downstream
		var mid := a.lerp(b, 0.5)
		for k in 3:
			var q := mid + across * (k - 1) * 12.0 + along * ((k % 2) * 10.0 - 5.0) + across * 18.0
			draw_line(q, q + Vector2.from_angle(0.6 + k) * 9.0, Color(plank_col, 0.8), 3.0, true)


func _draw_camp() -> void:
	var s := grid.find("S")
	if s.x < 0:
		return
	var c := grid.cell_center(s)
	# two tents and the campfire
	for t: Vector2 in [Vector2(-28, -12), Vector2(0, -30), Vector2(26, -14)]:
		var base := c + t
		var tri := PackedVector2Array([base + Vector2(0, -12), base + Vector2(-11, 7), base + Vector2(11, 7)])
		draw_colored_polygon(tri, Color(0.86, 0.78, 0.6, 1))
		tri.append(tri[0])
		draw_polyline(tri, Ink.INK, 1.6, true)
		draw_line(base + Vector2(0, -12), base + Vector2(0, 7), Ink.INK, 1.0, true)
	var fire := c + Vector2(0, 12)
	for i in 6:
		var a := TAU * i / 6.0
		draw_line(fire + Vector2.from_angle(a) * 3.0, fire + Vector2.from_angle(a) * 8.0, Ink.RED_INK, 1.5, true)
	draw_circle(fire, 2.5, Ink.RED_INK)


# =============================================================== sheet
func _draw_sheet() -> void:
	var size := grid.pixel_size()
	var rect := Rect2(Vector2.ZERO, size)
	# survey grid, every 8 cells
	var step := 8
	var faint := Color(Ink.INK, 0.12)
	for gx in range(step, grid.width, step):
		draw_line(Vector2(gx * C, 0), Vector2(gx * C, size.y), faint, 1.0)
	for gy in range(step, grid.height, step):
		draw_line(Vector2(0, gy * C), Vector2(size.x, gy * C), faint, 1.0)
	# neat lines
	var inner := rect.grow(18.0)
	var outer := rect.grow(28.0)
	_rect_lines(inner, Ink.INK, 2.2)
	_rect_lines(outer, Ink.INK, 1.0)
	# grid references in the border
	var letters := "ABCDEFGHIJKLMNOP"
	for i in ceili(grid.width / float(step)):
		var cx := (i * step + step * 0.5) * C
		var ch := letters[i]
		Ink.text(self, _serif, Vector2(cx, -46.0), ch, 22, Ink.INK)
		Ink.text(self, _serif, Vector2(cx, size.y + 46.0), ch, 22, Ink.INK)
	for j in ceili(grid.height / float(step)):
		var cy := (j * step + step * 0.5) * C
		Ink.text(self, _serif, Vector2(-46.0, cy), str(j + 1), 22, Ink.INK)
		Ink.text(self, _serif, Vector2(size.x + 46.0, cy), str(j + 1), 22, Ink.INK)
	for i in range(1, ceili(grid.width / float(step))):
		draw_line(Vector2(i * step * C, -18), Vector2(i * step * C, -28), Ink.INK, 1.0)
		draw_line(Vector2(i * step * C, size.y + 18), Vector2(i * step * C, size.y + 28), Ink.INK, 1.0)
	for j in range(1, ceili(grid.height / float(step))):
		draw_line(Vector2(-18, j * step * C), Vector2(-28, j * step * C), Ink.INK, 1.0)
		draw_line(Vector2(size.x + 18, j * step * C), Vector2(size.x + 28, j * step * C), Ink.INK, 1.0)
	# title cartouche
	Ink.text(self, _serif, Vector2(size.x * 0.5, size.y + 84.0), title, 34, Ink.INK)
	Ink.text(self, _italic, Vector2(size.x * 0.5, size.y + 116.0), subtitle, 22, Color(Ink.INK, 0.8))
	# compass rose (top-right, over the plateau's edge of the sheet)
	Ink.compass_rose(self, Vector2(size.x - 70.0, size.y - 250.0), 56.0, _serif, Color(Ink.INK, 0.85))
	# scale bar
	var sb := Vector2(0.0, size.y + 70.0)
	var seg := C * 4.0
	for i in 4:
		var r := Rect2(sb + Vector2(i * seg, 0), Vector2(seg, 7))
		if i % 2 == 0:
			draw_rect(r, Ink.INK)
		draw_rect(r, Ink.INK, false, 1.2)
	for i in 5:
		Ink.text(self, _serif, sb + Vector2(i * seg, 22.0), str(i), 16, Ink.INK)
	Ink.text(self, _italic, sb + Vector2(seg * 2.0, 44.0), "miles (approx.)", 16, Ink.INK)


func _rect_lines(r: Rect2, col: Color, w: float) -> void:
	var p := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
	for i in 4:
		Ink.line(self, p[i], p[(i + 1) % 4], col, w, 0.7)
