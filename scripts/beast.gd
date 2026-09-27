extends Node3D
## The beast of the labyrinth. A four-legged shape wrapped in smoke, with a
## wolfish skull and two red eyes.
##
## It sleeps in its hall in the east wing until the Black Key is taken. Then it
## hunts — but it hunts by ear:
##   running  loud  (heard ~20 m away, by the way sound travels round corners)
##   doors    loud-ish (~13 m)
##   walking  quiet (~4 m)      standing still: silent
## It also sees you if you're close and in a straight line of it.
## When it loses you it searches near where you are (it always drifts closer),
## stopping now and then to listen — and while it listens it hears twice as far.
## It is a little faster than you walk, slower than you run. Doors hold it a
## moment. It will not go into the light.

signal caught_player

@export var speed_ratio := 1.08         ## of the player's walking speed, when it knows where you are
@export var search_ratio := 0.6
@export var catch_distance := 1.9       ## from its centre; its jaws reach ~1.6 m ahead
@export var bash_delay := 1.3           ## how long it claws at a closed door
@export var sight_cells := 3

var maze: MazeBuilder
var player: Node3D
## Cells it will not enter (the light of the open door).
var forbidden := {}

enum State { DORMANT, EMERGING, HUNT, SEARCH, LISTEN, HALTED, FEEDING }
var state := State.DORMANT

var _path: Array[Vector2i] = []
var _repath := 0.0
var _gait := 0.0
var _t := 0.0
var _heading := 0.0
var _at_door := 0.0
var _screech_cool := 3.0
var _jaw_open := 0.0
var _moving := false
var _target_cell := Vector2i(-1, -1)
var _last_known := Vector2i(-1, -1)
var _lost_for := 0.0
var _listen_left := 0.0
var _next_listen := 5.0
var _hear_mult := 1.0
var _sense := 0.0

var _body: Node3D
var _head: Node3D
var _jaw: Node3D
var _legs: Array = []                   # [{hip, knee, phase}]
var _breath: AudioStreamPlayer3D
var _voice: AudioStreamPlayer3D
var _eyes: Node3D
var _smoke: CPUParticles3D


func _ready() -> void:
	_build()
	_breath = _make_audio("breath", true, 4.0, 22.0)
	_voice = _make_audio("screech", false, 6.0, 40.0)
	_breath.play()
	_heading = rotation.y
	_body.visible = false            # asleep, somewhere in the dark: only its breathing
	_smoke.emitting = false


func eye_position() -> Vector3:
	return _eyes.global_position


func is_active() -> bool:
	return state != State.DORMANT and state != State.EMERGING


