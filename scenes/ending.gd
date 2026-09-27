extends Control
## The two endings. Game.ending is "escape" or "caught".
##
## Escape: white — then he wakes beside the campfire. His map lies in front of
##   him. It is complete: every ridge, ford and bridge of the survey. Except, in
##   the corner, a sign he does not remember drawing.
## Caught: black — then the campfire, the expedition asleep. He sits beside them,
##   upright, still holding the map. We move closer. The jungle on it has become
##   the labyrinth — and something moves under the paper.
##
## Everything here is drawn in code, over a real render of the Level 1 map.

var _hand: Font = preload("res://assets/fonts/Caveat.ttf")
var _italic: Font = preload("res://assets/fonts/IMFellEnglish-Italic.ttf")
var _good := true
var _t := 0.0

# the "camera": world is a 1280x720 stage
var cam_center := Vector2(640, 500)
var cam_zoom := 1.5
var shake := 0.0
var white := 0.0          ## full-screen white (good ending's first frames)
var black := 1.0          ## full-screen black
var maze_k := 0.0         ## 0 = the jungle map, 1 = the labyrinth
var sign_k := 0.0         ## how much of the unremembered sign is drawn
var lump_k := -1.0        ## the thing under the paper (-1 = not there)
var fire_k := 1.0

const MAP_GOOD := Rect2(548, 588, 184, 118)       ## the map on the ground, in front of him
const MAP_BAD := Rect2(474, 538, 150, 96)         ## the map in his lap
var _map_rect := MAP_GOOD
var _map_tex: Texture2D
var _map_vp: SubViewport
var _maze: PackedStringArray = []

var _caption: Label
var _cap_tw: Tween
var _end_box: VBoxContainer
var _hold := 0.0
var _skip_bar: ColorRect
var _fire_audio: AudioStreamPlayer
var _ending := false
var _xf := Transform2D.IDENTITY


func _ready() -> void:
	add_to_group("cutscene")          # Game keeps the (paused) timer on screen
	_good = Game.ending != "caught"
	_map_rect = MAP_GOOD if _good else MAP_BAD
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	white = 1.0 if _good else 0.0
	black = 0.0 if _good else 1.0
	_maze = PackedStringArray(load("res://levels/level3/level3_data.gd").get_script_constant_map()["MAZE"])
	_render_map()
	_caption = Label.new()
	_caption.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_caption.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_caption.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_caption.position.y -= 70
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.add_theme_font_override("font", _hand)
	_caption.add_theme_font_size_override("font_size", 36)
	_caption.add_theme_color_override("font_color", Color(0.97, 0.93, 0.84))
	_caption.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.02, 0.95))
	_caption.add_theme_constant_override("outline_size", 9)
	_caption.modulate.a = 0.0
	add_child(_caption)
	var hint := Label.new()
	hint.name = "Hint"
	hint.text = "hold space — skip"
	hint.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	hint.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	hint.grow_vertical = Control.GROW_DIRECTION_BEGIN
	hint.position += Vector2(-24, -16)
	hint.add_theme_font_size_override("font_size", 18)
	hint.add_theme_color_override("font_color", Color(0.9, 0.86, 0.78, 0.55))
	hint.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	hint.add_theme_constant_override("outline_size", 5)
	add_child(hint)
	_skip_bar = ColorRect.new()
	_skip_bar.color = Color(0.97, 0.92, 0.8, 0.8)
	_skip_bar.size = Vector2(0, 3)
	add_child(_skip_bar)
	_fire_audio = AudioStreamPlayer.new()
	var st: AudioStreamOggVorbis = load("res://assets/sfx/fire.ogg").duplicate()
	st.loop = true
	_fire_audio.stream = st
	_fire_audio.volume_db = linear_to_db(maxf(Music.sfx_volume * 0.7, 0.0001))
	add_child(_fire_audio)
	_fire_audio.play()
	if _good:
		Music.play_set("menu", 4.0)
		_play_good()
	else:
		Music.stop(0.5)
		_play_bad()


