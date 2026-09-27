@tool
class_name MapNote
extends Node2D
## A handwritten annotation on the map. Drag these around in the editor.
##
## Styles:
##   NOTE     — the cartographer's own pencil notes
##   REGION   — spaced-out place names in italic capitals
##   OMINOUS  — writing that isn't his. Stays invisible until the player
##              comes within `reveal_radius`, then bleeds onto the page.
##   SKULL    — a skull he doesn't remember drawing (also revealed on approach)
##   TENTACLE — a tentacle doodle (also revealed on approach)

enum Style { NOTE, REGION, OMINOUS, SKULL, TENTACLE }

@export_multiline var text := "note":
	set(v):
		text = v
		queue_redraw()
@export var style: Style = Style.NOTE:
	set(v):
		style = v
		queue_redraw()
@export var font_size := 24:
	set(v):
		font_size = v
		queue_redraw()
@export var color_override := Color(0, 0, 0, 0):
	set(v):
		color_override = v
		queue_redraw()
## For OMINOUS / TENTACLE: how close (px) the player must get. 0 = always shown.
@export var reveal_radius := 150.0

var _hand: Font = preload("res://assets/fonts/Caveat.ttf")
var _italic: Font = preload("res://assets/fonts/IMFellEnglish-Italic.ttf")
var _reveal := 1.0
var _revealed := false
var _t := 0.0
var _player: Node2D


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	if _hidden_style() and reveal_radius > 0.0:
		_reveal = 0.0
	set_process(true)


func _hidden_style() -> bool:
	return style == Style.OMINOUS or style == Style.TENTACLE or style == Style.SKULL


var _chart: Node
var _chart_checked := false


func _process(delta: float) -> void:
	_t += delta
	# his own notes only appear once their place has been charted
	if style == Style.NOTE or style == Style.REGION:
		if not _chart_checked:
			_chart_checked = true
			_chart = get_tree().get_first_node_in_group("chart_reveal")
		if _chart:
			var want := 1.0 if _chart.amount_at(global_position) > 0.45 else 0.0
			modulate.a = move_toward(modulate.a, want, delta * 1.2)
		else:
			set_process(false)
		return
	if not _revealed:
		if _player == null:
			_player = get_tree().get_first_node_in_group("player") as Node2D
		if _player and _player.global_position.distance_to(global_position) < reveal_radius:
			_revealed = true
	if _revealed and _reveal < 1.0:
		_reveal = minf(1.0, _reveal + delta / 2.2)
	if _reveal > 0.0:
		queue_redraw()


func _draw() -> void:
	match style:
		Style.NOTE:
			var col := color_override if color_override.a > 0.0 else Color(0.25, 0.15, 0.08, 0.9)
			Ink.multiline(self, _hand, Vector2.ZERO, text, font_size, col, 0.0, 0.7)
		Style.REGION:
			var col := color_override if color_override.a > 0.0 else Color(0.25, 0.15, 0.08, 0.62)
			Ink.multiline(self, _italic, Vector2.ZERO, _spaced(text.to_upper()), font_size, col, 0.0, 0.55)
		Style.OMINOUS:
			if _reveal <= 0.0:
				return
			var col := color_override if color_override.a > 0.0 else Color(0.42, 0.04, 0.05, 0.92)
			var a := _ease(_reveal)
			# bleeding in: a blurry halo that tightens into letters
			for k in 3:
				var jit := Vector2(sin(_t * 13.0 + k * 2.0), cos(_t * 11.0 + k)) * (1.0 - a) * 4.0
				Ink.multiline(self, _hand, jit, text, font_size, Color(col, col.a * a * 0.25))
			var shiver := Vector2(sin(_t * 23.0), cos(_t * 19.0)) * 0.6
			Ink.multiline(self, _hand, shiver, text, font_size, Color(col, col.a * a), 0.0, 0.45 * a)
		Style.SKULL:
			if _reveal <= 0.0:
				return
			_draw_skull(_ease(_reveal))
		Style.TENTACLE:
			if _reveal <= 0.0:
				return
			_draw_tentacle(_ease(_reveal))