## Rise out of the dark `at`, facing `look_at`, and begin.
func wake(at: Vector3, look: Vector3) -> void:
	if state != State.DORMANT:
		return
	state = State.EMERGING
	global_position = at
	_face(look, 100.0)
	_body.visible = true
	_smoke.emitting = true
	_body.scale = Vector3(1, 0.05, 1)
	var tw := create_tween()
	tw.tween_property(_body, "scale", Vector3.ONE, 1.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_screech(0.85)
	await get_tree().create_timer(2.0).timeout
	_last_known = maze.cell_of(player.global_position)
	state = State.HUNT


## Something made a noise at `pos` that carries `radius` metres.
func hear(pos: Vector3, radius: float) -> void:
	if not is_active() or state == State.HALTED or state == State.FEEDING or radius <= 0.0:
		return
	var here := maze.cell_of(global_position)
	var there := maze.cell_of(pos)
	var d := (maze.path(here, there).size()) * maze.cell_size
	if d <= radius * _hear_mult:
		_heard(there)


func _heard(c: Vector2i) -> void:
	_last_known = c
	_lost_for = 0.0
	if state != State.HUNT:
		state = State.HUNT
		_listen_left = 0.0
		if _screech_cool <= 0.0:
			_screech(randf_range(0.9, 1.1))


# ================================================================ behaviour
func _physics_process(delta: float) -> void:
	_t += delta
	_screech_cool -= delta
	_jaw_open = move_toward(_jaw_open, 0.0, delta * 1.5)
	_moving = false
	if maze == null or player == null:
		_animate(delta)
		return
	var d := _flat(player.global_position).distance_to(_flat(global_position))
	if is_active() and state != State.HALTED and state != State.FEEDING and not forbidden.is_empty() \
			and forbidden.has(maze.cell_of(player.global_position)):
		state = State.HALTED           # he is in the light; it will not follow
		_screech(0.6)
	match state:
		State.HUNT, State.SEARCH, State.LISTEN:
			_sense -= delta
			if _sense <= 0.0:
				_sense = 0.25
				_perceive()
			_act(delta)
			if d < catch_distance and state != State.HALTED:
				state = State.FEEDING
				_jaw_open = 1.0
				caught_player.emit()
		State.HALTED:
			# at the edge of the light: it stops, it stares, it backs away
			var lc: Vector3 = maze.exit_door.global_position if maze.exit_door else player.global_position
			_face(lc, delta)
			var away := _flat(global_position) - _flat(lc)
			if away.length() < 8.0:
				global_position += Vector3(away.normalized().x, 0, away.normalized().y) * 0.6 * delta
	_animate(delta)
	var loud := 1.0
	if state == State.LISTEN:
		loud = 0.25                    # it holds its breath to listen
	elif state == State.DORMANT:
		loud = 0.7
	_breath.volume_db = linear_to_db(maxf(Music.sfx_volume * loud * (1.2 if d < 8.0 else 0.8), 0.0001))


## Does it hear or see him right now?
func _perceive() -> void:
	var here := maze.cell_of(global_position)
	var there := maze.cell_of(player.global_position)
	var r: float = player.noise_radius() if player.has_method("noise_radius") else 4.0
	var heard := false
	if r > 0.0:
		var d := maze.path(here, there, forbidden).size() * maze.cell_size
		heard = d <= r * _hear_mult
	if heard or _sees(here, there):
		_heard(there)
	else:
		_lost_for += 0.25


func _sees(here: Vector2i, there: Vector2i) -> bool:
	if here == there:
		return true
	if here.x != there.x and here.y != there.y:
		return false
	var step := Vector2i(signi(there.x - here.x), signi(there.y - here.y))
	var c := here
	for i in sight_cells:
		var nb := c + step
		var k := maze.edge_kind(c, nb)
		if k == "wall":
			return false
		if k == "door":
			var dr = maze.door_between(c, nb)
			if dr and not dr.is_passable():
				return false
		c = nb
		if c == there:
			return true
	return false


func _act(delta: float) -> void:
	var here := maze.cell_of(global_position)
	match state:
		State.HUNT:
			if _lost_for > 2.5:
				# gone quiet: go to where it last knew him, then start searching
				if here == _last_known or _last_known.x < 0:
					state = State.SEARCH
					_pick_search_cell()
					_next_listen = randf_range(3.0, 5.0)
				else:
					_go(_last_known, delta, speed_ratio)
			else:
				var pc := maze.cell_of(player.global_position)
				if pc == here or maze.path(here, pc, forbidden).size() <= 1:
					_step_toward(player.global_position, delta, speed_ratio)
				else:
					_go(pc, delta, speed_ratio)
		State.SEARCH:
			_next_listen -= delta
			if _next_listen <= 0.0:
				state = State.LISTEN
				_listen_left = 2.2
				_hear_mult = 1.9
				return
			if here == _target_cell or _target_cell.x < 0:
				_pick_search_cell()
			_go(_target_cell, delta, search_ratio)
		State.LISTEN:
			_listen_left -= delta
			_head.rotation.x = lerpf(_head.rotation.x, -0.45, 1.0 - exp(-4.0 * delta))
			if _listen_left <= 0.0:
				_hear_mult = 1.0
				state = State.SEARCH
				_next_listen = randf_range(4.0, 7.0)
				_pick_search_cell()


## Somewhere near him — it always finds its way closer.
func _pick_search_cell() -> void:
	var pc := maze.cell_of(player.global_position)
	var best := pc
	for attempt in 12:
		var c := pc + Vector2i(randi_range(-3, 3), randi_range(-3, 3))
		if c.x < 0 or c.y < 0 or c.x >= maze.n or c.y >= maze.n or forbidden.has(c):
			continue
		if absi(c.x - pc.x) + absi(c.y - pc.y) < 2:
			continue
		if maze.path(maze.cell_of(global_position), c, forbidden).size() > 0:
			best = c
			break
	_target_cell = best


## Walk the maze towards a cell, clawing through closed doors.
func _go(cell: Vector2i, delta: float, ratio: float) -> void:
	var here := maze.cell_of(global_position)
	_repath -= delta
	if _repath <= 0.0 or _path.is_empty() or (not _path.is_empty() and _path[-1] != cell):
		_repath = 0.3
		_path = maze.path(here, cell, forbidden)
	while not _path.is_empty() and _path[0] == here and _flat(global_position).distance_to(_flat(maze.cell_center(here))) < 0.6:
		_path.pop_front()
	if _path.is_empty():
		if forbidden.has(maze.cell_of(player.global_position)):
			state = State.HALTED
		return
	var next: Vector2i = _path[0]
	if forbidden.has(next):
		state = State.HALTED
		return
	if maze.edge_kind(here, next) == "door":
		var door = maze.door_between(here, next)
		if door and not door.is_passable():
			# a shut door: go to it, claw at it, then smash it
			var edge := (maze.cell_center(here) + maze.cell_center(next)) * 0.5
			var stand := edge + (maze.cell_center(here) - edge).normalized() * 0.9
			if _flat(global_position).distance_to(_flat(stand)) > 0.15:
				_step_toward(stand, delta, ratio)
			else:
				_face(edge, delta)
				_at_door += delta
				_jaw_open = 0.6
				if _at_door >= bash_delay:
					_at_door = 0.0
					door.bash(global_position)
					_screech(0.8)
			return
	_at_door = 0.0
	_step_toward(maze.cell_center(next), delta, ratio)


func _step_toward(p: Vector3, delta: float, ratio := 1.0) -> void:
	var to := _flat(p) - _flat(global_position)
	if to.length() < 0.02:
		return
	var sp: float = player.speed * ratio if "speed" in player else 4.5
	var step := minf(sp * delta, to.length())
	var dir := to.normalized()
	global_position += Vector3(dir.x, 0, dir.y) * step
	_face(p, delta)
	_moving = true


func _face(p: Vector3, delta: float) -> void:
	var to := _flat(p) - _flat(global_position)
	if to.length() < 0.01:
		return
	var want := atan2(-to.x, -to.y)
	_heading = rotate_toward(_heading, want, delta * 7.0)
	rotation.y = _heading


func _flat(v: Vector3) -> Vector2:
	return Vector2(v.x, v.z)


func _screech(pitch: float) -> void:
	_screech_cool = randf_range(3.5, 6.5)
	_jaw_open = 1.0
	_voice.pitch_scale = pitch
	_voice.volume_db = linear_to_db(maxf(Music.sfx_volume, 0.0001))
	_voice.play()


func _make_audio(sound: String, loop: bool, unit: float, max_d: float) -> AudioStreamPlayer3D:
	var a := AudioStreamPlayer3D.new()
	var path := "res://assets/sfx/%s.ogg" % sound
	if ResourceLoader.exists(path):
		var st: AudioStreamOggVorbis = load(path).duplicate()
		st.loop = loop
		a.stream = st
	a.unit_size = unit
	a.max_distance = max_d
	a.position = Vector3(0, 1.3, -0.9)
	add_child(a)
	return a


# ================================================================ body
func _build() -> void:
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.025, 0.02, 0.022)
	dark.roughness = 1.0
	dark.rim_enabled = true
	dark.rim = 0.35
	dark.rim_tint = 0.2
	var bone := StandardMaterial3D.new()
	bone.albedo_color = Color(0.2, 0.18, 0.16)
	bone.roughness = 0.9
	_body = Node3D.new()
	add_child(_body)
	# torso, lying along -Z (its forward)
	_part(_body, _capsule(0.42, 1.7), Vector3(0, 1.05, 0.05), Vector3(PI / 2.0, 0, 0), dark)
	_part(_body, _sphere(0.55), Vector3(0, 1.3, -0.5), Vector3.ZERO, dark, Vector3(1.0, 0.9, 1.1))   # hunched shoulders
	_part(_body, _sphere(0.4), Vector3(0, 1.15, 0.7), Vector3.ZERO, dark)                            # haunches
	_part(_body, _capsule(0.2, 0.8), Vector3(0, 1.4, -0.95), Vector3(PI / 2.6, 0, 0), dark)           # neck
	# head: long wolfish skull, snout, working jaw, swept-back horns
	_head = Node3D.new()
	_head.position = Vector3(0, 1.45, -1.25)
	_body.add_child(_head)
	_part(_head, _sphere(0.3), Vector3(0, 0.05, 0), Vector3.ZERO, dark, Vector3(1.0, 0.85, 1.25))
	_part(_head, _capsule(0.13, 0.6), Vector3(0, -0.02, -0.38), Vector3(PI / 2.0, 0, 0), dark, Vector3(1.1, 1.0, 0.8))
	_jaw = Node3D.new()
	_jaw.position = Vector3(0, -0.12, -0.08)
	_head.add_child(_jaw)
	_part(_jaw, _capsule(0.1, 0.55), Vector3(0, -0.02, -0.28), Vector3(PI / 2.0, 0, 0), dark, Vector3(1.0, 0.7, 1.0))
	for i in 5:   # teeth
		for s in [-1.0, 1.0]:
			_part(_jaw, _cone(0.018, 0.08), Vector3(s * 0.06, 0.05, -0.12 - i * 0.07), Vector3(0, 0, 0), bone)
			_part(_head, _cone(0.02, 0.1), Vector3(s * 0.07, -0.1, -0.2 - i * 0.07), Vector3(PI, 0, 0), bone)
	for s in [-1.0, 1.0]:
		_part(_head, _cone(0.07, 0.55), Vector3(s * 0.2, 0.25, 0.12), Vector3(-1.0, 0, s * 0.5), bone)   # horns
		_part(_head, _cone(0.08, 0.25), Vector3(s * 0.18, 0.28, -0.02), Vector3(-0.6, 0, s * 0.8), dark)  # ears
	# the eyes
	_eyes = Node3D.new()
	_eyes.position = Vector3(0, 0.12, -0.24)
	_head.add_child(_eyes)
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = Color(1.0, 0.08, 0.04)
	glow.disable_fog = true
	for s in [-1.0, 1.0]:
		_part(_eyes, _sphere(0.055), Vector3(s * 0.12, 0, -0.02), Vector3.ZERO, glow, Vector3(1.5, 0.7, 1.0))
		var halo := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(0.5, 0.5)
		halo.mesh = q
		var hm: StandardMaterial3D = preload("res://assets/materials/wisp.tres").duplicate()
		hm.albedo_color = Color(1.0, 0.1, 0.05, 0.8)
		halo.material_override = hm
		halo.position = Vector3(s * 0.12, 0, -0.02)
		_eyes.add_child(halo)
	var eye_light := OmniLight3D.new()
	eye_light.light_color = Color(1.0, 0.1, 0.05)
	eye_light.light_energy = 1.0
	eye_light.omni_range = 3.0
	eye_light.position = Vector3(0, -0.1, -0.6)
	eye_light.light_cull_mask = 1                  # lights the corridor, not itself
	_eyes.add_child(eye_light)
	# legs: hip -> thigh -> knee -> shin -> paw
	for spec in [[-0.32, -0.6, 0.0], [0.32, -0.6, PI], [-0.3, 0.65, PI], [0.3, 0.65, 0.0]]:
		var hip := Node3D.new()
		hip.position = Vector3(spec[0], 1.1, spec[1])
		_body.add_child(hip)
		_part(hip, _capsule(0.13, 0.7), Vector3(0, -0.3, 0), Vector3.ZERO, dark)
		var knee := Node3D.new()
		knee.position = Vector3(0, -0.6, 0)
		hip.add_child(knee)
		_part(knee, _capsule(0.09, 0.65), Vector3(0, -0.25, 0), Vector3.ZERO, dark)
		_part(knee, _sphere(0.12), Vector3(0, -0.48, -0.06), Vector3.ZERO, dark, Vector3(1.0, 0.6, 1.4))
		for c in 3:   # claws
			_part(knee, _cone(0.02, 0.12), Vector3((c - 1) * 0.06, -0.52, -0.2), Vector3(-PI / 2.0, 0, 0), bone)
		_legs.append({"hip": hip, "knee": knee, "phase": spec[2], "front": spec[1] < 0.0})
	# a shroud of black smoke that trails behind it
	var smoke := CPUParticles3D.new()
	_smoke = smoke
	smoke.amount = 160
	smoke.lifetime = 1.8
	smoke.local_coords = false
	smoke.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	smoke.emission_box_extents = Vector3(0.6, 0.7, 1.5)
	smoke.position = Vector3(0, 1.05, -0.3)
	smoke.direction = Vector3(0, 1, 0)
	smoke.spread = 60.0
	smoke.gravity = Vector3(0, 0.25, 0)
	smoke.initial_velocity_min = 0.05
	smoke.initial_velocity_max = 0.3
	smoke.scale_amount_min = 1.4
	smoke.scale_amount_max = 3.0
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 0.0))
	ramp.set_color(1, Color(1, 1, 1, 0.0))
	ramp.add_point(0.25, Color(1, 1, 1, 0.9))
	ramp.add_point(0.7, Color(1, 1, 1, 0.6))
	smoke.color_ramp = ramp
	var sq := QuadMesh.new()
	sq.size = Vector2(1.0, 1.0)
	sq.material = preload("res://assets/materials/smoke.tres")
	smoke.mesh = sq
	add_child(smoke)


