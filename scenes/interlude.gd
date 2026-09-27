extends Control
## Between two levels: a few lines of the dream, then a page from the Codex of
## the Ringed Eye — the Brothers' book about the Warden and the Knot. Chosen by
## the id of the level just finished (Game.current_level still points at it);
## then on to the next one. Space / Enter / click to advance, hold to skip.
## Not timed.
##
## An entry is either a line of narration (a String) or a Codex page:
##   {"codex": "Of the Warden", "folio": "iii", "art": "eye" | "knot" | "beast" | "sigil", "text": "..."}

const TEXTS := {
	"level1_expedition": [
		"In his dreams the maps were no longer drawn. They were places,\nand he walked them.",
		"“Look,” said a voice that was not his own.\nAnd he looked — and there was the sea.",
		{"codex": "Of the Warden", "folio": "iii", "art": "eye",
			"text": "It came up out of the western sea before there were kings to name it. The fisher-folk called it the Eye that Walks. We call it Custos, the Warden, for it keeps all that it takes, and gives nothing back."},
	],
	"level2_beacons": [
		"That was not the voyage he and his crew had sailed.\nThe sea had moved beneath them like a thing that breathes.",
		"Something older than the charts was at play.",
		{"codex": "Of the Knot", "folio": "xi", "art": "knot",
			"text": "Upon the isle the Brothers raised a maze of stone to hold it, and set in it three gates: of iron, of stone, and of black iron that weeps when it is touched. One door alone they blessed with light. The Warden will not cross it."},
	],
	"cave_hollow": [
		"Beyond the door the light was not daylight.\nIt was pale, and cold, and it came from nowhere at all.",
		"The painters had drawn the way in.\nNot one of them had drawn the way out.",
		{"codex": "Of Silence", "folio": "xvii", "art": "beast",
			"text": "The Brothers walked the Knot barefoot and spoke no word, for the Warden is blind to all but sound. Those who ran, it heard. Those who stood still, it passed by. Of those it heard, none are written here."},
		{"codex": "Of Maps", "folio": "xl", "art": "sigil",
			"text": "Let no man chart the Knot. What is drawn, the Warden knows; and whosoever maps the Knot is mapped by it, and is made a wall within it, forever."},
		"He felt trapped in his own mind.",
	],
}


static func has_lines(level_id: String) -> bool:
	return TEXTS.has(level_id)


var _fell: Font = preload("res://assets/fonts/IMFellEnglish.ttf")
var _fell_i: Font = preload("res://assets/fonts/IMFellEnglish-Italic.ttf")
var _lines: Array = []
var _index := 0
var _label: Label
var _page_body: Label
var _page_k := 0.0            ## the Codex page, faded in
var _time := 0.0
var _busy := false
var _done := false
var _hold := 0.0
var _vignette: GradientTexture2D
var _maze: PackedStringArray = []


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_lines = TEXTS.get(Game.LEVELS[Game.current_level]["id"], [])
	if _lines.is_empty():
		_finish()
		return
	_maze = PackedStringArray(load("res://levels/level3/level3_data.gd").get_script_constant_map()["MAZE"])
	var g := Gradient.new()
	g.set_color(0, Color(0, 0, 0, 0))
	g.set_color(1, Color(0, 0, 0, 0.9))
	_vignette = GradientTexture2D.new()
	_vignette.gradient = g
	_vignette.fill = GradientTexture2D.FILL_RADIAL
	_vignette.fill_from = Vector2(0.5, 0.5)
	_vignette.fill_to = Vector2(1.05, 1.05)
	_label = Label.new()
	_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_font_override("font", _fell)
	_label.add_theme_font_size_override("font_size", 36)
	_label.add_theme_color_override("font_color", Color(0.88, 0.8, 0.64))
	_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	_label.add_theme_constant_override("shadow_offset_y", 3)
	_label.modulate.a = 0.0
	add_child(_label)
	_page_body = Label.new()
	_page_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_page_body.add_theme_font_override("font", _fell_i)
	_page_body.add_theme_font_size_override("font_size", 25)
	_page_body.add_theme_color_override("font_color", Color(0.2, 0.11, 0.06))
	_page_body.add_theme_constant_override("line_spacing", 4)
	_page_body.modulate.a = 0.0
	add_child(_page_body)
	var hint := Label.new()
	hint.text = "space / enter  —  continue          hold  —  skip"
	hint.add_theme_font_override("font", _fell_i)
	hint.add_theme_font_size_override("font_size", 18)
	hint.add_theme_color_override("font_color", Color(0.75, 0.62, 0.45, 0.4))
	hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	hint.position.y -= 40
	hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
	add_child(hint)
	# the level's time, quietly, for those who race
	if Game.show_timer:
		var t := Label.new()
		var best := Game.get_best_time(Game.LEVELS[Game.current_level]["id"])
		t.text = "%s   %s      best  %s" % [Game.level_title(), Game.format_time(Game.level_time), Game.format_time(best)]
		t.add_theme_font_size_override("font_size", 22)
		t.add_theme_color_override("font_color", Color(0.85, 0.78, 0.65, 0.7))
		t.set_anchors_preset(Control.PRESET_CENTER_TOP)
		t.position.y += 30
		t.grow_horizontal = Control.GROW_DIRECTION_BOTH
		add_child(t)
	Music.sfx("hum", 0.3, 0.5)
	_show_line(0)


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()
	if _page_body:
		var page := _page_rect()
		_page_body.position = page.position + Vector2(page.size.x * 0.42, 132)
		_page_body.size = Vector2(page.size.x * 0.52, page.size.y - 150)
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
	var was_page := _index < _lines.size() and _lines[_index] is Dictionary and _page_k > 0.0
	_index = i
	var entry = _lines[i]
	var tw := create_tween()
	if _label.modulate.a > 0.0:
		tw.tween_property(_label, "modulate:a", 0.0, 0.4)
	if was_page:
		tw.tween_property(self, "_page_k", 0.0, 0.5)
		tw.parallel().tween_property(_page_body, "modulate:a", 0.0, 0.4)
	if entry is Dictionary:
		tw.tween_callback(func(): _page_body.text = entry.text; Music.sfx("page", 0.6, 0.8))
		tw.tween_property(self, "_page_k", 1.0, 1.0)
		tw.parallel().tween_property(_page_body, "modulate:a", 1.0, 1.4)
	else:
		tw.tween_callback(func(): _label.text = entry)
		tw.tween_property(_label, "modulate:a", 1.0, 1.1)
	tw.tween_callback(func(): _busy = false)


