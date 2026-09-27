extends Node2D
## A navigation beacon on an island: a dead lighthouse drawn on the chart.
## Sail close and it lights — a warm lamp and a sweeping beam. Level 2 needs
## all three lit before the pier's lamp will answer.

signal lit_up(beacon: Node2D)

@export var title := "the North Beacon"
## How close the ship must come (px).
@export var radius := 88.0

var lit := false
var ship: Node2D
var _t := 0.0
var _glow := 0.0
var _light: PointLight2D
var _hand: Font = preload("res://assets/fonts/Caveat.ttf")


func _ready() -> void:
	add_to_group("beacons")


func _process(delta: float) -> void:
	_t += delta
	if ship == null:
		ship = get_tree().get_first_node_in_group("player") as Node2D
	if not lit and ship and global_position.distance_to(ship.global_position) < radius:
		light()
	if lit:
		_glow = minf(1.0, _glow + delta * 1.2)
		if _light:
			_light.energy = 1.1 * _glow + sin(_t * 7.0) * 0.05
	queue_redraw()


func light() -> void:
	if lit:
		return
	lit = true
	_light = PointLight2D.new()
	var g := GradientTexture2D.new()
	g.width = 256
	g.height = 256
	g.fill = GradientTexture2D.FILL_RADIAL
	g.fill_from = Vector2(0.5, 0.5)
	g.fill_to = Vector2(1.0, 0.5)
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 1))
	grad.set_color(1, Color(1, 1, 1, 0))
	g.gradient = grad
	_light.texture = g
	_light.color = Color(1.0, 0.85, 0.55)
	_light.texture_scale = 2.4
	_light.energy = 0.0
	_light.position = Vector2(0, -15)
	add_child(_light)
	lit_up.emit(self)


func _draw() -> void:
	var ink := Color(0.2, 0.12, 0.07, 0.95)
	# the beam, sweeping, once lit
	if lit:
		var a := _t * 1.6
		for s: float in [0.0, PI]:
			var dir := Vector2.from_angle(a + s)
			var nrm := dir.orthogonal()
			var tip := Vector2(0, -15) + dir * 150.0
			draw_colored_polygon(PackedVector2Array([Vector2(0, -15), tip + nrm * 26.0, tip - nrm * 26.0]),
				Color(1.0, 0.9, 0.6, 0.16 * _glow))
	# the tower
	var tower := PackedVector2Array([Vector2(-8, 16), Vector2(-5, -12), Vector2(5, -12), Vector2(8, 16)])
	draw_colored_polygon(tower, Color(0.88, 0.83, 0.72, 0.97))
	tower.append(tower[0])
	draw_polyline(tower, ink, 1.8, true)
	for yy: float in [-4.0, 6.0]:
		draw_line(Vector2(-6.5, yy), Vector2(6.5, yy), Color(0.55, 0.1, 0.06), 3.0)
	# the lamp room
	var lamp := Rect2(-6, -20, 12, 8)
	draw_rect(lamp, Color(1.0, 0.82, 0.4).lerp(Color(0.12, 0.1, 0.1), 1.0 - _glow))
	draw_rect(lamp, ink, false, 1.5)
	draw_polyline(PackedVector2Array([Vector2(-8, -20), Vector2(0, -27), Vector2(8, -20)]), ink, 1.6, true)
	if lit:
		draw_circle(Vector2(0, -16), 9.0 + sin(_t * 5.0), Color(1.0, 0.85, 0.5, 0.35 * _glow))
	else:
		# unlit: a pulsing pencil ring saying "come here"
		var r := 30.0 + sin(_t * 2.5) * 3.0
		draw_arc(Vector2(0, -2), r, 0, TAU, 40, Color(0.6, 0.08, 0.05, 0.5), 1.6, true)
	Ink.text(self, _hand, Vector2(0, 34), title + (" — lit" if lit else ""), 20,
		Color(0.6, 0.08, 0.05, 0.95) if not lit else Color(0.25, 0.15, 0.08, 0.9))
