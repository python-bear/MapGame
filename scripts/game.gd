extends Node
## Global game state (autoloaded as `Game`).
##
## Owns: settings (saved to user://settings.cfg), the speedrun timer,
## best times (user://records.cfg), the level order, and scene fades.
##
## A level only needs to:
##   1. Instance res://scenes/ui/hud.tscn (timer, pause menu, completion screen).
##   2. Call Game.begin_level_timer() on the player's first input.
##   3. Call Game.complete_level() when the player reaches the exit.

signal settings_changed
signal level_completed(level_time: float, is_best: bool)
signal level_failed(reason: String)

const SETTINGS_PATH := "user://settings.cfg"
const RECORDS_PATH := "user://records.cfg"

## The dream, in order. Teammates: drop your scene at the path listed and it
## will be picked up automatically when the previous level is finished.
## The story runs: the crossing (he dreams the voyage out) → the survey of the
## island → the cave → the labyrinth. Between levels, scenes/interlude.gd shows
## a few lines if it has any for the level just finished.
const LEVELS := [
	{"id": "level2_beacons", "title": "I. The Drowned Chart", "scene": "res://levels/level2/level2.tscn",
		"goal": "Light the three beacons, then dock at the island. Don't linger.", "finds": "lost ships"},
	{"id": "level1_expedition", "title": "II. The Survey", "scene": "res://levels/level1/level1.tscn",
		"goal": "Survey the route in order — then get back to camp before dark.", "finds": "survey markers"},
	{"id": "cave_hollow", "title": "III. The Hollow", "scene": "res://levels/cave/cave.tscn",
		"goal": "Go down into the dark. Find the door the painters found.", "finds": "cave paintings"},
	{"id": "level3_keys", "title": "IV. Waking", "scene": "res://levels/level3/level3.tscn",
		"goal": "Find the three keys. Find the Door of Light.", "finds": "torn pages"},
]

## Set by the finale before it shows the ending scene: "escape" or "caught".
var ending := ""
## Optional objectives found on the last level played (for the ending screen).
var last_found := 0
var last_total := 0

# --- settings ---------------------------------------------------------------
## Off by default: the first run should be immersive.
var show_timer := false
var fullscreen := false
## 1 = as designed; higher lifts the dark (a gamma curve over the whole screen).
var brightness := 1.0
const BRIGHTNESS_MIN := 0.8
const BRIGHTNESS_MAX := 2.0

# --- run state ----------------------------------------------------------------
var current_level := 0
var level_time := 0.0        ## seconds on the current level
var run_time := 0.0          ## seconds across the whole run (for full-game runs)
var timing := false
var level_finished := false
var full_run := false        ## true when started from the title screen's "Begin"

var _records := ConfigFile.new()
var _fade_layer: CanvasLayer
var _fade_rect: ColorRect
var _changing := false
var _bright_layer: CanvasLayer
var _bright_rect: ColorRect
## The timer shown during cutscenes (intro, interludes, endings): paused, but
## still on screen for runners. Levels show their own in the HUD.
var _cut_layer: CanvasLayer
var _cut_time: Label
var _cut_total: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_register_input()
	_load_settings()
	_records.load(RECORDS_PATH)
	_build_fade()
	_build_brightness()
	_build_cutscene_timer()
	_apply_brightness()


func _process(delta: float) -> void:
	if timing and not get_tree().paused:
		level_time += delta
		run_time += delta
	var scene := get_tree().current_scene
	var cut := show_timer and scene != null and scene.is_in_group("cutscene")
	_cut_layer.visible = cut
	if cut:
		_cut_time.text = format_time(level_time)
		_cut_total.text = "run " + format_time(run_time)
		_cut_total.visible = full_run


# ============================================================ timer
func begin_level_timer() -> void:
	if not timing and not level_finished:
		timing = true


func reset_level_timer() -> void:
	# A restart throws away this attempt's time from the run total too.
	run_time -= level_time
	level_time = 0.0
	timing = false
	level_finished = false


func complete_level() -> void:
	if level_finished:
		return
	timing = false
	level_finished = true
	var id: String = LEVELS[current_level]["id"]
	var best := get_best_time(id)
	var is_best := best < 0.0 or level_time < best
	if is_best:
		_records.set_value("best", id, level_time)
		_records.save(RECORDS_PATH)
	level_completed.emit(level_time, is_best)


## The player died / was caught. Stops the clock; the HUD offers a retry.
func fail_level(reason: String = "") -> void:
	if level_finished:
		return
	timing = false
	level_finished = true
	level_failed.emit(reason)


## Furthest chapter reached (index into LEVELS); unlocks the Chapters page.
func reached() -> int:
	return int(_records.get_value("progress", "reached", -1))


func _mark_reached(index: int) -> void:
	if index > reached():
		_records.set_value("progress", "reached", index)
		_records.save(RECORDS_PATH)


## Most landmarks found in a level (optional objectives).
func record_landmarks(level_id: String, found: int, total: int) -> void:
	if found > get_landmarks(level_id):
		_records.set_value("landmarks", level_id, found)
	_records.set_value("landmarks_total", level_id, total)
	_records.save(RECORDS_PATH)


