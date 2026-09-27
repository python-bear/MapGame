extends Node2D
## The first half-minute of the crossing: nothing obvious. Strange rings on the
## water, spreading and fading.

var ship: Node2D
var _ripples: Array = []     ## {p, r, a}


func ripple(at: Vector2) -> void:
	_ripples.append({"p": at, "r": 2.0, "a": 0.9})
	_ripples.append({"p": at, "r": -6.0, "a": 0.9})


func _process(delta: float) -> void:
	if _ripples.is_empty():
		return
	for r in _ripples:
		r.r += delta * 22.0
		r.a -= delta * 0.45
	_ripples = _ripples.filter(func(r): return r.a > 0.0)
	queue_redraw()


func _draw() -> void:
	for r in _ripples:
		if r.r > 0.0:
			draw_arc(r.p, r.r, 0, TAU, 28, Color(0.85, 0.92, 0.96, r.a * 0.55), 1.3, true)