static func _spaced(s: String) -> String:
	var out := ""
	for i in s.length():
		out += s[i]
		if i < s.length() - 1 and s[i] != "\n" and s[i + 1] != "\n":
			out += " "
	return out


static func _ease(x: float) -> float:
	return x * x * (3.0 - 2.0 * x)


## A curling tentacle sketched in ink, drawn from the base upward.
func _draw_tentacle(a: float) -> void:
	var col := color_override if color_override.a > 0.0 else Color(0.2, 0.12, 0.1, 0.8)
	var n := 28
	var shown := int(n * a)
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	var sway := sin(_t * 0.9) * 0.15
	for i in shown + 1:
		var t := float(i) / n
		var ang := -PI / 2.0 + sin(t * 5.0 + sway) * 0.9 * t + t * t * 2.6
		var p := Vector2(sin(t * 4.0 + sway) * 14.0 * t, -t * 70.0) + Vector2.from_angle(ang) * t * t * 18.0
		var w := (1.0 - t) * 7.0 + 0.8
		var nrm := Vector2.from_angle(ang + PI / 2.0)
		left.append(p + nrm * w)
		right.append(p - nrm * w)
		if i % 3 == 1 and t < 0.85:
			draw_circle(p + nrm * w * 0.4, w * 0.25, Color(col, col.a * 0.6))
	if left.size() > 1:
		draw_polyline(left, col, 1.4, true)
		draw_polyline(right, col, 1.4, true)


## A skull inked in dark red, as if something marked this spot as a grave.
## Appears stroke by stroke as `a` goes 0 → 1.
func _draw_skull(a: float) -> void:
	var col := color_override if color_override.a > 0.0 else Color(0.36, 0.05, 0.04, 0.9)
	var fill := Color(0.93, 0.87, 0.74, 0.85 * a)
	var k := float(font_size) / 24.0
	var shiver := Vector2(sin(_t * 17.0), cos(_t * 13.0)) * 0.5
	draw_set_transform(shiver, 0.0, Vector2(k, k))
	if a > 0.85:
		# crossed bones behind
		var b := clampf((a - 0.85) / 0.15, 0.0, 1.0)
		for s in [-1.0, 1.0]:
			var p0 := Vector2(-22 * s, 26)
			var p1 := Vector2(22 * s, 8)
			draw_line(p0, p0.lerp(p1, b), Color(col, col.a * 0.8), 3.0, true)
			draw_circle(p0, 2.6, Color(col, col.a * 0.8))
	# cranium
	var head := PackedVector2Array()
	for i in 25:
		var ang := PI + PI * i / 24.0
		head.append(Vector2(cos(ang) * 16.0, sin(ang) * 15.0 - 2.0))
	head.append(Vector2(13, 6))
	head.append(Vector2(9, 12))
	head.append(Vector2(-9, 12))
	head.append(Vector2(-13, 6))
	var n := int(head.size() * clampf(a * 1.6, 0.0, 1.0))
	if a > 0.6:
		draw_colored_polygon(head, fill)
	if n > 1:
		draw_polyline(head.slice(0, n), col, 1.8, true)
	if a > 0.62:
		draw_line(head[head.size() - 1], head[0], col, 1.8, true)
	if a > 0.45:
		# eye sockets and nose
		var e := clampf((a - 0.45) / 0.3, 0.0, 1.0)
		for s in [-1.0, 1.0]:
			draw_circle(Vector2(s * 6.0, 0.0), 4.2 * e, Color(col, col.a * e))
		draw_colored_polygon(PackedVector2Array([Vector2(0, 4), Vector2(-2.2, 8), Vector2(2.2, 8)]), Color(col, col.a * e))
	if a > 0.7:
		# jaw and teeth
		var j := clampf((a - 0.7) / 0.3, 0.0, 1.0)
		var jaw := PackedVector2Array([Vector2(-9, 12), Vector2(-8, 18), Vector2(8, 18), Vector2(9, 12)])
		draw_colored_polygon(jaw, Color(fill, fill.a * j))
		draw_polyline(jaw, Color(col, col.a * j), 1.6, true)
		for t in 4:
			var x := -6.0 + t * 4.0
			draw_line(Vector2(x, 12), Vector2(x, 17), Color(col, col.a * j), 1.1)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