## Render the Level 1 map (finished — no fading at the edge) into a texture.
func _render_map() -> void:
	_map_vp = SubViewport.new()
	_map_vp.size = Vector2i(1680, 1080)
	_map_vp.transparent_bg = false
	_map_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(_map_vp)
	var r := Node2D.new()
	r.set_script(preload("res://scripts/map_renderer.gd"))
	r.unfinished_radius_cells = 0.01
	r.data_script = load("res://levels/level1/level1_data.gd")
	var sheet: Rect2 = r.sheet_rect()
	var paper := ColorRect.new()
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/parchment.gdshader")
	mat.set_shader_parameter("rect_size", sheet.size)
	paper.material = mat
	paper.position = sheet.position
	paper.size = sheet.size
	_map_vp.add_child(paper)
	_map_vp.add_child(r)
	var k := minf(_map_vp.size.x / sheet.size.x, _map_vp.size.y / sheet.size.y)
	_map_vp.canvas_transform = Transform2D(0.0, Vector2(k, k), 0.0, -sheet.position * k + (Vector2(_map_vp.size) - sheet.size * k) / 2.0)
	_map_tex = _map_vp.get_texture()


# ================================================================ the two sequences
func _play_good() -> void:
	_tween("white", 0.0, 3.0)
	await _wait(1.2)
	await _say("Light. Too much of it — and then only the crackle of a fire.", 3.6)
	await _say("He wakes beside the campfire. The others are still asleep.", 3.4)
	await _say("His map is lying in front of him, where he left it.", 2.0)
	await _move_to(_map_rect.get_center(), 720.0 / _map_rect.size.y * 0.92, 3.2)
	await _say("He looks down. The map is complete.", 3.2)
	await _say("Every ridge. Every ford. Every bridge he crossed.", 3.0)
	# pan into the corner, where the pen draws what he never drew
	var corner := _map_rect.position + _map_rect.size * Vector2(0.9, 0.84)
	_move_to(corner, cam_zoom * 2.4, 3.0)
	await _say("Except…", 2.6)
	_tween("sign_k", 1.0, 4.0)
	Music.sfx("ink", 0.6, 0.7)
	await _say("In the corner, there is a sign he does not remember drawing.", 5.0)
	await _wait(1.5)
	_show_end()


func _play_bad() -> void:
	fire_k = 0.55
	await _wait(0.8)
	_tween("black", 0.0, 3.5)
	await _wait(1.5)
	await _say("The fire is low. The expedition sleeps around it.", 3.6)
	await _say("He is sitting beside them, upright, his eyes open.\nHe is still holding the map.", 4.2)
	# the camera creeps towards the map
	_move_to(_map_rect.get_center(), 720.0 / _map_rect.size.y * 0.92, 9.0, Tween.TRANS_SINE)
	await _wait(9.2)
	await _say("The map has changed.", 2.2)
	_tween("maze_k", 1.0, 5.0)
	await _say("There is no jungle on it any more. Only the labyrinth,\nin ink he did not use.", 5.2)
	await _wait(0.8)
	Music.sfx("rustle", 1.0, 0.8)
	lump_k = 0.0
	_tween("lump_k", 1.0, 5.5)
	await _say("Something moves underneath the paper.", 4.5)
	Music.sfx("breath", 0.6, 0.7)
	_tween("black", 1.0, 2.2)
	await _wait(2.6)
	_show_end()


func _wait(t: float) -> void:
	await get_tree().create_timer(t).timeout


func _tween(prop: String, to: float, t: float) -> void:
	create_tween().tween_property(self, prop, to, t).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _move_to(center: Vector2, zoom: float, t: float, trans := Tween.TRANS_CUBIC) -> void:
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "cam_center", center, t).set_trans(trans).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(self, "cam_zoom", zoom, t).set_trans(trans).set_ease(Tween.EASE_IN_OUT)
	await tw.finished


func _say(text: String, hold: float) -> void:
	if _ending:
		return
	if _cap_tw:
		_cap_tw.kill()
	_caption.text = text
	_cap_tw = create_tween()
	_cap_tw.tween_property(_caption, "modulate:a", 1.0, 0.6)
	_cap_tw.tween_interval(hold)
	_cap_tw.tween_property(_caption, "modulate:a", 0.0, 0.6)
	await _cap_tw.finished


