@tool
extends Node2D
## Draws a MapGrid as an old nautical chart: engraved water-lines around the
## coasts, shallows, soundings in fathoms, rhumb lines from two compass roses,
## reefs, wrecks, the harbour pier and town, and the chart furniture.
## Terrain legend is in levels/level2/level2_data.gd.

@export var data_script: Script:
	set(v):
		data_script = v
		_rebuild()
@export var title := "MARE TENEBRARUM"
@export var subtitle := "a chart of a sea he has never sailed · soundings in fathoms"
## Compass roses (in cells). Rhumb lines radiate from each across the chart.
@export var roses: Array[Vector2] = [Vector2(40, 8), Vector2(52, 48)]
## Where the sea serpent is drawn (cells).
@export var serpent_at := Vector2(34, 36)
## Tents on the landing shore (cells).
@export var tents: Array[Vector2] = []
@export var redraw := false:
	set(v):
		_rebuild()

const C := MapGrid.CELL
const MARGIN := 140.0
const LAND := Color(0.80, 0.71, 0.52, 1.0)
const LAND_SHADE := Color(0.62, 0.52, 0.34, 0.5)
const COAST := Color(0.17, 0.12, 0.09, 0.95)
const WATERLINE := Color(0.18, 0.30, 0.38, 1.0)
const SHALLOW := Color(0.48, 0.64, 0.66, 0.38)
const SHALLOW_2 := Color(0.52, 0.66, 0.68, 0.16)
const RHUMB := [Color(0.15, 0.12, 0.1, 0.16), Color(0.2, 0.35, 0.2, 0.14), Color(0.55, 0.12, 0.08, 0.12)]

var grid: MapGrid
var _dist := PackedFloat32Array()   # distance (cells) from land, per cell
var _serif: Font = preload("res://assets/fonts/IMFellEnglish.ttf")
var _italic: Font = preload("res://assets/fonts/IMFellEnglish-Italic.ttf")
var _hand: Font = preload("res://assets/fonts/Caveat.ttf")


func _ready() -> void:
	_rebuild()


func _rebuild() -> void:
	if data_script == null:
		return
	grid = MapGrid.new(data_script)
	_compute_distance()
	queue_redraw()


## The sea has changed under the chart: recompute and redraw.
func refresh() -> void:
	_compute_distance()
	queue_redraw()


func sheet_rect() -> Rect2:
	return Rect2(Vector2(-MARGIN, -MARGIN), grid.pixel_size() + Vector2(MARGIN, MARGIN) * 2.0)


## Chamfer distance from land, in cells.
func _compute_distance() -> void:
	var w := grid.width
	var h := grid.height
	_dist.resize(w * h)
	for y in h:
		for x in w:
			_dist[y * w + x] = 0.0 if grid.tile_xy(x, y) in ["L", "P"] else 999.0
	var d2 := 1.414
	for pass_i in 2:
		for y in h:
			for x in w:
				var v := _dist[y * w + x]
				if x > 0: v = minf(v, _dist[y * w + x - 1] + 1.0)
				if y > 0: v = minf(v, _dist[(y - 1) * w + x] + 1.0)
				if x > 0 and y > 0: v = minf(v, _dist[(y - 1) * w + x - 1] + d2)
				if x < w - 1 and y > 0: v = minf(v, _dist[(y - 1) * w + x + 1] + d2)
				_dist[y * w + x] = v
		for y in range(h - 1, -1, -1):
			for x in range(w - 1, -1, -1):
				var v := _dist[y * w + x]
				if x < w - 1: v = minf(v, _dist[y * w + x + 1] + 1.0)
				if y < h - 1: v = minf(v, _dist[(y + 1) * w + x] + 1.0)
				if x < w - 1 and y < h - 1: v = minf(v, _dist[(y + 1) * w + x + 1] + d2)
				if x > 0 and y < h - 1: v = minf(v, _dist[(y + 1) * w + x - 1] + d2)
				_dist[y * w + x] = v


func dist_at(x: int, y: int) -> float:
	return _dist[clampi(y, 0, grid.height - 1) * grid.width + clampi(x, 0, grid.width - 1)]


