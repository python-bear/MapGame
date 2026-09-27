extends Node2D
## An island that isn't where the chart put it — and doesn't stay put.
##
## It writes itself into the level's grid as land ("L"), cell by cell, and
## gives the water back behind it, so ships and tentacles must go round it.
## It never lands on the ship: cells too close to the hull stay water.
## With `speed` 0 it simply appears (a new island) and stays.

@export var rx := 3.0            ## half-size in cells
@export var ry := 2.5
@export var a := Vector2.ZERO    ## drift between these two cell positions
@export var b := Vector2.ZERO
@export var speed := 0.0         ## cells per second (0 = still)
@export var label := ""

var grid: MapGrid
var ship: Node2D
var reveal: Node
var appear := 0.0                ## 0..1 fade-in as it rises out of the paper

var _centre := Vector2.ZERO      ## cells
var _dir := 1.0
var _cells := {}                 ## Vector2i -> original tile
var _outline := PackedVector2Array()
var _t := 0.0
var _hand: Font = preload("res://assets/fonts/Caveat.ttf")
const C := 32.0


func _ready() -> void:
	_centre = a
	position = _centre * C
	var n := 40
	for i in n:
		var ang := TAU * i / n
		_outline.append(Vector2(cos(ang) * rx, sin(ang) * ry) * (1.0 + _wob(ang)) * C)
	_occupy()
	create_tween().tween_property(self, "appear", 1.0, 2.5)


func _wob(ang: float) -> float:
	return 0.16 * sin(ang * 3.0 + 1.3) + 0.09 * sin(ang * 5.0 + 0.4)


func _inside(cell_centre: Vector2) -> bool:
	var d := (cell_centre - _centre)
	var ang := atan2(d.y / ry, d.x / rx)
	return Vector2(d.x / rx, d.y / ry).length() < 1.0 + _wob(ang)


func _process(delta: float) -> void:
	_t += delta
	if speed > 0.0 and b != a:
		var to: Vector2 = b if _dir > 0.0 else a
		var step := speed * delta
		# it waits for no one — but it won't crush the ship: pause if the hull
		# is right at its leading edge
		var ahead := _centre + (to - _centre).normalized() * (maxf(rx, ry) + 1.2)
		if ship and ship.global_position.distance_to(ahead * C) < 34.0:
			step = 0.0
		_centre = _centre.move_toward(to, step)
		if _centre.distance_to(to) < 0.01:
			_dir = -_dir
		position = _centre * C
		_occupy()
	queue_redraw()


func _occupy() -> void:
	if grid == null:
		return
	var want := {}
	for y in range(int(_centre.y - ry * 1.4) - 1, int(_centre.y + ry * 1.4) + 2):
		for x in range(int(_centre.x - rx * 1.4) - 1, int(_centre.x + rx * 1.4) + 2):
			var c := Vector2i(x, y)
			if grid.in_bounds(c) and _inside(Vector2(x + 0.5, y + 0.5)):
				want[c] = true
	# give back the water it has left
	for c: Vector2i in _cells.keys():
		if not want.has(c):
			grid.set_tile(c, _cells[c])
			_cells.erase(c)
	# and take the water it has moved onto (never under the hull)
	for c: Vector2i in want:
		if _cells.has(c):
			continue
		var t := grid.tile(c)
		if t not in [".", ","]:
			continue
		if ship and ship.global_position.distance_to(grid.cell_center(c)) < 30.0:
			continue
		_cells[c] = t
		grid.set_tile(c, "L")


func _draw() -> void:
	var seen: float = 1.0
	if reveal:
		seen = maxf(reveal.amount_at(global_position), 0.35)
	var al := appear * seen
	var waterline := Color(0.18, 0.30, 0.38)
	for k in 3:
		var s := 1.18 + k * 0.2
		var ring := PackedVector2Array()
		for p in _outline:
			ring.append(p * s)
		ring.append(ring[0])
		draw_polyline(ring, Color(waterline, (0.6 - k * 0.18) * al), 1.1, true)
	var fill := _outline.duplicate()
	draw_colored_polygon(fill, Color(0.80, 0.71, 0.52, al))
	var inner := PackedVector2Array()
	for p in _outline:
		inner.append(p * 0.55)
	draw_colored_polygon(inner, Color(0.62, 0.52, 0.34, 0.45 * al))
	fill.append(fill[0])
	draw_polyline(fill, Color(0.17, 0.12, 0.09, 0.95 * al), 2.4, true)
	# hachures, like the other islands
	for i in 9:
		var ang := TAU * i / 9.0 + 0.3
		var p := Vector2(cos(ang) * rx, sin(ang) * ry) * 0.62 * C
		draw_line(p, p * 0.8, Color(0.17, 0.12, 0.09, 0.5 * al), 1.2)
	if label != "":
		Ink.text(self, _hand, Vector2(0, ry * C + 30), label, 20, Color(0.55, 0.08, 0.05, 0.9 * al))