func get_landmarks(level_id: String) -> int:
	return int(_records.get_value("landmarks", level_id, 0))


func get_landmarks_total(level_id: String) -> int:
	return int(_records.get_value("landmarks_total", level_id, 3))


func get_best_time(level_id: String) -> float:
	return float(_records.get_value("best", level_id, -1.0))


static func format_time(t: float) -> String:
	if t < 0.0:
		return "--:--.--"
	var total_cs := int(round(t * 100.0))
	var cs := total_cs % 100
	var s := (total_cs / 100) % 60
	var m := total_cs / 6000
	return "%02d:%02d.%02d" % [m, s, cs]


# ============================================================ flow
func start_new_run() -> void:
	full_run = true
	run_time = 0.0
	level_time = 0.0
	timing = false
	level_finished = false
	current_level = 0
	change_scene("res://scenes/intro.tscn")


func start_level(index: int) -> void:
	current_level = index
	_mark_reached(index)
	level_time = 0.0
	timing = false
	level_finished = false
	change_scene(LEVELS[index]["scene"])


func restart_level() -> void:
	reset_level_timer()
	get_tree().paused = false
	change_scene(LEVELS[current_level]["scene"], 0.15)


## Animated cutscenes that play after a level instead of its interlude (they
## call next_level(…, true) when they end).
const CUTSCENES := {
	"level2_beacons": "res://scenes/arrival.tscn",      # the crossing → the isle at dawn, the Landing
}


## On to the next level — by way of its cutscene or interlude, if the level just finished
## has one (scenes/interlude.gd calls back with `from_interlude`).
func next_level(fade_color: Color = Color(0.05, 0.04, 0.03), from_interlude := false) -> void:
	if not from_interlude and CUTSCENES.has(LEVELS[current_level]["id"]):
		change_scene(CUTSCENES[LEVELS[current_level]["id"]], 1.2, fade_color)
		return
	if not from_interlude and _has_interlude(LEVELS[current_level]["id"]):
		change_scene("res://scenes/interlude.tscn", 0.8, fade_color)
		return
	var next := current_level + 1
	if next < LEVELS.size() and ResourceLoader.exists(LEVELS[next]["scene"]):
		current_level = next
		_mark_reached(next)
		level_time = 0.0
		timing = false
		level_finished = false
		change_scene(LEVELS[next]["scene"], 0.8, fade_color)
	else:
		# The rest of the dream hasn't been built yet.
		change_scene("res://scenes/to_be_continued.tscn", 0.8, fade_color)


func _has_interlude(id: String) -> bool:
	var script: Script = load("res://scenes/interlude.gd")
	return script != null and (script.get_script_constant_map().get("TEXTS", {}) as Dictionary).has(id)


func level_title(index: int = -1) -> String:
	if index < 0:
		index = current_level
	return LEVELS[index]["title"]


## The finale's last word: show one of the two endings.
func show_ending(kind: String) -> void:
	ending = kind
	change_scene("res://scenes/ending.tscn", 1.2, Color.WHITE if kind == "escape" else Color.BLACK)


func level_goal(index: int = -1) -> String:
	if index < 0:
		index = current_level
	return LEVELS[index].get("goal", "")


func go_to_menu() -> void:
	timing = false
	get_tree().paused = false
	change_scene("res://scenes/main_menu.tscn")


## Fade to black, swap scenes, fade back in.
func change_scene(path: String, fade_time: float = 0.6, color: Color = Color(0.05, 0.04, 0.03)) -> void:
	if _changing:
		return
	_changing = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_fade_rect.color = Color(color, _fade_rect.color.a)
	var tw := create_tween()
	tw.tween_property(_fade_rect, "color:a", 1.0, fade_time)
	await tw.finished
	get_tree().paused = false
	get_tree().change_scene_to_file(path)
	await get_tree().process_frame
	await get_tree().process_frame
	var tw2 := create_tween()
	tw2.tween_property(_fade_rect, "color:a", 0.0, fade_time)
	_changing = false


# ============================================================ settings
func set_show_timer(on: bool) -> void:
	show_timer = on
	_save_settings()
	settings_changed.emit()


func set_brightness(v: float) -> void:
	brightness = clampf(v, BRIGHTNESS_MIN, BRIGHTNESS_MAX)
	_apply_brightness()
	_save_settings()
	settings_changed.emit()


func _apply_brightness() -> void:
	if _bright_rect == null:
		return
	var on := absf(brightness - 1.0) > 0.01
	_bright_layer.visible = on          # no full-screen pass at all when it's off
	(_bright_rect.material as ShaderMaterial).set_shader_parameter("brightness", brightness)


func set_fullscreen(on: bool) -> void:
	fullscreen = on
	_apply_fullscreen()
	_save_settings()
	settings_changed.emit()


func _apply_fullscreen() -> void:
	if DisplayServer.get_name() == "headless":
		return
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)


