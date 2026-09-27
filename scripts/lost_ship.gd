extends Node2D
## A ship adrift, lanterns out, nobody at the wheel. Sail alongside and your
## crew fires a signal: something answers. (Optional in Level 2.)
## `reward` is what the level gives for it: "route", "story" or "message".

signal signalled(ship: Node2D)

@export var title := "the Albatross"
@export var reward := "story"
@export var radius := 64.0

var done := false
var level: Node
var _t := 0.0
var _rocket := 0.0
var _hand: Font = preload("res://assets/fonts/Caveat.ttf")


func _ready() -> void:
	_t = randf() * 5.0


func _process(delta: float) -> void:
	_t += delta
	var reveal: Node = level._reveal if level and "_reveal" in level else null
	# drawn only where the chart is charted — you find them, you don't see them
	var seen: float = reveal.amount_at(global_position) if reveal else 1.0
	modulate.a = move_toward(modulate.a, 1.0 if seen > 0.3 or done else 0.0, delta * 1.5)
	if not done and level and level.ship and global_position.distance_to(level.ship.global_position) < radius:
		done = true
		create_tween().tween_property(self, "_rocket", 1.0, 1.4)
		signalled.emit(self)
	queue_redraw()


func _draw() -> void:
	var ink := Color(0.18, 0.1, 0.07, 0.9)
	var bob := sin(_t * 1.3) * 0.08
	draw_set_transform(Vector2.ZERO, 0.5 + bob, Vector2.ONE)
	var hull := PackedVector2Array([Vector2(-18, 0), Vector2(-11, 7), Vector2(13, 6), Vector2(20, 0), Vector2(13, -6), Vector2(-11, -7)])
	draw_colored_polygon(hull, Color(0.38, 0.28, 0.2, 0.9))
	hull.append(hull[0])
	draw_polyline(hull, ink, 1.5, true)
	draw_line(Vector2(-3, 0), Vector2(8, 0), ink, 1.2)
	# a torn sail hanging off the mast
	draw_colored_polygon(PackedVector2Array([Vector2(0, -2), Vector2(9, -10), Vector2(5, 3)]), Color(0.85, 0.8, 0.7, 0.8))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if done:
		# the signal rocket and its red star
		var h := _rocket * 90.0
		draw_line(Vector2(0, -4), Vector2(0, -4 - h), Color(0.9, 0.6, 0.3, 0.6 * (1.0 - _rocket * 0.5)), 1.5)
		if _rocket >= 1.0:
			var a := 0.6 + 0.4 * sin(_t * 6.0)
			draw_circle(Vector2(0, -94), 5.0, Color(0.95, 0.25, 0.15, a))
			draw_arc(Vector2(0, -94), 11.0, 0, TAU, 20, Color(0.95, 0.35, 0.2, a * 0.5), 1.5, true)
	var ring := Color(0.25, 0.15, 0.08, 0.85) if done else Color(0.6, 0.08, 0.05, 0.8)
	Ink.text(self, _hand, Vector2(0, 26), title + (" — answered" if done else " — adrift"), 18, ring)
