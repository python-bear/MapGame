extends Node2D
## Level 1 — "The Drowned Chart". He dreams the crossing: the voyage out to
## the island they are now camped on.
##
## Night. Sail from the Mainland, light the three navigation beacons, then
## make fast at the pier of the Landing (either side of it). The chart stops
## telling the truth as you go:
##   * after the first beacon, an island appears that was never charted;
##   * after the second, the Maw silts shut and an island starts to drift
##     across the approach to the Landing.
##
## The tension builds on a clock:
##   0:00–0:30  nothing obvious — rings on the water
##   0:30–0:45  tentacles stand far off, watching, and sink when you come near;
##              something knocks under the ship
##   0:45–1:00  they hunt you, and rise in the channels ahead
##   1:00+      full attack: they erupt all round the ship. At 1:15 it's over.
## Hug the chart's edge or the shallows and they learn where you'll be.
##
## Flares (E / Space, three): chart a wide circle ahead — but light wakes things.
## Lost ships (optional): sail alongside to signal them. Each answers
## differently — a hidden route, a log, a message.

const PLAY_ZOOM := 1.8
const BAKE_SCALE := 1.3
const SEA_SPEEDS := {".": 1.0, ",": 0.75, "S": 1.0, "G": 1.0}

const WATCH_START := 30.0
const WATCHERS := [30.0, 33.5, 37.0, 40.5, 43.0]
const KNOCKS := [32.0, 36.5, 40.0, 43.5]
const CHASE_START := 45.0
const WAVES := [[45.0, 2], [50.0, 1], [55.0, 2]]
const BLOCKS := [47.0, 53.0, 58.0]
const BELLS := [30.0, 45.0, 55.0, 60.0]
const ATTACK_TIME := 60.0
const DOOM_TIME := 75.0
## Narrow places the sea can shut (cells).
const CHOKES := [Vector2(72, 9), Vector2(73, 29), Vector2(92, 19.5), Vector2(93, 38),
	Vector2(88, 27.5), Vector2(104, 26), Vector2(104, 35), Vector2(101, 12), Vector2(101, 46)]
## The Maw's water, which silts up after the second beacon (cells).
const MAW := Rect2i(67, 25, 11, 7)
## The sandbar a lost ship's log says isn't really there.
const HIDDEN_BAR := Rect2i(95, 25, 3, 6)
## Where the first new island may rise (cells, tried in order).
const NEW_ISLANDS := [Vector2(46, 28), Vector2(40, 17), Vector2(44, 41)]

enum Phase { SAILING, CAUGHT, DOOM, DOCKED }

@onready var chart: Node2D = $Chart
@onready var paper: ColorRect = $Paper
@onready var ship: Node2D = $Ship
@onready var camera: Camera2D = $Camera
@onready var hunters: Node2D = $Hunters
@onready var hud: CanvasLayer = $HUD
@onready var vignette: ColorRect = $Overlay/Vignette
@onready var gloom: ColorRect = $Overlay/Gloom

var grid: MapGrid
var phase := Phase.SAILING

var _sheet: Rect2
var _zoom := PLAY_ZOOM
var _cam := Vector2.ZERO
var _shake := 0.0
var _wave_i := 0
var _bell_i := 0
var _berth := Vector2.ZERO
var _pier := Rect2()
var _flow := PackedInt32Array()
var _flow_timer := 0.0
var _flow_cell := Vector2i(-99, -99)
var _hunter_scene: Script = preload("res://scripts/tentacle.gd")
var _thud_cool := 0.0
var _reveal: ChartReveal
## At night the lantern only shows a little of the sea around the ship.
const LANTERN_SIGHT := 4.0
const FLARES := 3
const FLARE_RANGE := 10.0         ## cells ahead of the bow
var flares := FLARES
var _flare_script: Script = preload("res://scripts/flare.gd")
var _flare_hud: Control
var _omens: Node2D
var _watch_i := 0
var _knock_i := 0
var _block_i := 0
var _erupt_cool := 0.0
var _ambush_cool := 0.0
var _hug_time := 0.0
var _beacons_lit := 0
var _answered := 0
var _pier_lamp: PointLight2D
var _dark_pier_cool := 0.0
var _say_left := 0.0
var _rebaking := false
var _baked: Sprite2D
## The chart's changes, rendered ahead of time (see SheetBaker): name -> patch.
var _patches := {}
var _baker := SheetBaker.new()
## Maw cells that were too close to the hull to silt at once; they fill in
## once the ship has moved off.
var _maw_left: Array[Vector2i] = []


