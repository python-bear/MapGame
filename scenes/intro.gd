extends Control
## The opening: why the cartographer goes to the isle — and, as "arrival", his
## first sight of it after the crossing. A short animated film,
## drawn in code in the manner of an old woodcut — candle-dark, parchment and
## soot, with a little blood-red and gold.
##
##   1. The year, and the King's hall: a commission under the royal seal.
##   2. The King's chart: every coast drawn, save one. At the western edge the
##      monks wrote a warning, and the King wants the blank filled.
##   3. The shore: seven winters ago his old master, Elias Vane, sailed for the
##      isle. The sea gave back only his journal — a labyrinth drawn over and
##      over, a ring with an eye, and one line.
##   4. The abbey: the chained Codex of the Ringed Eye, and the thing in the
##      glass. The Warden, the Knot, the light it will not cross, and the rule:
##      whosoever maps the Knot is mapped by it.
##   5. The harbour at Saltmere: he boards the ship. The voyage: on the ninth
##      night the stars are wrong, and the chart becomes the sea. (Level 1,
##      the crossing, begins.)
## The same scene plays "arrival" after the crossing: the isle at dawn, and
## Harrow's Landing, where Vane's old tents still stand.
##
## Space / Enter / click: next line. Hold: skip to the level. Not timed.

## The films this scene can play (`film`): the opening, and the arrival at the
## isle after the crossing.
const FILMS := {
	"intro": [
		{"art": "title", "lines": [
			"Anno Domini MCCCXLVIII",
			"The year the bells rang for the dead in every parish,\nand the King turned his eyes to the edge of the world.",
		]},
		{"art": "hall", "lines": [
			"He was summoned at night, to a hall without warmth.",
			"“Every coast of my kingdom is drawn,” said the King. “Save one.”",
			"“Go west, cartographer. Chart the isle the sea keeps hidden.\nA king cannot rule what he cannot draw.”",
		]},
		{"art": "chart", "lines": [
			"On the King's great chart the known world ended in a blank.",
			"Ships that sailed into it did not come home.",
			"At its edge the old monks had written a single line, in red:\nHic habitat Custos. — Here dwells the Warden.",
		]},
		{"art": "journal", "lines": [
			"He knew that blank. Seven winters past, his old master\nElias Vane had sailed to fill it.",
			"The sea gave back only his journal, swollen and stinking of brine.",
			"Page after page, the same labyrinth. The same ring, and the eye within it.\nAnd on the last page, one line:  It does not want to be drawn.",
		]},
		{"art": "codex", "lines": [
			"In the abbey at Wyrmhollow, the Codex of the Ringed Eye lies chained to its lectern.",
			"“Before there were kings, a thing came up out of the western sea.\nThe Brothers named it Custos — the Warden — for it keeps all it takes.”",
			"“They raised the Knot to hold it: a maze of stone, three gates,\nand one door blessed with light, that the Warden cannot cross.”",
			"“Walk it in silence, for it hunts by ear.\nAnd let no man map it — for whosoever maps the Knot is mapped by it.”",
		]},
		{"art": "harbour", "lines": [
			"He sailed from Saltmere in the month of the dead,\nwith the King's seal and his master's book.",
			"The harbourmaster would not take his coin.\n“No one comes back from the west,” he said. “Not even their ships.”",
		]},
		{"art": "voyage", "lines": [
			"For eight days the sea was kind. On the ninth night the stars were wrong.",
			"He spread the chart beneath the lantern to mark their course —\nand the lines on the paper became the sea itself.",
		]},
	],
	"arrival": [
		{"art": "isle", "lines": [
			"At dawn the fog drew back like a curtain, and there it was.",
			"The isle that was on no chart: black cliffs, a jungle steaming in the cold,\nand above it all the plateau, wrapped in cloud.",
			"The sailors would not go nearer. They lowered the boat,\nand did not look at him.",
		]},
		{"art": "landing", "lines": [
			"They came ashore at Harrow's Landing and made camp above the tideline.",
			"Three tents were already there, grey with salt and seven winters old.\nOn the post beside them, someone had carved the ring and the eye.",
			"That night the maps would not let him go.\nThey had become the only thing that was real.",
			"“Look,” said the guide in the morning, and pointed inland.",
		]},
	],
}

## Which film to play: "intro" (then Level 1) or "arrival" (then on to the
## next level, after the crossing).
@export var film := "intro"
var PANELS: Array = []

var _fell: Font = preload("res://assets/fonts/IMFellEnglish.ttf")
var _fell_i: Font = preload("res://assets/fonts/IMFellEnglish-Italic.ttf")
var _hand: Font = preload("res://assets/fonts/Caveat.ttf")

var _t := 0.0
var _panel := 0
var _line := 0
var _caption: Label
var _hint: Label
var _skip_bar: ColorRect
var _cap_tw: Tween
var _advance := false
var _done := false
var _hold := 0.0
var _vignette: GradientTexture2D
var _maze: PackedStringArray = []

# the "camera" (the stage is 1280 x 720)
var cam_center := Vector2(640, 360)
var cam_zoom := 1.0
var black := 1.0            ## full-screen black, for cuts between panels
var fire_k := 1.0           ## the camp fire, burning down
var eyes_k := 0.0           ## the eyes in the glass / under the sea
var ink_k := 0.0            ## the warning on the chart, being written
var title_k := 0.0          ## the year, on the title card
var chart_k := 0.0          ## the voyage dissolving into the chart
var fog_k := 1.0            ## the dawn fog round the isle


func _ready() -> void:
	add_to_group("cutscene")          # Game keeps the (paused) timer on screen
	PANELS = FILMS.get(film, FILMS["intro"])
	set_anchors_preset(Control.PRESET_FULL_RECT)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_maze = PackedStringArray(load("res://levels/level3/level3_data.gd").get_script_constant_map()["MAZE"])
	var g := Gradient.new()
	g.set_color(0, Color(0, 0, 0, 0))
	g.set_color(1, Color(0, 0, 0, 0.92))
	g.add_point(0.55, Color(0, 0, 0, 0.15))
	_vignette = GradientTexture2D.new()
	_vignette.gradient = g
	_vignette.fill = GradientTexture2D.FILL_RADIAL
	_vignette.fill_from = Vector2(0.5, 0.5)
	_vignette.fill_to = Vector2(1.05, 1.05)
	_vignette.width = 256
	_vignette.height = 256
	_caption = Label.new()
	_caption.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_caption.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_caption.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_caption.position.y -= 78
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.add_theme_font_override("font", _fell)
	_caption.add_theme_font_size_override("font_size", 30)
	_caption.add_theme_color_override("font_color", Color(0.9, 0.84, 0.7))
	_caption.add_theme_color_override("font_outline_color", Color(0.03, 0.02, 0.015, 0.95))
	_caption.add_theme_constant_override("outline_size", 9)
	_caption.modulate.a = 0.0
	add_child(_caption)
	_hint = Label.new()
	_hint.text = "space — next          hold — skip"
	_hint.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_hint.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_hint.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_hint.position += Vector2(-24, -14)
	_hint.add_theme_font_override("font", _fell_i)
	_hint.add_theme_font_size_override("font_size", 17)
	_hint.add_theme_color_override("font_color", Color(0.8, 0.7, 0.55, 0.45))
	add_child(_hint)
	_skip_bar = ColorRect.new()
	_skip_bar.color = Color(0.75, 0.15, 0.08, 0.85)
	_skip_bar.size = Vector2(0, 3)
	add_child(_skip_bar)
	Music.play_set("level3", 4.0)
	Music.set_danger(0.0)
	_play()


# ================================================================ the film
func _play() -> void:
	for p in PANELS.size():
		if _done:
			return
		_panel = p
		_set_up(PANELS[p].art)
		_tween("black", 0.0, 1.4)
		await _wait(0.9)
		var lines: Array = PANELS[p].lines
		for i in lines.size():
			if _done:
				return
			_line = i
			_on_line(PANELS[p].art, i)
			await _say(lines[i], PANELS[p].art == "title")
		if p < PANELS.size() - 1:
			_tween("black", 1.0, 1.0)
			await _wait(1.1)
	_tween("black", 1.0, 2.0)
	await _wait(2.1)
	_finish()


## Where each panel's camera starts, and where it drifts to.
func _set_up(art: String) -> void:
	fire_k = 1.0
	eyes_k = 0.0
	chart_k = 0.0
	fog_k = 1.0
	match art:
		"title":
			cam_center = Vector2(640, 360)
			cam_zoom = 1.0
			title_k = 0.0
			_tween("title_k", 1.0, 3.0)
		"hall":
			cam_center = Vector2(640, 380)
			cam_zoom = 1.0
			_move(Vector2(700, 400), 1.55, 16.0)
		"chart":
			cam_center = Vector2(900, 360)
			cam_zoom = 1.25
			ink_k = 0.0
			_move(Vector2(330, 360), 1.6, 15.0)
		"journal":
			cam_center = Vector2(640, 330)
			cam_zoom = 1.0
			_move(Vector2(640, 500), 2.0, 17.0)
		"codex":
			cam_center = Vector2(640, 560)
			cam_zoom = 1.6
			_move(Vector2(640, 250), 1.25, 22.0)
		"voyage":
			cam_center = Vector2(640, 330)
			cam_zoom = 1.05
			_move(Vector2(640, 400), 1.2, 14.0)
		"camp":
			cam_center = Vector2(640, 420)
			cam_zoom = 1.0
			_move(Vector2(560, 480), 1.5, 26.0)
		"harbour":
			cam_center = Vector2(560, 380)
			cam_zoom = 1.0
			_move(Vector2(760, 400), 1.35, 16.0)
		"isle":
			cam_center = Vector2(640, 400)
			cam_zoom = 1.0
			_move(Vector2(650, 330), 1.3, 22.0)
		"landing":
			cam_center = Vector2(900, 420)
			cam_zoom = 1.25
			_move(Vector2(420, 420), 1.3, 26.0)


