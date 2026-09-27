extends Node2D
## Level 1 — "The Survey".
## The jungle map he actually drew by the campfire. It feels safe at first —
## and then the map stops behaving.
##
##  1. The expedition route, in order: the old stone marker → the river
##     crossing → the abandoned campsite → the hilltop → the final surveying point.
##  2. Six survey markers to record. Two aren't where his map says they are.
##  3. After the campsite, part of the map changes: the rope bridge is gone, a
##     path appears that he never drew, and jungle covers open ground.
##  4. At the surveying point the goal becomes RETURN TO CAMP before nightfall —
##     and the way back has changed again.
##  5. Optional: "Perfect map" — finish without setting foot in dead-end terrain.

const PLAY_ZOOM := 1.45
## The paper and map are drawn once into a texture at this resolution, so the
## thousands of ink strokes don't have to be redrawn every frame.
const BAKE_SCALE := 1.5

@onready var map: Node2D = $Map
@onready var paper: ColorRect = $Paper
@onready var player: Node2D = $Explorer
@onready var camera: Camera2D = $Camera
@onready var goal: Node2D = $Goal
@onready var hud: CanvasLayer = $HUD
@onready var vignette: ColorRect = $Overlay/Vignette

var _sheet: Rect2
var _zoom := PLAY_ZOOM
var _cam := Vector2.ZERO
var _start := Vector2.ZERO
var _finished := false
var _grid: MapGrid
var _reveal: ChartReveal
var _baked: Sprite2D

## How far he can see (cells) — high ground shows more, jungle much less.
const SIGHT := {0: 4.5, 1: 7.0, 2: 9.0}
const JUNGLE_SIGHT := 3.0

## The pen: in the dream, what he draws is real. Two lines of ink left — each
## one draws a bridge across up to MAX_SPAN cells of river (or mends a broken one).
const INK := 2
const MAX_SPAN := 4
var ink := INK
var _bridge_cells: Array[Vector2i] = []
var _bridge_script: Script = preload("res://scripts/ink_bridge.gd")

# ------------------------------------------------------------------ the expedition
const ROUTE := [
	{"name": "the old stone marker", "cell": Vector2(13.5, 19.5)},
	{"name": "the river crossing", "cell": Vector2(20.5, 7.5)},
	{"name": "the abandoned campsite", "cell": Vector2(27.5, 21.5)},
	{"name": "the hilltop", "cell": Vector2(47.5, 17.5)},
	{"name": "the final surveying point", "cell": Vector2(59.5, 4.5)},
]
## Survey markers: where his map drew them, and where they really are.
const MARKERS := [
	{"drawn": Vector2(12.5, 31.5), "real": Vector2(12.5, 31.5)},
	{"drawn": Vector2(9.5, 13.5), "real": Vector2(9.5, 13.5)},
	{"drawn": Vector2(29.5, 6.5), "real": Vector2(27.5, 10.5)},
	{"drawn": Vector2(38.5, 21.5), "real": Vector2(40.5, 23.2)},
	{"drawn": Vector2(52.5, 28.5), "real": Vector2(52.5, 28.5)},
	{"drawn": Vector2(54.5, 7.5), "real": Vector2(54.5, 7.5)},
]
## Set true to make every marker required before the surveying point counts.
const REQUIRE_ALL_MARKERS := false
## Dead-end terrain for the "Perfect map" objective (cells). The spur to the
## washed-out bridge only counts while the bridge is broken.
const DEAD_ENDS := [
	Rect2i(16, 33, 8, 7),     # the Sombra delta marsh
	Rect2i(34, 15, 5, 4),     # under the sheer cliffs
	Rect2i(57, 29, 7, 11),    # the far corner of the Green Deep
]
const SPUR := Rect2i(42, 24, 3, 3)
## Seconds of daylight left for the walk back to camp.
const NIGHTFALL := 90.0

