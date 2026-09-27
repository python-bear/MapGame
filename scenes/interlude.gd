extends Control
## A few lines between two levels, like the intro's. Chosen by the id of the
## level just finished (Game.current_level still points at it); then on to the
## next one. Space / Enter / click to advance, hold to skip. Not timed.

const TEXTS := {
	# after the crossing
	"level2_beacons": [
		"They came ashore at the Landing and made camp above the tideline.",
		"In his dreams the maps would not let him go.\nThey had become the only thing that was real.",
		"\"Look,\" said the guide in the morning, and pointed inland.",
	],
	# after the survey, when the camp has become a cave
	"level1_expedition": [
		"That was not the journey he and his crew had taken.",
		"Where the camp had been, the ground opened into the dark,\nand cold air breathed out of it.",
		"Something eldritch was at play. And it wanted him to go down.",
	],
	"cave_hollow": [
		"Beyond the door the light was not daylight.\nIt was pale, and cold, and it came from nowhere at all.",
		"The painters had drawn the way in.\nNot one of them had drawn the way out.",
		"He felt trapped in his own mind.",
	],
}

var _hand: Font = preload("res://assets/fonts/Caveat.ttf")
var _lines: Array = []
var _index := 0
var _label: Label
var _time := 0.0
var _busy := false
var _done := false
var _hold := 0.0


func _ready() -> void:
	add_to_group("cutscene")          # Game keeps the (paused) timer on screen
	set_anchors_preset(Control.PRESET_FULL_RECT)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_lines = TEXTS.get(Game.LEVELS[Game.current_level]["id"], [])
	if _lines.is_empty():
		_finish()
		return
	_label = Label.new()
	_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_font_override("font", _hand)
	_label.add_theme_font_size_override("font_size", 40)
	_label.add_theme_color_override("font_color", Color(0.86, 0.88, 0.94))
	_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	_label.add_theme_constant_override("shadow_offset_y", 3)
	_label.modulate.a = 0.0
	add_child(_label)
	var hint := Label.new()
	hint.text = "space / enter  —  continue          hold  —  skip"
	hint.add_theme_font_size_override("font_size", 18)
	hint.add_theme_color_override("font_color", Color(0.7, 0.72, 0.8, 0.4))
	hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	hint.position.y -= 50
	hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
	add_child(hint)
	Music.sfx("hum", 0.35, 0.6)
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
		if _busy or _done:
			return
		if _index >= _lines.size() - 1:
			_finish()
		else:
			_show_line(_index + 1)


func _show_line(i: int) -> void:
	_busy = true
	_index = i
	var tw := create_tween()
	if _label.modulate.a > 0.0:
		tw.tween_property(_label, "modulate:a", 0.0, 0.4)
	tw.tween_callback(func(): _label.text = _lines[i])
	tw.tween_property(_label, "modulate:a", 1.0, 1.1)
	tw.tween_callback(func(): _busy = false)


func _finish() -> void:
	if _done:
		return
	_done = true
	Game.next_level(Color.BLACK, true)


## Black, a pale light far off, and dust drifting through it.
func _draw() -> void:
	var s := size
	draw_rect(Rect2(Vector2.ZERO, s), Color(0.02, 0.02, 0.03))
	var c := Vector2(s.x / 2.0, s.y * 0.5)
	var pulse := 0.9 + 0.1 * sin(_time * 1.3)
	var fade := 1.0 - float(_index) / maxf(1.0, float(_lines.size())) * 0.7
	for k in 40:
		var r := (40 - k) * 16.0 * pulse
		draw_circle(c, r, Color(0.7, 0.76, 0.95, 0.007 * fade))
	for e in 24:
		var sd := float(e) * 7.3
		var life := fmod(_time * (0.04 + Ink.hash2(sd, 1.0) * 0.05) + Ink.hash2(sd, 2.0), 1.0)
		var x := s.x * Ink.hash2(sd, 3.0) + sin(_time * 0.5 + sd) * 30.0
		var y := s.y * (1.0 - life)
		draw_circle(Vector2(x, y), 1.6, Color(0.85, 0.88, 1.0, sin(life * PI) * 0.35 * fade))
