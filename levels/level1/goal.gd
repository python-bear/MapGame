extends Node2D
## "Where the ink ends": the edge of what he has mapped. Walk into it to
## finish the level. Afterwards `bloom` spreads a pool of wet ink outwards.

signal reached

@export var trigger_radius := 22.0
## Only counts once the expedition has reached this step.
var active := true:
	set(v):
		active = v
		queue_redraw()
## Drawn as a camp (for the return leg) instead of the "?" of the unmapped.
var camp_mode := false
## What the camp circle is labelled (it becomes "the cave").
var camp_label := "camp":
	set(v):
		camp_label = v
		queue_redraw()
## The pool of ink that spreads when the level is left.
var bloom_color := Color(0.05, 0.1, 0.16)
var bloom_rim := Color(0.12, 0.28, 0.4)

var bloom := 0.0:
	set(v):
		bloom = v
		queue_redraw()

var _t := 0.0
var _done := false
var _player: Node2D
var _hand: Font = preload("res://assets/fonts/Caveat.ttf")


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()
	if _done:
		return
	if _player == null:
		_player = get_tree().get_first_node_in_group("player") as Node2D
	if active and _player and _player.global_position.distance_to(global_position) < trigger_radius:
		_done = true
		reached.emit()


func rearm() -> void:
	_done = false


func _draw() -> void:
	var pulse := 0.5 + 0.5 * sin(_t * 2.4)
	var red := Color(0.6, 0.1, 0.07, 0.85 if active else 0.3)
	if camp_mode:
		for i in 16:
			var a0 := TAU * i / 16 + _t * 0.3
			draw_arc(Vector2.ZERO, 44.0 + pulse * 3.0, a0, a0 + TAU / 16 * 0.55, 5, red, 2.4, true)
		Ink.text(self, _hand, Vector2(0, 60 if camp_label == "camp" else -74), camp_label, 28, Color(0.45, 0.08, 0.05, 0.9))
		if bloom > 0.0:
			_draw_bloom()
		return
	# dashed circle, slowly turning
	var n := 16
	for i in n:
		var a0 := TAU * i / n + _t * 0.3
		draw_arc(Vector2.ZERO, 26.0 + pulse * 3.0, a0, a0 + TAU / n * 0.55, 5, red, 2.0, true)
	# the unfinished pencil strokes trailing off into blank paper
	var pencil := Color(0.3, 0.25, 0.2, 0.35)
	for k in 5:
		var a := -0.9 + k * 0.45
		var p0 := Vector2.from_angle(a) * 34.0
		var p1 := p0 + Vector2.from_angle(a + sin(k * 3.1) * 0.3) * (30.0 + k * 9.0)
		draw_line(p0, p1, Color(pencil, pencil.a * (1.0 - k * 0.12)), 1.2, true)
	Ink.text(self, _hand, Vector2(0, 1), "?", 40, Color(0.35, 0.08, 0.05, 0.6 + pulse * 0.4))
	if bloom > 0.0:
		_draw_bloom()


func _draw_bloom() -> void:
	var r := bloom * 2200.0
	var pts := PackedVector2Array()
	var steps := 72
	for i in steps:
		var a := TAU * i / steps
		var wob := 1.0 + 0.18 * sin(a * 5.0 + _t * 1.5) + 0.1 * sin(a * 11.0 - _t * 2.0)
		pts.append(Vector2.from_angle(a) * r * wob)
	draw_colored_polygon(pts, Color(bloom_color, clampf(bloom * 3.0, 0.0, 0.96)))
	var rim := pts.duplicate()
	rim.append(pts[0])
	draw_polyline(rim, Color(bloom_rim, 0.6), 3.0, true)
