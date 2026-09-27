extends Node2D
## Currents in the Open Deep. Each lane is a polyline (in cells) that the sea
## flows along. Some speed you east towards the shoals; one runs the wrong way.
## They're only drawn where the chart has been charted — so a flare fired over
## the deep can show you a fast lane you'd never have found.

@export var lanes: Array[PackedVector2Array] = []
@export var width_cells := 1.8
@export var strength := 115.0          ## px/s at the centre of a lane

var reveal: Node                        ## ChartReveal
var _t := 0.0
const C := 32.0


## The push the sea gives at world position `p`.
func flow_at(p: Vector2) -> Vector2:
	var best := Vector2.ZERO
	for lane in lanes:
		for i in lane.size() - 1:
			var a := lane[i] * C
			var b := lane[i + 1] * C
			var q := Geometry2D.get_closest_point_to_segment(p, a, b)
			var d := p.distance_to(q) / C
			if d < width_cells:
				var push := (b - a).normalized() * strength * (1.0 - d / width_cells)
				if push.length() > best.length():
					best = push
	return best


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var ink := Color(0.14, 0.26, 0.4)
	for lane in lanes:
		for i in lane.size() - 1:
			var a := lane[i] * C
			var b := lane[i + 1] * C
			var dir := (b - a).normalized()
			var nrm := dir.orthogonal()
			var length := a.distance_to(b)
			var step := 46.0
			var off := fmod(_t * 40.0, step)
			var s := off
			while s < length:
				var p := a + dir * s
				var alpha: float = reveal.amount_at(p) if reveal else 1.0
				if alpha > 0.05:
					for k in [-1.0, 0.0, 1.0]:
						var c: Vector2 = p + nrm * k * 16.0 - dir * absf(k) * 6.0
						var col := Color(ink, 0.55 * alpha)
						draw_line(c - dir * 7.0 + nrm * 5.0, c, col, 2.0, true)
						draw_line(c - dir * 7.0 - nrm * 5.0, c, col, 2.0, true)
					# a long wavy stroke along the flow
					var pts := PackedVector2Array()
					for j in 7:
						var tt := j / 6.0
						pts.append(p - dir * 20.0 + dir * 30.0 * tt + nrm * sin(tt * TAU + _t * 3.0) * 2.5 + nrm * 26.0)
					draw_polyline(pts, Color(ink, 0.3 * alpha), 1.2, true)
				s += step