enum Leg { OUTBOUND, RETURN, DONE }
var leg := Leg.OUTBOUND
var perfect := true
var _spur_live := true
var _exp: Node2D
var _dusk := 0.0
var _night: CanvasModulate
var _return_started := 0.0
var _rebaking := false
var _say_left := 0.0


## A line in his hand, held on screen for a few seconds.
func say(text: String, secs := 3.5) -> void:
	hud.set_prompt(text)
	_say_left = secs


func _ready() -> void:
	var grid: MapGrid = map.grid
	_grid = grid
	player.grid = grid
	_start = grid.cell_center(grid.find("S")) + Vector2(0, 28)
	player.position = _start
	goal.position = grid.cell_center(grid.find("G"))
	_sheet = map.sheet_rect()
	paper.position = _sheet.position
	paper.size = _sheet.size
	(paper.material as ShaderMaterial).set_shader_parameter("rect_size", _sheet.size)
	_cam = player.position
	camera.position = _cam
	camera.zoom = Vector2(_zoom, _zoom)
	camera.reset_smoothing()
	goal.reached.connect(_on_goal_reached)
	hud.handle_continue_myself = true
	hud.continue_requested.connect(_leave)
	_reveal = ChartReveal.new()
	_reveal.name = "Reveal"
	add_child(_reveal)
	_reveal.setup(grid.width, grid.height, MapGrid.CELL)
	_reveal.reveal(_start, 6.5)                     # the camp he'd already drawn
	_bake_sheet()
	hud.set_ink(ink, INK, "E / Space — ink a bridge")
	_setup_expedition()
	Music.play_set("level1")
	hud.completion_text = "The last line is drawn. The ink should dry — but it doesn't. It spreads, dark and wet, and the paper begins to feel like water."


func sight_radius() -> float:
	var c := _grid.cell_of(player.position)
	var r: float = JUNGLE_SIGHT if _grid.tile(c) == "f" else SIGHT.get(_grid.elevation(c), 4.5)
	return r * (1.0 - 0.45 * _dusk)       # dusk closes in


func _process(delta: float) -> void:
	_reveal.reveal(player.position, sight_radius())
	_find_bridge_spot()
	_check_perfect()
	_update_dusk(delta)
	_update_camera(delta)
	# the vignette tightens and cools as he nears the edge of the known
	var total := _start.distance_to(goal.position)
	var progress := 1.0 - clampf(player.position.distance_to(goal.position) / total, 0.0, 1.0)
	var dread := smoothstep(0.45, 1.0, progress) * 0.7
	if _finished:
		dread = 1.0
	# faint at the camp; the tension layer creeps in towards the edge of the map
	Music.set_danger(0.35 if _finished else dread * 0.75)
	var mat := vignette.material as ShaderMaterial
	var cur: float = mat.get_shader_parameter("dread")
	mat.set_shader_parameter("dread", lerpf(cur, dread, 1.0 - exp(-2.0 * delta)))


func _update_camera(delta: float) -> void:
	var vp := get_viewport_rect().size
	var overview := Input.is_action_pressed("map_view") and not _finished
	var fit := minf(vp.x / _sheet.size.x, vp.y / _sheet.size.y)
	var target_zoom := fit if overview else PLAY_ZOOM
	if _finished:
		target_zoom = PLAY_ZOOM * 1.3
	_zoom = lerpf(_zoom, target_zoom, 1.0 - exp(-7.0 * delta))
	camera.zoom = Vector2(_zoom, _zoom)
	var target: Vector2 = _sheet.get_center() if overview else player.position
	_cam = _cam.lerp(target, 1.0 - exp(-9.0 * delta))
	camera.position = _clamp_to_sheet(_cam, vp / (2.0 * _zoom))


func _clamp_to_sheet(p: Vector2, half: Vector2) -> Vector2:
	var lo := _sheet.position + half
	var hi := _sheet.end - half
	p.x = _sheet.get_center().x if lo.x > hi.x else clampf(p.x, lo.x, hi.x)
	p.y = _sheet.get_center().y if lo.y > hi.y else clampf(p.y, lo.y, hi.y)
	return p


