extends Node2D
## A bridge he draws with the last of his ink — and in the dream, what he
## draws is real. Drawn plank by plank in fresh, dark ink.

var a := Vector2.ZERO       ## world start (bank)
var b := Vector2.ZERO       ## world end (far bank)
var _k := 0.0


func _ready() -> void:
	z_index = 2
	var tw := create_tween()
	tw.tween_property(self, "_k", 1.0, 0.9).set_trans(Tween.TRANS_SINE)


func _process(_delta: float) -> void:
	if _k < 1.0:
		queue_redraw()


func _draw() -> void:
	var ink := Color(0.07, 0.06, 0.14, 0.95)
	var along := (b - a).normalized()
	var across := along.orthogonal() * 11.0
	var end := a.lerp(b, _k)
	var n := int(a.distance_to(end) / 6.0)
	for i in n + 1:
		var p := a + along * i * 6.0
		var j := (Ink.hash2(p.x, p.y) - 0.5) * 2.0
		draw_line(p - across + along * j, p + across - along * j, Color(0.42, 0.3, 0.22, 0.95), 3.2, true)
		draw_line(p - across + along * j, p + across - along * j, Color(ink, 0.35), 1.0, true)
	for s in [-1.0, 1.0]:
		Ink.line(self, a + across * 1.15 * s, end + across * 1.15 * s, ink, 1.8, 0.8)
	draw_circle(a + across * 1.15, 2.6, ink)
	draw_circle(a - across * 1.15, 2.6, ink)
	if _k >= 1.0:
		draw_circle(b + across * 1.15, 2.6, ink)
		draw_circle(b - across * 1.15, 2.6, ink)
	else:
		# the pen nib, still drawing
		draw_colored_polygon(PackedVector2Array([end + Vector2(0, -2), end + Vector2(10, -16), end + Vector2(14, -12)]), ink)