func _ready() -> void:
	grid = chart.grid
	grid.speeds = SEA_SPEEDS
	ship.grid = grid
	var s := grid.find("S")
	ship.position = grid.cell_center(s)
	ship.heading = 0.0
	_pier = _find_pier()
	_berth = grid.cell_center(grid.find("G"))
	_sheet = chart.sheet_rect()
	paper.position = _sheet.position
	paper.size = _sheet.size
	(paper.material as ShaderMaterial).set_shader_parameter("rect_size", _sheet.size)
	_cam = ship.position
	camera.position = _cam
	camera.zoom = Vector2(_zoom, _zoom)
	ship.bumped.connect(_on_bump)
	for n in get_tree().get_nodes_in_group("tentacles"):
		n.level = self
	for g in $Obstacles.get_children():
		if "level" in g:
			g.level = self
	hud.failure_title = "Dragged under."
	hud.handle_continue_myself = true
	hud.continue_requested.connect(_leave)
	hud.completion_text = "He makes fast at the pier. The crew wade the stores ashore, and by dark there are tents above the tideline and a fire between them — and beyond the beach, the jungle, waiting to be mapped. Behind them the sea folds shut like a book."
	Music.play_set("level2")
	Music.set_danger(0.05)
	_make_night()
	_reveal = ChartReveal.new()
	_reveal.name = "Reveal"
	add_child(_reveal)
	_reveal.setup(grid.width, grid.height, MapGrid.CELL)
	_reveal.reveal(ship.position, 7.0)                 # the harbour he sailed from
	_reveal.reveal(_pier.get_center() + Vector2(64, 0), 3.5)   # the lit pier, seen from afar
	_build_flare_hud()
	var names: Array = []
	for bc in $Beacons.get_children():
		names.append(bc.title)
		bc.lit_up.connect(_on_beacon)
	hud.set_objectives("beacons", names, false, true)
	for ls in $LostShips.get_children():
		ls.level = self
		ls.signalled.connect(_on_lost_ship)
	_omens = Node2D.new()
	_omens.set_script(preload("res://scripts/sea_omens.gd"))
	_omens.name = "Omens"
	_omens.ship = ship
	add_child(_omens)
	move_child(_omens, ship.get_index())
	_update_notes()
	_bake_sheet()


# ================================================================ loop
func _process(delta: float) -> void:
	var t := Game.level_time
	_thud_cool = maxf(0.0, _thud_cool - delta)
	_dark_pier_cool -= delta
	if _say_left > 0.0:
		_say_left -= delta
		if _say_left <= 0.0:
			hud.set_prompt("")
	if phase == Phase.SAILING:
		_run_timeline(t)
		if _near_pier():
			if _beacons_lit >= $Beacons.get_child_count():
				_dock()
			elif _dark_pier_cool <= 0.0:
				_dark_pier_cool = 4.0
				say("The pier is dark. It won't answer until the three beacons are lit.")
	if phase == Phase.SAILING:
		_reveal.reveal(ship.position, LANTERN_SIGHT)
	if not _maw_left.is_empty():
		_silt_behind()
	_update_flow(delta)
	_update_camera(delta)
	_update_mood(t, delta)


func _run_timeline(t: float) -> void:
	var delta := get_process_delta_time()
	# 0:00–0:30 — nothing obvious
	if t < WATCH_START and randf() < delta * 0.7:
		var p: Vector2 = ship.position + Vector2.from_angle(randf() * TAU) * randf_range(90.0, 260.0)
		if grid.is_walkable(grid.cell_of(p)):
			_omens.ripple(p)
	# 0:30–0:45 — watchers in the distance, knocking beneath
	while _watch_i < WATCHERS.size() and t >= WATCHERS[_watch_i]:
		_spawn_watcher()
		_watch_i += 1
	while _knock_i < KNOCKS.size() and t >= KNOCKS[_knock_i]:
		Music.sfx("thud", 0.55, 0.55 + _knock_i * 0.04)
		shake(2.5)
		_knock_i += 1
	# 0:45–1:00 — the hunt, and channels shutting ahead of you
	while _wave_i < WAVES.size() and t >= WAVES[_wave_i][0]:
		var count: int = WAVES[_wave_i][1]
		for i in count:
			get_tree().create_timer(i * 0.45).timeout.connect(_spawn_hunter)
		if _wave_i == 0:
			Music.sfx("roar", 0.5)
			for w in hunters.get_children():
				if w.mode == Mode_WATCHER:
					w.submerge(1.0)
		_wave_i += 1
	while _block_i < BLOCKS.size() and t >= BLOCKS[_block_i]:
		_block_route()
		_block_i += 1
	while _bell_i < BELLS.size() and t >= BELLS[_bell_i]:
		Music.sfx("bell", 0.9, 1.0 - _bell_i * 0.06)
		shake(2.0)
		_bell_i += 1
	# 1:00+ — full attack
	if t >= ATTACK_TIME:
		if _bell_i >= BELLS.size() and t - ATTACK_TIME < 0.1:
			say("They're rising all round the ship. Make for the pier — now.", 4.0)
		_erupt_cool -= delta
		if _erupt_cool <= 0.0:
			_erupt_cool = lerpf(1.4, 0.7, clampf((t - ATTACK_TIME) / (DOOM_TIME - ATTACK_TIME), 0.0, 1.0))
			_erupt()
		shake(1.2)
	_check_ambush(t, delta)
	if t >= DOOM_TIME:
		_doom()