# ================================================================ the pen
## Where could a bridge go from here, in the direction he's facing?
func _find_bridge_spot() -> void:
	_bridge_cells.clear()
	if _say_left > 0.0:
		_say_left -= get_process_delta_time()
		if _say_left <= 0.0:
			hud.set_prompt("")
		return
	if ink <= 0 or _finished:
		hud.set_prompt("")
		return
	var f: Vector2 = player._facing
	var d := Vector2i(signi(roundi(f.x)) if absf(f.x) >= absf(f.y) else 0, 0 if absf(f.x) >= absf(f.y) else signi(roundi(f.y)))
	if d == Vector2i.ZERO:
		hud.set_prompt("")
		return
	var here := _grid.cell_of(player.position)
	var h := _grid.elevation(here)
	var c := here + d
	if not _is_water(c):
		c += d                     # allow a step of bank between him and the water
	var cells: Array[Vector2i] = []
	while _is_water(c) and cells.size() <= MAX_SPAN:
		cells.append(c)
		c += d
	if cells.is_empty() or cells.size() > MAX_SPAN:
		hud.set_prompt("")
		return
	if not _grid.is_walkable(c) or _grid.elevation(c) != h or _is_water(c):
		hud.set_prompt("")
		return
	_bridge_cells = cells
	hud.set_prompt("E / Space — ink a bridge  (%d left)" % ink)


func _is_water(c: Vector2i) -> bool:
	return _grid.tile(c) in ["~", "b"]


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and not _bridge_cells.is_empty() and not _finished and not get_tree().paused:
		get_viewport().set_input_as_handled()
		_draw_bridge()


func _draw_bridge() -> void:
	ink -= 1
	Game.begin_level_timer()
	for c in _bridge_cells:
		_grid.set_tile(c, "=")
		_reveal.reveal(_grid.cell_center(c), 2.0)
	var br := Node2D.new()
	br.set_script(_bridge_script)
	var d := Vector2(_bridge_cells[-1] - _bridge_cells[0]).normalized()
	if d == Vector2.ZERO:
		var f: Vector2 = player._facing
		d = Vector2(signf(f.x), 0) if absf(f.x) >= absf(f.y) else Vector2(0, signf(f.y))
	br.a = _grid.cell_center(_bridge_cells[0]) - d * MapGrid.CELL * 0.7
	br.b = _grid.cell_center(_bridge_cells[-1]) + d * MapGrid.CELL * 0.7
	add_child(br)
	move_child(br, $Route.get_index())
	Music.sfx("ink", 0.8, 1.3)
	hud.set_ink(ink, INK, "E / Space — ink a bridge" if ink > 0 else "the pen is dry")
	_bridge_cells.clear()


# ================================================================ expedition
func _setup_expedition() -> void:
	_exp = Node2D.new()
	_exp.set_script(preload("res://levels/level1/expedition.gd"))
	_exp.name = "Expedition"
	_exp.route = ROUTE
	_exp.markers = MARKERS
	_exp.player = player
	_exp.reveal = _reveal
	add_child(_exp)
	move_child(_exp, $Route.get_index())
	_exp.waypoint_reached.connect(_on_waypoint)
	_exp.marker_recorded.connect(_on_marker)
	_exp.marker_missing.connect(_on_marker_missing)
	goal.active = false
	var names: Array = []
	for w in ROUTE:
		names.append(w.name)
	hud.set_objectives("expedition", names, true)
	_update_notes()


func _update_notes() -> void:
	var lines := ["survey markers  %d / %d" % [_exp.recorded.size(), MARKERS.size()]]
	lines.append("perfect map  " + ("— so far" if perfect else "— lost"))
	if leg == Leg.RETURN:
		var left := NIGHTFALL - (Game.level_time - _return_started)
		lines.push_front("RETURN TO CAMP — " + ("the sun is low" if left > 40.0 else ("the sun is setting" if left > 15.0 else "dusk")))
	hud.set_objective_notes(lines)