## Things that happen on a particular line.
func _on_line(art: String, i: int) -> void:
	match art:
		"chart":
			if i == 2:
				_tween("ink_k", 1.0, 3.0)
				Music.sfx("ink", 0.5, 0.7)
		"journal":
			if i == 0:
				Music.sfx("splash", 0.35, 0.6)
		"codex":
			if i == 1:
				_tween("eyes_k", 1.0, 4.0)
				Music.sfx("whisper", 0.45, 0.7)
			if i == 3:
				Music.sfx("heartbeat", 0.6, 0.8)
		"voyage":
			if i == 0:
				_tween("eyes_k", 1.0, 6.0)
				Music.sfx("emerge", 0.4, 0.5)
			if i == 1:
				_tween("chart_k", 1.0, 5.0)
				Music.sfx("page", 0.5, 0.8)
		"harbour":
			if i == 0:
				Music.sfx("bell", 0.35, 0.7)
		"isle":
			if i == 0:
				_tween("fog_k", 0.0, 8.0)
		"landing":
			if i == 1:
				Music.sfx("whisper", 0.35, 0.8)
		"camp":
			_tween("fire_k", 1.0 - (i + 1) * 0.16, 3.0)


func _say(text: String, big := false) -> void:
	if _done:
		return
	_advance = false
	_caption.text = "" if big else text
	_caption.add_theme_font_override("font", _fell_i if text.begins_with("“") else _fell)
	if _cap_tw:
		_cap_tw.kill()
	if big:
		_big_text = text
		_big_a = 0.0
		_cap_tw = create_tween()
		_cap_tw.tween_property(self, "_big_a", 1.0, 1.2)
	else:
		_cap_tw = create_tween()
		_cap_tw.tween_property(_caption, "modulate:a", 1.0, 0.7)
	var hold := 2.4 + text.length() * 0.05
	var waited := 0.0
	while waited < hold and not _advance and not _done:
		await get_tree().process_frame
		waited += get_process_delta_time()
	if _cap_tw:
		_cap_tw.kill()
	_cap_tw = create_tween()
	if big:
		_cap_tw.tween_property(self, "_big_a", 0.0, 0.6)
	else:
		_cap_tw.tween_property(_caption, "modulate:a", 0.0, 0.5)
	await _cap_tw.finished


var _big_text := ""
var _big_a := 0.0


func _wait(t: float) -> void:
	await get_tree().create_timer(t).timeout


func _tween(prop: String, to: float, t: float) -> void:
	create_tween().tween_property(self, prop, to, t).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _move(center: Vector2, zoom: float, t: float) -> void:
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "cam_center", center, t).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(self, "cam_zoom", zoom, t).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()
	if Input.is_action_pressed("skip") and _t > 0.8:
		_hold += delta
		if _hold > 0.7:
			_finish()
	else:
		_hold = 0.0
	_skip_bar.size.x = 200.0 * clampf(_hold / 0.7, 0.0, 1.0)
	_skip_bar.position = Vector2(size.x - 224.0, size.y - 8.0)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("skip") or (event is InputEventMouseButton and event.pressed):
		get_viewport().set_input_as_handled()
		_advance = true


func _finish() -> void:
	if _done:
		return
	_done = true
	if film == "intro":
		Game.start_level(0)
	else:
		Game.next_level(Color.BLACK, true)


# ================================================================ drawing
func _draw() -> void:
	var s := size
	draw_rect(Rect2(Vector2.ZERO, s), Color(0.012, 0.01, 0.01))
	var k := maxf(s.x / 1280.0, s.y / 720.0) * cam_zoom
	var off := s / 2.0 - cam_center * k
	draw_set_transform_matrix(Transform2D(0.0, Vector2(k, k), 0.0, off))
	match PANELS[_panel].art:
		"title":
			_draw_title()
		"hall":
			_draw_hall()
		"chart":
			_draw_chart()
		"journal":
			_draw_journal()
		"codex":
			_draw_codex()
		"voyage":
			_draw_voyage()
		"camp":
			_draw_camp()
		"harbour":
			_draw_harbour()
		"isle":
			_draw_isle()
		"landing":
			_draw_landing()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# the dark closing in at the edges, a candle's unsteadiness, and letterbox bars
	draw_texture_rect(_vignette, Rect2(Vector2.ZERO, s), false)
	var flick := 0.04 + 0.03 * sin(_t * 7.0) * sin(_t * 3.1)
	draw_rect(Rect2(Vector2.ZERO, s), Color(0, 0, 0, flick))
	var bar := s.y * 0.085
	draw_rect(Rect2(0, 0, s.x, bar), Color.BLACK)
	draw_rect(Rect2(0, s.y - bar, s.x, bar), Color.BLACK)
	if _big_a > 0.0 and _big_text != "":
		_draw_big(s)
	if black > 0.0:
		draw_rect(Rect2(Vector2.ZERO, s), Color(0, 0, 0, black))


func _draw_big(s: Vector2) -> void:
	var lines := _big_text.split("\n")
	var big := lines.size() == 1
	var fs := 60 if big else 30
	var font := _fell if big else _fell_i
	var y := s.y * 0.5 - (lines.size() - 1) * fs * 0.6
	for ln in lines:
		var w := font.get_string_size(ln, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var at := Vector2((s.x - w) / 2.0, y)
		draw_string_outline(font, at, ln, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 8, Color(0, 0, 0, _big_a))
		draw_string(font, at, ln, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.82, 0.7, 0.45, _big_a) if big else Color(0.88, 0.82, 0.68, _big_a))
		y += fs * 1.25


# ---------------------------------------------------------------- shared bits
func _flame(c: Vector2, h: float, w: float, seed_: float, a := 1.0) -> void:
	for layer in 3:
		var col: Color = [Color(0.85, 0.22, 0.05, 0.85), Color(1.0, 0.52, 0.1, 0.85), Color(1.0, 0.85, 0.45, 0.9)][layer]
		var ww := w * (1.0 - layer * 0.28)
		var pts := PackedVector2Array()
		for i in 11:
			var tt := float(i) / 10.0
			var x := lerpf(-ww, ww, tt)
			var y := -h * (1.0 - layer * 0.25) * pow(sin(tt * PI), 0.8) * (0.75 + 0.25 * sin(_t * (9.0 + layer * 3.0) + i * 1.9 + seed_))
			pts.append(c + Vector2(x + sin(_t * 6.0 + i + seed_) * ww * 0.08, y))
		pts.append(c + Vector2(ww, 2))
		pts.append(c + Vector2(-ww, 2))
		draw_colored_polygon(pts, Color(col, col.a * a))


func _glow(c: Vector2, r: float, col: Color, steps := 14) -> void:
	for i in steps:
		var f := 1.0 - float(i) / steps
		draw_circle(c, r * f, Color(col, col.a / steps))


func _candle(base: Vector2, h: float, seed_: float) -> void:
	var flick := 0.85 + 0.15 * sin(_t * 10.0 + seed_) * sin(_t * 6.1 + seed_ * 2.0)
	_glow(base + Vector2(0, -h - 10), 150.0 * flick, Color(1.0, 0.55, 0.2, 0.35))
	draw_rect(Rect2(base + Vector2(-6, -h), Vector2(12, h)), Color(0.78, 0.72, 0.58))
	draw_rect(Rect2(base + Vector2(-6, -h), Vector2(4, h)), Color(0.9, 0.85, 0.72))
	draw_colored_polygon(PackedVector2Array([base + Vector2(-6, -h), base + Vector2(-3, -h + 14), base + Vector2(0, -h)]), Color(0.9, 0.86, 0.75))
	_flame(base + Vector2(0, -h - 2), 22.0 * flick, 5.0, seed_)


func _stone_wall(r: Rect2, base: Color, rows := 12) -> void:
	draw_rect(r, base)
	var bh := r.size.y / rows
	for j in rows:
		var shift := (j % 2) * 45.0
		var x := r.position.x - shift
		while x < r.end.x:
			var w := 90.0
			var v := Ink.hash2(x * 0.1, j) * 0.05
			draw_rect(Rect2(Vector2(x + 2, r.position.y + j * bh + 2), Vector2(w - 4, bh - 4)), Color(base.r + v, base.g + v * 0.9, base.b + v * 0.8))
			x += w


## The pointed arch of a gothic window: `r` is its bounding box.
func _arch(r: Rect2, steps := 14) -> PackedVector2Array:
	var spring := r.position.y + r.size.x * 0.8
	var apex := Vector2(r.position.x + r.size.x * 0.5, r.position.y)
	var pts := PackedVector2Array([Vector2(r.position.x, r.end.y), Vector2(r.position.x, spring)])
	var ctrl_l := Vector2(r.position.x, r.position.y + (spring - r.position.y) * 0.3)
	var ctrl_r := Vector2(r.end.x, ctrl_l.y)
	for i in range(1, steps + 1):
		var t := float(i) / steps
		var a0 := Vector2(r.position.x, spring)
		pts.append(a0.lerp(ctrl_l, t).lerp(ctrl_l.lerp(apex, t), t))
	for i in range(steps - 1, -1, -1):
		var t := float(i) / steps
		var b0 := Vector2(r.end.x, spring)
		pts.append(b0.lerp(ctrl_r, t).lerp(ctrl_r.lerp(apex, t), t))
	pts.append(Vector2(r.end.x, r.end.y))
	return pts


