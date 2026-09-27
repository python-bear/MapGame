extends Node3D
## Finale — "Waking". There is no map for this place.
##
## FIND THE DOOR OF LIGHT. It is behind the Black gate; the Black Key is behind
## the Stone gate; the Stone Key is behind the Iron gate; and the Iron Key is in
## a small room in the south-west, where the door closes behind you.
##
##   Iron Key   the silent room: the door shuts, the music stops. Take the key
##              and every light goes out; the door opens again — and outside,
##              the labyrinth is not the one you walked in through. His journal
##              map runs to ink after this.
##   Stone Key  follow the lights: three groups of wisps lead three ways. Two
##              flicker and hurry off into dead ends; one moves steadily, and
##              waits for you.
##   Black Key  the beast's hall. You hear it breathing. Take the key and it
##              wakes — and the final chase begins: the fog thickens, every wisp
##              goes out, the music stops, and it hunts you by sound.
##
## The labyrinth remembers you: a corridor of three doors has four the next time,
## and then one stands ajar; a door you walked through becomes a wall.
##
## Three false doors in the outer walls: two glowing violet, with the same
## spiral carved over them, are joined — walk into one and you step out of the
## other, keys and all. The third looks like the Door of Light and is only
## bricks behind a painted light.

@onready var maze: MazeBuilder = $Maze
@onready var player: CharacterBody3D = $Player
@onready var beast: Node3D = $Beast
@onready var overlay: CanvasLayer = $Overlay
@onready var hud: CanvasLayer = $HUD
@onready var env: Environment = $WorldEnvironment.environment

enum Phase { EXPLORE, SILENT, CHASE, OVER }
var phase := Phase.EXPLORE
var _over := false

const SANCTUM := [Vector2i(5, 0), Vector2i(6, 0), Vector2i(7, 0), Vector2i(5, 1), Vector2i(6, 1), Vector2i(7, 1)]
const SILENT := [Vector2i(0, 10), Vector2i(1, 10), Vector2i(0, 11), Vector2i(1, 11)]
const SILENT_DOOR := "4,21"
## Leaving the silent room: these walls rise (true) or sink (false).
const IRON_SHIFTS := {"5,22": true, "5,20": true, "6,21": false}
const BARRED_DOOR := "21,14"
const BARRED_SIDE := Vector2i(10, 6)
## The Stone Key's wisps: all start at the junction inside the Iron gate.
const GUIDE_START := Vector2i(3, 5)
const GUIDE_TRUE := [Vector2i(2, 5), Vector2i(2, 4), Vector2i(1, 4), Vector2i(1, 3), Vector2i(1, 2), Vector2i(2, 2), Vector2i(2, 1), Vector2i(1, 1), Vector2i(0, 1), Vector2i(0, 0)]
const GUIDE_FALSE := [
	[Vector2i(3, 4), Vector2i(3, 3), Vector2i(3, 2), Vector2i(3, 1), Vector2i(3, 0), Vector2i(2, 0), Vector2i(1, 0)],
	[Vector2i(3, 6), Vector2i(2, 6), Vector2i(1, 6), Vector2i(0, 6), Vector2i(0, 5), Vector2i(0, 4), Vector2i(0, 3), Vector2i(0, 2)],
]
## Where the beast rises when the Black Key is taken.
const BEAST_RISES := Vector2i(12, 0)
## Corridors that remember.
const DOOR_ROW := [Vector2i(3, 8), Vector2i(4, 8), Vector2i(5, 8), Vector2i(6, 8)]
const DOOR_ROW_NEW := "13,16"      # the fourth door
const DOOR_ROW_AJAR := "9,16"
const FORGETFUL := [Vector2i(11, 10), Vector2i(11, 11), Vector2i(10, 11), Vector2i(12, 11)]
const FORGETFUL_DOOR := "23,22"

var held := {}                      ## key name -> true
var hotbar: CanvasLayer             ## the three key slots; gates open for the key in hand
var journal: CanvasLayer
var _wisps: Array = []
var _guides: Array = []
var _guiding := false
var _light_timer := 0.0
const MAX_WISP_LIGHTS := 10
const WISP_LIGHT_RANGE := 26.0
var _candle: OmniLight3D
var _key_light: OmniLight3D
var _heart_cool := 0.0
var _mem := {"row": {"inside": false, "visits": 0, "pending": 0}, "forget": {"inside": false, "visits": 0, "pending": 0}}
var _pages_total := 0
var _pages_read := 0
var _shake := 0.0

