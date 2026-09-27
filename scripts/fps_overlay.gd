extends CanvasLayer
## First-person overlay: a faint crosshair, the "E — open the door" prompt,
## page text, blood on the lens, and the final fade.

var _hand: Font = preload("res://assets/fonts/Caveat.ttf")
var _prompt: Label
var _page: PanelContainer
var _page_text: Label
var _blood: Control
var _fade: ColorRect
var _cross: Control
var _splats: Array = []
var _blood_t := -1.0


func _ready() -> void:
	layer = 6
	add_to_group("fps_overlay")
	_cross = Control.new()
	_cross.set_anchors_preset(Control.PRESET_FULL_RECT)
	_cross.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cross.draw.connect(func(): _cross.draw_circle(_cross.size / 2.0, 2.0, Color(0.9, 0.9, 0.95, 0.35)))
	add_child(_cross)
	_prompt = Label.new()
	_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt.set_anchors_preset(Control.PRESET_CENTER)
	_prompt.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_prompt.position.y += 60
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.add_theme_font_override("font", _hand)
	_prompt.add_theme_font_size_override("font_size", 30)
	_prompt.add_theme_color_override("font_color", Color(0.92, 0.9, 0.85, 0.85))
	_prompt.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_prompt.add_theme_constant_override("outline_size", 6)
	add_child(_prompt)
	_page = PanelContainer.new()
	_page.set_anchors_preset(Control.PRESET_CENTER)
	_page.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_page.grow_vertical = Control.GROW_DIRECTION_BOTH
	_page.custom_minimum_size = Vector2(560, 0)
	_page.modulate.a = 0.0
	_page.mouse_filter = Control.MOUSE_FILTER_IGNORE   # (it sat at screen centre and swallowed mouse-look)
	_page_text = Label.new()
	_page_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_page_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_page_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_page_text.add_theme_font_override("font", _hand)
	_page_text.add_theme_font_size_override("font_size", 30)
	_page_text.add_theme_color_override("font_color", Color(0.25, 0.14, 0.08))
	_page.add_child(_page_text)
	add_child(_page)
	_blood = Control.new()
	_blood.set_anchors_preset(Control.PRESET_FULL_RECT)
	_blood.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_blood.draw.connect(_draw_blood)
	add_child(_blood)
	_fade = ColorRect.new()
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.color = Color(0, 0, 0, 0)
	add_child(_fade)


var _line: Label
var _line_tw: Tween
var _stam: Control
var player: Node3D


## A line of his thoughts, near the top of the screen, for a few seconds.
func say(text: String, secs := 3.5, big := false) -> void:
	if _line == null:
		_line = Label.new()
		_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_line.set_anchors_preset(Control.PRESET_CENTER_TOP)
		_line.grow_horizontal = Control.GROW_DIRECTION_BOTH
		_line.position.y = 150
		_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_line.add_theme_font_override("font", _hand)
		_line.add_theme_color_override("font_color", Color(0.92, 0.88, 0.8))
		_line.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
		_line.add_theme_constant_override("outline_size", 8)
		add_child(_line)
	_line.add_theme_font_size_override("font_size", 64 if big else 32)
	_line.text = text
	if big:
		_line.add_theme_color_override("font_color", Color(0.85, 0.12, 0.08))
	else:
		_line.add_theme_color_override("font_color", Color(0.92, 0.88, 0.8))
	if _line_tw:
		_line_tw.kill()
	_line.modulate.a = 0.0
	_line_tw = create_tween()
	_line_tw.tween_property(_line, "modulate:a", 1.0, 0.4)
	_line_tw.tween_interval(secs)
	_line_tw.tween_property(_line, "modulate:a", 0.0, 1.0)


## A quick flash of colour (a false door's white).
func flash(color: Color, hold := 0.3, out := 0.8) -> void:
	_fade.color = Color(color, 1.0)
	var tw := create_tween()
	tw.tween_interval(hold)
	tw.tween_property(_fade, "color:a", 0.0, out)


func _draw_stamina() -> void:
	if player == null or not ("stamina" in player):
		return
	var f: float = player.stamina / player.stamina_max
	if f >= 0.999:
		return
	var w := 160.0
	var at := Vector2((_stam.size.x - w) / 2.0, _stam.size.y - 46.0)
	_stam.draw_rect(Rect2(at, Vector2(w, 5)), Color(0, 0, 0, 0.5))
	_stam.draw_rect(Rect2(at, Vector2(w * f, 5)), Color(0.85, 0.82, 0.75, 0.6) if f > 0.2 else Color(0.8, 0.2, 0.15, 0.7))


func set_prompt(text: String) -> void:
	var passive := text.begins_with("locked") or text.begins_with("it") or text.begins_with("the light")
	_prompt.text = "" if text == "" else (text if passive else "E / Space — " + text)