func _update_mood(t: float, delta: float) -> void:
	var danger := 0.06 + minf(t / WATCH_START, 1.0) * 0.12
	if t >= WATCH_START:
		danger = maxf(danger, 0.25 + 0.2 * clampf((t - WATCH_START) / 15.0, 0.0, 1.0))
	var nearest := 9999.0
	for h in hunters.get_children():
		nearest = minf(nearest, h.global_position.distance_to(ship.position))
	if _wave_i > 0:
		danger = maxf(danger, 0.45 + 0.45 * clampf(1.0 - (nearest - 90.0) / 380.0, 0.0, 1.0))
	danger = maxf(danger, clampf((t - 50.0) / 12.0, 0.0, 1.0) * 0.95)
	match phase:
		Phase.CAUGHT, Phase.DOOM:
			danger = 1.0
		Phase.DOCKED:
			danger = 0.15
	Music.set_danger(danger)
	# the chart darkens as the minute runs out
	var dusk := clampf((t - 40.0) / 30.0, 0.0, 1.0)
	if phase == Phase.DOCKED:
		dusk = 0.0
	if phase == Phase.CAUGHT or phase == Phase.DOOM:
		dusk = 1.0
	gloom.color.a = lerpf(gloom.color.a, dusk * 0.4, 1.0 - exp(-2.0 * delta))
	var mat := vignette.material as ShaderMaterial
	var cur: float = mat.get_shader_parameter("dread")
	mat.set_shader_parameter("dread", lerpf(cur, 0.35 + dusk * 0.6, 1.0 - exp(-2.0 * delta)))


func _update_camera(delta: float) -> void:
	var vp := get_viewport_rect().size
	var overview := Input.is_action_pressed("map_view") and phase == Phase.SAILING
	var fit := minf(vp.x / _sheet.size.x, vp.y / _sheet.size.y)
	var target_zoom := fit if overview else PLAY_ZOOM
	if phase == Phase.CAUGHT or phase == Phase.DOOM:
		target_zoom = PLAY_ZOOM * 1.35
	_zoom = lerpf(_zoom, target_zoom, 1.0 - exp(-7.0 * delta))
	camera.zoom = Vector2(_zoom, _zoom)
	var look: Vector2 = ship.velocity() * 0.45
	var target: Vector2 = _sheet.get_center() if overview else ship.position + look
	_cam = _cam.lerp(target, 1.0 - exp(-6.0 * delta))
	var half := vp / (2.0 * _zoom)
	var lo := _sheet.position + half
	var hi := _sheet.end - half
	var p := _cam
	p.x = _sheet.get_center().x if lo.x > hi.x else clampf(p.x, lo.x, hi.x)
	p.y = _sheet.get_center().y if lo.y > hi.y else clampf(p.y, lo.y, hi.y)
	_shake = move_toward(_shake, 0.0, 20.0 * delta)
	camera.position = p + Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake


func shake(amount: float) -> void:
	_shake = maxf(_shake, amount)


func _on_bump(strength: float) -> void:
	if _thud_cool <= 0.0:
		_thud_cool = 0.4
		Music.sfx("thud", 0.4 + strength * 0.5, randf_range(0.9, 1.1))
		shake(3.0 * strength)


# ================================================================ flares
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and phase == Phase.SAILING and not get_tree().paused:
		get_viewport().set_input_as_handled()
		fire_flare()


func fire_flare() -> void:
	if flares <= 0:
		Music.sfx("thud", 0.3, 1.6)      # a dry click: none left
		return
	flares -= 1
	Game.begin_level_timer()
	_flare_hud.queue_redraw()
	var f := Node2D.new()
	f.set_script(_flare_script)
	f.from = ship.position
	var dir := Vector2.from_angle(ship.heading)
	f.target = ship.position + dir * FLARE_RANGE * MapGrid.CELL
	f.reveal = _reveal
	f.burst.connect(_on_flare_burst)
	add_child(f)


## The light wakes something beneath it.
func _on_flare_burst(at: Vector2) -> void:
	shake(2.5)
	await get_tree().create_timer(1.1).timeout
	if phase != Phase.SAILING:
		return
	if Game.level_time < CHASE_START:
		Music.sfx("emerge", 0.4, 0.8)
		_spawn_watcher(at)
		return
	Music.sfx("roar", 0.35, 1.3)
	_spawn_hunter(at)


func _build_flare_hud() -> void:
	_flare_hud = Control.new()
	_flare_hud.name = "FlareHud"
	_flare_hud.position = Vector2(20, 20)
	_flare_hud.size = Vector2(160, 60)
	_flare_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flare_hud.draw.connect(_draw_flare_hud)
	hud.add_child(_flare_hud)


