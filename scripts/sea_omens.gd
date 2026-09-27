extends Node2D
## The first half-minute of Level 2: nothing obvious. Strange rings on the
## water, and now and then something long and dark sliding under the ship.

var ship: Node2D
var _ripples: Array = []     ## {p, r, a}
var _shadow := {}            ## {p, dir, t, len}
var _t := 0.0


func ripple(at: Vector2) -> void:
	_ripples.append({"p": at, "r": 2.0, "a": 0.9})
	_ripples.append({"p": at, "r": -6.0, "a": 0.9})


## Something passes beneath the hull.
func shadow_pass() -> void:
	if ship == null:
		return
	var dir := Vector2.from_angle(randf() * TAU)
	_shadow = {"p": ship.global_position - dir * 260.0, "dir": dir, "t": 0.0, "len": randf_range(150.0, 210.0)}


func _process(delta: float) -> void:
	_t += delta
	for r in _ripples:
		r.r += delta * 22.0
		r.a -= delta * 0.45
	_ripples = _ripples.filter(func(r): return r.a > 0.0)
	if not _shadow.is_empty():
		_shadow.t += delta
		_shadow.p += _shadow.dir * 130.0 * delta
		if _shadow.t > 4.2:
			_shadow = {}
	queue_redraw()


func _draw() -> void:
	for r in _ripples:
		if r.r > 0.0:
			draw_arc(r.p, r.r, 0, TAU, 28, Color(0.85, 0.92, 0.96, r.a * 0.55), 1.3, true)
	if _shadow.is_empty():
		return
	var fade := clampf(minf(_shadow.t, 4.2 - _shadow.t) / 1.0, 0.0, 1.0)
	var d: Vector2 = _shadow.dir
	var n := d.orthogonal()
	var L: float = _shadow.len
	var body := PackedVector2Array()
	for i in 24:
		var s := float(i) / 23.0
		var w := sin(s * PI) * 30.0 * (1.0 - s * 0.5)
		body.append(_shadow.p + d * (0.5 - s) * L + n * w * (1.0 + 0.1 * sin(_t * 4.0 + s * 8.0)))
	for i in range(23, -1, -1):
		var s := float(i) / 23.0
		var w := sin(s * PI) * 30.0 * (1.0 - s * 0.5)
		body.append(_shadow.p + d * (0.5 - s) * L - n * w * (1.0 + 0.1 * sin(_t * 4.0 + s * 8.0)))
	draw_colored_polygon(body, Color(0.0, 0.02, 0.04, 0.28 * fade))
	# a long trailing limb
	var tail := PackedVector2Array()
	for i in 10:
		var s := float(i) / 9.0
		tail.append(_shadow.p - d * (0.5 * L + s * 120.0) + n * sin(_t * 3.0 + s * 5.0) * 18.0 * s)
	draw_polyline(tail, Color(0.0, 0.02, 0.04, 0.22 * fade), 9.0, true)
