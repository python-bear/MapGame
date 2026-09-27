extends Control
## Backstory card shown before Level 1. Any "skip" input advances; holding it
## (or pressing it on the last line) jumps straight into the level.

const LINES := [
	"Two days into the jungle, the porters stopped singing.",
	"We made camp where the river bends. While the others slept,\nI sat by the fire and inked what we had walked that day —\nevery ridge, every ford, every rotten bridge.",
	"The guide would not tell me what lay past the plateau.\nHe only tapped the blank edge of my map, and shook his head.",
	"The fire burned low. The pen grew heavy.\nI remember thinking, just one more line…",
	"…and I was at sea again, the night we made the crossing,\nthe chart spread out under the lantern —\nand then the map was all there was.",
]

var _hand: Font = preload("res://assets/fonts/Caveat.ttf")
var _index := 0
var _label: Label
var _hint: Label
var _time := 0.0
var _busy := false
var _done := false
var _hold := 0.0


func _ready() -> void:
	add_to_group("cutscene")          # Game keeps the (paused) timer on screen
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_label = Label.new()
	_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_font_override("font", _hand)
	_label.add_theme_font_size_override("font_size", 40)
	_label.add_theme_color_override("font_color", Color(0.95, 0.84, 0.62))
	_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	_label.add_theme_constant_override("shadow_offset_y", 3)
	_label.modulate.a = 0.0
	add_child(_label)
	_hint = Label.new()
	_hint.text = "space / enter  —  continue          hold  —  skip"
	_hint.add_theme_font_size_override("font_size", 18)
	_hint.add_theme_color_override("font_color", Color(0.8, 0.65, 0.45, 0.45))
	_hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_hint.position.y -= 50
	_hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
	add_child(_hint)
	_show_line(0)


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()
	if Input.is_action_pressed("skip") and _time > 0.8:
		_hold += delta
		if _hold > 0.6:
			_finish()
	else:
		_hold = 0.0


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("skip") or (event is InputEventMouseButton and event.pressed):
		get_viewport().set_input_as_handled()
		if _busy:
			return
		if _index >= LINES.size() - 1:
			_finish()
		else:
			_show_line(_index + 1)


func _show_line(i: int) -> void:
	_busy = true
	_index = i
	var tw := create_tween()
	if _label.modulate.a > 0.0:
		tw.tween_property(_label, "modulate:a", 0.0, 0.35)
	tw.tween_callback(func(): _label.text = LINES[i])
	tw.tween_property(_label, "modulate:a", 1.0, 0.9)
	tw.tween_callback(func(): _busy = false)


func _finish() -> void:
	if _done:
		return
	_done = true
	Game.start_level(0)


## Campfire glow and a few embers.
func _draw() -> void:
	var s := size
	draw_rect(Rect2(Vector2.ZERO, s), Color(0.04, 0.03, 0.025))
	var c := Vector2(s.x / 2.0, s.y + 40.0)
	var flick := 0.85 + 0.15 * sin(_time * 9.0) * sin(_time * 5.3 + 1.0)
	var dim := 1.0 - float(_index) / float(LINES.size()) * 0.6
	for k in 48:
		var r := (48 - k) * 14.5 * flick
		draw_circle(c, r, Color(0.9, 0.42, 0.12, 0.011 * dim))
	for e in 14:
		var sd := float(e) * 13.7
		var life := fmod(_time * (0.25 + Ink.hash2(sd, 1.0) * 0.3) + Ink.hash2(sd, 2.0), 1.0)
		var x := c.x + (Ink.hash2(sd, 3.0) - 0.5) * 260.0 + sin(_time * 2.0 + sd) * 20.0 * life
		var y := c.y - 60.0 - life * 380.0
		draw_circle(Vector2(x, y), 3.2 * (1.0 - life), Color(1.0, 0.6, 0.2, (1.0 - life) * 0.8 * dim))
