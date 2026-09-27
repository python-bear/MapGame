extends Node2D
## The expedition's work in Level 1:
##   * the ROUTE — five places to reach in order (the next is always marked)
##   * the SURVEY MARKERS — stakes shown on his original map. Reach each one to
##     record it. Two of them are not where the map says: at the drawn spot
##     there's nothing, and the real stake is somewhere nearby.
## Levels read `step`, and listen for the signals.

signal waypoint_reached(index: int)
signal marker_recorded(index: int)
signal marker_missing(index: int)

const C := 32.0

var route: Array = []        ## [{name, cell}]
var markers: Array = []      ## [{drawn, real}]
var step := 0
var recorded := {}
var missing := {}
var player: Node2D
var reveal: Node

var _t := 0.0
var _hand: Font = preload("res://assets/fonts/Caveat.ttf")


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()
	if player == null:
		return
	var p := player.global_position
	# the route, strictly in order (the last step is the level's goal node)
	if step < route.size() - 1:
		var w: Vector2 = route[step].cell * C
		if p.distance_to(w) < 30.0:
			var i := step
			step += 1
			waypoint_reached.emit(i)
	# markers
	for i in markers.size():
		if recorded.has(i):
			continue
		var m: Dictionary = markers[i]
		var real: Vector2 = m.real * C
		var drawn: Vector2 = m.drawn * C
		if p.distance_to(real) < 20.0:
			recorded[i] = true
			marker_recorded.emit(i)
		elif not missing.has(i) and drawn.distance_to(real) > 1.0 and p.distance_to(drawn) < 26.0:
			missing[i] = true
			marker_missing.emit(i)


func _draw() -> void:
	var red := Color(0.6, 0.08, 0.05, 0.9)
	var pencil := Color(0.25, 0.18, 0.12, 0.8)
	# survey markers, as the original map drew them
	for i in markers.size():
		var m: Dictionary = markers[i]
		var drawn: Vector2 = m.drawn * C
		var real: Vector2 = m.real * C
		var tri := PackedVector2Array([drawn + Vector2(0, -9), drawn + Vector2(-8, 6), drawn + Vector2(8, 6)])
		if recorded.has(i) and drawn.distance_to(real) < 1.0:
			draw_colored_polygon(tri, red)
		else:
			tri.append(tri[0])
			draw_polyline(tri, pencil, 1.6, true)
		Ink.text(self, _hand, drawn + Vector2(0, 18), "S%d" % (i + 1), 16, pencil)
		if missing.has(i):
			# nothing here — struck through
			draw_line(drawn + Vector2(-12, -12), drawn + Vector2(12, 10), red, 2.2)
			draw_line(drawn + Vector2(12, -12), drawn + Vector2(-12, 10), red, 2.2)
			Ink.text(self, _hand, drawn + Vector2(0, -22), "not here", 18, red)
		# the real stake, once its place is charted
		if drawn.distance_to(real) > 1.0 and reveal and reveal.amount_at(real) > 0.4:
			_stake(real, recorded.has(i))
	# the route
	for i in route.size():
		var w: Vector2 = route[i].cell * C
		if i < step:
			draw_line(w + Vector2(-7, 0), w + Vector2(-2, 6), red, 2.5)
			draw_line(w + Vector2(-2, 6), w + Vector2(9, -8), red, 2.5)
			Ink.text(self, _hand, w + Vector2(0, 22), route[i].name, 18, Color(red, 0.7))
		elif i == step and i < route.size() - 1:
			var pulse := 0.5 + 0.5 * sin(_t * 3.0)
			draw_line(w + Vector2(-10, -10), w + Vector2(10, 10), red, 3.0)
			draw_line(w + Vector2(10, -10), w + Vector2(-10, 10), red, 3.0)
			draw_arc(w, 18.0 + pulse * 3.0, 0, TAU, 28, Color(red, 0.6), 1.8, true)
			Ink.text(self, _hand, w + Vector2(0, 32), "%d. %s" % [i + 1, route[i].name], 22, red)


func _stake(p: Vector2, done: bool) -> void:
	var wood := Color(0.45, 0.3, 0.16)
	draw_line(p + Vector2(0, 8), p + Vector2(0, -10), wood, 3.0)
	draw_colored_polygon(PackedVector2Array([p + Vector2(0, -10), p + Vector2(10, -7), p + Vector2(0, -4)]), Color(0.75, 0.15, 0.1) if done else Color(0.9, 0.85, 0.7))
	draw_circle(p + Vector2(0, 9), 3.0, Color(0.2, 0.12, 0.07))