# ================================================================ end card
func _show_end() -> void:
	if _end_box != null:
		return
	_ending = true
	if _cap_tw:
		_cap_tw.kill()
	_caption.modulate.a = 0.0
	if has_node("Hint"):
		get_node("Hint").hide()
	var tw := create_tween()
	tw.tween_property(self, "black", 1.0 if not _good else 0.6, 1.2)
	_end_box = VBoxContainer.new()
	_end_box.set_anchors_preset(Control.PRESET_CENTER)
	_end_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_end_box.grow_vertical = Control.GROW_DIRECTION_BOTH
	_end_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_end_box.add_theme_constant_override("separation", 12)
	add_child(_end_box)
	var panel_ink := Color(0.97, 0.93, 0.84)
	var title := Label.new()
	title.text = "The map is finished." if _good else "The map keeps its maker."
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_color_override("font_color", panel_ink)
	title.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.02, 0.9))
	title.add_theme_constant_override("outline_size", 10)
	_end_box.add_child(title)
	var sub := Label.new()
	sub.text = "— you escaped the labyrinth —" if _good else "— the beast caught you —"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_override("font", _italic)
	sub.add_theme_font_size_override("font_size", 26)
	sub.add_theme_color_override("font_color", Color(panel_ink, 0.85))
	sub.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.02, 0.9))
	sub.add_theme_constant_override("outline_size", 7)
	_end_box.add_child(sub)
	if Game.show_timer:
		var t := Label.new()
		var lines := "labyrinth  " + Game.format_time(Game.level_time)
		if _good and Game.full_run:
			lines += "\nwhole dream  " + Game.format_time(Game.run_time)
		t.text = lines
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		t.add_theme_font_size_override("font_size", 28)
		t.add_theme_color_override("font_color", panel_ink)
		t.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.02, 0.9))
		t.add_theme_constant_override("outline_size", 7)
		_end_box.add_child(t)
	if Game.last_total > 0:
		var pg := Label.new()
		pg.text = "torn pages found  %d / %d" % [Game.last_found, Game.last_total]
		pg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		pg.add_theme_font_override("font", _hand)
		pg.add_theme_font_size_override("font_size", 28)
		pg.add_theme_color_override("font_color", panel_ink)
		pg.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.02, 0.9))
		pg.add_theme_constant_override("outline_size", 7)
		_end_box.add_child(pg)
	if not _good:
		var again := _button("Enter the labyrinth again")
		again.pressed.connect(func(): Game.start_level(Game.LEVELS.size() - 1))
		_end_box.add_child(again)
	var menu := _button("Return to the title")
	menu.pressed.connect(Game.go_to_menu)
	_end_box.add_child(menu)
	_end_box.modulate.a = 0.0
	create_tween().tween_property(_end_box, "modulate:a", 1.0, 1.2)
	(_end_box.get_child(_end_box.get_child_count() - (2 if not _good else 1)) as Button).grab_focus()


func _button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return b


func _process(delta: float) -> void:
	_t += delta
	shake = move_toward(shake, 0.0, delta)
	queue_redraw()
	if _end_box == null and Input.is_action_pressed("skip") and _t > 0.8:
		_hold += delta
		if _hold > 0.6:
			if _good:
				cam_center = _map_rect.get_center()
				cam_zoom = 720.0 / _map_rect.size.y * 0.92
				sign_k = 1.0
				white = 0.0
			_show_end()
	else:
		_hold = 0.0
	_skip_bar.size.x = 200.0 * clampf(_hold / 0.6, 0.0, 1.0)
	_skip_bar.position = Vector2(size.x - 224.0, size.y - 12.0)


# ================================================================ drawing
func _draw() -> void:
	var s := size
	var k := minf(s.x / 1280.0, s.y / 720.0) * cam_zoom
	var off := s / 2.0 - cam_center * k
	if shake > 0.0:
		off += Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake * 6.0
	draw_rect(Rect2(Vector2.ZERO, s), Color(0.01, 0.01, 0.015))
	_xf = Transform2D(0.0, Vector2(k, k), 0.0, off)
	draw_set_transform_matrix(_xf)
	_draw_scene()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if white > 0.0:
		draw_rect(Rect2(Vector2.ZERO, s), Color(1.0, 0.98, 0.94, white))
	if black > 0.0:
		draw_rect(Rect2(Vector2.ZERO, s), Color(0, 0, 0, black))