# ================================================================ draw
func _draw() -> void:
	if grid == null:
		return
	var w := grid.width
	var h := grid.height
	_draw_rhumb_lines()
	var dist := IsoLines.values(w, h, func(x, y): return minf(dist_at(x, y), 8.0))
	var land := IsoLines.field(w, h, func(x, y): return grid.tile_xy(x, y) == "L")
	var reef := IsoLines.field(w, h, func(x, y): return grid.tile_xy(x, y) in ["r", "w"])
	# shallows
	IsoLines.fill(self, _invert(dist), w, h, C, -3.2, SHALLOW_2)
	IsoLines.fill(self, _invert(dist), w, h, C, -1.7, SHALLOW)
	# engraved water-lines, fading out to sea
	var lines := [[1.15, 0.75, 1.3], [1.7, 0.55, 1.1], [2.4, 0.4, 1.0], [3.3, 0.28, 0.9], [4.5, 0.16, 0.9]]
	for l in lines:
		IsoLines.contour(self, dist, w, h, C, l[0], Color(WATERLINE, l[1]), l[2], 0.8)
	# land
	IsoLines.fill(self, land, w, h, C, 0.5, LAND)
	var inland := IsoLines.values(w, h, func(x, y): return _land_depth(x, y))
	IsoLines.fill(self, inland, w, h, C, 2.2, LAND_SHADE)
	IsoLines.contour(self, inland, w, h, C, 2.2, Color(COAST, 0.3), 1.0, 1.0)
	IsoLines.contour(self, land, w, h, C, 0.5, COAST, 2.4, 1.2)
	# hazards: reefs and wrecks get the chart's dotted danger line
	IsoLines.dotted(self, reef, w, h, C, 0.22, Color(0.45, 0.08, 0.06, 0.7), 1.6)
	# sandbars: water too shallow to sail — stippled sand inside a dotted line
	var sand := IsoLines.field(w, h, func(x, y): return grid.tile_xy(x, y) == "z")
	IsoLines.fill(self, sand, w, h, C, 0.5, Color(0.84, 0.74, 0.5, 0.75))
	IsoLines.dotted(self, sand, w, h, C, 0.5, Color(0.35, 0.25, 0.12, 0.8), 1.4)
	_draw_sandbars()
	_draw_soundings()
	_draw_waves()
	_draw_land_marks()
	_draw_reefs()
	_draw_wrecks()
	_draw_pier()
	_draw_serpent(serpent_at * C)
	_draw_tents()
	_draw_sheet()


func _invert(f: PackedFloat32Array) -> PackedFloat32Array:
	var o := f.duplicate()
	for i in o.size():
		o[i] = -o[i]
	return o


## How far inside the coast a land cell is (for hill shading).
func _land_depth(x: int, y: int) -> float:
	if grid.tile_xy(x, y) != "L":
		return 0.0
	var best := 9.0
	for dy in range(-3, 4):
		for dx in range(-3, 4):
			var t := grid.tile_xy(x + dx, y + dy)
			if t != "L" and t != "P" and t != "X":
				best = minf(best, Vector2(dx, dy).length())
	return best


func _rng_for(x: int, y: int, salt: int = 0) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = hash(Vector3i(x, y, salt + 77))
	return r


func _is_sea(x: int, y: int) -> bool:
	return grid.tile_xy(x, y) in [".", ",", "S", "G"]


func _draw_rhumb_lines() -> void:
	var rect := Rect2(Vector2.ZERO, grid.pixel_size())
	for rc: Vector2 in roses:
		var c := rc * C
		for i in 32:
			var a := TAU * i / 32.0
			var far := c + Vector2.from_angle(a) * 6000.0
			var seg := _clip(c, far, rect)
			if seg.size() == 2:
				var kind := 0 if i % 4 == 0 else (1 if i % 2 == 0 else 2)
				draw_line(seg[0], seg[1], RHUMB[kind], 1.0 if kind else 1.3)


## Liang–Barsky clip of a segment to a rectangle.
func _clip(a: Vector2, b: Vector2, r: Rect2) -> PackedVector2Array:
	var t0 := 0.0
	var t1 := 1.0
	var d := b - a
	var p := [-d.x, d.x, -d.y, d.y]
	var q := [a.x - r.position.x, r.end.x - a.x, a.y - r.position.y, r.end.y - a.y]
	for i in 4:
		if absf(p[i]) < 1e-6:
			if q[i] < 0.0:
				return PackedVector2Array()
		else:
			var t: float = q[i] / p[i]
			if p[i] < 0.0:
				t0 = maxf(t0, t)
			else:
				t1 = minf(t1, t)
	if t0 > t1:
		return PackedVector2Array()
	return PackedVector2Array([a + d * t0, a + d * t1])