func _draw_flare_hud() -> void:
	var ink := Color(0.95, 0.9, 0.78)
	var font: Font = preload("res://assets/fonts/Caveat.ttf")
	for i in FLARES:
		var x := 14.0 + i * 26.0
		var lit := i < flares
		var c := Color(0.85, 0.25, 0.15) if lit else Color(0.5, 0.45, 0.4, 0.4)
		_flare_hud.draw_rect(Rect2(x - 5, 10, 10, 26), c)
		_flare_hud.draw_rect(Rect2(x - 5, 10, 10, 26), Color(0.1, 0.06, 0.04, 0.9), false, 2.0)
		_flare_hud.draw_colored_polygon(PackedVector2Array([Vector2(x - 5, 10), Vector2(x, 2), Vector2(x + 5, 10)]), Color(0.1, 0.06, 0.04, 0.9 if lit else 0.4))
	_flare_hud.draw_string_outline(font, Vector2(0, 56), "E / Space — flare", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, 5, Color(0.1, 0.06, 0.04, 0.8))
	_flare_hud.draw_string(font, Vector2(0, 56), "E / Space — flare", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, ink)


# ================================================================ hunters
## Breadth-first distances from the ship over open water, refreshed often.
func _update_flow(delta: float) -> void:
	_flow_timer -= delta
	var c := grid.cell_of(ship.position)
	if _flow_timer > 0.0 and c == _flow_cell:
		return
	_flow_timer = 0.25
	_flow_cell = c
	var w := grid.width
	_flow.resize(w * grid.height)
	_flow.fill(-1)
	if not grid.in_bounds(c):
		return
	var q: Array[Vector2i] = [c]
	_flow[c.y * w + c.x] = 0
	var head := 0
	while head < q.size():
		var cur := q[head]
		head += 1
		var d := _flow[cur.y * w + cur.x]
		for o: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n := cur + o
			if grid.in_bounds(n) and _flow[n.y * w + n.x] < 0 and grid.is_walkable(n):
				_flow[n.y * w + n.x] = d + 1
				q.append(n)


## Which way should something in the water at `pos` swim to reach the ship?
func flow_dir(pos: Vector2) -> Vector2:
	var c := grid.cell_of(pos)
	var direct := (ship.position - pos).normalized()
	if not grid.in_bounds(c) or _flow.is_empty():
		return direct
	var w := grid.width
	var here := _flow[c.y * w + c.x]
	if here < 0 or here <= 2:
		return direct
	var best := c
	var best_d := here
	for o: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
			Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]:
		var n := c + o
		if not grid.in_bounds(n):
			continue
		if o.x != 0 and o.y != 0 and (not grid.is_walkable(Vector2i(n.x, c.y)) or not grid.is_walkable(Vector2i(c.x, n.y))):
			continue
		var nd := _flow[n.y * w + n.x]
		if nd >= 0 and nd < best_d:
			best_d = nd
			best = n
	return (grid.cell_center(best) - pos).normalized()


func _hunter_speed() -> float:
	return lerpf(110.0, 165.0, clampf((Game.level_time - CHASE_START) / 25.0, 0.0, 1.0))


func _spawn_hunter(near := Vector2.INF) -> void:
	if phase != Phase.SAILING:
		return
	if near != Vector2.INF:
		# woken by a flare: rise somewhere under where it burst
		for attempt in 30:
			var p := near + Vector2.from_angle(randf() * TAU) * randf_range(0.0, 110.0)
			var c := grid.cell_of(p)
			if grid.is_walkable(c) and p.distance_to(ship.position) > 150.0:
				var w := _make_tentacle(Mode_CHASER, grid.cell_center(c))
				w.speed = _hunter_speed()
				w.caught_ship.connect(_on_caught)
				w.rise(0.9)
				Music.sfx("emerge", 0.9)
				return
		return
	var back := -Vector2.from_angle(ship.heading)
	if ship.velocity().length() > 20.0:
		back = -ship.velocity().normalized()
	var spot := Vector2.INF
	for attempt in 40:
		var dist := randf_range(230.0, 340.0) + attempt * 6.0
		var side := randf_range(-0.9, 0.9) * (1.0 + attempt * 0.05)
		var p: Vector2 = ship.position + back.rotated(side) * dist
		var c := grid.cell_of(p)
		var behind := (p - ship.position).normalized().dot(-back) < -0.25
		if behind and grid.is_walkable(c) and grid.in_bounds(c) and _flow.size() > 0 \
				and _flow[c.y * grid.width + c.x] > 5:
			spot = grid.cell_center(c)
			break
	if spot == Vector2.INF:
		# nowhere behind him yet (tight channel) — try again in a moment
		get_tree().create_timer(0.7).timeout.connect(_spawn_hunter)
		return
	var h := _make_tentacle(Mode_CHASER, spot)
	h.speed = _hunter_speed()
	h.caught_ship.connect(_on_caught)
	h.rise(0.9)
	Music.sfx("emerge", 0.9, randf_range(0.85, 1.1))
	Music.sfx("splash", 0.7)


