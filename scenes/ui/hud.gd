extends CanvasLayer
## Shared in-level HUD: speedrun timer, level title card, control hints,
## pause menu and the level-complete card. Instance res://scenes/ui/hud.tscn
## in any level.
##
## If the level wants its own "leaving" transition, connect to
## `continue_requested` and set `handle_continue_myself = true`; otherwise the
## HUD simply calls Game.next_level().

signal continue_requested

@export var controls_hint := "WASD / arrows — walk      Tab — your map      R — restart      Esc — pause"
@export var handle_continue_myself := false
## Levels that show their own ending (the finale) switch the cards off.
@export var show_completion_card := true
@export var show_failure_card := true
## First-person levels: keep the mouse captured while playing.
@export var captures_mouse := false

var _hand: Font = preload("res://assets/fonts/Caveat.ttf")
var _italic: Font = preload("res://assets/fonts/IMFellEnglish-Italic.ttf")

var _timer_label: Label
var _total_label: Label
var _hint: Label
var _title: Label
var _pause: Control
var _pause_timer_check: CheckButton
var _complete: Control
var _complete_time: Label
var _complete_best: Label
var _complete_flavor: Label
var _continue_btn: Button
var _fail: Control
var _fail_title: Label
var _fail_text: Label
var _retry_btn: Button
var _hint_hidden := false


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_timer()
	_build_title()
	_build_hint()
	_build_pause()
	_build_complete()
	_build_fail()
	_title.text = Game.level_title()
	Game.settings_changed.connect(_apply_settings)
	Game.level_completed.connect(_on_level_completed)
	Game.level_failed.connect(_on_level_failed)
	_apply_settings()


func _process(delta: float) -> void:
	if _objectives:
		for k in _obj_flash.keys():
			_obj_flash[k] = maxf(0.0, _obj_flash[k] - delta * 0.5)
		_objectives.queue_redraw()
	_timer_label.text = Game.format_time(Game.level_time)
	_total_label.text = "run " + Game.format_time(Game.run_time)
	if Game.timing and not _hint_hidden:
		_hint_hidden = true
		create_tween().tween_property(_hint, "modulate:a", 0.0, 2.5).set_delay(2.0)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart") and not _complete.visible:
		get_viewport().set_input_as_handled()
		Game.restart_level()
	elif event.is_action_pressed("pause") and not _complete.visible and not _fail.visible:
		get_viewport().set_input_as_handled()
		_set_paused(not get_tree().paused)


func _set_paused(on: bool) -> void:
	get_tree().paused = on
	_pause.visible = on
	if captures_mouse:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if on else Input.MOUSE_MODE_CAPTURED
	if on:
		_pause_timer_check.set_pressed_no_signal(Game.show_timer)
		(_pause.find_child("Resume", true, false) as Button).grab_focus()


func _apply_settings() -> void:
	_timer_label.visible = Game.show_timer
	_total_label.visible = Game.show_timer and Game.full_run and Game.current_level > 0


# ------------------------------------------------------------------ builders
func _build_timer() -> void:
	_timer_label = Label.new()
	_timer_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_timer_label.offset_left = -240
	_timer_label.offset_right = -24
	_timer_label.offset_top = 14
	_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_timer_label.add_theme_font_size_override("font_size", 38)
	_timer_label.add_theme_color_override("font_color", Color(0.98, 0.93, 0.82))
	_timer_label.add_theme_color_override("font_outline_color", Color(0.15, 0.09, 0.05))
	_timer_label.add_theme_constant_override("outline_size", 8)
	add_child(_timer_label)
	_total_label = _timer_label.duplicate()
	_total_label.offset_top = 58
	_total_label.add_theme_font_size_override("font_size", 22)
	add_child(_total_label)


func _build_title() -> void:
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.offset_top = 36
	box.add_theme_constant_override("separation", -4)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.modulate.a = 0.0
	add_child(box)
	_title = Label.new()
	_title.text = Game.level_title()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_override("font", _italic)
	_title.add_theme_font_size_override("font_size", 48)
	_title.add_theme_color_override("font_color", Color(0.22, 0.13, 0.07))
	_title.add_theme_color_override("font_outline_color", Color(0.93, 0.87, 0.72, 0.85))
	_title.add_theme_constant_override("outline_size", 10)
	box.add_child(_title)
	# the level's goal, in one line, in his hand
	var goal := Label.new()
	goal.text = Game.level_goal()
	goal.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	goal.add_theme_font_override("font", _hand)
	goal.add_theme_font_size_override("font_size", 30)
	goal.add_theme_color_override("font_color", Color(0.42, 0.08, 0.05))
	goal.add_theme_color_override("font_outline_color", Color(0.93, 0.87, 0.72, 0.85))
	goal.add_theme_constant_override("outline_size", 8)
	box.add_child(goal)
	var tw := create_tween()
	tw.tween_property(box, "modulate:a", 1.0, 1.2).set_delay(0.4)
	tw.tween_interval(3.4)
	tw.tween_property(box, "modulate:a", 0.0, 1.5)