func _draw_scene() -> void:
	# the night, and the jungle all round
	var top := Color(0.05, 0.06, 0.1) if _good else Color(0.02, 0.015, 0.02)
	var low := Color(0.2, 0.18, 0.2) if _good else Color(0.08, 0.03, 0.03)
	for i in 24:
		var y := -200.0 + i * 50.0
		draw_rect(Rect2(-600, y, 2480, 51), top.lerp(low, float(i) / 23.0))
	_treeline(300.0, Color(0.06, 0.07, 0.06) if _good else Color(0.03, 0.02, 0.02), 1.0, 0.0)
	_treeline(360.0, Color(0.035, 0.04, 0.035) if _good else Color(0.015, 0.01, 0.01), 1.4, 2.0)
	# the ground
	draw_rect(Rect2(-600, 420, 2480, 700), Color(0.09, 0.07, 0.05) if _good else Color(0.05, 0.03, 0.025))
	var fire := Vector2(640, 520)
	var flick := 0.85 + 0.15 * sin(_t * 11.0) * sin(_t * 7.3 + 1.0)
	# firelight on the ground
	for i in 7:
		var r := 420.0 - i * 55.0
		draw_circle(fire + Vector2(0, 20), r * flick, Color(1.0, 0.45, 0.15, 0.035 * fire_k))
	# tents
	for tx: float in [360.0, 930.0]:
		var base := Vector2(tx, 470)
		var tent := PackedVector2Array([base + Vector2(-90, 0), base + Vector2(0, -95), base + Vector2(90, 0)])
		draw_colored_polygon(tent, Color(0.22, 0.18, 0.13) if _good else Color(0.11, 0.08, 0.07))
		draw_line(base + Vector2(0, -95), base + Vector2(0, 0), Color(0.08, 0.06, 0.04), 2.0)
		draw_colored_polygon(PackedVector2Array([base + Vector2(-18, 0), base + Vector2(0, -40), base + Vector2(18, 0)]), Color(0.05, 0.04, 0.03))
	# the sleepers
	for p: Vector2 in [Vector2(400, 560), Vector2(860, 575), Vector2(760, 640)]:
		_sleeper(p, p.x > 640.0)
	# him
	_cartographer()
	# the fire
	_fire(fire, flick)
	# the map
	_draw_map()


func _treeline(y: float, col: Color, scale_: float, seed_: float) -> void:
	var pts := PackedVector2Array([Vector2(-600, 700)])
	for i in 130:
		var x := -600.0 + i * 20.0
		var h := 90.0 * scale_ * (0.6 + 0.4 * sin(x * 0.013 + seed_) * sin(x * 0.037 + seed_ * 2.0)) + 30.0 * absf(sin(x * 0.09 + seed_))
		pts.append(Vector2(x, y - h))
	pts.append(Vector2(2000, 700))
	draw_colored_polygon(pts, col)
	# palm crowns poking up
	for i in 14:
		var x := -500.0 + i * 185.0 + seed_ * 60.0
		var c := Vector2(x, y - 150.0 * scale_ - 20.0 * sin(i * 1.7))
		draw_line(c, c + Vector2(8, 150.0 * scale_), col, 5.0)
		for f in 7:
			var a := -PI + f * PI / 6.0
			var tip := c + Vector2.from_angle(a) * 60.0 * scale_ + Vector2(0, 22)
			draw_polyline(PackedVector2Array([c, c.lerp(tip, 0.5) + Vector2(0, -12), tip]), col, 6.0 * scale_, true)


func _sleeper(p: Vector2, flip: bool) -> void:
	var col := Color(0.16, 0.12, 0.09) if _good else Color(0.09, 0.06, 0.05)
	var rim := Color(0.85, 0.45, 0.2, 0.5 * fire_k)
	var body := Rect2(p + Vector2(-70, -16), Vector2(140, 34))
	draw_rect(body, col)
	draw_circle(p + Vector2(-70 if not flip else 70, -2), 17.0, col)
	draw_circle(p + Vector2(-70 if not flip else 70, -2), 13.0, Color(0.3, 0.2, 0.14) if _good else Color(0.12, 0.08, 0.06))
	draw_line(body.position, body.position + Vector2(body.size.x, 0), rim, 2.0)
	draw_circle(p + Vector2(70 if not flip else -70, 0), 17.0, col)