## The ring and the eye.
func _sigil(c: Vector2, r: float, col: Color, w := 3.0) -> void:
	draw_arc(c, r, 0, TAU, 40, col, w, true)
	var eye := PackedVector2Array()
	for i in 17:
		var a := PI * i / 16.0
		eye.append(c + Vector2(cos(a) * r * 0.62, -sin(a) * r * 0.32))
	for i in range(1, 16):
		var a := PI * i / 16.0
		eye.append(c + Vector2(-cos(a) * r * 0.62, sin(a) * r * 0.32))
	eye.append(eye[0])
	draw_polyline(eye, col, w * 0.8, true)
	draw_circle(c, r * 0.14, col)


# ---------------------------------------------------------------- 0. the year
func _draw_title() -> void:
	draw_rect(Rect2(-400, -300, 2080, 1320), Color(0.02, 0.015, 0.012))
	# a single candle, far off, and the ring drawn faintly in soot behind the words
	_sigil(Vector2(640, 360), 170.0, Color(0.35, 0.08, 0.05, 0.18 * title_k), 5.0)
	_candle(Vector2(640, 610), 60.0, 0.0)


# ---------------------------------------------------------------- 1. the King's hall
func _draw_hall() -> void:
	_stone_wall(Rect2(-300, -200, 1880, 800), Color(0.075, 0.062, 0.055), 18)
	# three tall windows, moonlight
	for x: float in [250.0, 640.0, 1030.0]:
		var r := Rect2(x - 60, 20, 120, 300)
		draw_colored_polygon(_arch(r), Color(0.1, 0.12, 0.18))
		draw_colored_polygon(_arch(r.grow(-10)), Color(0.16, 0.19, 0.28))
		draw_line(Vector2(x, 50), Vector2(x, 320), Color(0.05, 0.05, 0.06), 5.0)
		for yy: float in [150.0, 230.0]:
			draw_line(Vector2(x - 50, yy), Vector2(x + 50, yy), Color(0.05, 0.05, 0.06), 4.0)
	# pillars between them
	for x: float in [445.0, 835.0]:
		draw_rect(Rect2(x - 32, -200, 64, 800), Color(0.05, 0.042, 0.038))
		draw_rect(Rect2(x - 32, -200, 10, 800), Color(0.09, 0.075, 0.065))
	# banners
	for x: float in [120.0, 1160.0]:
		var sway := sin(_t * 0.8 + x) * 4.0
		var ban := PackedVector2Array([Vector2(x - 55, -20), Vector2(x + 55, -20), Vector2(x + 55 + sway, 380), Vector2(x + sway, 330), Vector2(x - 55 + sway, 380)])
		draw_colored_polygon(ban, Color(0.32, 0.03, 0.03))
		draw_polyline(PackedVector2Array([Vector2(x - 45, -20), Vector2(x - 45 + sway, 360)]), Color(0.5, 0.36, 0.1), 3.0)
		draw_polyline(PackedVector2Array([Vector2(x + 45, -20), Vector2(x + 45 + sway, 360)]), Color(0.5, 0.36, 0.1), 3.0)
		_crown(Vector2(x + sway * 0.5, 130), 30.0, Color(0.62, 0.46, 0.14))
	# the dais and throne
	var floor_c := Color(0.045, 0.036, 0.03)
	draw_rect(Rect2(-300, 560, 1880, 400), floor_c)
	for i in 3:
		draw_rect(Rect2(820 - i * 40, 520 + i * 20, 360 + i * 80, 22), Color(0.07, 0.057, 0.048))
	var tb := Vector2(1000, 520)
	draw_colored_polygon(PackedVector2Array([tb + Vector2(-80, 0), tb + Vector2(-80, -170), tb + Vector2(-60, -260), tb + Vector2(-40, -200),
		tb + Vector2(0, -300), tb + Vector2(40, -200), tb + Vector2(60, -260), tb + Vector2(80, -170), tb + Vector2(80, 0)]), Color(0.03, 0.022, 0.02))
	# the King: a shape of furs and a crown, one arm out, the commission in his hand
	var kc := Color(0.018, 0.014, 0.013)
	_glow(tb + Vector2(-20, -160), 150.0, Color(1.0, 0.45, 0.15, 0.25))
	draw_colored_polygon(PackedVector2Array([tb + Vector2(-58, 0), tb + Vector2(-50, -130), tb + Vector2(-30, -165), tb + Vector2(30, -165),
		tb + Vector2(50, -130), tb + Vector2(58, 0)]), kc)
	draw_circle(tb + Vector2(0, -185), 24.0, kc)
	_crown(tb + Vector2(0, -210), 22.0, Color(0.75, 0.56, 0.18))
	# firelight catching the edge of his furs and face
	draw_polyline(PackedVector2Array([tb + Vector2(-58, 0), tb + Vector2(-50, -130), tb + Vector2(-30, -165)]), Color(1.0, 0.5, 0.2, 0.55), 3.0, true)
	draw_arc(tb + Vector2(0, -185), 24.0, PI * 0.55, PI * 1.25, 12, Color(1.0, 0.5, 0.2, 0.55), 3.0, true)
	draw_circle(tb + Vector2(-9, -188), 2.0, Color(0.9, 0.7, 0.4, 0.8))
	var hand := tb + Vector2(-150, -110)
	draw_polyline(PackedVector2Array([tb + Vector2(-35, -150), tb + Vector2(-95, -125), hand]), kc, 16.0, true)
	# the scroll, and its seal
	draw_rect(Rect2(hand + Vector2(-44, -8), Vector2(46, 22)), Color(0.72, 0.64, 0.48))
	draw_circle(hand + Vector2(-44, 3), 11.0, Color(0.62, 0.55, 0.4))
	draw_circle(hand + Vector2(-22, 16), 9.0, Color(0.55, 0.05, 0.04))
	draw_rect(Rect2(hand + Vector2(-24, 14), Vector2(4, 22)), Color(0.45, 0.04, 0.03))
	# braziers
	for x: float in [720.0, 1280.0]:
		var bc := Vector2(x, 560)
		var flick := 0.85 + 0.15 * sin(_t * 9.0 + x) * sin(_t * 5.3 + x)
		_glow(bc + Vector2(0, -40), 260.0 * flick, Color(1.0, 0.45, 0.15, 0.4))
		draw_line(bc + Vector2(-20, 0), bc + Vector2(0, -60), Color(0.08, 0.06, 0.05), 6.0)
		draw_line(bc + Vector2(20, 0), bc + Vector2(0, -60), Color(0.08, 0.06, 0.05), 6.0)
		draw_colored_polygon(PackedVector2Array([bc + Vector2(-34, -70), bc + Vector2(34, -70), bc + Vector2(22, -50), bc + Vector2(-22, -50)]), Color(0.1, 0.07, 0.05))
		_flame(bc + Vector2(0, -70), 46.0 * flick, 26.0, x)
	# him, kneeling, hood down, maps on his back
	var mc := Color(0.012, 0.01, 0.01)
	var kb := Vector2(560, 600)
	draw_colored_polygon(PackedVector2Array([kb + Vector2(-90, 0), kb + Vector2(-70, -60), kb + Vector2(-40, -130), kb + Vector2(0, -150),
		kb + Vector2(30, -120), kb + Vector2(50, -60), kb + Vector2(80, -40), kb + Vector2(90, 0)]), mc)
	draw_circle(kb + Vector2(10, -168), 26.0, mc)
	for i in 3:
		draw_line(kb + Vector2(-60 + i * 12, -110), kb + Vector2(-100 + i * 14, -210), Color(0.35, 0.3, 0.22), 9.0)
		draw_circle(kb + Vector2(-100 + i * 14, -210), 5.5, Color(0.5, 0.44, 0.32))
	draw_polyline(PackedVector2Array([kb + Vector2(20, -120), kb + Vector2(70, -110), kb + Vector2(100, -120)]), mc, 13.0, true)
	# rim light from the braziers
	draw_polyline(PackedVector2Array([kb + Vector2(30, -120), kb + Vector2(50, -60), kb + Vector2(80, -40)]), Color(1.0, 0.5, 0.2, 0.45), 3.0, true)


func _crown(c: Vector2, w: float, col: Color) -> void:
	var pts := PackedVector2Array([c + Vector2(-w, w * 0.5), c + Vector2(-w, -w * 0.3), c + Vector2(-w * 0.5, w * 0.05), c + Vector2(0, -w * 0.6),
		c + Vector2(w * 0.5, w * 0.05), c + Vector2(w, -w * 0.3), c + Vector2(w, w * 0.5)])
	draw_colored_polygon(pts, col)


