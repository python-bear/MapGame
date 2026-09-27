extends Control
## Title screen: begin a run, change settings, quit.

@onready var paper: ColorRect = $Paper
@onready var doodles: Control = $Doodles
@onready var begin_btn: Button = $Center/Menu/Begin
@onready var settings_btn: Button = $Center/Menu/Settings
@onready var quit_btn: Button = $Center/Menu/Quit
@onready var best_label: Label = $Center/BestTime
@onready var settings_panel: PanelContainer = $SettingsPanel
@onready var timer_check: CheckButton = $SettingsPanel/VBox/ShowTimer
@onready var fullscreen_check: CheckButton = $SettingsPanel/VBox/Fullscreen
@onready var back_btn: Button = $SettingsPanel/VBox/Back
@onready var music_slider: HSlider = $SettingsPanel/VBox/MusicRow/MusicVolume
@onready var sfx_slider: HSlider = $SettingsPanel/VBox/SfxRow/SfxVolume

var _hand: Font = preload("res://assets/fonts/Caveat.ttf")
var _chapters_btn: Button
var _chapters: PanelContainer


func _ready() -> void:
	begin_btn.pressed.connect(Game.start_new_run)
	settings_btn.pressed.connect(_open_settings)
	quit_btn.pressed.connect(func(): get_tree().quit())
	back_btn.pressed.connect(_close_settings)
	timer_check.button_pressed = Game.show_timer
	fullscreen_check.button_pressed = Game.fullscreen
	timer_check.toggled.connect(Game.set_show_timer)
	fullscreen_check.toggled.connect(Game.set_fullscreen)
	Game.settings_changed.connect(_refresh_best)
	music_slider.value = Music.music_volume
	sfx_slider.value = Music.sfx_volume
	music_slider.value_changed.connect(Music.set_music_volume)
	sfx_slider.value_changed.connect(Music.set_sfx_volume)
	sfx_slider.drag_ended.connect(func(_c): Music.sfx("bell", 0.6))
	Music.play_set("menu")
	Music.set_danger(0.0)
	if OS.has_feature("web"):
		quit_btn.hide()
	_build_chapters()
	doodles.draw.connect(_draw_doodles)
	resized.connect(_on_resized)
	_on_resized()
	_refresh_best()
	begin_btn.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if settings_panel.visible and event.is_action_pressed("ui_cancel"):
		_close_settings()
		get_viewport().set_input_as_handled()
	elif _chapters and _chapters.visible and event.is_action_pressed("ui_cancel"):
		_close_chapters()
		get_viewport().set_input_as_handled()


## "Chapters": jump straight back into any level you've reached, with your
## best time beside it.
func _build_chapters() -> void:
	_chapters_btn = Button.new()
	_chapters_btn.text = "Chapters"
	$Center/Menu.add_child(_chapters_btn)
	$Center/Menu.move_child(_chapters_btn, 1)
	_chapters_btn.visible = Game.reached() >= 1
	_chapters_btn.pressed.connect(_open_chapters)
	_chapters = PanelContainer.new()
	_chapters.set_anchors_preset(Control.PRESET_CENTER)
	_chapters.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_chapters.grow_vertical = Control.GROW_DIRECTION_BOTH
	_chapters.custom_minimum_size = Vector2(620, 0)
	_chapters.hide()
	add_child(_chapters)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	_chapters.add_child(box)
	var head := Label.new()
	head.text = "Chapters"
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_theme_font_size_override("font_size", 40)
	box.add_child(head)
	for i in Game.LEVELS.size():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 18)
		box.add_child(row)
		var b := Button.new()
		b.custom_minimum_size = Vector2(360, 0)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var open := i <= maxi(0, Game.reached())
		b.text = Game.level_title(i) if open else "— not yet dreamt —"
		b.disabled = not open
		b.pressed.connect(func():
			Game.full_run = false
			Game.start_level(i))
		row.add_child(b)
		var t := Label.new()
		var best := Game.get_best_time(Game.LEVELS[i]["id"])
		var marks := ""
		if open and best >= 0.0:
			var id: String = Game.LEVELS[i]["id"]
			var what: String = ["survey markers", "lost ships", "torn pages"][mini(i, 2)]
			marks = "%s %d/%d" % [what, Game.get_landmarks(id), Game.get_landmarks_total(id)]
		t.text = (("best  " + Game.format_time(best) + "   ") if (open and best >= 0.0 and Game.show_timer) else "") + marks
		t.add_theme_font_override("font", _hand)
		t.add_theme_font_size_override("font_size", 26)
		t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(t)
	var back := Button.new()
	back.text = "Back"
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(_close_chapters)
	box.add_child(back)


func _open_chapters() -> void:
	_chapters.show()
	$Center.hide()
	(_chapters.get_child(0).get_child(1).get_child(0) as Button).grab_focus()


func _close_chapters() -> void:
	_chapters.hide()
	$Center.show()
	_chapters_btn.grab_focus()


func _on_resized() -> void:
	(paper.material as ShaderMaterial).set_shader_parameter("rect_size", size)
	doodles.queue_redraw()


func _refresh_best() -> void:
	var best := Game.get_best_time(Game.LEVELS[0]["id"])
	if Game.show_timer and best >= 0.0:
		best_label.text = "best survey:  " + Game.format_time(best)
	else:
		best_label.text = ""


func _open_settings() -> void:
	settings_panel.show()
	$Center.hide()
	timer_check.grab_focus()


func _close_settings() -> void:
	settings_panel.hide()
	$Center.show()
	settings_btn.grab_focus()


## Faint survey doodles around the edges of the title page.
func _draw_doodles() -> void:
	var s := doodles.size
	var faint := Color(Ink.INK, 0.28)
	Ink.compass_rose(doodles, Vector2(s.x - 150.0, s.y - 150.0), 95.0, get_theme_default_font(), Color(Ink.INK, 0.45))
	# a dotted route across the page
	var route := [Vector2(60, s.y - 80), Vector2(200, s.y - 170), Vector2(330, s.y - 140),
		Vector2(420, s.y - 260), Vector2(380, 200), Vector2(250, 120), Vector2(120, 90)]
	for i in route.size() - 1:
		Ink.dashed(doodles, route[i], route[i + 1], Color(Ink.RED_INK, 0.45), 2.0, 6.0, 7.0)
	doodles.draw_line(route[-1] + Vector2(-8, -8), route[-1] + Vector2(8, 8), Color(Ink.RED_INK, 0.6), 3.0)
	doodles.draw_line(route[-1] + Vector2(-8, 8), route[-1] + Vector2(8, -8), Color(Ink.RED_INK, 0.6), 3.0)
	# contour squiggles in the corner
	for k in 5:
		var pts := PackedVector2Array()
		for i in 40:
			var a := TAU * i / 39.0
			var r := 40.0 + k * 22.0 + sin(a * 3.0 + k) * 8.0
			pts.append(Vector2(s.x - 120.0, 120.0) + Vector2(cos(a) * r * 1.4, sin(a) * r))
		doodles.draw_polyline(pts, faint, 1.2, true)
	Ink.text(doodles, _hand, Vector2(s.x - 140.0, 125.0), "unsurveyed", 22, Color(Ink.INK, 0.4), -0.1)
	Ink.text(doodles, _hand, Vector2(150, 60), "base camp?", 22, Color(Ink.RED_INK, 0.5), 0.08)