func _finish() -> void:
	if _done:
		return
	_done = true
	Game.next_level(Color.BLACK, false)


func _page_rect() -> Rect2:
	var w := minf(size.x * 0.78, 980.0)
	var h := minf(size.y * 0.7, 480.0)
	var r := Rect2((size.x - w) / 2.0, (size.y - h) / 2.0 - 10.0, w, h)
	r.position.y += (1.0 - _page_k) * 30.0
	return r


# ================================================================ drawing
## Near-black, one candle's warmth low down, dust drifting through it — and,
## when the Codex speaks, its page.
func _draw() -> void:
	var s := size
	draw_rect(Rect2(Vector2.ZERO, s), Color(0.018, 0.013, 0.011))
	var c := Vector2(s.x / 2.0, s.y * 0.95)
	var flick := 0.88 + 0.12 * sin(_time * 8.0) * sin(_time * 4.7 + 1.0)
	for k in 40:
		var r := (40 - k) * 20.0 * flick
		draw_circle(c, r, Color(0.85, 0.4, 0.14, 0.008))
	for e in 24:
		var sd := float(e) * 7.3
		var life := fmod(_time * (0.04 + Ink.hash2(sd, 1.0) * 0.05) + Ink.hash2(sd, 2.0), 1.0)
		var x := s.x * Ink.hash2(sd, 3.0) + sin(_time * 0.5 + sd) * 30.0
		var y := s.y * (1.0 - life)
		draw_circle(Vector2(x, y), 1.6, Color(1.0, 0.75, 0.45, sin(life * PI) * 0.3))
	if _page_k > 0.0 and _index < _lines.size():
		var entry = _lines[_index]
		if entry is Dictionary:
			_draw_page(entry)
	draw_texture_rect(_vignette, Rect2(Vector2.ZERO, s), false)


