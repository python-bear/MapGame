extends CanvasLayer
## His map of the labyrinth, drawn as he goes. Hold Tab to look at it.
##
## It only knows what he has *seen*: corridors down his lines of sight, the
## doors, the doorway of light, where he last glimpsed the beast. When a wall
## moves somewhere he isn't looking, the page keeps the old line until he sees
## that place again — then the old line is struck through and the new one
## drawn in fresh ink.

const SIGHT_CELLS := 6

var maze: MazeBuilder
var player: Node3D
var beast: Node3D

var open := false
var visible_cells := {}          # cells in line of sight right now
var _seen_cells := {}            # Vector2i -> true
var _edges := {}                 # edge key -> {"kind": String, "old": String}
var _exit_seen := false
var _beast_seen_at := Vector2i(-1, -1)
var _beast_seen_time := -999.0
var _changes := 0
var _page: Control
var _t := 0.0
var _tick := 0.0
var _hand: Font = preload("res://assets/fonts/Caveat.ttf")
var _italic: Font = preload("res://assets/fonts/IMFellEnglish-Italic.ttf")
var _hint_shown := false
## After the silent room the ink runs: the map is gone.
var ruined := false
var _ruin := 0.0
var _blots: Array = []

signal first_change_noticed


func _ready() -> void:
	layer = 21   # above the HUD title card, below nothing that matters while reading
	_page = Control.new()
	_page.set_anchors_preset(Control.PRESET_FULL_RECT)
	_page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_page.draw.connect(_draw_page)
	_page.modulate.a = 0.0
	add_child(_page)


func _process(delta: float) -> void:
	_t += delta
	_tick -= delta
	if maze and player and _tick <= 0.0:
		_tick = 0.12
		_look()
	if ruined:
		_ruin = minf(1.0, _ruin + delta * 0.35)
	var want := Input.is_action_pressed("map_view") and not get_tree().paused
	open = want
	_page.modulate.a = move_toward(_page.modulate.a, 1.0 if want else 0.0, delta * 6.0)
	if _page.modulate.a > 0.0:
		_page.queue_redraw()


# ================================================================ seeing
func _look() -> void:
	visible_cells.clear()
	var here := maze.cell_of(player.global_position)
	_see_cell(here)
	for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var c := here
		for k in SIGHT_CELLS:
			var nb := c + d
			var kind := _actual(c, nb)
			_record(c, nb, kind)
			if kind == "wall" or (kind == "door" and not _door_open(c, nb)):
				break
			c = nb
			_see_cell(c)
	# the beast: seen if its eyes are in the line of sight
	if beast and beast.state != 0:
		var bc := maze.cell_of(beast.global_position)
		if visible_cells.has(bc):
			_beast_seen_at = bc
			_beast_seen_time = _t


func _see_cell(c: Vector2i) -> void:
	visible_cells[c] = true
	_seen_cells[c] = true
	# the walls around a cell you can see into
	for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		_record(c, c + d, _actual(c, c + d))


func _actual(a: Vector2i, b: Vector2i) -> String:
	if b.x < 0 or b.y < 0 or b.x >= maze.n or b.y >= maze.n:
		var e := maze._edge(a, b)
		if e.y >= 0 and e.y < maze.rows.size() and e.x >= 0 and e.x < maze.rows[e.y].length() and maze.rows[e.y][e.x] == "X":
			return "exit"
		return "wall"
	return maze.edge_kind(a, b, false)


func _door_open(a: Vector2i, b: Vector2i) -> bool:
	var d = maze.door_between(a, b)
	return d != null and d.is_passable()


func _record(a: Vector2i, b: Vector2i, kind: String) -> void:
	var key := maze.edge_key(a, b)
	if kind == "exit":
		_exit_seen = true
	if _edges.has(key):
		var e: Dictionary = _edges[key]
		if e.kind != kind and (e.kind == "wall" or kind == "wall"):
			e.old = e.kind
			_changes += 1
			if _changes == 1:
				first_change_noticed.emit()
		e.kind = kind
	else:
		_edges[key] = {"kind": kind, "old": ""}