func _animate(delta: float) -> void:
	var sp := 1.0 if _moving else 0.0
	_gait += delta * (9.0 if _moving else 0.0)
	var breathe := sin(_t * (2.2 if state == State.HUNT else 1.2))
	_body.position.y = absf(sin(_gait)) * 0.08 * sp + breathe * 0.02
	_body.rotation.x = sin(_gait * 2.0) * 0.04 * sp
	_body.scale = Vector3(1.0 + breathe * 0.02, 1.0, 1.0)
	if state != State.LISTEN:
		_head.rotation.x = sin(_gait) * 0.12 * sp + sin(_t * 0.7) * 0.08 - 0.1
	_head.rotation.y = sin(_t * 0.5) * 0.25 * (1.0 - sp)
	_jaw.rotation.x = _jaw_open * 0.7 + (sin(_t * 9.0) * 0.08 if _jaw_open > 0.3 else 0.0)
	for leg in _legs:
		var ph: float = _gait + leg.phase
		(leg.hip as Node3D).rotation.x = sin(ph) * 0.65 * sp
		var bend := maxf(0.0, -cos(ph)) * 1.1 * sp
		(leg.knee as Node3D).rotation.x = bend if leg.front else -bend * 0.6


# ---------------------------------------------------------------- mesh helpers
func _part(parent: Node3D, mesh: Mesh, pos: Vector3, rot: Vector3, mat: Material, scl := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.rotation = rot
	mi.scale = scl
	mi.material_override = mat
	mi.layers = 2          # its own eye-light doesn't touch its hide
	parent.add_child(mi)
	return mi


func _capsule(r: float, h: float) -> CapsuleMesh:
	var m := CapsuleMesh.new()
	m.radius = r
	m.height = maxf(h, r * 2.0)
	m.radial_segments = 12
	m.rings = 4
	return m


func _sphere(r: float) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	m.radial_segments = 14
	m.rings = 8
	return m


func _cone(r: float, h: float) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.bottom_radius = r
	m.top_radius = 0.0
	m.height = h
	m.radial_segments = 8
	return m