## The pen, one last time: a wall of ink across the passage ahead (Q / right
## mouse). It's real for a few seconds.
const INK := 2
const INK_WALL_LIFE := 12.0
var ink := INK


func _ready() -> void:
	add_to_group("level3")
	player.global_position = maze.cell_center(maze.start_cell, 0.05)
	player.rotation.y = 0.0
	beast.global_position = maze.cell_center(maze.beast_cell)
	beast.maze = maze
	beast.player = player
	beast.caught_player.connect(_on_caught)
	maze.exit_reached.connect(_on_escape)
	player.prompt_changed.connect(overlay.set_prompt)
	overlay.player = player
	hud.captures_mouse = true
	hud.show_completion_card = false
	hud.show_failure_card = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	for n in maze.get_children():
		if n.has_method("set_lit"):
			_wisps.append(n)
		if n.has_signal("was_read"):
			_pages_total += 1
			n.was_read.connect(func(_p): _pages_read += 1; _update_notes())
	journal = CanvasLayer.new()
	journal.set_script(preload("res://scripts/labyrinth_journal.gd"))
	journal.name = "Journal"
	journal.maze = maze
	journal.player = player
	journal.beast = beast
	add_child(journal)
	hotbar = CanvasLayer.new()
	hotbar.set_script(preload("res://scripts/key_hotbar.gd"))
	hotbar.name = "KeyHotbar"
	hotbar.camera = player.camera
	add_child(hotbar)
	# locks, keys, doors
	for k: String in maze.keys:
		maze.keys[k].taken.connect(_on_key)
	for key: String in maze.doors:
		_watch_door(maze.doors[key])
	var barred = maze.doors.get(BARRED_DOOR)
	if barred:
		barred.bar_side = maze.cell_center(BARRED_SIDE)
	for ld in maze.light_doors:
		match ld.role:
			"portal":
				ld.traversed.connect(_on_portal.bind(ld))
			"dud":
				ld.fooled.connect(_on_dud.bind(ld))
	_make_candle()
	_make_guides()
	hud.set_ink(ink, INK, "Q / right-click — ink a wall")
	hud.set_objectives("keys", ["the Iron Key", "the Stone Key", "the Black Key"], false, true)
	_update_notes()
	Music.play_set("level3", 3.0)
	Music.set_danger(0.0)
	_update_lights()
	await get_tree().create_timer(1.2).timeout
	overlay.say("There is no map of this place. Not yet.", 3.5)


## Can he open a gate that wants key `n`? Only with that key in his hand.
func has_key(n: String) -> bool:
	return held.has(n) and hotbar.has_selected(n)


## Has he got key `n` at all (in hand or not)?
func holds_key(n: String) -> bool:
	return held.has(n)


## Which number picks key `n` on the hotbar.
func key_slot(n: String) -> int:
	return hotbar.slot_of(n)


func _update_notes() -> void:
	var lines := []
	if phase == Phase.CHASE:
		lines.append("the Door of Light is behind the black gate")
	else:
		lines.append("then: find the Door of Light")
	if _pages_total > 0:
		lines.append("torn pages  %d / %d" % [_pages_read, _pages_total])
	hud.set_objective_notes(lines)


func _watch_door(d: Node) -> void:
	# a door opening or closing carries — if he's the one doing it
	d.opened.connect(func(): _door_noise(d))
	d.closed.connect(func(): _door_noise(d))
	d.rattled.connect(func(): _door_noise(d, 9.0))


func _door_noise(d: Node3D, radius := 13.0) -> void:
	if player.global_position.distance_to(d.global_position) < 3.2:
		beast.hear(d.global_position, radius)