func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		show_timer = cfg.get_value("speedrun", "show_timer", false)
		fullscreen = cfg.get_value("display", "fullscreen", false)
		brightness = clampf(float(cfg.get_value("display", "brightness", 1.0)), BRIGHTNESS_MIN, BRIGHTNESS_MAX)
	_apply_fullscreen()


func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)  # keep other sections (audio)
	cfg.set_value("speedrun", "show_timer", show_timer)
	cfg.set_value("display", "fullscreen", fullscreen)
	cfg.set_value("display", "brightness", brightness)
	cfg.save(SETTINGS_PATH)


# ============================================================ internals
func _build_fade() -> void:
	_fade_layer = CanvasLayer.new()
	_fade_layer.layer = 100
	add_child(_fade_layer)
	_fade_rect = ColorRect.new()
	_fade_rect.color = Color(0.05, 0.04, 0.03, 0.0)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade_layer.add_child(_fade_rect)


## Brightness: a gamma lift over everything (below the fades, so black stays black).
func _build_brightness() -> void:
	_bright_layer = CanvasLayer.new()
	_bright_layer.layer = 99
	add_child(_bright_layer)
	_bright_rect = ColorRect.new()
	_bright_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bright_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/brightness.gdshader")
	_bright_rect.material = mat
	_bright_layer.add_child(_bright_rect)


func _build_cutscene_timer() -> void:
	_cut_layer = CanvasLayer.new()
	_cut_layer.layer = 90
	_cut_layer.visible = false
	add_child(_cut_layer)
	# placed and styled exactly like the in-level HUD's, so it simply stays put
	_cut_time = Label.new()
	_cut_time.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_cut_time.offset_left = -240
	_cut_time.offset_right = -24
	_cut_time.offset_top = 14
	_cut_time.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_cut_time.add_theme_font_size_override("font_size", 38)
	_cut_time.add_theme_color_override("font_color", Color(0.98, 0.93, 0.82))
	_cut_time.add_theme_color_override("font_outline_color", Color(0.15, 0.09, 0.05))
	_cut_time.add_theme_constant_override("outline_size", 8)
	_cut_layer.add_child(_cut_time)
	_cut_total = _cut_time.duplicate()
	_cut_total.offset_top = 58
	_cut_total.add_theme_font_size_override("font_size", 22)
	_cut_layer.add_child(_cut_total)


## Actions are registered in code so the project works out of the box.
## If an action is already defined in Project Settings > Input Map, that wins.
func _register_input() -> void:
	_add_action("move_left", [KEY_A, KEY_LEFT], [JOY_BUTTON_DPAD_LEFT], JOY_AXIS_LEFT_X, -1.0)
	_add_action("move_right", [KEY_D, KEY_RIGHT], [JOY_BUTTON_DPAD_RIGHT], JOY_AXIS_LEFT_X, 1.0)
	_add_action("move_up", [KEY_W, KEY_UP], [JOY_BUTTON_DPAD_UP], JOY_AXIS_LEFT_Y, -1.0)
	_add_action("move_down", [KEY_S, KEY_DOWN], [JOY_BUTTON_DPAD_DOWN], JOY_AXIS_LEFT_Y, 1.0)
	_add_action("pause", [KEY_ESCAPE, KEY_P], [JOY_BUTTON_START])
	_add_action("restart", [KEY_R], [JOY_BUTTON_BACK])
	_add_action("map_view", [KEY_TAB, KEY_M], [JOY_BUTTON_Y])
	_add_action("skip", [KEY_SPACE, KEY_ENTER, KEY_ESCAPE], [JOY_BUTTON_A, JOY_BUTTON_START])
	_add_action("interact", [KEY_E, KEY_SPACE, KEY_F], [JOY_BUTTON_X, JOY_BUTTON_A])
	_add_action("draw", [KEY_Q], [JOY_BUTTON_B])
	if InputMap.has_action("draw"):
		var rmb := InputEventMouseButton.new()
		rmb.button_index = MOUSE_BUTTON_RIGHT
		InputMap.action_add_event("draw", rmb)
	_add_action("sprint", [KEY_SHIFT], [JOY_BUTTON_LEFT_STICK])
	_add_action("turn_left", [KEY_COMMA], [JOY_BUTTON_LEFT_SHOULDER])
	_add_action("turn_right", [KEY_PERIOD], [JOY_BUTTON_RIGHT_SHOULDER])
	_add_action("look_left", [], [], JOY_AXIS_RIGHT_X, -1.0)
	_add_action("look_right", [], [], JOY_AXIS_RIGHT_X, 1.0)
	_add_action("look_up", [], [], JOY_AXIS_RIGHT_Y, -1.0)
	_add_action("look_down", [], [], JOY_AXIS_RIGHT_Y, 1.0)


func _add_action(action: String, keys: Array, buttons: Array = [], axis: int = -1, axis_dir: float = 0.0) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action, 0.25)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)
	for b in buttons:
		var jb := InputEventJoypadButton.new()
		jb.button_index = b
		InputMap.action_add_event(action, jb)
	if axis >= 0:
		var ja := InputEventJoypadMotion.new()
		ja.axis = axis
		ja.axis_value = axis_dir
		InputMap.action_add_event(action, ja)