## He sits on the fire's left, facing it. In the good ending he has just woken,
## leaning on one arm; in the bad ending he sits bolt upright, the map in his lap.
func _cartographer() -> void:
	var col := Color(0.12, 0.09, 0.07) if _good else Color(0.06, 0.04, 0.035)
	var rim := Color(1.0, 0.55, 0.25, 0.7 * fire_k)
	var base := Vector2(470, 560)
	if _good:
		# half-risen from his bedroll, leaning on one arm, looking at the fire
		draw_rect(Rect2(base + Vector2(-140, -8), Vector2(190, 30)), Color(0.2, 0.15, 0.1))
		draw_circle(base + Vector2(-140, 7), 15.0, Color(0.2, 0.15, 0.1))
		var torso := PackedVector2Array([base + Vector2(-46, 12), base + Vector2(-40, -40), base + Vector2(-30, -74),
			base + Vector2(-10, -86), base + Vector2(14, -82), base + Vector2(26, -60), base + Vector2(30, 12)])
		draw_colored_polygon(torso, col)
		draw_polyline(PackedVector2Array([base + Vector2(14, -82), base + Vector2(26, -60), base + Vector2(30, 12)]), rim, 3.0, true)
		draw_circle(base + Vector2(2, -104), 20.0, col)
		draw_arc(base + Vector2(2, -104), 20.0, -1.2, 1.0, 12, rim, 3.0, true)
		draw_colored_polygon(PackedVector2Array([base + Vector2(-100, -6), base + Vector2(-86, -24), base + Vector2(-58, -24), base + Vector2(-44, -6)]), col)
		draw_polyline(PackedVector2Array([base + Vector2(16, -70), base + Vector2(40, -30), base + Vector2(52, 12)]), col, 11.0, true)
	else:
		# bolt upright, legs out towards the fire, the map on his knees
		var torso := PackedVector2Array([base + Vector2(-38, 4), base + Vector2(-36, -80), base + Vector2(-30, -112),
			base + Vector2(-12, -124), base + Vector2(14, -122), base + Vector2(24, -104), base + Vector2(26, 4)])
		draw_colored_polygon(torso, col)
		draw_polyline(PackedVector2Array([base + Vector2(14, -122), base + Vector2(24, -104), base + Vector2(26, 4)]), rim, 3.0, true)
		draw_circle(base + Vector2(-6, -146), 22.0, col)
		draw_arc(base + Vector2(-6, -146), 22.0, -1.0, 1.0, 12, rim, 3.0, true)
		draw_colored_polygon(PackedVector2Array([base + Vector2(-46, -162), base + Vector2(34, -162), base + Vector2(26, -170),
			base + Vector2(14, -170), base + Vector2(10, -192), base + Vector2(-22, -192), base + Vector2(-26, -170), base + Vector2(-38, -170)]), col)
		draw_circle(base + Vector2(8, -149), 2.2, Color(0.95, 0.55, 0.3, 0.85))
		draw_colored_polygon(PackedVector2Array([base + Vector2(-30, -10), base + Vector2(150, -2), base + Vector2(160, 22), base + Vector2(-30, 18)]), col)
		draw_polyline(PackedVector2Array([base + Vector2(10, -104), base + Vector2(30, -60), base + Vector2(52, -26)]), col, 11.0, true)
		draw_polyline(PackedVector2Array([base + Vector2(-26, -100), base + Vector2(-20, -50), base + Vector2(4, -26)]), col, 11.0, true)


func _fire(c: Vector2, flick: float) -> void:
	# logs and stones
	for a: float in [0.4, -0.4, 1.2]:
		var d := Vector2.from_angle(a) * 46.0
		draw_line(c - d + Vector2(0, 12), c + d + Vector2(0, 12), Color(0.18, 0.1, 0.05), 11.0)
	for i in 9:
		var p := c + Vector2.from_angle(TAU * i / 9.0) * Vector2(58, 22) + Vector2(0, 16)
		draw_circle(p, 10.0, Color(0.2, 0.18, 0.16) if _good else Color(0.1, 0.09, 0.08))
	# flames
	var h := 70.0 * fire_k
	for layer in 3:
		var col: Color = [Color(0.9, 0.25, 0.05, 0.85), Color(1.0, 0.55, 0.1, 0.85), Color(1.0, 0.85, 0.4, 0.9)][layer]
		var w := 40.0 - layer * 11.0
		var pts := PackedVector2Array()
		for i in 13:
			var tt := float(i) / 12.0
			var x := lerpf(-w, w, tt)
			var y := -h * (1.0 - layer * 0.25) * pow(sin(tt * PI), 0.8) * (0.75 + 0.25 * sin(_t * (9.0 + layer * 3.0) + i * 1.9))
			pts.append(c + Vector2(x + sin(_t * 6.0 + i) * 3.0, y * flick))
		pts.append(c + Vector2(w, 8))
		pts.append(c + Vector2(-w, 8))
		draw_colored_polygon(pts, Color(col, col.a * clampf(fire_k * 1.4, 0.0, 1.0)))
	# embers
	for i in 8:
		var ph := fmod(_t * 0.6 + i * 0.37, 1.0)
		draw_circle(c + Vector2(sin(i * 3.3 + _t) * 20.0, -20.0 - ph * 160.0), 1.8 * (1.0 - ph), Color(1.0, 0.6, 0.2, (1.0 - ph) * fire_k))