func _build_hint() -> void:
	_hint = Label.new()
	_hint.text = controls_hint
	_hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_hint.offset_top = -46
	_hint.offset_bottom = -14
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_font_override("font", _hand)
	_hint.add_theme_font_size_override("font_size", 24)
	_hint.add_theme_color_override("font_color", Color(0.96, 0.9, 0.78))
	_hint.add_theme_color_override("font_outline_color", Color(0.15, 0.09, 0.05, 0.9))
	_hint.add_theme_constant_override("outline_size", 6)
	add_child(_hint)


func _make_panel(width: float) -> Array:
	var dim := ColorRect.new()
	dim.color = Color(0.04, 0.03, 0.02, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.hide()
	add_child(dim)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(width, 0)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	dim.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	return [dim, box]


func _heading(text: String, size: int = 44) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	return l


func _button(text: String, cb: Callable, node_name: String = "") -> Button:
	var b := Button.new()
	b.text = text
	if node_name != "":
		b.name = node_name
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(cb)
	return b


func _build_pause() -> void:
	var parts := _make_panel(440)
	_pause = parts[0]
	var box: VBoxContainer = parts[1]
	box.add_child(_heading("Paused"))
	box.add_child(_button("Resume", func(): _set_paused(false), "Resume"))
	box.add_child(_button("Restart level", Game.restart_level))
	_pause_timer_check = CheckButton.new()
	_pause_timer_check.text = "Show speedrun timer"
	_pause_timer_check.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_pause_timer_check.toggled.connect(Game.set_show_timer)
	box.add_child(_pause_timer_check)
	box.add_child(_button("Return to title", Game.go_to_menu))


func _build_complete() -> void:
	var parts := _make_panel(520)
	_complete = parts[0]
	var box: VBoxContainer = parts[1]
	box.add_child(_heading("Charted."))
	_complete_flavor = Label.new()
	_complete_flavor.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_complete_flavor.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_complete_flavor.custom_minimum_size = Vector2(440, 0)
	_complete_flavor.add_theme_font_override("font", _hand)
	_complete_flavor.add_theme_font_size_override("font_size", 28)
	_complete_flavor.add_theme_color_override("font_color", Color(0.4, 0.22, 0.12))
	box.add_child(_complete_flavor)
	_complete_time = _heading("", 40)
	box.add_child(_complete_time)
	_complete_best = _heading("", 24)
	box.add_child(_complete_best)
	_continue_btn = _button("Continue", _on_continue)
	box.add_child(_continue_btn)
	box.add_child(_button("Retry", Game.restart_level))


func _build_fail() -> void:
	var parts := _make_panel(520)
	_fail = parts[0]
	var box: VBoxContainer = parts[1]
	_fail_title = _heading("Dragged under.")
	box.add_child(_fail_title)
	_fail_text = Label.new()
	_fail_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_fail_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_fail_text.custom_minimum_size = Vector2(440, 0)
	_fail_text.add_theme_font_override("font", _hand)
	_fail_text.add_theme_font_size_override("font_size", 28)
	_fail_text.add_theme_color_override("font_color", Color(0.42, 0.06, 0.05))
	box.add_child(_fail_text)
	_retry_btn = _button("Try again", Game.restart_level)
	box.add_child(_retry_btn)
	box.add_child(_button("Return to title", Game.go_to_menu))


## Levels may set these before calling Game.fail_level().
var failure_title := "Dragged under."
var failure_text := "The sea keeps what it takes."


func _on_level_failed(reason: String) -> void:
	if not show_failure_card:
		return
	await get_tree().create_timer(0.3).timeout
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_fail_title.text = failure_title
	_fail_text.text = reason if reason != "" else failure_text
	_fail.show()
	_fail.modulate.a = 0.0
	create_tween().tween_property(_fail, "modulate:a", 1.0, 0.8)
	_retry_btn.grab_focus()


# ================================================================ survey list
## Optional objectives: a small handwritten checklist in the top-left corner.
var _objectives: Control
var _obj_names: Array = []
var _obj_done := {}
var _obj_flash := {}
var _obj_heading := "survey"
var _obj_ordered := false
var _obj_notes: Array = []
var _obj_plain := false


## `ordered`: a route — only the next item is named, later ones are "? ? ?".
## `plain`: unordered items are simply named (no "? ? ?").
func set_objectives(heading: String, names: Array, ordered := false, plain := false) -> void:
	_obj_plain = plain
	_obj_heading = heading
	_obj_names = names.duplicate()
	_obj_ordered = ordered
	_obj_done.clear()
	if _objectives == null:
		_objectives = Control.new()
		_objectives.position = Vector2(20, 96)
		_objectives.size = Vector2(300, 40 + 28 * names.size())
		_objectives.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_objectives.draw.connect(_draw_objectives)
		add_child(_objectives)
	_objectives.queue_redraw()


func tick_objective(name: String) -> void:
	if _obj_done.has(name):
		return
	_obj_done[name] = true
	_obj_flash[name] = 1.0
	Music.sfx("page", 0.8)


func objectives_done() -> int:
	return _obj_done.size()


## Extra lines under the list (e.g. "survey markers 2 / 6", "perfect map").
func set_objective_notes(lines: Array) -> void:
	_obj_notes = lines.duplicate()
	if _objectives:
		_objectives.size.y = 60 + 28 * (_obj_names.size() + _obj_notes.size())
		_objectives.queue_redraw()


func _draw_objectives() -> void:
	var ink := Color(0.95, 0.9, 0.78)
	var shadow := Color(0.1, 0.06, 0.04, 0.8)
	_text(_objectives, Vector2(0, 18), "%s  %d / %d" % [_obj_heading, _obj_done.size(), _obj_names.size()], 22, ink, shadow)
	var current := -1
	for i in _obj_names.size():
		if not _obj_done.has(_obj_names[i]):
			current = i
			break
	for i in _obj_names.size():
		var n: String = _obj_names[i]
		var y := 44.0 + i * 26.0
		var box := Rect2(2, y - 14, 14, 14)
		_objectives.draw_rect(box.grow(1.5), shadow, false, 2.0)
		_objectives.draw_rect(box, ink, false, 1.5)
		var done: bool = _obj_done.has(n)
		var f: float = _obj_flash.get(n, 0.0)
		if done:
			_objectives.draw_line(box.position + Vector2(2, 7), box.position + Vector2(6, 12), Color(0.85, 0.2, 0.12), 2.5)
			_objectives.draw_line(box.position + Vector2(6, 12), box.position + Vector2(15, -2), Color(0.85, 0.2, 0.12), 2.5)
		var label := n
		var col := Color(1.0, 0.75, 0.5).lerp(ink, 1.0 - f) if done else Color(ink, 0.75)
		if not done:
			if _obj_ordered:
				if i == current:
					col = Color(1.0, 0.62, 0.45)
				else:
					label = "? ? ?"
					col = Color(ink, 0.45)
			elif not _obj_plain:
				label = "? ? ?  (" + n + ")"
		_text(_objectives, Vector2(24, y), label, 20, col, shadow)
	for j in _obj_notes.size():
		_text(_objectives, Vector2(2, 50.0 + (_obj_names.size() + j) * 26.0), str(_obj_notes[j]), 20, Color(ink, 0.85), shadow)


func _text(ci: CanvasItem, at: Vector2, t: String, size: int, col: Color, outline: Color) -> void:
	ci.draw_string_outline(_hand, at, t, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 5, outline)
	ci.draw_string(_hand, at, t, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


# ================================================================ the pen
## Ink for drawing things that become real (bridges, walls): drawn as drops.
var _ink: Control
var _ink_count := 0
var _ink_max := 0
var _ink_hint := ""


func set_ink(count: int, max_count: int, hint: String) -> void:
	_ink_count = count
	_ink_max = max_count
	_ink_hint = hint
	if _ink == null:
		_ink = Control.new()
		_ink.position = Vector2(20, 20)
		_ink.size = Vector2(320, 64)
		_ink.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_ink.draw.connect(_draw_ink)
		add_child(_ink)
	_ink.queue_redraw()


func _draw_ink() -> void:
	for i in _ink_max:
		var c := Vector2(14 + i * 26, 22)
		var full := i < _ink_count
		var drop := PackedVector2Array()
		for k in 16:
			var a := TAU * k / 16.0
			var r := 8.0
			var p := c + Vector2(cos(a), sin(a)) * r
			if sin(a) < -0.3:
				p = c + Vector2(cos(a) * r * (1.0 + sin(a)) * 1.4, -r * 1.9 * (-sin(a)))
			drop.append(p)
		if full:
			_ink.draw_colored_polygon(drop, Color(0.16, 0.2, 0.5))
			_ink.draw_circle(c + Vector2(-2.5, -2.0), 2.0, Color(0.7, 0.75, 1.0, 0.8))
		drop.append(drop[0])
		_ink.draw_polyline(drop, Color(0.95, 0.9, 0.78, 0.95 if full else 0.35), 1.5, true)
	_text(_ink, Vector2(0, 56), _ink_hint, 20, Color(0.95, 0.9, 0.78), Color(0.1, 0.06, 0.04, 0.8))


# ================================================================ notes
## A page of someone else's handwriting, shown for a while at the bottom of
## the screen without pausing (messages found at sea, etc).
var _note: PanelContainer
var _note_title: Label
var _note_body: Label
var _note_tw: Tween


func show_note(title: String, body: String, secs := 7.0) -> void:
	if _note == null:
		_note = PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.88, 0.82, 0.67, 0.96)
		sb.border_color = Color(0.35, 0.22, 0.12)
		sb.set_border_width_all(2)
		sb.set_content_margin_all(16)
		sb.shadow_color = Color(0, 0, 0, 0.45)
		sb.shadow_size = 8
		_note.add_theme_stylebox_override("panel", sb)
		_note.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_note.custom_minimum_size = Vector2(560, 0)
		var v := VBoxContainer.new()
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_note.add_child(v)
		_note_title = Label.new()
		_note_title.add_theme_font_override("font", _italic)
		_note_title.add_theme_font_size_override("font_size", 22)
		_note_title.add_theme_color_override("font_color", Color(0.45, 0.1, 0.06))
		v.add_child(_note_title)
		_note_body = Label.new()
		_note_body.add_theme_font_override("font", _hand)
		_note_body.add_theme_font_size_override("font_size", 25)
		_note_body.add_theme_color_override("font_color", Color(0.2, 0.12, 0.07))
		_note_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_note_body.custom_minimum_size = Vector2(528, 0)
		v.add_child(_note_body)
		add_child(_note)
	_note_title.text = title
	_note_body.text = body
	_note.show()
	_note.reset_size()
	await get_tree().process_frame
	var vs := get_viewport().get_visible_rect().size
	_note.reset_size()
	_note.position = Vector2((vs.x - _note.size.x) / 2.0, vs.y - 56.0 - _note.size.y)
	if _note_tw:
		_note_tw.kill()
	_note.modulate.a = 0.0
	_note_tw = create_tween()
	_note_tw.tween_property(_note, "modulate:a", 1.0, 0.5)
	_note_tw.tween_interval(secs)
	_note_tw.tween_property(_note, "modulate:a", 0.0, 1.0)


# ================================================================ context prompt
var _ctx: Label


func set_prompt(text: String) -> void:
	if _ctx == null:
		_ctx = Label.new()
		_ctx.set_anchors_preset(Control.PRESET_CENTER)
		_ctx.grow_horizontal = Control.GROW_DIRECTION_BOTH
		_ctx.position.y += 70
		_ctx.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_ctx.add_theme_font_override("font", _hand)
		_ctx.add_theme_font_size_override("font_size", 30)
		_ctx.add_theme_color_override("font_color", Color(0.98, 0.93, 0.82))
		_ctx.add_theme_color_override("font_outline_color", Color(0.15, 0.08, 0.05, 0.9))
		_ctx.add_theme_constant_override("outline_size", 7)
		_ctx.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_ctx)
	_ctx.text = text


## The level can set this before completion to customise the card's line.
var completion_text := "The map is finished. But the ink will not stay dry."


func _on_level_completed(t: float, is_best: bool) -> void:
	if not show_completion_card:
		return
	await get_tree().create_timer(0.6).timeout
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_complete_flavor.text = completion_text
	_complete_time.visible = Game.show_timer
	_complete_best.visible = Game.show_timer
	_complete_time.text = Game.format_time(t)
	var best := Game.get_best_time(Game.LEVELS[Game.current_level]["id"])
	_complete_best.text = "a new personal best!" if is_best else "best  " + Game.format_time(best)
	_complete.show()
	_complete.modulate.a = 0.0
	create_tween().tween_property(_complete, "modulate:a", 1.0, 0.5)
	_continue_btn.grab_focus()


func _on_continue() -> void:
	_complete.hide()
	if handle_continue_myself:
		continue_requested.emit()
	else:
		Game.next_level()
