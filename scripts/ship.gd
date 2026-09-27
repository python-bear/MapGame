extends Node2D
## The dream ship, seen from above. Steer with the movement keys: the ship
## turns towards the direction you hold and picks up speed as its bow comes
## round. Shallows slow it; land, reefs and wrecks stop it.

signal bumped(strength: float)

@export var max_speed := 180.0
@export var accel := 260.0
@export var turn_rate := 3.6            ## radians per second
@export var radius := 11.0
@export var route_path: NodePath

var grid: MapGrid
var heading := 0.0
var speed := 0.0
## An outside push (sea currents), set by the level every frame.
var drift := Vector2.ZERO
var frozen := false
var sink := 0.0:                        ## 0..1 — being dragged under
	set(v):
		sink = v
		queue_redraw()

var _knock := Vector2.ZERO
var _stun := 0.0
var _t := 0.0
var _route: Node
var _foam: Array = []                  ## [{p, a, life}] little wake strokes


func _ready() -> void:
	add_to_group("player")
	if route_path:
		_route = get_node_or_null(route_path)


func velocity() -> Vector2:
	return Vector2.from_angle(heading) * speed + _knock + (drift if not frozen else Vector2.ZERO)


## Shove the ship (tentacle slap, ghost-ship collision).
func knock(impulse: Vector2, stun := 0.4) -> void:
	_knock += impulse
	speed *= 0.3
	_stun = maxf(_stun, stun)


func _physics_process(delta: float) -> void:
	_t += delta
	if grid == null:
		return
	_stun = maxf(0.0, _stun - delta)
	var input := Vector2.ZERO
	if not frozen:
		input = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var terrain := grid.speed_at(position)
	if terrain <= 0.0:
		terrain = 1.0
	if input.length() > 0.15:
		Game.begin_level_timer()
		if _stun <= 0.0:
			var want := input.angle()
			heading = rotate_toward(heading, want, turn_rate * delta)
			var align := cos(angle_difference(heading, want))
			var target := max_speed * terrain * minf(input.length(), 1.0) * clampf(0.3 + 0.7 * align, 0.25, 1.0)
			speed = move_toward(speed, target, (accel if speed < target else accel * 0.8) * delta)
	else:
		speed = move_toward(speed, 0.0, 120.0 * delta)
	if frozen:
		speed = move_toward(speed, 0.0, 300.0 * delta)
	_knock = _knock.move_toward(Vector2.ZERO, 520.0 * delta)
	var step := velocity() * delta
	var before := position
	if not _fits(position + step):
		var moved := false
		for d: Vector2 in [Vector2(step.x, 0.0), Vector2(0.0, step.y)]:
			if d != Vector2.ZERO and _fits(position + d):
				position += d
				moved = true
		if not moved:
			if speed > 60.0:
				bumped.emit(speed / max_speed)
			speed *= 0.5
			_knock *= 0.3
		else:
			speed *= 0.985   # scraping along the coast
	else:
		position += step
	var moved_by := position.distance_to(before)
	if moved_by > 0.01 and _route:
		_route.add_point(position)
	_update_foam(delta)
	queue_redraw()


func _fits(p: Vector2) -> bool:
	if not grid.is_walkable(grid.cell_of(p)):
		return false
	for i in 8:
		var q := p + Vector2.from_angle(TAU * i / 8.0) * radius
		if not grid.is_walkable(grid.cell_of(q)):
			return false
	return true


func _update_foam(delta: float) -> void:
	for f in _foam:
		f.life -= delta
	_foam = _foam.filter(func(f): return f.life > 0.0)
	if speed > 40.0 and randf() < speed / max_speed * 0.8:
		var back := -Vector2.from_angle(heading)
		var side := Vector2(-back.y, back.x)
		for s in [-1.0, 1.0]:
			_foam.append({"p": position + back * 14.0 + side * 4.0 * s, "a": (back + side * 0.6 * s).angle(), "life": 1.2})


func _draw() -> void:
	# wake (drawn in world space, so undo our own position)
	for f in _foam:
		var p: Vector2 = f.p - position
		var a: float = f.life / 1.2
		draw_line(p, p + Vector2.from_angle(f.a) * (6.0 + (1.0 - a) * 10.0), Color(0.95, 0.97, 1.0, a * 0.8), 1.5, true)
	var k := 1.0 - sink
	if k <= 0.02:
		return
	# ripples while sinking
	if sink > 0.0:
		for r in 3:
			var rr := fmod(_t * 30.0 + r * 12.0, 36.0) + 10.0
			draw_arc(Vector2.ZERO, rr, 0, TAU, 28, Color(0.15, 0.25, 0.32, 0.5 * (1.0 - rr / 46.0)), 1.5, true)
	var ink := Color(0.14, 0.08, 0.05, k)
	draw_set_transform(Vector2.ZERO, heading + sink * 2.5, Vector2.ONE * (1.25 * (0.4 + 0.6 * k)))
	# shadow
	draw_colored_polygon(_hull(Vector2(2, 3)), Color(0.05, 0.1, 0.14, 0.25 * k))
	var hull := _hull(Vector2.ZERO)
	draw_colored_polygon(hull, Color(0.52, 0.36, 0.2, k))
	var outline := hull.duplicate()
	outline.append(hull[0])
	draw_polyline(outline, ink, 1.5, true)
	draw_line(Vector2(-12, 0), Vector2(14, 0), Color(0.3, 0.2, 0.1, 0.6 * k), 1.0)
	# sails, bellied forward
	var billow := 3.0 + minf(speed / max_speed, 1.0) * 3.0
	for mx in [7.0, -4.0]:
		var pts := PackedVector2Array()
		for i in 9:
			var t := i / 8.0
			var y := lerpf(-10.0, 10.0, t)
			pts.append(Vector2(mx + sin(t * PI) * billow, y))
		draw_colored_polygon(pts + PackedVector2Array([Vector2(mx, 10), Vector2(mx, -10)]), Color(0.93, 0.88, 0.76, 0.95 * k))
		draw_polyline(pts, ink, 1.2, true)
		draw_line(Vector2(mx, -10), Vector2(mx, 10), ink, 1.0)
		draw_circle(Vector2(mx, 0), 1.8, ink)
	# pennant
	var flap := sin(_t * 9.0) * 2.0
	draw_colored_polygon(PackedVector2Array([Vector2(-4, 0), Vector2(-13, -2 + flap), Vector2(-12, 2 + flap)]), Color(0.6, 0.1, 0.07, k))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _hull(off: Vector2) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(18, 0) + off, Vector2(10, 6.5) + off, Vector2(-8, 7.5) + off, Vector2(-15, 5) + off,
		Vector2(-15, -5) + off, Vector2(-8, -7.5) + off, Vector2(10, -6.5) + off,
	])