func _draw_soundings() -> void:
	for y in range(1, grid.height - 1):
		for x in range(1, grid.width - 1):
			if grid.tile_xy(x, y) != ".":
				continue
			var r := _rng_for(x, y, 1)
			if r.randf() > 0.07:
				continue
			var d := dist_at(x, y)
			if d < 2.0:
				continue
			var fathoms := int(d * 3.0 + r.randi_range(0, 6))
			if d > 6.0 and r.randf() < 0.25:
				fathoms = 99 + r.randi_range(0, 400)  # "no bottom found"
			var p := Vector2(x + r.randf_range(0.2, 0.8), y + r.randf_range(0.3, 0.8)) * C
			Ink.text(self, _italic, p, str(fathoms), 15, Color(0.2, 0.22, 0.25, 0.55))


func _draw_waves() -> void:
	for y in grid.height:
		for x in grid.width:
			if grid.tile_xy(x, y) != "." or dist_at(x, y) < 3.0:
				continue
			var r := _rng_for(x, y, 2)
			if r.randf() > 0.05:
				continue
			var p := Vector2(x + 0.5, y + 0.5) * C
			for k in 2:
				var pts := PackedVector2Array()
				for i in 9:
					var t := i / 8.0
					pts.append(p + Vector2((t - 0.5) * 22.0, sin(t * TAU) * 2.5 + k * 5.0))
				draw_polyline(pts, Color(WATERLINE, 0.35), 1.0, true)


func _draw_land_marks() -> void:
	var ink := Color(0.2, 0.14, 0.09, 0.8)
	for y in grid.height:
		for x in grid.width:
			if grid.tile_xy(x, y) != "L":
				continue
			var r := _rng_for(x, y, 3)
			var p := Vector2(x + r.randf_range(0.25, 0.75), y + r.randf_range(0.35, 0.8)) * C
			var depth := _land_depth(x, y)
			var near_tents := false
			for tc: Vector2 in tents:
				if Vector2(x, y).distance_to(tc) < 2.2:
					near_tents = true
			if near_tents:
				continue
			if depth >= 2.5 and r.randf() < 0.45:
				# a little hill, shaded on its east side
				var s := r.randf_range(7.0, 11.0)
				draw_colored_polygon(PackedVector2Array([p + Vector2(0, -s), p + Vector2(s * 1.1, s * 0.4), p + Vector2(0, s * 0.4)]), Color(LAND_SHADE, 0.7))
				draw_polyline(PackedVector2Array([p + Vector2(-s * 1.1, s * 0.4), p + Vector2(0, -s), p + Vector2(s * 1.1, s * 0.4)]), ink, 1.3, true)
			elif depth < 2.0 and r.randf() < 0.18:
				# a palm on the shore
				draw_line(p + Vector2(0, 6), p, ink, 1.2, true)
				for i in 5:
					var a := -PI / 2.0 + (i - 2) * 0.7
					draw_line(p, p + Vector2.from_angle(a) * 6.5, ink, 1.1, true)


## Three tents on the landing shore — pitched just like his own camp.
func _draw_tents() -> void:
	for i in tents.size():
		var base: Vector2 = tents[i] * C
		var tri := PackedVector2Array([base + Vector2(0, -14), base + Vector2(-13, 8), base + Vector2(13, 8)])
		draw_colored_polygon(tri, Color(0.88, 0.8, 0.62, 1))
		var outline := tri.duplicate()
		outline.append(tri[0])
		draw_polyline(outline, Ink.INK, 1.7, true)
		draw_line(base + Vector2(0, -14), base + Vector2(0, 8), Ink.INK, 1.1, true)
		draw_line(base + Vector2(-3, 8), base + Vector2(0, 0), Color(Ink.INK, 0.6), 1.0, true)
	if tents.size() > 0:
		var c := Vector2.ZERO
		for t: Vector2 in tents:
			c += t
		c = c / tents.size() * C
		for i in 6:
			var a := TAU * i / 6.0
			draw_line(c + Vector2.from_angle(a) * 3.0, c + Vector2.from_angle(a) * 8.0, Ink.RED_INK, 1.5, true)
		draw_circle(c, 2.5, Ink.RED_INK)


