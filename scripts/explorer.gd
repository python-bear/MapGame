extends Node2D
## The cartographer, seen from above: pith helmet, pack, notebook.
## Moves over a MapGrid with terrain speed and elevation rules, and leaves a
## dashed red route behind him like a line drawn on the map.

signal moved(pos: Vector2)

@export var base_speed := 115.0
## Half the size of the collision square (cells are 32px).
@export var half_size := 7.0
@export var route_path: NodePath

var grid: MapGrid
var frozen := false
## Holding up the map (Tab): he stands still to study it.
var studying := false

var _speed_mult := 1.0
var _facing := Vector2.DOWN
var _walk := 0.0
var _moving := false
var _route: Node


func _ready() -> void:
	add_to_group("player")
	scale = Vector2(1.25, 1.25)  # drawn a touch larger than his hitbox
	if route_path:
		_route = get_node_or_null(route_path)


func _physics_process(delta: float) -> void:
	if grid == null:
		return
	var input := Vector2.ZERO
	if not frozen and not studying:
		input = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	_moving = input.length() > 0.1
	if _moving:
		Game.begin_level_timer()
		_facing = _facing.slerp(input.normalized(), 1.0 - exp(-14.0 * delta))
	var target_mult := grid.speed_at(position)
	if target_mult <= 0.0:
		target_mult = 1.0
	_speed_mult = lerpf(_speed_mult, target_mult, 1.0 - exp(-10.0 * delta))
	var step := input * base_speed * _speed_mult * delta
	var before := position
	_move_axis(Vector2(step.x, 0.0))
	_move_axis(Vector2(0.0, step.y))
	var moved_by := position.distance_to(before)
	if moved_by > 0.01:
		_walk += moved_by * 0.35
		if _route:
			_route.add_point(position)
		moved.emit(position)
	queue_redraw()


## Move along one axis; if blocked, try to slip around the corner so
## narrow bridges and stairs don't feel sticky.
func _move_axis(d: Vector2) -> void:
	if d == Vector2.ZERO:
		return
	var from := grid.cell_of(position)
	if grid.body_fits(position + d, half_size, from):
		position += d
		return
	var perp := Vector2(d.y, d.x).normalized()
	var push := d.length()
	for off in [3.0, 6.0, 9.0, 12.0]:
		for s in [1.0, -1.0]:
			var nudge: Vector2 = perp * off * s
			if grid.body_fits(position + nudge + d, half_size, from) and grid.body_fits(position + perp * s * push, half_size, from):
				position += perp * s * push
				return


func _draw() -> void:
	var bob := sin(_walk) * (1.0 if _moving else 0.0)
	var ink := Color(0.16, 0.09, 0.05)
	var side := Vector2(-_facing.y, _facing.x)
	# shadow
	draw_set_transform(Vector2(2, 4), 0.0, Vector2(1.0, 0.6))
	draw_circle(Vector2.ZERO, 11.0, Color(0.1, 0.06, 0.03, 0.28))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# legs/boots peeking out while walking
	for s in [-1.0, 1.0]:
		var stride := _facing * sin(_walk + (0.0 if s > 0 else PI)) * 4.0 * (1.0 if _moving else 0.0)
		draw_circle(side * 4.0 * s + stride + _facing * 2.0, 2.6, Color(0.3, 0.2, 0.12))
	# pack on his back
	var pack := -_facing * 7.0
	draw_set_transform(pack, _facing.angle(), Vector2.ONE)
	draw_rect(Rect2(-4, -6, 8, 12), Color(0.45, 0.32, 0.18))
	draw_rect(Rect2(-4, -6, 8, 12), ink, false, 1.2)
	draw_line(Vector2(-2, -6), Vector2(-2, 6), Color(ink, 0.5), 1.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# shoulders
	draw_circle(Vector2.ZERO + _facing * bob * 0.3, 7.5, Color(0.62, 0.55, 0.38))
	draw_arc(Vector2.ZERO + _facing * bob * 0.3, 7.5, 0.0, TAU, 20, ink, 1.3, true)
	# notebook held out in front
	var nb := _facing * 9.0 + side * 3.0
	draw_set_transform(nb, _facing.angle(), Vector2.ONE)
	draw_rect(Rect2(-2.5, -3.5, 5, 7), Color(0.95, 0.9, 0.78))
	draw_rect(Rect2(-2.5, -3.5, 5, 7), ink, false, 1.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# pith helmet: brim and crown
	var hp := _facing * 1.5
	draw_circle(hp, 8.5, Color(0.86, 0.79, 0.6))
	draw_arc(hp, 8.5, 0.0, TAU, 24, ink, 1.4, true)
	draw_circle(hp + _facing * 0.8, 5.0, Color(0.93, 0.88, 0.72))
	draw_arc(hp + _facing * 0.8, 5.0, 0.0, TAU, 18, Color(ink, 0.8), 1.1, true)
	draw_arc(hp + _facing * 0.8, 5.0, _facing.angle() - 0.9, _facing.angle() + 0.9, 8, Color(0.4, 0.28, 0.16), 2.0, true)