# ================================================================ drawing
func _draw_page() -> void:
	var vs := _page.size
	var side := minf(vs.x, vs.y) * 0.74
	var cs := side / maze.n
	var origin := (vs - Vector2(side, side)) / 2.0 + Vector2(0, 14)
	var tilt := -0.025
	_page.draw_set_transform(vs / 2.0, tilt, Vector2.ONE)
	var o := origin - vs / 2.0
	# the page
	var paper := Rect2(o - Vector2(34, 58), Vector2(side + 68, side + 96))
	_page.draw_rect(Rect2(paper.position + Vector2(8, 10), paper.size), Color(0, 0, 0, 0.45))
	_page.draw_rect(paper, Color(0.9, 0.84, 0.69))
	_page.draw_rect(paper, Color(0.35, 0.22, 0.12), false, 2.0)
	var ink := Color(0.2, 0.12, 0.07, 0.95)
	_page.draw_string(_hand, paper.position + Vector2(26, 42), "the labyrinth — as far as I have seen it", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, ink)
	# faint pencil grid
	for i in maze.n + 1:
		_page.draw_line(o + Vector2(i * cs, 0), o + Vector2(i * cs, side), Color(0.3, 0.25, 0.2, 0.08), 1.0)
		_page.draw_line(o + Vector2(0, i * cs), o + Vector2(side, i * cs), Color(0.3, 0.25, 0.2, 0.08), 1.0)
	# floors he's seen
	for c: Vector2i in _seen_cells:
		var col := Color(0.8, 0.72, 0.55, 0.9) if not visible_cells.has(c) else Color(0.95, 0.9, 0.75, 1.0)
		_page.draw_rect(Rect2(o + Vector2(c) * cs + Vector2(1, 1), Vector2(cs - 2, cs - 2)), col)
	# walls, doors, the light
	for key: String in _edges:
		var e: Dictionary = _edges[key]
		var seg := _edge_segment(key, o, cs)
		match e.kind:
			"wall":
				var fresh: bool = e.old == "open" or e.old == "door"
				_wobbly(seg[0], seg[1], Color(0.55, 0.1, 0.06, 0.95) if fresh else ink, 3.0)
			"door":
				var mid: Vector2 = (seg[0] + seg[1]) / 2.0
				var along: Vector2 = (seg[1] - seg[0]).normalized()
				_page.draw_line(mid - along * cs * 0.25, mid + along * cs * 0.25, Color(0.45, 0.25, 0.1), 6.0)
				_wobbly(seg[0], mid - along * cs * 0.25, ink, 3.0)
				_wobbly(mid + along * cs * 0.25, seg[1], ink, 3.0)
			"exit":
				var m: Vector2 = (seg[0] + seg[1]) / 2.0
				for k in 12:
					var a := TAU * k / 12.0 + _t * 0.3
					_page.draw_line(m + Vector2.from_angle(a) * 7.0, m + Vector2.from_angle(a) * 15.0, Color(0.85, 0.6, 0.1), 2.0)
				_page.draw_circle(m, 6.0, Color(0.95, 0.75, 0.2))
		# a wall that isn't there any more: struck through
		if e.old == "wall" and e.kind != "wall":
			_wobbly(seg[0], seg[1], Color(ink, 0.35), 3.0)
			var mid2: Vector2 = (seg[0] + seg[1]) / 2.0
			var n2: Vector2 = (seg[1] - seg[0]).normalized().orthogonal() * cs * 0.18
			var a2: Vector2 = (seg[1] - seg[0]) * 0.3
			_page.draw_line(mid2 - a2 - n2, mid2 + a2 + n2, Color(0.6, 0.08, 0.05), 2.5)
			_page.draw_line(mid2 - a2 + n2, mid2 + a2 - n2, Color(0.6, 0.08, 0.05), 2.5)
	# where he last saw it
	if _beast_seen_at.x >= 0:
		var age := _t - _beast_seen_time
		var bp := o + (Vector2(_beast_seen_at) + Vector2(0.5, 0.5)) * cs
		var a3 := clampf(1.0 - age / 20.0, 0.25, 1.0)
		_page.draw_circle(bp + Vector2(-5, 0), 3.5, Color(0.8, 0.05, 0.02, a3))
		_page.draw_circle(bp + Vector2(5, 0), 3.5, Color(0.8, 0.05, 0.02, a3))
		_page.draw_string(_hand, bp + Vector2(-20, 22), "%ds ago" % int(age) if age > 1.5 else "HERE", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(0.6, 0.05, 0.02, a3))
	# him: a red arrow, pointing the way he faces
	var here := Vector2(player.global_position.x, player.global_position.z) / maze.cell_size
	var pp := o + here * cs
	var fwd := -player.global_transform.basis.z
	var f2 := Vector2(fwd.x, fwd.z).normalized()
	var tri := PackedVector2Array([pp + f2 * 12.0, pp + f2.rotated(2.5) * 8.0, pp + f2.rotated(-2.5) * 8.0])
	_page.draw_colored_polygon(tri, Color(0.7, 0.08, 0.05))
	if _changes > 0:
		_page.draw_string(_hand, paper.position + Vector2(26, paper.size.y - 14), "the walls are not where I drew them.", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(0.6, 0.08, 0.05))
	if _ruin > 0.0:
		_draw_ruin(paper)
	_page.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## The ink runs: blots spread over everything he drew, and it drips down the page.