# ---------------------------------------------------------------- 2. the chart
func _draw_chart() -> void:
	draw_rect(Rect2(-300, -200, 1880, 1120), Color(0.05, 0.035, 0.025))     # the table
	var sheet := Rect2(60, 60, 1160, 600)
	draw_rect(Rect2(sheet.position + Vector2(10, 12), sheet.size), Color(0, 0, 0, 0.5))
	draw_rect(sheet, Color(0.66, 0.56, 0.4))
	for i in 60:            # stains and foxing
		var p := sheet.position + Vector2(Ink.hash2(i, 1.0), Ink.hash2(i, 2.0)) * sheet.size
		draw_circle(p, 10.0 + Ink.hash2(i, 3.0) * 60.0, Color(0.35, 0.25, 0.14, 0.05))
	# the west edge: scorched, and darker, as if nobody dared to finish it
	for i in 30:
		draw_rect(Rect2(sheet.position, Vector2(260 - i * 8, sheet.size.y)), Color(0.12, 0.07, 0.04, 0.03))
	var ink := Color(0.2, 0.12, 0.07)
	# rhumb lines from a compass rose
	var rose := Vector2(850, 330)
	for i in 16:
		var d := Vector2.from_angle(TAU * i / 16.0)
		draw_line(rose, rose + d * 900.0, Color(ink, 0.18), 1.0)
	for i in 8:
		var a := TAU * i / 8.0
		var tip := rose + Vector2.from_angle(a) * (60.0 if i % 2 == 0 else 34.0)
		var l := rose + Vector2.from_angle(a + 0.3) * 12.0
		var r := rose + Vector2.from_angle(a - 0.3) * 12.0
		draw_colored_polygon(PackedVector2Array([l, tip, r]), Color(0.45, 0.06, 0.04) if i % 2 == 0 else ink)
	draw_arc(rose, 20.0, 0, TAU, 24, ink, 2.0)
	# the known coast, to the east
	var coast := PackedVector2Array()
	for i in 40:
		var y := sheet.position.y + i * sheet.size.y / 39.0
		var x := 1000.0 + 60.0 * sin(i * 0.7) + 30.0 * sin(i * 2.3) + 20.0 * Ink.hash2(i, 5.0)
		coast.append(Vector2(x, y))
	var land := coast.duplicate()
	land.append(Vector2(sheet.end.x, sheet.end.y))
	land.append(Vector2(sheet.end.x, sheet.position.y))
	draw_colored_polygon(land, Color(0.58, 0.47, 0.31))
	draw_polyline(coast, ink, 2.5, true)
	for i in 6:              # hills and a castle, small
		var p := Vector2(1100 + Ink.hash2(i, 7.0) * 90.0, 120 + i * 85)
		draw_colored_polygon(PackedVector2Array([p + Vector2(-14, 8), p + Vector2(0, -10), p + Vector2(14, 8)]), Color(ink, 0.7))
	var cast := Vector2(1130, 360)
	draw_rect(Rect2(cast + Vector2(-16, -20), Vector2(32, 26)), ink)
	for i in 3:
		draw_rect(Rect2(cast + Vector2(-18 + i * 14, -32), Vector2(8, 12)), ink)
	draw_string(_fell_i, cast + Vector2(-60, 40), "Regnum", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, ink)
	# a ship, a serpent
	var sh := Vector2(700, 520)
	draw_colored_polygon(PackedVector2Array([sh + Vector2(-26, 0), sh + Vector2(26, 0), sh + Vector2(18, 10), sh + Vector2(-18, 10)]), ink)
	draw_line(sh, sh + Vector2(0, -34), ink, 2.0)
	draw_colored_polygon(PackedVector2Array([sh + Vector2(2, -32), sh + Vector2(20, -20), sh + Vector2(2, -8)]), Color(ink, 0.8))
	var sp := PackedVector2Array()
	for i in 30:
		sp.append(Vector2(470 + i * 8, 180 + sin(i * 0.8 + _t * 0.5) * 12.0))
	draw_polyline(sp, ink, 4.0, true)
	draw_circle(sp[sp.size() - 1] + Vector2(6, 0), 7.0, ink)
	# the isle: only a dotted guess, and the ring and eye
	var isle := Vector2(250, 360)
	var pts := PackedVector2Array()
	for i in 36:
		var a := TAU * i / 36.0
		pts.append(isle + Vector2(cos(a) * (70 + 16 * sin(a * 3.0)), sin(a) * (48 + 10 * sin(a * 5.0))))
	for i in range(0, pts.size(), 2):
		draw_line(pts[i], pts[(i + 1) % pts.size()], Color(ink, 0.6), 2.0)
	_sigil(isle, 26.0, Color(0.45, 0.05, 0.04, 0.85), 2.0)
	# the warning, written in red as we watch
	var warn := "Hic habitat Custos"
	var n := int(ceil(warn.length() * ink_k))
	draw_string(_fell_i, Vector2(110, 520), warn.substr(0, n), HORIZONTAL_ALIGNMENT_LEFT, -1, 40, Color(0.5, 0.05, 0.04, 0.9))
	# a candle burning at the corner of the table, and the quill
	_candle(Vector2(1180, 700), 80.0, 1.0)
	draw_line(Vector2(520, 690), Vector2(640, 610), Color(0.85, 0.82, 0.74), 3.0)
	draw_colored_polygon(PackedVector2Array([Vector2(640, 610), Vector2(610, 616), Vector2(600, 640), Vector2(630, 628)]), Color(0.8, 0.77, 0.7))


# ---------------------------------------------------------------- 3. the drowned journal
func _draw_journal() -> void:
	for i in 14:          # a grey dawn
		var y := -200.0 + i * 30.0
		draw_rect(Rect2(-300, y, 1880, 31), Color(0.1, 0.11, 0.13).lerp(Color(0.2, 0.2, 0.21), float(i) / 13.0))
	draw_rect(Rect2(-300, 220, 1880, 140), Color(0.06, 0.07, 0.08))      # the sea
	for i in 7:
		var pts := PackedVector2Array()
		for j in 60:
			var x := -300.0 + j * 32.0
			pts.append(Vector2(x, 235 + i * 18 + sin(x * 0.02 + _t * (0.8 + i * 0.1) + i) * 4.0))
		draw_polyline(pts, Color(0.35, 0.37, 0.4, 0.35), 1.5, true)
	# sand, and the wet line where the sea just was
	draw_rect(Rect2(-300, 350, 1880, 700), Color(0.2, 0.17, 0.13))
	var wet := 360.0 + sin(_t * 0.6) * 10.0
	draw_rect(Rect2(-300, 350, 1880, wet - 350.0 + 25.0), Color(0.13, 0.11, 0.09))
	var foam := PackedVector2Array()
	for j in 60:
		var x := -300.0 + j * 32.0
		foam.append(Vector2(x, wet + 25.0 + sin(x * 0.05 + _t) * 5.0))
	draw_polyline(foam, Color(0.7, 0.72, 0.72, 0.5), 2.0, true)
	# kelp
	for i in 5:
		var p := Vector2(200 + i * 230, 470 + Ink.hash2(i, 1.0) * 150.0)
		var kelp := PackedVector2Array()
		for j in 8:
			kelp.append(p + Vector2(j * 14, sin(j * 1.2 + i) * 10.0))
		draw_polyline(kelp, Color(0.1, 0.12, 0.06), 5.0, true)
	# the book, open, swollen, the ink run
	var bc := Vector2(640, 520)
	var book := Transform2D(-0.08, bc)
	draw_set_transform_matrix(_cam_xf() * book)
	draw_colored_polygon(PackedVector2Array([Vector2(-260, -140), Vector2(260, -140), Vector2(270, 150), Vector2(-270, 150)]), Color(0.18, 0.1, 0.06))
	var lp := Rect2(-250, -130, 245, 270)
	var rp := Rect2(5, -130, 245, 270)
	for pg: Rect2 in [lp, rp]:
		draw_rect(pg, Color(0.62, 0.55, 0.42))
		for i in 12:
			var p := pg.position + Vector2(Ink.hash2(i + pg.position.x, 4.0), Ink.hash2(i, 5.0 + pg.position.x)) * pg.size
			draw_circle(p, 14.0 + Ink.hash2(i, 6.0) * 40.0, Color(0.3, 0.22, 0.14, 0.12))
	draw_line(Vector2(0, -130), Vector2(0, 140), Color(0.2, 0.13, 0.08), 3.0)
	# left page: the labyrinth, drawn in a shaking hand
	var n := _maze.size()
	var cs := 230.0 / float(n - 1)
	var o := lp.position + Vector2(8, 20)
	var mink := Color(0.16, 0.09, 0.07, 0.85)
	for y in n:
		for x in _maze[y].length():
			if (x % 2 == 0) == (y % 2 == 0):
				continue
			if _maze[y][x] in ["#", "h", "F", "I", "T", "K", "Q", "B", "X"]:
				var a: Vector2
				var b: Vector2
				if y % 2 == 0:
					a = o + Vector2(x - 1, y) * cs
					b = o + Vector2(x + 1, y) * cs
				else:
					a = o + Vector2(x, y - 1) * cs
					b = o + Vector2(x, y + 1) * cs
				var j := Vector2(Ink.hash2(x, y) - 0.5, Ink.hash2(y, x) - 0.5) * 1.2
				draw_line(a + j, b - j, mink, 1.6, true)
	# right page: the ring and the eye, scribbled lines, and the last words
	_sigil(rp.position + Vector2(122, 80), 48.0, Color(0.42, 0.06, 0.04, 0.9), 3.0)
	for i in 5:
		var y := rp.position.y + 160 + i * 14
		var w := 180.0 - Ink.hash2(i, 9.0) * 60.0
		var sc := PackedVector2Array()
		for j in 20:
			sc.append(Vector2(rp.position.x + 30 + j * w / 19.0, y + sin(j * 2.1 + i) * 2.0))
		draw_polyline(sc, Color(0.18, 0.1, 0.07, 0.5), 1.2, true)
	draw_string(_hand, rp.position + Vector2(18, 255), "It does not want to be drawn.   — E. Vane", HORIZONTAL_ALIGNMENT_LEFT, 220, 17, Color(0.3, 0.06, 0.04, 0.95))
	draw_set_transform_matrix(_cam_xf())