func show_page(text: String) -> void:
	_page_text.text = text
	var tw := create_tween()
	tw.tween_property(_page, "modulate:a", 1.0, 0.3)
	tw.tween_interval(4.5)
	tw.tween_property(_page, "modulate:a", 0.0, 0.8)


func fade_to(color: Color, t: float) -> void:
	_fade.color = Color(color, _fade.color.a)
	await create_tween().tween_property(_fade, "color:a", 1.0, t).finished


## Blood hits the lens in a burst of splats that then run down the screen.
func splatter() -> void:
	_cross.hide()
	_prompt.text = ""
	var s := _blood.size
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for i in 11:
		var c := Vector2(rng.randf_range(0.05, 0.95) * s.x, rng.randf_range(0.05, 0.75) * s.y)
		var r := rng.randf_range(28.0, 90.0)
		if i < 2:
			c = s * Vector2(rng.randf_range(0.35, 0.65), rng.randf_range(0.3, 0.55))
			r = rng.randf_range(110.0, 160.0)
		# a smooth, lumpy blob (always star-shaped around c, so it fills cleanly)
		var pts := PackedVector2Array()
		var k := 40
		var p1 := rng.randf() * TAU
		var p2 := rng.randf() * TAU
		for j in k:
			var a := TAU * j / k
			var rr := r * (1.0 + 0.22 * sin(3.0 * a + p1) + 0.12 * sin(7.0 * a + p2))
			pts.append(c + Vector2.from_angle(a) * rr)
		# flung spatter: thin rays and droplets
		var rays := []
		for d in rng.randi_range(3, 7):
			var a := rng.randf() * TAU
			rays.append({"a": a, "len": r * rng.randf_range(1.2, 2.2), "w": r * rng.randf_range(0.08, 0.16)})
		var drops := []
		for d in rng.randi_range(5, 12):
			drops.append({"p": c + Vector2.from_angle(rng.randf() * TAU) * r * rng.randf_range(1.2, 2.4), "r": rng.randf_range(2.5, 9.0)})
		var drips := []
		for d in rng.randi_range(1, 3):
			drips.append({"x": c.x + rng.randf_range(-r * 0.5, r * 0.5), "w": rng.randf_range(4.0, 10.0), "speed": rng.randf_range(30.0, 110.0), "y0": c.y + r * 0.5})
		_splats.append({"c": c, "r": r, "poly": pts, "rays": rays, "drops": drops, "drips": drips,
			"delay": i * 0.025 + (0.0 if i < 2 else 0.1), "shade": rng.randf_range(0.3, 0.48)})
	_blood_t = 0.0


func _process(delta: float) -> void:
	if _stam == null:
		_stam = Control.new()
		_stam.set_anchors_preset(Control.PRESET_FULL_RECT)
		_stam.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_stam.draw.connect(_draw_stamina)
		add_child(_stam)
		move_child(_stam, 1)
	_stam.queue_redraw()
	if _blood_t >= 0.0:
		_blood_t += delta
		_blood.queue_redraw()


func _draw_blood() -> void:
	if _blood_t < 0.0:
		return
	# a red wash first
	_blood.draw_rect(Rect2(Vector2.ZERO, _blood.size), Color(0.35, 0.0, 0.0, clampf(_blood_t * 1.5, 0.0, 0.35)))
	for sp in _splats:
		var t: float = _blood_t - sp.delay
		if t <= 0.0:
			continue
		var grow := minf(t / 0.1, 1.0)
		var c: Vector2 = sp.c
		var col := Color(sp.shade, 0.0, 0.01, 0.9)
		var dark := Color(sp.shade * 0.55, 0.0, 0.0, 0.9)
		for ray in sp.rays:
			var dir: Vector2 = Vector2.from_angle(ray.a)
			var side: Vector2 = dir.orthogonal() * ray.w
			var tip: Vector2 = c + dir * ray.len * grow
			_blood.draw_colored_polygon(PackedVector2Array([c + side, tip, c - side]), col)
			_blood.draw_circle(tip, ray.w * 0.6, col)
		var poly := PackedVector2Array()
		for p in sp.poly:
			poly.append(c + (p - c) * grow)
		_blood.draw_colored_polygon(poly, col)
		_blood.draw_colored_polygon(_shrink(poly, c, 0.6), dark)
		_blood.draw_circle(c - Vector2(sp.r, sp.r) * 0.25 * grow, sp.r * 0.12, Color(1, 0.6, 0.6, 0.12))  # wet highlight
		for d in sp.drops:
			_blood.draw_circle(c + (d.p - c) * grow, d.r * grow, col)
		for dr in sp.drips:
			var length := minf(t * dr.speed, 500.0)
			var top := Vector2(dr.x - dr.w / 2.0, dr.y0)
			_blood.draw_rect(Rect2(top, Vector2(dr.w, length)), col)
			_blood.draw_circle(top + Vector2(dr.w / 2.0, length), dr.w * 0.7, col)


func _shrink(poly: PackedVector2Array, c: Vector2, k: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in poly:
		out.append(c + (p - c) * k)
	return out