# ================================================================ loop
func _process(delta: float) -> void:
	_light_timer -= delta
	if _light_timer <= 0.0:
		_light_timer = 0.25
		_update_lights()
	if _over:
		return
	player.speed_mult = 0.0 if journal.open else 1.0      # he stops to read his map
	var here := maze.cell_of(player.global_position)
	match phase:
		Phase.EXPLORE:
			if here in SILENT and not held.has("Iron"):
				_enter_silent_room()
			if not _guiding and held.has("Iron") and here == GUIDE_START:
				_guiding = true
				for g in _guides:
					g.start_guiding(player)
				overlay.say("Three lights. They are all going somewhere.", 3.0)
			Music.set_danger(0.05)
		Phase.CHASE:
			if maze.exit_door and not maze.exit_door.is_open and player.global_position.distance_to(maze.exit_door.global_position) < 6.0:
				_open_the_light()
			# no music now: only its breathing, and his heart when it's near
			var d := player.global_position.distance_to(beast.global_position)
			_heart_cool -= delta
			if d < 11.0 and _heart_cool <= 0.0 and beast.is_active():
				_heart_cool = lerpf(0.55, 1.1, clampf((d - 3.0) / 8.0, 0.0, 1.0))
				Music.sfx("heartbeat", clampf(1.2 - d / 11.0, 0.25, 1.0))
	_remember(here)
	if _shake > 0.0:
		_shake = move_toward(_shake, 0.0, delta * 1.5)
		player.camera.h_offset = randf_range(-1, 1) * _shake * 0.08
		player.camera.v_offset = randf_range(-1, 1) * _shake * 0.08


func _update_lights() -> void:
	var here := player.global_position
	var live: Array = _wisps.filter(func(w): return is_instance_valid(w) and w.visible)
	live.sort_custom(func(a, b): return a.global_position.distance_squared_to(here) < b.global_position.distance_squared_to(here))
	for i in live.size():
		live[i].set_lit(i < MAX_WISP_LIGHTS and live[i].global_position.distance_to(here) < WISP_LIGHT_RANGE)


# ================================================================ keys
func _on_key(k: Node3D) -> void:
	held[k.key_name] = true
	hotbar.add_key(k.key_name)
	hud.tick_objective("the %s Key" % k.key_name)
	Game.begin_level_timer()
	match k.key_name:
		"Iron":
			_silent_room_key()
		"Stone":
			overlay.say("The Stone Key. Cold, like something from a grave.", 3.5)
		"Black":
			_final_chase(k)


# ---------------------------------------------------------------- the silent room
func _make_candle() -> void:
	var c := Vector3.ZERO
	for cell: Vector2i in SILENT:
		c += maze.cell_center(cell)
	_candle = OmniLight3D.new()
	_candle.light_color = Color(1.0, 0.72, 0.42)
	_candle.light_energy = 0.9
	_candle.omni_range = 6.5
	_candle.position = c / SILENT.size() + Vector3(0, 2.4, 0)
	add_child(_candle)


func _enter_silent_room() -> void:
	phase = Phase.SILENT
	var door = maze.doors.get(SILENT_DOOR)
	if door:
		door.lock_shut()
	Music.stop(1.2)
	await get_tree().create_timer(1.0).timeout
	overlay.say("The door has shut behind me. It is very quiet in here.", 3.5)


func _silent_room_key() -> void:
	await get_tree().create_timer(0.5).timeout
	# every light goes out
	Music.sfx("lights_out", 1.0)
	var old_ambient := env.ambient_light_energy
	_candle.visible = false
	for w in _wisps:
		w.set_lit(false)
	_light_timer = 99.0
	create_tween().tween_property(env, "ambient_light_energy", 0.0, 0.15)
	# …and in the dark, outside, the labyrinth moves
	for key: String in IRON_SHIFTS:
		maze.shift(key, IRON_SHIFTS[key], 0.1)
	journal.ruined = true
	await get_tree().create_timer(3.0).timeout
	var door = maze.doors.get(SILENT_DOOR)
	if door:
		door.unlock()
		door._open_away_from(maze.cell_center(SILENT[0]), 2.6, "creak")
	create_tween().tween_property(env, "ambient_light_energy", old_ambient, 2.5)
	_light_timer = 0.0
	await get_tree().create_timer(1.5).timeout
	Music.play_set("level3", 4.0)
	phase = Phase.EXPLORE
	overlay.say("Nothing has changed. The Iron Key is heavy in my hand.", 3.5)
	await get_tree().create_timer(5.0).timeout
	overlay.say("My map — the ink is running. I can't read any of it.", 3.5)


# ---------------------------------------------------------------- the wisps that lead
func _make_guides() -> void:
	var paths := [GUIDE_TRUE]
	paths.append_array(GUIDE_FALSE)
	var start := maze.cell_center(GUIDE_START, 2.2)
	for i in paths.size():
		var g := Node3D.new()
		g.set_script(preload("res://scripts/wisp_group.gd"))
		g.name = "Guide_%d" % i
		g.position = start + Vector3(cos(i * 2.1), 0, sin(i * 2.1)) * 0.7
		g.honest = i == 0
		var pts: Array = []
		for c: Vector2i in paths[i]:
			pts.append(maze.cell_center(c, 2.2))
		g.guide_path = pts
		maze.add_child(g)
		_wisps.append(g)
		_guides.append(g)