func _cam_xf() -> Transform2D:
	var s := size
	var k := maxf(s.x / 1280.0, s.y / 720.0) * cam_zoom
	return Transform2D(0.0, Vector2(k, k), 0.0, s / 2.0 - cam_center * k)


# ---------------------------------------------------------------- 4. the Codex, and the thing in the glass
func _draw_codex() -> void:
	_stone_wall(Rect2(-300, -300, 1880, 1100), Color(0.06, 0.05, 0.047), 22)
	# the great window
	var win := Rect2(440, -60, 400, 560)
	draw_colored_polygon(_arch(win.grow(22)), Color(0.035, 0.03, 0.03))
	var glass := _arch(win)
	draw_colored_polygon(glass, Color(0.08, 0.06, 0.1))
	# panes of dim colour
	for j in 14:
		for i in 8:
			var p := win.position + Vector2(i * 50 + 25, j * 40 + 60)
			var hue := Ink.hash2(i * 3 + j, 2.0)
			var col := Color(0.2, 0.05, 0.06) if hue < 0.4 else (Color(0.06, 0.09, 0.2) if hue < 0.75 else Color(0.18, 0.14, 0.05))
			draw_rect(Rect2(p - Vector2(24, 19), Vector2(48, 38)), Color(col, 0.55))
	# the Warden, leaded into the glass: wings, arms, the skull and its beard
	var c := Vector2(640, 250)
	var body := Color(0.02, 0.018, 0.02)
	for s: float in [-1.0, 1.0]:
		var wing := PackedVector2Array([c + Vector2(s * 30, -30), c + Vector2(s * 180, -170), c + Vector2(s * 170, -60),
			c + Vector2(s * 150, -40), c + Vector2(s * 145, 20), c + Vector2(s * 120, 0), c + Vector2(s * 110, 60), c + Vector2(s * 40, 40)])
		draw_colored_polygon(wing, body)
		for f: Vector2 in [Vector2(180, -170), Vector2(170, -60), Vector2(145, 20), Vector2(110, 60)]:
			draw_line(c + Vector2(s * 30, -30), c + Vector2(s * f.x, f.y), Color(0.1, 0.06, 0.06), 3.0)
		draw_polyline(PackedVector2Array([c + Vector2(s * 50, 40), c + Vector2(s * 90, 120), c + Vector2(s * 80, 200), c + Vector2(s * 100, 230)]), body, 18.0, true)
	draw_colored_polygon(PackedVector2Array([c + Vector2(-70, -25), c + Vector2(70, -25), c + Vector2(58, 60), c + Vector2(36, 150),
		c + Vector2(-36, 150), c + Vector2(-58, 60)]), body)
	for i in 6:     # it stands on coils, not feet
		var x0 := -30.0 + i * 12.0
		var coil := PackedVector2Array()
		for j in 10:
			coil.append(c + Vector2(x0 + (x0 * 0.12) * j + sin(_t * 1.1 + i * 1.7 + j * 0.5) * 6.0, 140 + j * 16))
		draw_polyline(coil, body, 12.0 - (i % 3) * 2.0, true)
	draw_colored_polygon(PackedVector2Array([c + Vector2(-38, -40), c + Vector2(-30, -120), c + Vector2(0, -150), c + Vector2(30, -120), c + Vector2(38, -40)]), body)
	for i in 7:
		var x := -30.0 + i * 10.0
		var tent := PackedVector2Array()
		for j in 8:
			tent.append(c + Vector2(x + sin(_t * 1.5 + i + j * 0.6) * 4.0 * j * 0.3, -40 + j * 13))
		draw_polyline(tent, body, 6.0 - i % 2, true)
	# its eyes, glowing through the glass
	var glow_a := 0.25 + 0.75 * eyes_k * (0.8 + 0.2 * sin(_t * 3.0))
	for s: float in [-1.0, 1.0]:
		var e := c + Vector2(s * 14, -62)
		_glow(e, 40.0 * (0.5 + eyes_k), Color(1.0, 0.1, 0.05, 0.5 * glow_a), 10)
		draw_colored_polygon(PackedVector2Array([e + Vector2(-8, 0), e + Vector2(0, -3), e + Vector2(8, 0), e + Vector2(0, 3)]), Color(1.0, 0.25, 0.1, glow_a))
	# lead lines over it all
	for i in 9:
		draw_line(Vector2(win.position.x + i * 50, win.position.y + 100), Vector2(win.position.x + i * 50, win.end.y), Color(0.02, 0.02, 0.02, 0.8), 3.0)
	for j in 12:
		draw_line(Vector2(win.position.x, win.position.y + 140 + j * 40), Vector2(win.end.x, win.position.y + 140 + j * 40), Color(0.02, 0.02, 0.02, 0.8), 3.0)
	var outline := glass.duplicate()
	outline.append(outline[0])
	draw_polyline(outline, Color(0.02, 0.02, 0.02), 8.0, true)
	# the ring and the eye cut in the stone above
	_sigil(Vector2(640, -110), 34.0, Color(0.5, 0.42, 0.3, 0.5), 4.0)
	# the floor, the lectern, the chained book, candles
	draw_rect(Rect2(-300, 540, 1880, 500), Color(0.04, 0.033, 0.03))
	var lec := Vector2(640, 700)
	draw_colored_polygon(PackedVector2Array([lec + Vector2(-30, 0), lec + Vector2(-20, -120), lec + Vector2(20, -120), lec + Vector2(30, 0)]), Color(0.08, 0.05, 0.035))
	draw_colored_polygon(PackedVector2Array([lec + Vector2(-130, -110), lec + Vector2(130, -110), lec + Vector2(110, -150), lec + Vector2(-110, -150)]), Color(0.1, 0.065, 0.04))
	draw_colored_polygon(PackedVector2Array([lec + Vector2(-115, -150), lec + Vector2(0, -145), lec + Vector2(115, -150), lec + Vector2(105, -172), lec + Vector2(0, -166), lec + Vector2(-105, -172)]), Color(0.66, 0.58, 0.44))
	draw_line(lec + Vector2(0, -145), lec + Vector2(0, -166), Color(0.3, 0.22, 0.15), 2.0)
	for i in 3:
		draw_line(lec + Vector2(-95, -160 + i * 5), lec + Vector2(-20, -158 + i * 5), Color(0.2, 0.12, 0.08, 0.5), 1.0)
		draw_line(lec + Vector2(20, -158 + i * 5), lec + Vector2(95, -160 + i * 5), Color(0.2, 0.12, 0.08, 0.5), 1.0)
	draw_circle(lec + Vector2(-80, -164), 5.0, Color(0.5, 0.05, 0.04))
	# the chain, hanging from the book's spine to a ring in the floor
	for i in 14:
		var p := lec + Vector2(-110 - i * 6, -140 + i * 10 + sin(i * 0.4) * 4)
		draw_arc(p, 5.0, 0, TAU, 10, Color(0.25, 0.22, 0.2), 2.0)
	_candle(Vector2(470, 690), 90.0, 2.0)
	_candle(Vector2(810, 690), 70.0, 3.0)