func _house(p: Vector2, r: RandomNumberGenerator) -> void:
	var ink := Color(0.2, 0.14, 0.09, 0.85)
	var s := r.randf_range(5.0, 7.0)
	var body := Rect2(p - Vector2(s, s * 0.4), Vector2(s * 2.0, s * 1.2))
	draw_rect(body, Color(0.9, 0.84, 0.7))
	draw_rect(body, ink, false, 1.0)
	draw_polyline(PackedVector2Array([body.position, p + Vector2(0, -s * 1.3), Vector2(body.end.x, body.position.y)]), ink, 1.2, true)
	if r.randf() < 0.15:  # a church
		draw_line(p + Vector2(0, -s * 1.3), p + Vector2(0, -s * 2.4), ink, 1.2)
		draw_line(p + Vector2(-2.5, -s * 2.0), p + Vector2(2.5, -s * 2.0), ink, 1.2)


func _draw_sandbars() -> void:
	var ink := Color(0.35, 0.25, 0.12, 0.7)
	var labelled := {}
	for y in grid.height:
		for x in grid.width:
			if grid.tile_xy(x, y) != "z":
				continue
			var r := _rng_for(x, y, 9)
			for k in 7:
				draw_circle(Vector2(x + r.randf(), y + r.randf()) * C, 1.1, ink)
			# one label per bar, on its first cell
			var key := Vector2i(x / 6, y / 6)
			if not labelled.has(key) and grid.tile_xy(x - 1, y) != "z" and grid.tile_xy(x, y - 1) != "z":
				labelled[key] = true
				Ink.text(self, _hand, Vector2(x + 1.5, y - 0.3) * C, "dries ½ fm", 17, Color(0.3, 0.2, 0.1, 0.85))


func _draw_reefs() -> void:
	var ink := Color(0.25, 0.1, 0.08, 0.85)
	for y in grid.height:
		for x in grid.width:
			if grid.tile_xy(x, y) != "r":
				continue
			var r := _rng_for(x, y, 4)
			for k in 3:
				var p := Vector2(x + r.randf_range(0.2, 0.8), y + r.randf_range(0.2, 0.8)) * C
				if k == 0:
					var poly := PackedVector2Array()
					for i in 6:
						poly.append(p + Vector2.from_angle(TAU * i / 6.0 + r.randf()) * r.randf_range(5.0, 8.0))
					draw_colored_polygon(poly, Color(0.5, 0.44, 0.38, 0.9))
					poly.append(poly[0])
					draw_polyline(poly, ink, 1.2, true)
				else:
					draw_line(p - Vector2(4, 0), p + Vector2(4, 0), ink, 1.3)
					draw_line(p - Vector2(0, 4), p + Vector2(0, 4), ink, 1.3)


func _draw_wrecks() -> void:
	var ink := Color(0.18, 0.1, 0.07, 0.9)
	for y in grid.height:
		for x in grid.width:
			if grid.tile_xy(x, y) != "w":
				continue
			var c := grid.cell_center(Vector2i(x, y))
			var a := _rng_for(x, y, 5).randf_range(-0.6, 0.6)
			draw_set_transform(c, a, Vector2.ONE)
			var hull := PackedVector2Array([Vector2(-15, 0), Vector2(-9, 6), Vector2(12, 5), Vector2(17, -1), Vector2(11, -4), Vector2(-10, -4)])
			draw_colored_polygon(hull, Color(0.35, 0.25, 0.17, 0.85))
			hull.append(hull[0])
			draw_polyline(hull, ink, 1.3, true)
			for mx in [-6.0, 2.0, 9.0]:
				draw_line(Vector2(mx, 0), Vector2(mx + 5, -12), ink, 1.3, true)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_pier() -> void:
	var cells := []
	for y in grid.height:
		for x in grid.width:
			if grid.tile_xy(x, y) == "P":
				cells.append(Vector2i(x, y))
	if cells.is_empty():
		return
	var a := grid.cell_center(cells[0]) - Vector2(C * 0.5, 0)
	var b := grid.cell_center(cells[-1]) + Vector2(C * 0.6, 0)
	var r := Rect2(Vector2(a.x, a.y - C * 0.32), Vector2(b.x - a.x, C * 0.64))
	draw_rect(r, Color(0.56, 0.4, 0.24))
	var x := r.position.x
	while x < r.end.x:
		draw_line(Vector2(x, r.position.y), Vector2(x, r.end.y), Color(0.25, 0.15, 0.08, 0.7), 1.0)
		x += 5.0
	draw_rect(r, Ink.INK, false, 1.4)
	for px in [r.position.x, r.position.x + r.size.x * 0.5]:
		draw_circle(Vector2(px, r.position.y), 2.8, Ink.INK)
		draw_circle(Vector2(px, r.end.y), 2.8, Ink.INK)
	# a lantern at the end of the pier
	draw_circle(Vector2(r.position.x + 4, r.position.y - 7), 4.0, Color(0.95, 0.75, 0.3, 0.9))
	draw_arc(Vector2(r.position.x + 4, r.position.y - 7), 4.0, 0, TAU, 12, Ink.INK, 1.0)