func _on_waypoint(i: int) -> void:
	hud.tick_objective(ROUTE[i].name)
	Game.begin_level_timer()
	Music.sfx("page", 0.6, 0.9)
	var lines := ["The old stone marker. Older than the survey — older than the map.",
		"The crossing. The rope is sound.",
		"",
		"The hilltop. From here the jungle looks like something drawn.",
		""]
	if lines[i] != "":
		say(lines[i])
	if i == 2:
		_change_map_after_campsite()
	if i + 1 == ROUTE.size() - 1:
		goal.active = not REQUIRE_ALL_MARKERS or _exp.recorded.size() == MARKERS.size()


func _on_marker(i: int) -> void:
	Music.sfx("page", 0.7, 1.2)
	_update_notes()
	if REQUIRE_ALL_MARKERS and _exp.step == ROUTE.size() - 1 and _exp.recorded.size() == MARKERS.size():
		goal.active = true


func _on_marker_missing(i: int) -> void:
	Music.sfx("ink", 0.5, 0.7)
	say("The marker isn't where I drew it.", 3.0)


func _check_perfect() -> void:
	if not perfect:
		return
	var c := _grid.cell_of(player.position)
	var bad := false
	for r: Rect2i in DEAD_ENDS:
		if r.has_point(c):
			bad = true
	if _spur_live and SPUR.has_point(c):
		bad = true
	if bad:
		perfect = false
		Music.sfx("thud", 0.3, 1.4)
		_update_notes()


# ================================================================ the map changes
## Change some cells, then re-ink the sheet so the map shows it (where charted).
func _mutate(changes: Array, note: String) -> void:
	for ch in changes:
		_grid.set_tile(ch[0], ch[1])
	Music.sfx("ink", 1.0, 0.6)
	shake_vignette()
	say(note, 4.0)
	await _rebake()


func _cells_where(r: Rect2i, from: Array, to: String) -> Array:
	var out := []
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			if _grid.tile_xy(x, y) in from:
				out.append([Vector2i(x, y), to])
	return out


## After the abandoned campsite: the rope bridge is gone, a path he never drew
## runs north through the jungle, and jungle has swallowed the open ground east.
func _change_map_after_campsite() -> void:
	var ch := []
	ch.append_array(_cells_where(Rect2i(18, 6, 5, 3), ["="], "~"))           # the rope bridge
	ch.append_array(_cells_where(Rect2i(32, 18, 9, 5), ["."], "f"))          # jungle on open ground
	for p in [Vector2i(28, 20), Vector2i(29, 19), Vector2i(29, 18), Vector2i(30, 17), Vector2i(30, 16),
			Vector2i(30, 15), Vector2i(31, 14), Vector2i(31, 13), Vector2i(31, 12), Vector2i(31, 11),
			Vector2i(32, 10), Vector2i(32, 9)]:
		ch.append([p, "p"])                                                   # a path that wasn't drawn
		ch.append([p + Vector2i(1, 0), "p"])
	_mutate(ch, "The map has changed. I did not draw this.")


## At the surveying point: the way down to the west has fallen in, the east
## bridge is gone — and the washed-out bridge is whole again.
func _change_map_for_return() -> void:
	var ch := []
	ch.append_array(_cells_where(Rect2i(31, 3, 3, 7), ["s"], "#"))           # the west stairs fall in
	ch.append_array(_cells_where(Rect2i(57, 22, 3, 5), ["="], "~"))          # the east bridge
	ch.append_array(_cells_where(Rect2i(42, 23, 3, 4), ["b"], "="))          # the old bridge, mended
	_spur_live = false
	_mutate(ch, "The way back is not the way I came.")


func shake_vignette() -> void:
	var mat := vignette.material as ShaderMaterial
	mat.set_shader_parameter("dread", 1.0)