const Mode_GUARD := 0
const Mode_CHASER := 1
const Mode_CLOSE := 2
const Mode_WATCHER := 3


## Far off, something stands out of the water and watches. Near a flare's
## burst if given, otherwise somewhere ahead where he'll see it.
func _spawn_watcher(near := Vector2.INF) -> void:
	if phase != Phase.SAILING:
		return
	var fwd := Vector2.from_angle(ship.heading)
	for attempt in 30:
		var p: Vector2
		if near != Vector2.INF:
			p = near + Vector2.from_angle(randf() * TAU) * randf_range(0.0, 90.0)
		else:
			p = ship.position + fwd.rotated(randf_range(-1.2, 1.2)) * randf_range(290.0, 360.0)
		var c := grid.cell_of(p)
		if grid.in_bounds(c) and grid.is_walkable(c) and p.distance_to(ship.position) > 250.0:
			var w := _make_tentacle(Mode_WATCHER, grid.cell_center(c))
			w.speed = 0.0
			w.lean = (ship.position - p).angle()
			w.rise(1.4, 0.4)
			Music.sfx("splash", 0.3, 0.6)
			w.lifetime = randf_range(6.0, 8.0)      # they don't stay long
			return


## A channel ahead of the ship fills with a rising tentacle (a guard: it
## shoves ships away rather than taking them).
func _block_route() -> void:
	if phase != Phase.SAILING:
		return
	var fwd: Vector2 = ship.velocity().normalized() if ship.velocity().length() > 20.0 else Vector2.from_angle(ship.heading)
	var best := Vector2.INF
	var best_score := 1e9
	for c: Vector2 in CHOKES:
		var p := c * MapGrid.CELL
		var to := p - ship.position
		var d := to.length()
		if d < 200.0 or d > 900.0:
			continue
		var score := d * (1.6 - to.normalized().dot(fwd))
		if score < best_score and grid.is_walkable(grid.cell_of(p)):
			best_score = score
			best = p
	if best == Vector2.INF:
		return
	var g := _make_tentacle(Mode_GUARD, best, true)
	g.length = 96.0
	g.thickness = 14.0
	g.lean = randf() * TAU
	g.rise(1.0, 1.0)
	Music.sfx("emerge", 0.8, 0.7)
	say("Something has risen in the channel ahead.", 2.5)


## 1:00+ — they erupt around the ship.
func _erupt() -> void:
	if phase != Phase.SAILING:
		return
	var v: Vector2 = ship.velocity()
	for attempt in 20:
		var a := randf() * TAU
		if v.length() > 30.0 and attempt < 10:
			a = v.angle() + randf_range(-1.1, 1.1)      # mostly where he's going
		var p: Vector2 = ship.position + Vector2.from_angle(a) * randf_range(120.0, 190.0)
		var c := grid.cell_of(p)
		if grid.in_bounds(c) and grid.is_walkable(c):
			var h := _make_tentacle(Mode_CHASER, grid.cell_center(c))
			h.speed = _hunter_speed()
			h.caught_ship.connect(_on_caught)
			h.rise(0.7, 0.75)
			Music.sfx("emerge", 0.8, randf_range(0.8, 1.2))
			return


## Hugging the chart's edge, or creeping along the shallows, is exactly what
## they expect: they come up ahead of you there.
func _check_ambush(t: float, delta: float) -> void:
	_ambush_cool -= delta
	if t < 20.0 or _ambush_cool > 0.0:
		return
	var c := grid.cell_of(ship.position)
	var at_edge := c.y <= 3 or c.y >= grid.height - 4
	if grid.tile(c) == "," and t >= CHASE_START:
		_hug_time += delta
	else:
		_hug_time = maxf(0.0, _hug_time - delta * 2.0)
	if not at_edge and _hug_time < 2.5:
		return
	var v: Vector2 = ship.velocity()
	if v.length() < 40.0:
		return
	for k in [6.0, 7.0, 5.0, 8.0]:
		var p: Vector2 = ship.position + v.normalized() * k * MapGrid.CELL
		var pc := grid.cell_of(p)
		if grid.in_bounds(pc) and grid.is_walkable(pc):
			var h := _make_tentacle(Mode_CHASER if t >= CHASE_START else Mode_GUARD, grid.cell_center(pc), true)
			if t >= CHASE_START:
				h.speed = _hunter_speed()
				h.caught_ship.connect(_on_caught)
			else:
				h.lifetime = 7.0
			h.rise(0.8, 1.0)
			Music.sfx("emerge", 0.9)
			_ambush_cool = 9.0
			_hug_time = 0.0
			if at_edge:
				say("They know the edges of the chart.", 2.5)
			else:
				say("They're waiting in the shallows.", 2.5)
			return


func _make_tentacle(mode: int, at: Vector2, hidden := false) -> Node2D:
	var h := Node2D.new()
	h.set_script(_hunter_scene)
	h.mode = mode
	if hidden:
		h.rise_radius = 1.0        # starts under the water; the caller raises it
		h.always_visible = true
	h.length = randf_range(62.0, 80.0)
	h.thickness = randf_range(10.0, 13.0)
	h.level = self
	h.position = at
	hunters.add_child(h)
	return h