func _draw_map() -> void:
	var r := _map_rect
	var tilt := -0.04 if _good else 0.03
	draw_set_transform_matrix(_xf * Transform2D(tilt, r.get_center()) * Transform2D(0.0, -r.get_center()))
	# the sheet (shadow, paper, the drawing)
	draw_rect(Rect2(r.position + Vector2(5, 6), r.size), Color(0, 0, 0, 0.45))
	if _map_tex:
		draw_texture_rect(_map_tex, r, false, Color(1, 1, 1, 1))
	# warm firelight across the paper
	draw_rect(r, Color(1.0, 0.6, 0.3, 0.12 * fire_k))
	if maze_k > 0.0:
		_draw_labyrinth(r)
	if sign_k > 0.0:
		_draw_sign(r)
	if lump_k >= 0.0:
		_draw_lump(r)
	draw_set_transform_matrix(_xf)


## The jungle is gone: the paper is blank and the labyrinth is inked over it.
func _draw_labyrinth(r: Rect2) -> void:
	var inner := r.grow(-r.size.y * 0.08)
	draw_rect(inner.grow(r.size.y * 0.04), Color(0.88, 0.81, 0.64, 0.97 * maze_k))
	var n := _maze.size()
	var side := minf(inner.size.x, inner.size.y)
	var o := inner.get_center() - Vector2(side, side) / 2.0
	var cs := side / float(n - 1)
	var ink := Color(0.12, 0.05, 0.04, maze_k)
	for y in n:
		for x in _maze[y].length():
			var ch := _maze[y][x]
			if (x % 2 == 0) == (y % 2 == 0):
				continue
			if ch in ["#", "h", "e", "F", "I", "T", "K", "Q", "B", "X"]:
				var a: Vector2
				var b: Vector2
				if y % 2 == 0:
					a = o + Vector2(x - 1, y) * cs
					b = o + Vector2(x + 1, y) * cs
				else:
					a = o + Vector2(x, y - 1) * cs
					b = o + Vector2(x, y + 1) * cs
				draw_line(a, b, Color(0.6, 0.05, 0.03, maze_k) if ch == "X" else ink, maxf(cs * 0.16, 0.4), true)
	# the inked-over title
	draw_string(_hand, r.position + Vector2(0, r.size.y - 2.0), "the Sombra basin", HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 8, Color(0.12, 0.05, 0.04, 0.6 * maze_k))


## Ring and eye: the sign that was carved over the Door of Light.
func _draw_sign(r: Rect2) -> void:
	var c := r.position + r.size * Vector2(0.9, 0.84)
	var rad := r.size.y * 0.035
	var ink := Color(0.45, 0.05, 0.03, 0.95)
	var a := sign_k * TAU * 1.05
	draw_arc(c, rad, -PI / 2.0, -PI / 2.0 + minf(a, TAU), 40, ink, rad * 0.22, true)
	if sign_k > 0.8:
		draw_circle(c, rad * 0.3 * clampf((sign_k - 0.8) * 5.0, 0.0, 1.0), ink)


## Something under the paper, pushing it up as it crawls.
func _draw_lump(r: Rect2) -> void:
	var t := lump_k
	var p := r.position + r.size * Vector2(0.18 + 0.64 * t, 0.62 - 0.28 * sin(t * PI))
	var dir := Vector2(0.64, -0.28 * PI * cos(t * PI)).normalized()
	var L := r.size.y * (0.16 + 0.02 * sin(_t * 4.0))
	var W := r.size.y * 0.07
	var body := PackedVector2Array()
	for i in 24:
		var a := TAU * i / 24.0
		body.append(p + dir * cos(a) * L + dir.orthogonal() * sin(a) * W * (1.0 + 0.25 * cos(a)))
	# the shadow it casts away from the fire, the paper lit where it bulges
	var shadow := PackedVector2Array()
	for q in body:
		shadow.append(q + Vector2(W * 0.35, W * 0.45))
	draw_colored_polygon(shadow, Color(0, 0, 0, 0.28))
	draw_colored_polygon(body, Color(0.93, 0.86, 0.7, 0.35))
	var hi := PackedVector2Array()
	for q in body:
		hi.append(p + (q - p) * 0.55 - Vector2(W * 0.2, W * 0.25))
	draw_colored_polygon(hi, Color(1.0, 0.97, 0.88, 0.3))
	for q in body:
		pass
	var ring := body.duplicate()
	ring.append(ring[0])
	draw_polyline(ring, Color(0.1, 0.04, 0.03, 0.25), 0.6, true)