# ---------------------------------------------------------------- 5. the voyage
func _draw_voyage() -> void:
	for i in 16:
		var y := -200.0 + i * 30.0
		draw_rect(Rect2(-300, y, 1880, 31), Color(0.02, 0.025, 0.04).lerp(Color(0.06, 0.07, 0.1), float(i) / 15.0))
	var moon := Vector2(930, 110)
	_glow(moon, 200.0, Color(0.7, 0.75, 0.9, 0.35))
	draw_circle(moon, 38.0, Color(0.78, 0.8, 0.86))
	draw_circle(moon + Vector2(10, -6), 34.0, Color(0.72, 0.75, 0.82))
	for i in 5:          # clouds drifting over it
		var cx := fmod(-200.0 + i * 380.0 + _t * 8.0, 1900.0) - 300.0
		var cy := 70.0 + i * 25.0
		for j in 5:
			draw_circle(Vector2(cx + j * 50, cy + sin(j) * 8.0), 40.0 - absf(j - 2.0) * 8.0, Color(0.03, 0.035, 0.05, 0.85))
	var horizon := 280.0
	draw_rect(Rect2(-300, horizon, 1880, 800), Color(0.035, 0.045, 0.06))
	for i in 6:          # the moon's path on the water
		var w := 150.0 - i * 22.0
		draw_rect(Rect2(930 - w / 2.0, horizon, w, 420), Color(0.2, 0.22, 0.28, 0.035))
	# the thing beneath: a vast shape, arms spread, two dim eyes
	var deep := Vector2(640, 560)
	var dc := Color(0.0, 0.0, 0.0, 0.7)
	draw_colored_polygon(PackedVector2Array([deep + Vector2(-160, -40), deep + Vector2(0, -90), deep + Vector2(160, -40), deep + Vector2(120, 60), deep + Vector2(-120, 60)]), dc)
	for i in 8:
		var a := -PI + i * PI / 7.0
		var arm := PackedVector2Array()
		for j in 12:
			var r := 80.0 + j * 38.0
			arm.append(deep + Vector2(cos(a + sin(_t * 0.4 + i + j * 0.3) * 0.15) * r * 1.6, sin(a) * r * 0.3 + 40 + j * 4))
		draw_polyline(arm, dc, 30.0 - 2.0 * (i % 3), true)
	for s: float in [-1.0, 1.0]:
		var e := deep + Vector2(s * 40, -40)
		_glow(e, 30.0, Color(0.9, 0.08, 0.04, 0.45 * eyes_k), 8)
		draw_circle(e, 3.0, Color(1.0, 0.2, 0.08, 0.7 * eyes_k))
	# the waves over it
	for i in 16:
		var pts := PackedVector2Array()
		for j in 50:
			var x := -300.0 + j * 40.0
			pts.append(Vector2(x, horizon + i * i * 1.8 + 6 + sin(x * 0.012 + _t * (0.6 + i * 0.05) + i * 1.3) * (2.0 + i * 0.8)))
		draw_polyline(pts, Color(0.25, 0.3, 0.4, 0.28 - i * 0.012), 1.5 + i * 0.12, true)
	# the ship: a cog, one sail, a lantern at the stern
	var sh := Vector2(620, horizon + 70 + sin(_t * 0.9) * 5.0)
	var roll := sin(_t * 0.7) * 0.05
	draw_set_transform_matrix(_cam_xf() * Transform2D(roll, sh))
	var hull := Color(0.012, 0.01, 0.01)
	draw_colored_polygon(PackedVector2Array([Vector2(-130, -20), Vector2(130, -30), Vector2(100, 20), Vector2(-100, 20)]), hull)
	draw_line(Vector2(-130, -20), Vector2(130, -30), Color(0.55, 0.6, 0.7, 0.4), 2.0)
	draw_line(Vector2(0, -20), Vector2(0, -230), hull, 6.0)
	draw_colored_polygon(PackedVector2Array([Vector2(-80, -210), Vector2(80, -210), Vector2(90, -70), Vector2(-90, -70)]), Color(0.13, 0.12, 0.115))
	draw_line(Vector2(80, -210), Vector2(90, -70), Color(0.6, 0.65, 0.75, 0.5), 3.0)
	draw_line(Vector2(-85, -212), Vector2(85, -212), hull, 5.0)
	_sigil(Vector2(0, -140), 26.0, Color(0.3, 0.06, 0.04, 0.6), 2.5)
	draw_rect(Rect2(Vector2(-125, -60), Vector2(40, 40)), hull)
	draw_rect(Rect2(Vector2(90, -64), Vector2(40, 36)), hull)
	var lamp := Vector2(-110, -76)
	_glow(lamp, 90.0 * (0.9 + 0.1 * sin(_t * 8.0)), Color(1.0, 0.6, 0.25, 0.5))
	draw_circle(lamp, 5.0, Color(1.0, 0.8, 0.4))
	draw_set_transform_matrix(_cam_xf())
	if chart_k > 0.0:
		_draw_chart_dissolve()


# ---------------------------------------------------------------- 6. the camp
func _draw_camp() -> void:
	for i in 18:
		var y := -200.0 + i * 40.0
		draw_rect(Rect2(-300, y, 1880, 41), Color(0.02, 0.025, 0.03).lerp(Color(0.07, 0.05, 0.045), float(i) / 17.0))
	for layer in 2:
		var col := Color(0.03, 0.035, 0.03) if layer == 0 else Color(0.015, 0.018, 0.015)
		var pts := PackedVector2Array([Vector2(-300, 720)])
		for i in 110:
			var x := -300.0 + i * 18.0
			var h := (110.0 + layer * 40.0) * (0.6 + 0.4 * sin(x * 0.011 + layer * 2.0) * sin(x * 0.041 + layer)) + 30.0 * absf(sin(x * 0.08 + layer))
			pts.append(Vector2(x, 330.0 + layer * 60.0 - h))
		pts.append(Vector2(1700, 720))
		draw_colored_polygon(pts, col)
	draw_rect(Rect2(-300, 450, 1880, 600), Color(0.06, 0.045, 0.035))
	var fire := Vector2(700, 560)
	var flick := 0.85 + 0.15 * sin(_t * 11.0) * sin(_t * 7.3 + 1.0)
	_glow(fire + Vector2(0, -20), 520.0 * flick * (0.4 + 0.6 * fire_k), Color(1.0, 0.42, 0.14, 0.55 * fire_k), 18)
	# tents and sleepers
	for tx: float in [330.0, 1020.0]:
		var base := Vector2(tx, 500)
		draw_colored_polygon(PackedVector2Array([base + Vector2(-95, 0), base + Vector2(0, -100), base + Vector2(95, 0)]), Color(0.13, 0.1, 0.075))
		draw_colored_polygon(PackedVector2Array([base + Vector2(-20, 0), base + Vector2(0, -42), base + Vector2(20, 0)]), Color(0.03, 0.025, 0.02))
	for p: Vector2 in [Vector2(930, 600), Vector2(820, 665), Vector2(380, 610)]:
		draw_rect(Rect2(p + Vector2(-70, -16), Vector2(140, 32)), Color(0.1, 0.075, 0.055))
		draw_circle(p + Vector2(-72, -2), 16.0, Color(0.1, 0.075, 0.055))
		draw_line(p + Vector2(-70, -16), p + Vector2(70, -16), Color(1.0, 0.5, 0.2, 0.35 * fire_k), 2.0)
	# him, hunched over the map on his knees, the pen in his hand
	var mc := Color(0.03, 0.022, 0.018)
	var b := Vector2(560, 600)
	var nod := (1.0 - fire_k) * 16.0
	draw_colored_polygon(PackedVector2Array([b + Vector2(-50, 10), b + Vector2(-44, -70), b + Vector2(-24, -110), b + Vector2(4, -118 + nod * 0.5),
		b + Vector2(28, -96), b + Vector2(40, -40), b + Vector2(44, 10)]), mc)
	draw_circle(b + Vector2(18, -132 + nod), 21.0, mc)
	draw_polyline(PackedVector2Array([b + Vector2(4, -118 + nod * 0.5), b + Vector2(28, -96), b + Vector2(40, -40)]), Color(1.0, 0.5, 0.2, 0.6 * fire_k), 3.0, true)
	draw_arc(b + Vector2(18, -132 + nod), 21.0, -1.3, 0.9, 12, Color(1.0, 0.5, 0.2, 0.6 * fire_k), 3.0, true)
	draw_colored_polygon(PackedVector2Array([b + Vector2(-20, -30), b + Vector2(110, -18), b + Vector2(120, 8), b + Vector2(-20, 6)]), mc)
	var mp := Rect2(b + Vector2(30, -52), Vector2(96, 60))
	draw_set_transform_matrix(_cam_xf() * Transform2D(0.12, mp.get_center()) * Transform2D(0.0, -mp.get_center()))
	draw_rect(mp, Color(0.62, 0.52, 0.36))
	draw_rect(mp, Color(1.0, 0.55, 0.25, 0.18 * fire_k))
	for i in 6:
		draw_line(mp.position + Vector2(8, 10 + i * 8), mp.position + Vector2(40 + Ink.hash2(i, 1.0) * 45.0, 12 + i * 8), Color(0.2, 0.12, 0.08, 0.7), 1.2)
	draw_set_transform_matrix(_cam_xf())
	draw_polyline(PackedVector2Array([b + Vector2(24, -96), b + Vector2(60, -60), b + Vector2(84, -40)]), mc, 10.0, true)
	draw_line(b + Vector2(84, -40), b + Vector2(96, -62), Color(0.8, 0.78, 0.7), 2.0)
	# the fire
	for a: float in [0.4, -0.4, 1.2]:
		var d := Vector2.from_angle(a) * 42.0
		draw_line(fire - d + Vector2(0, 10), fire + d + Vector2(0, 10), Color(0.16, 0.09, 0.05), 10.0)
	for i in 9:
		draw_circle(fire + Vector2.from_angle(TAU * i / 9.0) * Vector2(54, 20) + Vector2(0, 14), 9.0, Color(0.12, 0.1, 0.09))
	_flame(fire, 70.0 * fire_k * flick, 36.0, 0.0, clampf(fire_k * 1.5, 0.0, 1.0))
	for i in 10:
		var ph := fmod(_t * 0.5 + i * 0.37, 1.0)
		draw_circle(fire + Vector2(sin(i * 3.3 + _t) * 24.0, -20.0 - ph * 200.0), 2.0 * (1.0 - ph), Color(1.0, 0.6, 0.2, (1.0 - ph) * fire_k))