func _physics_process(_delta: float) -> void:
	# hunters speed up as the minute runs down
	if phase == Phase.SAILING:
		var sp := _hunter_speed()
		for h in hunters.get_children():
			if h.mode == Mode_CHASER:
				h.speed = sp


# ================================================================ endings
func _on_caught() -> void:
	if phase != Phase.SAILING:
		return
	phase = Phase.CAUGHT
	_drag_under("A tentacle touched the hull and wrapped the keel.\nWatch for dark shapes swelling under the water — and remember that light wakes them.", 4, 36.0)


func _doom() -> void:
	if phase != Phase.SAILING:
		return
	phase = Phase.DOOM
	Game.timing = false
	ship.frozen = true
	Music.sfx("roar", 1.0)
	shake(8.0)
	# they rise all around him…
	var ring := []
	var n := 14
	for i in n:
		var a := TAU * i / n + randf_range(-0.1, 0.1)
		var p: Vector2 = ship.position + Vector2.from_angle(a) * randf_range(150.0, 190.0)
		for tries in 6:   # only out of the water, never out of the land
			if grid.is_walkable(grid.cell_of(p)):
				break
			p = ship.position + Vector2.from_angle(a) * randf_range(70.0, 150.0)
		if not grid.is_walkable(grid.cell_of(p)):
			continue
		var h := _make_tentacle(Mode_CLOSE, p)
		h.target = ship.position + Vector2.from_angle(a) * 26.0
		h.speed = 0.0
		h.lean = a + PI
		ring.append(h)
		_rise_later(h, i * 0.08)
	await get_tree().create_timer(1.8).timeout
	# …and close in
	for h in ring:
		if is_instance_valid(h):
			h.speed = 90.0
	await get_tree().create_timer(1.6).timeout
	_drag_under("After the minute the sea stops watching and comes for you; a quarter-minute later the water closes over him like a page turning.\nThe bell tolls at 30, 45, 55 and 60 seconds.", 0, 0.0)


func _rise_later(h: Node2D, delay: float) -> void:
	await get_tree().create_timer(delay).timeout
	if is_instance_valid(h):
		h.rise(0.8)
		Music.sfx("splash", 0.4, randf_range(0.7, 1.2))


func _drag_under(reason: String, extra: int, radius: float) -> void:
	Game.timing = false
	ship.frozen = true
	Music.sfx("roar", 0.9, 0.9)
	shake(7.0)
	for i in extra:
		var a := TAU * i / extra + 0.4
		var h := _make_tentacle(Mode_CLOSE, ship.position + Vector2.from_angle(a) * radius)
		h.target = ship.position + Vector2.from_angle(a) * 14.0
		h.speed = 30.0
		h.lean = a + PI
		h.rise(0.5, 0.0)
	await get_tree().create_timer(0.6).timeout
	Music.sfx("splash", 1.0, 0.6)
	var tw := create_tween()
	tw.tween_property(ship, "sink", 1.0, 2.2).set_ease(Tween.EASE_IN)
	await tw.finished
	for h in hunters.get_children():
		h.submerge(1.5)
	Game.fail_level(reason)


func _dock() -> void:
	phase = Phase.DOCKED
	ship.frozen = true
	hud.completion_text += "\n\nYou charted %d%% of the sea." % roundi(_reveal.fraction() * 100.0)
	var total := $LostShips.get_child_count()
	Game.record_landmarks(Game.LEVELS[Game.current_level]["id"], _answered, total)
	hud.completion_text += "  Lost ships answered: %d of %d." % [_answered, total]
	hud.set_prompt("")
	Music.sfx("bell", 1.0, 1.1)
	Game.complete_level()
	for h in hunters.get_children():
		h.submerge(1.4)
	# come alongside whichever side of the pier we reached
	var north := ship.position.y < _pier.get_center().y
	var bx := clampf(ship.position.x, _pier.position.x + 18.0, _pier.end.x - 18.0)
	_berth = Vector2(bx, _pier.position.y - 17.0 if north else _pier.end.y + 17.0)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(ship, "position", _berth, 1.2).set_trans(Tween.TRANS_SINE)
	tw.tween_property(ship, "heading", 0.0, 1.2).set_trans(Tween.TRANS_SINE)


## The pier's rectangle in world space.
func _find_pier() -> Rect2:
	var r := Rect2()
	var first := true
	for y in grid.height:
		for x in grid.width:
			if grid.tile_xy(x, y) == "P":
				var cr := Rect2(Vector2(x, y) * MapGrid.CELL, Vector2.ONE * MapGrid.CELL)
				r = cr if first else r.merge(cr)
				first = false
	return r


