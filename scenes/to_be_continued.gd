extends Control
## Shown when the next level's scene doesn't exist yet.

var _hand: Font = preload("res://assets/fonts/Caveat.ttf")
var _t := 0.0

## What waits beyond the last finished level, keyed by that level's index.
const TEASERS := {
	0: "The ink runs wet. The lines begin to drift,\nand somewhere beneath the paper, something vast turns over in the deep…",
	1: "He climbs the ladder onto the pier. The street beyond is his own street —\nbut every window is dark, and the people standing in them are not people any more…",
	2: "There is no map for what comes next.",
}


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 18)
	add_child(box)
	Music.play_set("level2")
	Music.set_danger(0.0)
	var msg := Label.new()
	msg.text = TEASERS.get(Game.current_level, TEASERS[0])
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.add_theme_font_override("font", _hand)
	msg.add_theme_font_size_override("font_size", 38)
	msg.add_theme_color_override("font_color", Color(0.78, 0.86, 0.9))
	box.add_child(msg)
	var sub := Label.new()
	sub.text = "The rest of the dream is still being drawn."
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 24)
	sub.add_theme_color_override("font_color", Color(0.6, 0.7, 0.75, 0.8))
	box.add_child(sub)
	if Game.show_timer and Game.full_run:
		var t := Label.new()
		t.text = "run time  " + Game.format_time(Game.run_time)
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		t.add_theme_font_size_override("font_size", 28)
		t.add_theme_color_override("font_color", Color(0.85, 0.9, 0.92))
		box.add_child(t)
	var btn := Button.new()
	btn.text = "Wake (return to title)"
	btn.add_theme_color_override("font_color", Color(0.8, 0.88, 0.92))
	btn.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	btn.add_theme_color_override("font_focus_color", Color(1, 1, 1))
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.pressed.connect(Game.go_to_menu)
	box.add_child(btn)
	btn.grab_focus()


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.03, 0.06, 0.09))
	for k in 9:
		var pts := PackedVector2Array()
		var y0 := size.y * (0.1 + k * 0.1)
		for i in 65:
			var x := size.x * i / 64.0
			pts.append(Vector2(x, y0 + sin(x * 0.01 + _t * 0.7 + k) * 10.0 + sin(x * 0.023 - _t * 0.4) * 6.0))
		draw_polyline(pts, Color(0.35, 0.55, 0.65, 0.12), 1.5, true)