## The obligatory sea serpent in the empty corner of the chart.
func _draw_serpent(at: Vector2) -> void:
	var ink := Color(0.16, 0.2, 0.2, 0.75)
	var fill := Color(0.35, 0.45, 0.42, 0.45)
	for k in 3:
		var c := at + Vector2(k * 34.0, 0)
		var r := 13.0 - k * 2.0
		draw_arc(c, r, PI, TAU, 16, ink, 2.0, true)
		draw_colored_polygon(PackedVector2Array([c + Vector2(-r, 0), c + Vector2(0, -r), c + Vector2(r, 0)]), fill)
		for s in 3:
			var q := c + Vector2.from_angle(PI + (s + 1) * PI / 4.0) * r
			draw_line(q, q + Vector2.from_angle(PI + (s + 1) * PI / 4.0) * 5.0, ink, 1.4)
	var head := at + Vector2(-26, -6)
	draw_circle(head, 8.0, fill)
	draw_arc(head, 8.0, 0, TAU, 14, ink, 1.8, true)
	draw_line(head + Vector2(-6, 3), head + Vector2(-16, 6), ink, 1.6)
	draw_circle(head + Vector2(-2, -2), 1.8, Color(0.6, 0.1, 0.06))
	var tail := PackedVector2Array()
	for i in 10:
		var t := i / 9.0
		tail.append(at + Vector2(88 + t * 40, sin(t * 5.0) * 7.0 * (1.0 - t)))
	draw_polyline(tail, ink, 2.0, true)
	for i in 5:
		var q := at + Vector2(-30 + i * 38, 12)
		draw_arc(q, 9.0, 0.2, PI - 0.2, 8, Color(0.2, 0.3, 0.38, 0.5), 1.2, true)


func _draw_sheet() -> void:
	var size := grid.pixel_size()
	var rect := Rect2(Vector2.ZERO, size)
	var step := 8
	for gx in range(step, grid.width, step):
		draw_line(Vector2(gx * C, 0), Vector2(gx * C, size.y), Color(Ink.INK, 0.08), 1.0)
	for gy in range(step, grid.height, step):
		draw_line(Vector2(0, gy * C), Vector2(size.x, gy * C), Color(Ink.INK, 0.08), 1.0)
	# neat line with a chequered border, like an engraved chart
	var inner := rect.grow(18.0)
	var outer := rect.grow(30.0)
	_rect_lines(inner, Ink.INK, 2.2)
	_rect_lines(outer, Ink.INK, 1.0)
	var seg := C * 2.0
	var i := 0
	var x := 0.0
	while x < size.x:
		if i % 2 == 0:
			draw_rect(Rect2(Vector2(x, -30), Vector2(minf(seg, size.x - x), 12)), Color(Ink.INK, 0.8))
			draw_rect(Rect2(Vector2(x, size.y + 18), Vector2(minf(seg, size.x - x), 12)), Color(Ink.INK, 0.8))
		x += seg
		i += 1
	i = 0
	var y := 0.0
	while y < size.y:
		if i % 2 == 0:
			draw_rect(Rect2(Vector2(-30, y), Vector2(12, minf(seg, size.y - y))), Color(Ink.INK, 0.8))
			draw_rect(Rect2(Vector2(size.x + 18, y), Vector2(12, minf(seg, size.y - y))), Color(Ink.INK, 0.8))
		y += seg
		i += 1
	# roses
	for rc: Vector2 in roses:
		Ink.compass_rose(self, rc * C, 70.0, _serif, Color(Ink.INK, 0.85))
	# cartouche
	Ink.text(self, _serif, Vector2(size.x * 0.5, size.y + 78.0), title, 40, Ink.INK)
	Ink.text(self, _italic, Vector2(size.x * 0.5, size.y + 114.0), subtitle, 22, Color(Ink.INK, 0.8))
	Ink.text(self, _italic, Vector2(size.x * 0.5, -62.0), "— sheet II —", 20, Color(Ink.INK, 0.7))


func _rect_lines(r: Rect2, col: Color, wd: float) -> void:
	var p := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
	for k in 4:
		Ink.line(self, p[k], p[(k + 1) % 4], col, wd, 0.7)