func _draw_ruin(paper: Rect2) -> void:
	if _blots.is_empty():
		var rng := RandomNumberGenerator.new()
		rng.seed = 77
		for i in 26:
			_blots.append({"p": paper.position + Vector2(rng.randf_range(0.08, 0.92), rng.randf_range(0.12, 0.85)) * paper.size,
				"r": rng.randf_range(18.0, 70.0), "d": rng.randf_range(0.0, 0.6), "drip": rng.randf_range(40.0, 220.0), "w": rng.randf_range(3.0, 9.0)})
	var ink := Color(0.1, 0.06, 0.05)
	for b in _blots:
		var k := clampf((_ruin - b.d) / 0.4, 0.0, 1.0)
		if k <= 0.0:
			continue
		_page.draw_circle(b.p, b.r * k, Color(ink, 0.85 * k))
		_page.draw_circle(b.p + Vector2(b.r * 0.4, -b.r * 0.2) * k, b.r * 0.6 * k, Color(ink, 0.7 * k))
		var len: float = b.drip * k
		_page.draw_rect(Rect2(b.p + Vector2(-b.w / 2.0, 0), Vector2(b.w, len)), Color(ink, 0.8 * k))
		_page.draw_circle(b.p + Vector2(0, len), b.w * 0.8, Color(ink, 0.8 * k))
	var a := clampf((_ruin - 0.5) * 2.0, 0.0, 1.0)
	var box := Rect2(paper.position + Vector2(20, paper.size.y * 0.42), Vector2(paper.size.x - 40, 64))
	_page.draw_rect(box, Color(0.9, 0.84, 0.69, 0.85 * a))
	_page.draw_string(_hand, box.position + Vector2(0, 46), "I cannot map this place.", HORIZONTAL_ALIGNMENT_CENTER, box.size.x, 44, Color(0.55, 0.06, 0.04, a))


func _edge_segment(key: String, o: Vector2, cs: float) -> Array:
	var p := key.split(",")
	var x := int(p[0])
	var y := int(p[1])
	var a := o + Vector2(x, y) * 0.5 * cs
	if y % 2 == 0:
		return [a - Vector2(cs * 0.5, 0), a + Vector2(cs * 0.5, 0)]
	return [a - Vector2(0, cs * 0.5), a + Vector2(0, cs * 0.5)]


func _wobbly(a: Vector2, b: Vector2, col: Color, w: float) -> void:
	var mid := (a + b) / 2.0 + (b - a).orthogonal().normalized() * (Ink.hash2(a.x, a.y) - 0.5) * 2.0
	_page.draw_polyline(PackedVector2Array([a, mid, b]), col, w, true)