## The sea becoming the chart: parchment washes over the picture, and the
## ship is left as a little inked mark with its course dotted behind it.
func _draw_chart_dissolve() -> void:
	var a := chart_k
	draw_rect(Rect2(-300, -200, 1880, 1120), Color(0.62, 0.55, 0.42, a * 0.96))
	for i in 30:
		var p := Vector2(Ink.hash2(i, 1.0) * 1280.0, Ink.hash2(i, 2.0) * 720.0)
		draw_circle(p, 20.0 + Ink.hash2(i, 3.0) * 70.0, Color(0.35, 0.25, 0.14, 0.05 * a))
	var ink := Color(0.2, 0.12, 0.07, a)
	var rose := Vector2(640, 400)
	for i in 16:
		draw_line(rose, rose + Vector2.from_angle(TAU * i / 16.0) * 900.0, Color(ink, 0.2 * a), 1.0)
	# the course so far, dotted, and the ship at the end of it
	var sh := Vector2(700, 370)
	for i in 14:
		var p := sh + Vector2(-40 - i * 26, 30 + sin(i * 0.6) * 18.0)
		draw_circle(p, 2.2, Color(0.5, 0.08, 0.05, a))
	draw_colored_polygon(PackedVector2Array([sh + Vector2(-16, 0), sh + Vector2(16, 0), sh + Vector2(10, 7), sh + Vector2(-10, 7)]), ink)
	draw_line(sh, sh + Vector2(0, -22), ink, 2.0)
	draw_colored_polygon(PackedVector2Array([sh + Vector2(1, -20), sh + Vector2(13, -12), sh + Vector2(1, -5)]), Color(ink, 0.8 * a))
	# the western edge: blank, and the warning
	for i in 20:
		draw_rect(Rect2(-300, -200, 520 - i * 14, 1120), Color(0.12, 0.07, 0.04, 0.03 * a))
	draw_string(_fell_i, Vector2(120, 250), "Hic habitat Custos", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color(0.5, 0.05, 0.04, 0.85 * a))


# ---------------------------------------------------------------- 5a. the harbour at Saltmere
func _draw_harbour() -> void:
	for i in 16:          # a cold dawn
		var y := -200.0 + i * 32.0
		draw_rect(Rect2(-300, y, 1880, 33), Color(0.06, 0.07, 0.1).lerp(Color(0.3, 0.27, 0.26), float(i) / 15.0))
	# the town behind: roofs, a spire, the castle on its hill
	var town := Color(0.07, 0.07, 0.085)
	var pts := PackedVector2Array([Vector2(-300, 420)])
	for i in 60:
		var x := -300.0 + i * 20.0
		var h := 40.0 + 30.0 * absf(sin(i * 1.7)) + 20.0 * Ink.hash2(i, 4.0)
		pts.append(Vector2(x, 360 - h))
		pts.append(Vector2(x + 10, 360 - h - 14))
	pts.append(Vector2(900, 420))
	draw_colored_polygon(pts, town)
	draw_colored_polygon(PackedVector2Array([Vector2(180, 330), Vector2(200, 170), Vector2(220, 330)]), town)       # the spire
	draw_rect(Rect2(Vector2(20, 240), Vector2(120, 110)), town)                                                   # the castle
	for i in 4:
		draw_rect(Rect2(Vector2(14 + i * 34, 222), Vector2(18, 20)), town)
	for i in 7:           # a few lit windows
		draw_rect(Rect2(Vector2(40 + i * 110 + Ink.hash2(i, 1.0) * 40.0, 300 + Ink.hash2(i, 2.0) * 40.0), Vector2(5, 7)), Color(1.0, 0.7, 0.35, 0.7))
	# the water
	draw_rect(Rect2(-300, 400, 1880, 700), Color(0.05, 0.06, 0.07))
	for i in 10:
		var wl := PackedVector2Array()
		for j in 50:
			var x := -300.0 + j * 40.0
			wl.append(Vector2(x, 420 + i * i * 3.0 + sin(x * 0.02 + _t * (0.7 + i * 0.05) + i) * (1.5 + i * 0.4)))
		draw_polyline(wl, Color(0.35, 0.37, 0.4, 0.22), 1.3, true)
	# the quay
	var quay := Color(0.1, 0.09, 0.085)
	draw_colored_polygon(PackedVector2Array([Vector2(-300, 470), Vector2(640, 470), Vector2(640, 520), Vector2(-300, 520)]), quay)
	draw_rect(Rect2(Vector2(-300, 520), Vector2(940, 400)), Color(0.07, 0.065, 0.06))
	for i in 18:
		draw_line(Vector2(-300 + i * 55, 470), Vector2(-300 + i * 55, 520), Color(0.05, 0.045, 0.04), 2.0)
	# a lantern on its post
	var lp := Vector2(520, 360)
	draw_line(lp, lp + Vector2(0, 110), Color(0.05, 0.04, 0.035), 6.0)
	_glow(lp, 120.0 * (0.9 + 0.1 * sin(_t * 7.0)), Color(1.0, 0.6, 0.25, 0.45))
	draw_circle(lp, 6.0, Color(1.0, 0.8, 0.45))
	# the ship at its mooring, sail furled
	var sh := Vector2(900, 470 + sin(_t * 0.8) * 3.0)
	var hull := Color(0.03, 0.025, 0.025)
	draw_colored_polygon(PackedVector2Array([sh + Vector2(-200, -40), sh + Vector2(220, -60), sh + Vector2(170, 30), sh + Vector2(-160, 30)]), hull)
	draw_rect(Rect2(sh + Vector2(-210, -95), Vector2(80, 60)), hull)
	draw_rect(Rect2(sh + Vector2(150, -110), Vector2(80, 60)), hull)
	draw_line(sh + Vector2(0, -40), sh + Vector2(0, -330), hull, 8.0)
	draw_line(sh + Vector2(-130, -300), sh + Vector2(130, -300), hull, 6.0)
	draw_colored_polygon(PackedVector2Array([sh + Vector2(-125, -300), sh + Vector2(125, -300), sh + Vector2(110, -280), sh + Vector2(-110, -280)]), Color(0.16, 0.14, 0.12))
	for r in [Vector2(-200, -40), Vector2(220, -60)]:
		draw_line(sh + Vector2(0, -330), sh + r, Color(0.06, 0.05, 0.05), 1.5)
	draw_line(sh + Vector2(-200, -40), sh + Vector2(220, -60), Color(0.55, 0.5, 0.45, 0.3), 2.0)
	var stern := sh + Vector2(-190, -100)
	_glow(stern, 70.0, Color(1.0, 0.6, 0.25, 0.4))
	draw_circle(stern, 4.0, Color(1.0, 0.8, 0.45))
	# the gangplank, and him on it — map-cases on his back
	var g0 := Vector2(620, 470)
	var g1 := sh + Vector2(-150, -40)
	draw_line(g0, g1, Color(0.16, 0.12, 0.09), 8.0)
	var me := g0.lerp(g1, 0.45)
	var mc := Color(0.01, 0.01, 0.01)
	draw_colored_polygon(PackedVector2Array([me + Vector2(-18, -4), me + Vector2(-14, -70), me + Vector2(0, -84), me + Vector2(14, -70), me + Vector2(18, -4)]), mc)
	draw_circle(me + Vector2(0, -96), 13.0, mc)
	for i in 2:
		draw_line(me + Vector2(-10 + i * 7, -60), me + Vector2(-26 + i * 8, -118), Color(0.35, 0.3, 0.22), 6.0)
	draw_line(me + Vector2(-8, -4), me + Vector2(-14, 10), mc, 5.0)
	draw_line(me + Vector2(8, -4), me + Vector2(14, 8), mc, 5.0)
	# gulls
	for i in 4:
		var gp := Vector2(fmod(300.0 + i * 260.0 + _t * (18.0 + i * 3.0), 1600.0) - 200.0, 120 + i * 30 + sin(_t + i) * 10.0)
		var flap := sin(_t * 6.0 + i) * 5.0
		draw_polyline(PackedVector2Array([gp + Vector2(-12, flap), gp, gp + Vector2(12, flap)]), Color(0.08, 0.08, 0.09), 2.0, true)