func _near_pier() -> bool:
	var p: Vector2 = ship.position
	var q := Vector2(clampf(p.x, _pier.position.x, _pier.end.x), clampf(p.y, _pier.position.y, _pier.end.y))
	return p.distance_to(q) < 30.0


## Night falls on the chart: everything dims to a cold blue, and only lamps
## show the paper's true colour — the ship's lantern, the pier's lamp, and the
## campfire between the three tents on the Landing.
func _make_night() -> void:
	var night := CanvasModulate.new()
	night.name = "Night"
	night.color = Color(0.36, 0.4, 0.54)
	add_child(night)
	ship.add_child(_lamp(Color(1.0, 0.86, 0.6), 1.25, 2.6))
	var pier_lamp := _lamp(Color(1.0, 0.8, 0.5), 0.25, 1.4)   # dark until the beacons are lit
	pier_lamp.position = Vector2(_pier.position.x + 4.0, _pier.position.y - 7.0)
	add_child(pier_lamp)
	_pier_lamp = pier_lamp
	if chart.tents.size() > 0:
		var c := Vector2.ZERO
		for t: Vector2 in chart.tents:
			c += t
		var fire := _lamp(Color(1.0, 0.55, 0.25), 1.1, 1.6)
		fire.position = c / chart.tents.size() * MapGrid.CELL
		fire.name = "Campfire"
		add_child(fire)


func _lamp(col: Color, energy: float, scale_: float) -> PointLight2D:
	var l := PointLight2D.new()
	var g := GradientTexture2D.new()
	g.width = 256
	g.height = 256
	g.fill = GradientTexture2D.FILL_RADIAL
	g.fill_from = Vector2(0.5, 0.5)
	g.fill_to = Vector2(1.0, 0.5)
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 1))
	grad.set_color(1, Color(1, 1, 1, 0))
	grad.add_point(0.45, Color(1, 1, 1, 0.55))
	g.gradient = grad
	l.texture = g
	l.color = col
	l.energy = energy
	l.texture_scale = scale_
	return l


func _leave() -> void:
	Music.sfx("ink", 0.8)
	Game.next_level(Color(0.02, 0.02, 0.03))


# ================================================================ baking
## Render the paper + chart into a mipmapped texture shown through the
## charting shader — then, while the title is up, render the two ways the sea
## can change (so neither causes a stall when it happens).
func _bake_sheet() -> void:
	await _rebake()
	await _prebake_changes()


func _rebake() -> void:
	if DisplayServer.get_name() == "headless" or _rebaking:
		return
	_rebaking = true
	var img: Image = await _baker.render(self, chart, paper, _sheet, BAKE_SCALE)
	if _baked == null:
		_baked = _baker.sheet_sprite(img, _sheet, BAKE_SCALE)
		add_child(_baked)
		move_child(_baked, paper.get_index() + 1)
		_reveal.attach_to(_baked, _sheet, grid.pixel_size(), Color(0.05, 0.08, 0.12))
	else:
		img.generate_mipmaps()
		_baked.texture = ImageTexture.create_from_image(img)
		for p in _patches.values():
			p.hide()
		_patches.clear()
	_rebaking = false


## Each change is rendered on a copy of the grid, on its own (they are far
## apart on the chart, so either can happen first).
func _prebake_changes() -> void:
	if DisplayServer.get_name() == "headless" or _baked == null:
		return
	_rebaking = true
	var live := grid
	for change in [["maw", MAW, [".", ","], "z"], ["route", HIDDEN_BAR, ["z"], "."]]:
		var g := live.clone()
		var r: Rect2i = change[1]
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				if g.tile_xy(x, y) in change[2]:
					g.set_tile(Vector2i(x, y), change[3])
		chart.grid = g
		chart.refresh()
		var img: Image = await _baker.render(self, chart, paper, _sheet, BAKE_SCALE)
		var patch := _baker.patch(img, Rect2(Vector2(r.position) * MapGrid.CELL, Vector2(r.size) * MapGrid.CELL).grow(3.0 * MapGrid.CELL),
			_sheet, BAKE_SCALE, _baked.material)
		patch.name = "Patch_" + change[0]
		add_child(patch)
		move_child(patch, _baked.get_index() + 1)
		_patches[change[0]] = patch
	chart.grid = live
	chart.refresh()
	_rebaking = false


func _show_patch(patch_name: String) -> void:
	while _rebaking:
		await get_tree().process_frame
	var p: Sprite2D = _patches.get(patch_name)
	if p == null:
		chart.refresh()
		await _rebake()           # not baked (or headless): the slow way
		return
	p.modulate.a = 0.0
	p.show()
	create_tween().tween_property(p, "modulate:a", 1.0, 0.9)


# ================================================================ beacons & the changing sea
## A line in his hand, held on screen for a few seconds.
func say(text: String, secs := 3.5) -> void:
	hud.set_prompt(text)
	_say_left = secs