func _on_goal_reached() -> void:
	if leg == Leg.OUTBOUND:
		hud.tick_objective(ROUTE[ROUTE.size() - 1].name)
		Music.sfx("bell", 0.6, 0.8)
		leg = Leg.RETURN
		_return_started = Game.level_time
		hud.set_objectives("return", ["back to camp"], true)
		_update_notes()
		_change_map_for_return()
		# the goal moves to the camp
		goal.position = _start - Vector2(0, 28)
		goal.camp_mode = true
		goal.rearm()
		return
	_finished = true
	leg = Leg.DONE
	hud.tick_objective("back to camp")
	hud.set_prompt("")
	var id: String = Game.LEVELS[Game.current_level]["id"]
	Game.record_landmarks(id, _exp.recorded.size(), MARKERS.size())
	hud.completion_text += "\n\nSurvey markers recorded: %d of %d.  Perfect map: %s." % [_exp.recorded.size(), MARKERS.size(), "yes" if perfect else "no"]
	hud.completion_text += "\nYou charted %d%% of the sheet." % roundi(_reveal.fraction() * 100.0)
	player.frozen = true
	Game.complete_level()
	goal.z_index = 10
	Music.sfx("ink", 0.9)
	create_tween().tween_property(goal, "bloom", 0.22, 2.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)


# ================================================================ nightfall
func _update_dusk(delta: float) -> void:
	if leg != Leg.RETURN:
		return
	var t := Game.level_time - _return_started
	_dusk = clampf(t / NIGHTFALL, 0.0, 1.0)
	if _night == null:
		_night = CanvasModulate.new()
		add_child(_night)
	_night.color = Color(1, 1, 1).lerp(Color(0.3, 0.33, 0.48), _dusk)
	Music.set_danger(0.3 + 0.6 * _dusk)
	if Engine.get_process_frames() % 30 == 0:
		_update_notes()
	if t >= NIGHTFALL and not _finished:
		_finished = true
		player.frozen = true
		hud.failure_title = "Night fell."
		Game.fail_level("The light went before he reached the camp, and the jungle closed round him in the dark.\nThe way back changes — look for the landmarks, not the way you came.")


func _leave() -> void:
	var tw := create_tween()
	tw.tween_property(goal, "bloom", 1.0, 1.6).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	await tw.finished
	Game.next_level(Color(0.03, 0.07, 0.11))


## Render the paper + map into a mipmapped texture and show it through the
## charting shader. Called again whenever the map changes.
func _bake_sheet() -> void:
	await _rebake()


func _rebake() -> void:
	if DisplayServer.get_name() == "headless" or _rebaking:
		return
	_rebaking = true
	var vp := SubViewport.new()
	vp.size = Vector2i((_sheet.size * BAKE_SCALE).ceil())
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(vp)
	vp.canvas_transform = Transform2D(0.0, Vector2(BAKE_SCALE, BAKE_SCALE), 0.0, -_sheet.position * BAKE_SCALE)
	# the bake gets its own copy of the paper; the live paper stays underneath,
	# so uncharted areas show the very same sheet with no ink on it
	vp.add_child(paper.duplicate())
	map.reparent(vp, false)
	map.show()
	map.queue_redraw()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	img.generate_mipmaps()
	map.reparent(self, false)        # keep the renderer for the next change
	map.hide()
	if _baked == null:
		_baked = Sprite2D.new()
		_baked.name = "BakedSheet"
		_baked.centered = false
		_baked.position = _sheet.position
		_baked.scale = Vector2.ONE / BAKE_SCALE
		_baked.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		add_child(_baked)
		move_child(_baked, paper.get_index() + 1)
		_baked.texture = ImageTexture.create_from_image(img)
		_reveal.attach_to(_baked, _sheet, _grid.pixel_size())
	else:
		_baked.texture = ImageTexture.create_from_image(img)
	vp.queue_free()
	_rebaking = false