# ---------------------------------------------------------------- arrival 1. the isle at dawn
func _draw_isle() -> void:
	for i in 18:          # dawn: bruised blue into a thin, sickly gold
		var y := -200.0 + i * 30.0
		var f := float(i) / 17.0
		draw_rect(Rect2(-300, y, 1880, 31), Color(0.05, 0.06, 0.1).lerp(Color(0.5, 0.36, 0.22), f * f))
	var sun := Vector2(760, 330)
	_glow(sun, 420.0, Color(1.0, 0.7, 0.35, 0.35))
	var horizon := 360.0
	# the isle: cliffs rising out of the sea, jungle on the slopes, the plateau
	var rock := Color(0.035, 0.035, 0.04)
	var isle := PackedVector2Array([Vector2(150, horizon + 10)])
	var prof := [[150, 0], [200, 60], [260, 90], [330, 150], [400, 170], [470, 230], [520, 250], [560, 255], [640, 258], [720, 256], [780, 250], [830, 225], [900, 170], [960, 150], [1030, 100], [1090, 60], [1150, 20], [1180, 0]]
	for pr in prof:
		isle.append(Vector2(pr[0], horizon - pr[1]))
	isle.append(Vector2(1180, horizon + 10))
	draw_colored_polygon(isle, rock)
	# jungle crowns along the lower slopes, catching a little light
	for i in 70:
		var x := 190.0 + i * 13.5
		if x > 1150: break
		var top := horizon - _isle_height(x, prof) + 6.0
		var r := 9.0 + Ink.hash2(i, 5.0) * 8.0
		if x > 500 and x < 820:
			continue            # the plateau's sheer walls: no trees
		draw_circle(Vector2(x, top + r * 0.6), r, Color(0.05, 0.07, 0.05))
		draw_arc(Vector2(x, top + r * 0.6), r, -2.4, -1.0, 8, Color(0.5, 0.4, 0.2, 0.25), 1.5, true)
	# the plateau's cliff faces, and a thread of waterfall
	for i in 6:
		var x := 530.0 + i * 50.0
		draw_line(Vector2(x, horizon - 250), Vector2(x - 8, horizon - 120), Color(0.07, 0.07, 0.08), 3.0)
	var wf := PackedVector2Array()
	for j in 20:
		wf.append(Vector2(700 + sin(j * 0.8 + _t * 3.0) * 1.5, horizon - 255 + j * 8))
	draw_polyline(wf, Color(0.75, 0.75, 0.7, 0.5), 2.0, true)
	# cloud wrapped round the plateau's top
	for i in 9:
		var cx := 470.0 + i * 50.0 + sin(_t * 0.2 + i) * 12.0
		draw_circle(Vector2(cx, horizon - 262 + sin(i * 1.3) * 8.0), 34.0 + Ink.hash2(i, 8.0) * 16.0, Color(0.55, 0.5, 0.48, 0.35))
	# the sea, with the dawn laid across it
	draw_rect(Rect2(-300, horizon, 1880, 800), Color(0.04, 0.045, 0.06))
	for i in 8:
		var w := 240.0 - i * 26.0
		draw_rect(Rect2(sun.x - w / 2.0, horizon, w, 400), Color(0.9, 0.6, 0.3, 0.025))
	for i in 14:
		var wl := PackedVector2Array()
		for j in 50:
			var x := -300.0 + j * 40.0
			wl.append(Vector2(x, horizon + 6 + i * i * 2.2 + sin(x * 0.015 + _t * (0.6 + i * 0.05) + i * 1.3) * (1.5 + i * 0.7)))
		draw_polyline(wl, Color(0.4, 0.38, 0.4, 0.22 - i * 0.01), 1.3 + i * 0.1, true)
	# fog lifting off the water
	for i in 40:
		var y := horizon - 40.0 + (i % 8) * 20.0
		var x := fmod(i * 173.0 + _t * (5.0 + (i % 5)), 2000.0) - 400.0
		draw_circle(Vector2(x, y), 70.0 + (i % 3) * 25.0, Color(0.55, 0.52, 0.5, 0.07 * fog_k))
	draw_rect(Rect2(-300, -200, 1880, 1120), Color(0.5, 0.48, 0.46, 0.55 * fog_k))
	# the ship's bow and rail, close in the corner
	var hull := Color(0.012, 0.01, 0.01)
	draw_colored_polygon(PackedVector2Array([Vector2(-300, 720), Vector2(-300, 560), Vector2(120, 600), Vector2(330, 660), Vector2(360, 720)]), hull)
	draw_line(Vector2(120, 600), Vector2(420, 470), hull, 7.0)       # the bowsprit
	draw_line(Vector2(420, 470), Vector2(-100, 380), Color(0.05, 0.04, 0.04), 1.5)
	for i in 6:
		draw_line(Vector2(-280 + i * 70, 560 + i * 7), Vector2(-280 + i * 70, 520 + i * 7), hull, 5.0)
	draw_line(Vector2(-300, 520), Vector2(120, 562), hull, 5.0)


func _isle_height(x: float, prof: Array) -> float:
	for i in prof.size() - 1:
		if x >= prof[i][0] and x <= prof[i + 1][0]:
			var t: float = (x - prof[i][0]) / float(prof[i + 1][0] - prof[i][0])
			return lerpf(prof[i][1], prof[i + 1][1], t)
	return 0.0


# ---------------------------------------------------------------- arrival 2. Harrow's Landing
func _draw_landing() -> void:
	for i in 14:          # overcast morning
		var y := -200.0 + i * 30.0
		draw_rect(Rect2(-300, y, 1880, 31), Color(0.14, 0.15, 0.16).lerp(Color(0.32, 0.31, 0.29), float(i) / 13.0))
	# the jungle wall
	for layer in 2:
		var col := Color(0.05, 0.07, 0.05) if layer == 0 else Color(0.025, 0.035, 0.025)
		var pts := PackedVector2Array([Vector2(-300, 420)])
		for i in 110:
			var x := -300.0 + i * 18.0
			var h := (120.0 + layer * 30.0) * (0.6 + 0.4 * sin(x * 0.013 + layer * 2.0) * sin(x * 0.041 + layer)) + 30.0 * absf(sin(x * 0.09 + layer))
			pts.append(Vector2(x, 300.0 + layer * 40.0 - h))
		pts.append(Vector2(1700, 420))
		draw_colored_polygon(pts, col)
		for i in 12:
			var x := -250.0 + i * 170.0 + layer * 60.0
			var c := Vector2(x, 180.0 + layer * 40.0 - 20.0 * sin(i * 1.7))
			draw_line(c, c + Vector2(6, 160), col, 5.0)
			for f in 7:
				var ang := -PI + f * PI / 6.0
				var tip := c + Vector2.from_angle(ang) * 55.0 + Vector2(0, 20)
				draw_polyline(PackedVector2Array([c, c.lerp(tip, 0.5) + Vector2(0, -10), tip]), col, 6.0, true)
	# the sand, the sea to the right, and the tide line
	draw_rect(Rect2(-300, 400, 1880, 700), Color(0.24, 0.21, 0.17))
	draw_colored_polygon(PackedVector2Array([Vector2(1000, 400), Vector2(1600, 400), Vector2(1600, 900), Vector2(820, 900)]), Color(0.08, 0.09, 0.1))
	var tide := PackedVector2Array()
	for j in 30:
		var t := float(j) / 29.0
		tide.append(Vector2(1000, 400).lerp(Vector2(820, 900), t) + Vector2(sin(t * 20.0 + _t) * 6.0, 0))
	draw_polyline(tide, Color(0.75, 0.75, 0.72, 0.5), 3.0, true)
	# the rotting pier, running out into the water
	var pier := Color(0.1, 0.08, 0.06)
	draw_colored_polygon(PackedVector2Array([Vector2(930, 470), Vector2(1500, 430), Vector2(1500, 450), Vector2(935, 492)]), pier)
	for i in 9:
		var x := 960.0 + i * 62.0
		var y := 488.0 - i * 3.0
		draw_line(Vector2(x, y - 4), Vector2(x, y + 50), pier, 7.0)
	# the ship's boat, pulled up on the sand
	var boat := Vector2(820, 560)
	draw_colored_polygon(PackedVector2Array([boat + Vector2(-70, -10), boat + Vector2(70, -18), boat + Vector2(50, 12), boat + Vector2(-55, 12)]), Color(0.12, 0.09, 0.07))
	draw_line(boat + Vector2(-20, -10), boat + Vector2(40, -40), Color(0.2, 0.15, 0.1), 4.0)
	# three old tents above the tideline, grey and torn — one fallen in
	var tent := Color(0.3, 0.29, 0.26)
	for i in 3:
		var b := Vector2(260 + i * 150, 470 + i * 12)
		if i == 2:
			draw_colored_polygon(PackedVector2Array([b + Vector2(-70, 0), b + Vector2(-10, -34), b + Vector2(60, 0)]), tent.darkened(0.2))
			draw_line(b + Vector2(-10, -34), b + Vector2(30, -60), Color(0.1, 0.08, 0.06), 3.0)
			continue
		draw_colored_polygon(PackedVector2Array([b + Vector2(-65, 0), b + Vector2(0, -80), b + Vector2(65, 0)]), tent)
		draw_colored_polygon(PackedVector2Array([b + Vector2(-16, 0), b + Vector2(0, -34), b + Vector2(16, 0)]), Color(0.04, 0.035, 0.03))
		draw_line(b + Vector2(10, -60), b + Vector2(40, -20), Color(0.18, 0.17, 0.15), 2.0)   # a rent in the canvas
	# their new camp: a fire's thread of smoke
	var fire := Vector2(640, 600)
	for i in 10:
		var ph := fmod(_t * 0.15 + i / 10.0, 1.0)
		draw_circle(fire + Vector2(sin(_t * 0.6 + i) * 10.0 * ph, -ph * 200.0), 4.0 + ph * 16.0, Color(0.5, 0.48, 0.46, 0.08 * (1.0 - ph)))
	_glow(fire, 70.0, Color(1.0, 0.5, 0.2, 0.35))
	_flame(fire, 22.0, 12.0, 0.0)
	# the carved post at the jungle's edge: the ring and the eye
	var post := Vector2(150, 470)
	draw_colored_polygon(PackedVector2Array([post + Vector2(-16, 0), post + Vector2(-13, -150), post + Vector2(0, -162), post + Vector2(13, -150), post + Vector2(16, 0)]), Color(0.14, 0.12, 0.1))
	_sigil(post + Vector2(0, -110), 12.0, Color(0.45, 0.07, 0.05, 0.9), 2.0)
	# him before the post; the guide, pointing inland
	var mc := Color(0.02, 0.018, 0.016)
	var me := Vector2(240, 560)
	draw_colored_polygon(PackedVector2Array([me + Vector2(-20, 0), me + Vector2(-16, -76), me + Vector2(0, -90), me + Vector2(16, -76), me + Vector2(20, 0)]), mc)
	draw_circle(me + Vector2(0, -104), 14.0, mc)
	for i in 2:
		draw_line(me + Vector2(-8 + i * 7, -70), me + Vector2(-22 + i * 8, -124), Color(0.3, 0.26, 0.2), 6.0)
	var gd := Vector2(360, 590)
	draw_colored_polygon(PackedVector2Array([gd + Vector2(-18, 0), gd + Vector2(-15, -72), gd + Vector2(0, -84), gd + Vector2(15, -72), gd + Vector2(18, 0)]), mc)
	draw_circle(gd + Vector2(0, -96), 13.0, mc)
	draw_polyline(PackedVector2Array([gd + Vector2(-10, -70), gd + Vector2(-50, -96), gd + Vector2(-86, -120)]), mc, 7.0, true)