func _update_notes() -> void:
	var lines := []
	var n := $Beacons.get_child_count()
	lines.append("then: dock at the island" + ("" if _beacons_lit >= n else "  (the pier is dark)"))
	lines.append("lost ships answered  %d / %d" % [_answered, $LostShips.get_child_count()])
	hud.set_objective_notes(lines)


func _on_beacon(b: Node2D) -> void:
	_beacons_lit += 1
	hud.tick_objective(b.title)
	Game.begin_level_timer()
	Music.sfx("bell", 0.7, 1.25)
	_reveal.reveal(b.global_position, 5.0)
	_update_notes()
	match _beacons_lit:
		1:
			_raise_new_island()
		2:
			_sea_forgets()
		3:
			say("Three lights. Far off, the pier's lamp answers.", 4.0)
			create_tween().tween_property(_pier_lamp, "energy", 1.3, 1.5)
			_reveal.reveal(_pier.get_center() + Vector2(64, 0), 5.0)


## After the first beacon: an island where the chart shows open sea.
func _raise_new_island() -> void:
	for c: Vector2 in NEW_ISLANDS:
		if ship.position.distance_to(c * MapGrid.CELL) > 11.0 * MapGrid.CELL:
			var isl := _make_island(c, c, 0.0, 3.2, 2.6, "an island. it was not here.")
			_reveal.reveal(c * MapGrid.CELL, 4.5)
			Music.sfx("roar", 0.25, 0.5)
			shake(3.0)
			say("There's an island off the bow that isn't on the chart.", 4.0)
			return


## After the second beacon: the Maw silts up, and an island starts to drift
## across the approach to the Landing.
func _sea_forgets() -> void:
	var here := grid.cell_of(ship.position)
	for y in range(MAW.position.y, MAW.end.y):
		for x in range(MAW.position.x, MAW.end.x):
			var c := Vector2i(x, y)
			if grid.tile(c) in [".", ","]:
				if Vector2(c - here).length() > 4.0:
					grid.set_tile(c, "z")
				else:
					_maw_left.append(c)         # the silt closes in behind him
	_show_patch("maw")
	_make_island(Vector2(101.5, 13.0), Vector2(101.5, 45.0), 0.9, 3.0, 2.4, "it is moving")
	Music.sfx("roar", 0.35, 0.45)
	shake(4.0)
	hud.show_note("in the margin, in his own hand",
		"The Maw has silted shut. An island is drifting across the chart.\nThe map isn't describing the ocean any more. It's describing something else's idea of the ocean.", 8.0)


## The Maw's last open water fills in once the ship has left it.
func _silt_behind() -> void:
	var here := grid.cell_of(ship.position)
	for i in range(_maw_left.size() - 1, -1, -1):
		var c := _maw_left[i]
		if Vector2(c - here).length() > 5.0:
			if grid.tile(c) in [".", ","]:
				grid.set_tile(c, "z")
			_maw_left.remove_at(i)


func _make_island(a: Vector2, b: Vector2, speed: float, rx: float, ry: float, label: String) -> Node2D:
	var isl := Node2D.new()
	isl.set_script(preload("res://scripts/drifting_island.gd"))
	isl.a = a
	isl.b = b
	isl.speed = speed
	isl.rx = rx
	isl.ry = ry
	isl.label = label
	isl.grid = grid
	isl.ship = ship
	isl.reveal = _reveal
	add_child(isl)
	move_child(isl, $Route.get_index())
	return isl


## Lost ships: optional. Each answers differently.
func _on_lost_ship(ls: Node2D) -> void:
	_answered += 1
	Game.begin_level_timer()
	Music.sfx("bell", 0.5, 1.5)
	_update_notes()
	match ls.reward:
		"route":
			for y in range(HIDDEN_BAR.position.y, HIDDEN_BAR.end.y):
				for x in range(HIDDEN_BAR.position.x, HIDDEN_BAR.end.x):
					if grid.tile_xy(x, y) == "z":
						grid.set_tile(Vector2i(x, y), ".")
			_show_patch("route")
			for x in range(86, 100, 3):
				_reveal.reveal(Vector2(x + 0.5, 27.5) * MapGrid.CELL, 2.5)
			hud.show_note("the log of the " + ls.title.trim_prefix("the "),
				"Sounded the channel through the second islands at dusk: four fathoms, clean sand. The bar drawn across it on the Admiralty chart is not there — or was not, when we passed.\n(A way through the second islands is charted.)", 8.0)
		"story":
			hud.show_note("the log of the " + ls.title.trim_prefix("the "),
				"Day 9. The stars are wrong. Mr Harrow swears the island moved in the night, and I have stopped arguing with him. We lit the lamps and something came up under the hull to look at them.", 8.0)
		_:
			hud.show_note("scratched into the " + ls.title.trim_prefix("the ") + "'s rail",
				"IF YOU CAN READ THIS YOU ARE DREAMING TOO.\nWhen you make camp on the island, do not sleep. The ground opens where you sleep, and there is no map for what is under it.\n— E. Vane, cartographer", 8.0)
