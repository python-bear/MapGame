extends Node2D
## A signal flare: arcs from the ship to `target`, bursts, lights the sea for a
## few seconds and charts a wide circle of the map. Its light also wakes
## something below — the level listens for `burst`.

signal burst(at: Vector2)

@export var flight_time := 0.55
@export var chart_radius := 11.0       ## cells
@export var light_time := 4.5

var from := Vector2.ZERO
var target := Vector2.ZERO
var reveal: ChartReveal

var _t := 0.0
var _burst := false
var _light: PointLight2D
var _sparks: Array = []


func _ready() -> void:
	position = from
	z_index = 20
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
	grad.add_point(0.55, Color(1, 1, 1, 0.5))
	g.gradient = grad
	_light.texture = g
	_light.color = Color(1.0, 0.45, 0.35)
	_light.energy = 0.6
	_light.texture_scale = 0.6
	add_child(_light)
	Music.sfx("flare", 0.9)


func _process(delta: float) -> void:
	_t += delta
	if not _burst:
		var k := clampf(_t / flight_time, 0.0, 1.0)
		position = from.lerp(target, k)
		if k >= 1.0:
			_do_burst()
	else:
		var life := _t - flight_time
		var fade := clampf(1.0 - (life - light_time * 0.6) / (light_time * 0.4), 0.0, 1.0)
		_light.energy = 0.75 * fade * (0.9 + 0.1 * sin(_t * 23.0))
		_light.texture_scale = lerpf(_light.texture_scale, 6.5, 1.0 - exp(-6.0 * delta))
		# the ink spreads outwards with the light
		if reveal and life < 0.8:
			reveal.reveal(position, chart_radius * clampf(life / 0.6, 0.15, 1.0))
		for s in _sparks:
			s.p += s.v * delta
			s.v *= 0.94
			s.a -= delta * 0.6
		if life > light_time:
			queue_free()
	queue_redraw()


func _do_burst() -> void:
	_burst = true
	_light.color = Color(1.0, 0.72, 0.55)
	for i in 26:
		var a := randf() * TAU
		_sparks.append({"p": Vector2.ZERO, "v": Vector2.from_angle(a) * randf_range(60.0, 180.0), "a": 1.0})
	burst.emit(position)


func _draw() -> void:
	if not _burst:
		# the rising flare: an arc (drawn as a shrinking/growing dot) with a smoke tail
		var k := clampf(_t / flight_time, 0.0, 1.0)
		var lift := sin(k * PI) * 18.0
		draw_circle(Vector2(0, -lift), 4.0, Color(1.0, 0.55, 0.4))
		draw_circle(Vector2(0, -lift), 8.0, Color(1.0, 0.4, 0.3, 0.3))
		var back := (from - target).normalized() * 16.0
		draw_line(Vector2(0, -lift), back, Color(0.8, 0.75, 0.7, 0.4), 3.0, true)
	else:
		var life := _t - flight_time
		var fade := clampf(1.0 - life / light_time, 0.0, 1.0)
		draw_circle(Vector2.ZERO, 5.0 * fade + 1.0, Color(1.0, 0.85, 0.7, fade))
		for s in _sparks:
			if s.a > 0.0:
				draw_circle(s.p, 1.8, Color(1.0, 0.7, 0.4, s.a))
		if life < 0.5:
			draw_arc(Vector2.ZERO, life * 260.0, 0, TAU, 48, Color(1, 0.9, 0.8, (0.5 - life) * 1.6), 2.0, true)
