extends Node2D
## The dashed red line of the route actually walked, inked as you go.

@export var color := Color(0.62, 0.12, 0.08, 0.75)
@export var width := 2.2
@export var dash := 7.0
@export var gap := 6.0
@export var max_segments := 6000

var _segs := PackedVector2Array()
var _last := Vector2.INF
var _acc := 0.0
var _pen_down := true
var _dash_start := Vector2.ZERO


func add_point(p: Vector2) -> void:
	if _last == Vector2.INF:
		_last = p
		_dash_start = p
		return
	var d := _last.distance_to(p)
	if d < 0.5:
		return
	_acc += d
	var limit := dash if _pen_down else gap
	if _acc >= limit:
		if _pen_down:
			_segs.append(_dash_start)
			_segs.append(p)
			if _segs.size() > max_segments * 2:
				_segs = _segs.slice(2)
		_pen_down = not _pen_down
		_acc = 0.0
		_dash_start = p
		queue_redraw()
	_last = p


func _draw() -> void:
	if _segs.size() >= 2:
		draw_multiline(_segs, color, width)