func _draw_page(entry: Dictionary) -> void:
	var r := _page_rect()
	var a := _page_k
	# ragged, scorched edges
	var pts := PackedVector2Array()
	var n := 64
	for i in n:
		var t := float(i) / n
		var p: Vector2
		if t < 0.25:
			p = r.position.lerp(Vector2(r.end.x, r.position.y), t * 4.0)
		elif t < 0.5:
			p = Vector2(r.end.x, r.position.y).lerp(r.end, (t - 0.25) * 4.0)
		elif t < 0.75:
			p = r.end.lerp(Vector2(r.position.x, r.end.y), (t - 0.5) * 4.0)
		else:
			p = Vector2(r.position.x, r.end.y).lerp(r.position, (t - 0.75) * 4.0)
		pts.append(p + Vector2(Ink.hash2(i, 1.0) - 0.5, Ink.hash2(i, 2.0) - 0.5) * 14.0)
	var shadow := PackedVector2Array()
	for p in pts:
		shadow.append(p + Vector2(10, 14))
	draw_colored_polygon(shadow, Color(0, 0, 0, 0.6 * a))
	draw_colored_polygon(pts, Color(0.2, 0.12, 0.06, a))
	var inner := PackedVector2Array()
	var cc := r.get_center()
	for p in pts:
		inner.append(cc + (p - cc) * Vector2(0.985, 0.97))
	draw_colored_polygon(inner, Color(0.7, 0.6, 0.44, a))
	for i in 40:
		var p := r.position + Vector2(Ink.hash2(i, 7.0), Ink.hash2(i, 8.0)) * r.size
		draw_circle(p, 8.0 + Ink.hash2(i, 9.0) * 50.0, Color(0.38, 0.25, 0.12, 0.06 * a))
	# the rubric: book, chapter, folio
	var red := Color(0.5, 0.06, 0.04, a)
	var brown := Color(0.25, 0.14, 0.07, a)
	draw_string(_fell_i, r.position + Vector2(40, 46), "Codex of the Ringed Eye", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, brown)
	draw_string(_fell_i, r.position + Vector2(0, 46), "fol. %s" % entry.get("folio", "i"), HORIZONTAL_ALIGNMENT_RIGHT, r.size.x - 40, 20, brown)
	var title: String = entry.codex
	var tx := r.position.x + r.size.x * 0.42
	# an illuminated first letter
	draw_rect(Rect2(Vector2(tx - 4, r.position.y + 62), Vector2(52, 52)), Color(0.5, 0.06, 0.04, a))
	draw_rect(Rect2(Vector2(tx - 4, r.position.y + 62), Vector2(52, 52)), Color(0.72, 0.55, 0.18, a), false, 2.0)
	draw_string(_fell, Vector2(tx + 6, r.position.y + 106), title.substr(0, 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 48, Color(0.95, 0.85, 0.55, a))
	draw_string(_fell, Vector2(tx + 58, r.position.y + 100), title.substr(1), HORIZONTAL_ALIGNMENT_LEFT, -1, 38, red)
	draw_line(Vector2(tx - 4, r.position.y + 122), Vector2(r.end.x - 40, r.position.y + 122), Color(0.5, 0.06, 0.04, 0.5 * a), 1.5)
	# the illustration, in the left third
	var art := Rect2(r.position + Vector2(40, 70), Vector2(r.size.x * 0.34, r.size.y - 110))
	draw_rect(art, Color(0.25, 0.14, 0.07, 0.6 * a), false, 2.0)
	draw_rect(art.grow(-6), Color(0.25, 0.14, 0.07, 0.35 * a), false, 1.0)
	match entry.get("art", "sigil"):
		"eye":
			_art_eye(art.grow(-14), a)
		"knot":
			_art_knot(art.grow(-14), a)
		"beast":
			_art_beast(art.grow(-14), a)
		_:
			_art_sigil(art.grow(-14), a)


func _ink(a: float, k := 1.0) -> Color:
	return Color(0.2, 0.11, 0.06, a * k)


## The Eye that Walks: an eye rising out of waves.
func _art_eye(r: Rect2, a: float) -> void:
	var c := r.get_center() + Vector2(0, -r.size.y * 0.12)
	var w := r.size.x * 0.38
	var eye := PackedVector2Array()
	for i in 33:
		var t := TAU * i / 32.0
		eye.append(c + Vector2(cos(t) * w, sin(t) * w * 0.42 * (1.0 if sin(t) > 0 else 1.0)))
	draw_colored_polygon(eye, Color(0.85, 0.78, 0.6, a))
	eye.append(eye[0])
	draw_polyline(eye, _ink(a), 3.0, true)
	var look := Vector2(sin(_time * 0.7) * w * 0.25, 0)
	draw_circle(c + look, w * 0.34, Color(0.45, 0.05, 0.03, a))
	draw_circle(c + look, w * 0.14, _ink(a))
	for i in 9:             # lashes like little arms
		var t := PI + PI * (i + 0.5) / 9.0
		var p := c + Vector2(cos(t) * w, sin(t) * w * 0.42)
		draw_line(p, p + Vector2(cos(t), sin(t)) * 14.0, _ink(a), 2.0)
	for j in 5:
		var pts := PackedVector2Array()
		for i in 30:
			var x := r.position.x + i * r.size.x / 29.0
			pts.append(Vector2(x, r.end.y - 20 - j * 16 + sin(x * 0.08 + j + _time * 0.8) * 5.0))
		draw_polyline(pts, _ink(a, 0.8), 2.0, true)


## The Knot: the labyrinth itself, three gates, and the door of light.
func _art_knot(r: Rect2, a: float) -> void:
	var n := _maze.size()
	var side := minf(r.size.x, r.size.y)
	var cs := side / float(n - 1)
	var o := r.get_center() - Vector2(side, side) / 2.0
	for y in n:
		for x in _maze[y].length():
			if (x % 2 == 0) == (y % 2 == 0):
				continue
			var ch := _maze[y][x]
			if ch in ["#", "h", "F", "Q", "B", "I", "T", "K", "X"]:
				var p0: Vector2
				var p1: Vector2
				if y % 2 == 0:
					p0 = o + Vector2(x - 1, y) * cs
					p1 = o + Vector2(x + 1, y) * cs
				else:
					p0 = o + Vector2(x, y - 1) * cs
					p1 = o + Vector2(x, y + 1) * cs
				var col := _ink(a)
				var w := 1.6
				if ch in ["I", "T", "K"]:
					col = Color(0.5, 0.06, 0.04, a)
					w = 3.0
				elif ch == "X":
					col = Color(0.8, 0.62, 0.2, a)
					w = 4.0
				draw_line(p0, p1, col, w, true)


## The Warden, as a monk drew it: wings, arms, the tentacled face, two red eyes.
func _art_beast(r: Rect2, a: float) -> void:
	var c := r.get_center() + Vector2(0, -r.size.y * 0.1)
	var s := r.size.y / 300.0
	var ink := _ink(a)
	for sd: float in [-1.0, 1.0]:
		var wing := PackedVector2Array([c + Vector2(sd * 20, -20) * s, c + Vector2(sd * 110, -110) * s, c + Vector2(sd * 105, -40) * s,
			c + Vector2(sd * 90, -30) * s, c + Vector2(sd * 88, 10) * s, c + Vector2(sd * 70, 0) * s, c + Vector2(sd * 62, 36) * s, c + Vector2(sd * 26, 26) * s])
		draw_colored_polygon(wing, Color(0.2, 0.11, 0.06, 0.8 * a))
		draw_polyline(PackedVector2Array([c + Vector2(sd * 34, 20) * s, c + Vector2(sd * 58, 80) * s, c + Vector2(sd * 52, 130) * s]), ink, 7.0 * s, true)
	draw_colored_polygon(PackedVector2Array([c + Vector2(-40, -10) * s, c + Vector2(40, -10) * s, c + Vector2(28, 110) * s, c + Vector2(-28, 110) * s]), ink)
	draw_colored_polygon(PackedVector2Array([c + Vector2(-24, -20) * s, c + Vector2(-20, -70) * s, c + Vector2(0, -92) * s, c + Vector2(20, -70) * s, c + Vector2(24, -20) * s]), ink)
	for i in 6:
		var x := -18.0 + i * 7.0
		var t := PackedVector2Array()
		for j in 7:
			t.append(c + Vector2(x + sin(_time * 1.3 + i + j * 0.6) * 2.5, -24 + j * 9) * s)
		draw_polyline(t, ink, 3.0 * s, true)
	for i in 5:
		var x := -20.0 + i * 10.0
		var t := PackedVector2Array()
		for j in 8:
			t.append(c + Vector2(x + sin(_time + i * 1.7 + j * 0.5) * 4.0, 108 + j * 10) * s)
		draw_polyline(t, ink, 5.0 * s, true)
	for sd: float in [-1.0, 1.0]:
		draw_circle(c + Vector2(sd * 9, -44) * s, 3.2 * s, Color(0.6, 0.05, 0.03, a))
	# the monks' warning, under it
	draw_string(_fell_i, Vector2(r.position.x, r.end.y - 4), "tace", HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 22, Color(0.5, 0.06, 0.04, a))


## The ring and the eye, with a hand reaching for a quill beneath.
func _art_sigil(r: Rect2, a: float) -> void:
	var c := r.get_center() + Vector2(0, -r.size.y * 0.12)
	var rad := minf(r.size.x, r.size.y) * 0.3
	var red := Color(0.5, 0.06, 0.04, a)
	draw_arc(c, rad, 0, TAU, 48, red, 4.0, true)
	var eye := PackedVector2Array()
	for i in 17:
		var t := PI * i / 16.0
		eye.append(c + Vector2(cos(t) * rad * 0.62, -sin(t) * rad * 0.32))
	for i in range(1, 16):
		var t := PI * i / 16.0
		eye.append(c + Vector2(-cos(t) * rad * 0.62, sin(t) * rad * 0.32))
	eye.append(eye[0])
	draw_polyline(eye, red, 3.0, true)
	draw_circle(c, rad * 0.14, red)
	# a quill, snapped
	var q := c + Vector2(0, rad * 1.7)
	draw_line(q + Vector2(-rad, 10), q + Vector2(-8, -4), _ink(a), 3.0, true)
	draw_line(q + Vector2(8, 4), q + Vector2(rad, -12), _ink(a), 3.0, true)
	draw_colored_polygon(PackedVector2Array([q + Vector2(rad, -12), q + Vector2(rad * 0.6, -26), q + Vector2(rad * 0.5, -8)]), _ink(a, 0.8))
	for i in 5:
		draw_circle(q + Vector2(Ink.hash2(i, 3.0) * 20.0 - 10.0, 12 + i * 5), 2.0 + i * 0.6, red)