# ---------------------------------------------------------------- the black key: the final chase
func _final_chase(k: Node3D) -> void:
	phase = Phase.CHASE
	var k_pos := k.global_position
	beast.wake(maze.cell_center(BEAST_RISES), k_pos)
	_shake = 1.0
	overlay.say("ESCAPE", 2.5, true)
	hud.set_objectives("the way out", ["ESCAPE"], false, true)
	_update_notes()
	maze.exit_door.armed = true
	# the key's red glow, in his hand: the only light he has now
	_key_light = OmniLight3D.new()
	_key_light.light_color = Color(1.0, 0.2, 0.12)
	_key_light.light_energy = 0.55
	_key_light.omni_range = 5.0
	_key_light.position = Vector3(0.25, 1.1, -0.3)
	player.add_child(_key_light)
	# everything changes: thicker fog, every wisp out, no music
	create_tween().tween_property(env, "fog_density", 0.14, 4.0)
	Music.stop(3.0)
	for w in _wisps:
		if is_instance_valid(w) and w.has_method("extinguish"):
			w.extinguish(randf_range(1.5, 4.0))
	await get_tree().create_timer(7.0).timeout
	if _over:
		return
	# breathing, right behind him
	var a := AudioStreamPlayer3D.new()
	a.stream = preload("res://assets/sfx/breath.ogg")
	a.unit_size = 3.0
	a.volume_db = linear_to_db(maxf(Music.sfx_volume, 0.0001))
	add_child(a)
	a.global_position = player.global_position + player.global_transform.basis.z * 1.6 + Vector3(0, 1.5, 0)
	a.play()
	a.finished.connect(a.queue_free)


func _open_the_light() -> void:
	maze.exit_door.open()
	var f := {}
	for c: Vector2i in SANCTUM:
		f[c] = true
	beast.forbidden = f
	await get_tree().create_timer(1.0).timeout
	if beast.is_active():
		Music.sfx("screech", 0.5, 0.6)


# ================================================================ the labyrinth remembers
func _remember(here: Vector2i) -> void:
	_zone("row", DOOR_ROW, here)
	_zone("forget", FORGETFUL, here)


func _zone(name: String, cells: Array, here: Vector2i) -> void:
	var z: Dictionary = _mem[name]
	var inside := here in cells
	if inside and not z.inside:
		z.visits += 1
	if not inside and z.inside:
		z.pending = z.visits          # something will be different next time
	z.inside = inside
	if inside or z.pending == 0:
		return
	# change it only where he can't see
	for c: Vector2i in cells:
		if journal.visible_cells.has(c):
			return
	var far := true
	for c: Vector2i in cells:
		if absi(c.x - here.x) + absi(c.y - here.y) < 2:
			far = false
	if not far:
		return
	match name:
		"row":
			if z.pending == 1 and maze.shifters.has(DOOR_ROW_NEW):
				var d := maze.wall_to_door(DOOR_ROW_NEW)
				_watch_door(d)
			elif z.pending == 2:
				var d2 = maze.doors.get(DOOR_ROW_AJAR)
				if d2:
					d2.set_ajar(0.3)
		"forget":
			if z.pending == 1 and maze.doors.has(FORGETFUL_DOOR):
				maze.door_to_wall(FORGETFUL_DOOR)
	z.pending = 0


# ================================================================ false doors
## Two of the false doors are a joined pair: walk into one and you step out of
## the other, on the far side of the labyrinth — keys, pages and ink all still
## with you. The third is a dud: bricks behind a painted light.
var _portal_cool := 0.0
var _portal_uses := 0


func _on_portal(from: Node3D) -> void:
	var to: Node3D = from.partner
	if _over or to == null or Time.get_ticks_msec() / 1000.0 < _portal_cool:
		return
	_portal_cool = Time.get_ticks_msec() / 1000.0 + 1.2
	_portal_uses += 1
	Game.begin_level_timer()
	# a violet rush and a lurch of the lens…
	overlay.flash(Color(0.45, 0.22, 0.85), 0.12, 0.8)
	Music.sfx("whisper", 0.8, 1.3)
	Music.sfx("hum", 1.0, 0.55)
	var cam: Camera3D = player.camera
	var fov := 72.0
	var tw := create_tween()
	tw.tween_property(cam, "fov", 118.0, 0.1).set_ease(Tween.EASE_IN)
	tw.tween_property(cam, "fov", fov, 0.7).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# …and out of the other door, walking on into the maze
	to.open_portal(0.25)
	var dir: Vector3 = to.inward()
	var spd := Vector2(player.velocity.x, player.velocity.z).length()
	player.global_position = to.arrival_point(1.7) + Vector3(0, 0.05, 0)
	player.rotation.y = atan2(-dir.x, -dir.z)
	player.velocity = Vector3(dir.x, 0, dir.z) * spd
	_shake = 0.6
	await get_tree().create_timer(0.9).timeout
	if _portal_uses == 1:
		overlay.say("Through one door — and out of another, across the labyrinth. I still have everything I carried.", 5.0)
	else:
		overlay.say("The two doors are joined.", 2.5)


func _on_dud(_ld: Node3D) -> void:
	await get_tree().create_timer(0.8).timeout
	overlay.say("Bricks. The light was painted on the stone.", 3.5)


# ================================================================ ink
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("draw") and not _over and not get_tree().paused:
		get_viewport().set_input_as_handled()
		_draw_wall()


## Seal the passage he's facing with a wall of ink.
func _draw_wall() -> void:
	if ink <= 0:
		overlay.set_prompt("the pen is dry")
		return
	var fwd := -player.global_transform.basis.z
	var d := Vector2i(signi(roundi(fwd.x)), 0) if absf(fwd.x) >= absf(fwd.z) else Vector2i(0, signi(roundi(fwd.z)))
	var here := maze.cell_of(player.global_position)
	var there := here + d
	if maze.edge_kind(here, there) != "open":
		return
	var edge := (maze.cell_center(here) + maze.cell_center(there)) * 0.5
	if Vector2(edge.x - player.global_position.x, edge.z - player.global_position.z).length() < 0.8:
		return
	if Vector2(edge.x - beast.global_position.x, edge.z - beast.global_position.z).length() < 1.6:
		return
	ink -= 1
	Game.begin_level_timer()
	maze.ink_wall(here, there, INK_WALL_LIFE)
	Music.sfx("ink", 0.9, 1.4)
	hud.set_ink(ink, INK, "Q / right-click — ink a wall" if ink > 0 else "the pen is dry")


# ================================================================ endings
func _record_pages() -> void:
	Game.last_found = _pages_read
	Game.last_total = _pages_total
	Game.record_landmarks(Game.LEVELS[Game.current_level]["id"], _pages_read, _pages_total)


func _on_caught() -> void:
	if _over:
		return
	_over = true
	phase = Phase.OVER
	_record_pages()
	player.frozen = true
	Game.timing = false
	hotbar.hide_all()
	overlay.set_prompt("")
	overlay.say("", 0.01)
	# the jumpscare: a black blink — then it is right in his face
	var to := beast.global_position - player.global_position
	player.rotation.y = atan2(-to.x, -to.z)
	player.head.rotation.x = 0.0
	player._pitch = 0.0
	overlay.flash(Color.BLACK, 0.06, 0.05)
	beast.jumpscare(player.camera)
	Music.sfx("roar", 1.0, 0.8)
	Music.sfx("screech", 1.0, 1.15)
	_shake = 2.6
	var cam: Camera3D = player.camera
	var fov := cam.fov
	var tw := create_tween()
	tw.tween_property(cam, "fov", fov - 16.0, 0.12).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	await get_tree().create_timer(1.1).timeout
	Music.sfx("splat", 1.0)
	_shake = 2.2
	overlay.splatter()
	await get_tree().create_timer(1.4).timeout
	await overlay.fade_to(Color.BLACK, 1.6)
	Game.fail_level("caught")
	Music.stop(1.0)
	Game.show_ending("caught")


func _on_escape() -> void:
	if _over:
		return
	_over = true
	phase = Phase.OVER
	_record_pages()
	player.frozen = true
	hotbar.hide_all()
	Game.complete_level()
	Music.sfx("exit", 1.0)
	await overlay.fade_to(Color(1.0, 0.98, 0.94), 1.8)
	Game.show_ending("escape")
