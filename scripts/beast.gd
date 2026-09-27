extends Node3D
## The beast of the labyrinth: a winged, tentacle-faced colossus with two red
## eyes, black mist pooling round its feet.
##
## It sleeps in its hall in the east wing until the Black Key is taken. Then it
## hunts — but it hunts by ear:
##   running  loud  (heard ~20 m away, by the way sound travels round corners)
##   doors    loud-ish (~13 m)
##   walking  quiet (~4 m)      standing still: silent
## It also sees you if you're close and in a straight line of it.
## When it loses you it searches near where you are (it always drifts closer),
## stopping now and then to listen — and while it listens it hears twice as far.
## It moves at 0.9x your walking speed — you can always get away, if you
## keep moving. Doors hold it a
## moment. It will not go into the light.

signal caught_player

@export var speed_ratio := 0.9          ## of the player's walking speed, when it knows where you are
@export var search_ratio := 0.55
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
var _legs: Array = []                   # [{hip, knee, phase, side}]
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
## A winged, tentacle-faced colossus: a hunched giant's body of dark, stony
## hide; a swollen octopus skull with a beard of writhing tentacles and two
## red eyes under a heavy brow; long clawed arms; ragged bat wings, half-folded
## in the corridors and flung wide when it screams; and long spined tentacles
## coiling from its back. Black mist pools round its feet.
var _torso: Node3D
var _arms: Array = []                   # [{shoulder, elbow, side}]
var _wings: Array = []                  # [{pivot, side}]
var _face_tentacles: Array = []         # [{joints: [Node3D], side, i}]
var _back_tentacles: Array = []         # [{joints: [Node3D], side, phase, curl}]
var _spread := 0.0                      # wings: 0 half-folded … 1 flung wide
var _scare := false                     # the jumpscare pose
var _scare_light: OmniLight3D
var _hide: StandardMaterial3D
var _membrane: StandardMaterial3D
var _bone: StandardMaterial3D


func _build() -> void:
	_hide = StandardMaterial3D.new()
	_hide.albedo_color = Color(0.1, 0.115, 0.1)
	_hide.roughness = 0.85
	_hide.rim_enabled = true
	_hide.rim = 0.45
	_hide.rim_tint = 0.3
	_membrane = StandardMaterial3D.new()
	_membrane.albedo_color = Color(0.05, 0.055, 0.055)
	_membrane.roughness = 0.75
	_membrane.cull_mode = BaseMaterial3D.CULL_DISABLED
	_membrane.rim_enabled = true
	_membrane.rim = 0.3
	_bone = StandardMaterial3D.new()
	_bone.albedo_color = Color(0.2, 0.19, 0.17)
	_bone.roughness = 0.7
	var hide := _hide
	var giant := Node3D.new()          # the whole thing, a little over life-size
	giant.scale = Vector3.ONE * 1.12
	add_child(giant)
	_body = Node3D.new()
	giant.add_child(_body)
	# ---- legs: hip -> thigh -> knee -> shin -> clawed foot
	for side: float in [-1.0, 1.0]:
		var hip := Node3D.new()
		hip.position = Vector3(side * 0.22, 1.15, 0.05)
		_body.add_child(hip)
		_part(hip, _capsule(0.19, 0.72), Vector3(0, -0.3, 0), Vector3.ZERO, hide)
		_part(hip, _sphere(0.22), Vector3(side * 0.03, -0.18, -0.03), Vector3.ZERO, hide, Vector3(1.0, 1.4, 1.0))   # thigh muscle
		var knee := Node3D.new()
		knee.position = Vector3(0, -0.58, 0)
		hip.add_child(knee)
		_part(knee, _capsule(0.12, 0.62), Vector3(0, -0.28, 0.02), Vector3.ZERO, hide)
		_part(knee, _sphere(0.14), Vector3(0, -0.14, 0.06), Vector3.ZERO, hide, Vector3(1.0, 1.6, 1.0))              # calf
		_part(knee, _sphere(0.13), Vector3(0, -0.56, -0.08), Vector3.ZERO, hide, Vector3(1.0, 0.45, 1.6))
		for c in 3:   # long toes, like roots
			var a := (c - 1) * 0.45
			_part(knee, _cone(0.035, 0.26), Vector3(sin(a) * 0.12, -0.6, -0.22 - cos(a) * 0.04), Vector3(-PI / 2.0 + 0.2, a, 0), _bone)
		_legs.append({"hip": hip, "knee": knee, "phase": 0.0 if side < 0.0 else PI, "side": side})
	# ---- torso, pivoting at the hips so it can hunch
	_torso = Node3D.new()
	_torso.position = Vector3(0, 1.15, 0.05)
	_body.add_child(_torso)
	_part(_torso, _sphere(0.3), Vector3(0, 0.02, 0), Vector3.ZERO, hide, Vector3(1.2, 0.8, 0.9))            # pelvis
	_part(_torso, _capsule(0.27, 0.7), Vector3(0, 0.32, 0), Vector3.ZERO, hide, Vector3(1.0, 1.0, 0.85))    # belly
	_part(_torso, _sphere(0.46), Vector3(0, 0.66, 0), Vector3.ZERO, hide, Vector3(1.4, 1.0, 0.9))          # chest
	_part(_torso, _sphere(0.3), Vector3(0, 0.78, 0.18), Vector3.ZERO, hide, Vector3(1.8, 1.0, 1.0))           # hunched back
	for side: float in [-1.0, 1.0]:
		_part(_torso, _sphere(0.25), Vector3(side * 0.5, 0.84, 0.0), Vector3.ZERO, hide, Vector3(1.0, 0.9, 1.0))   # shoulders
		_part(_torso, _sphere(0.16), Vector3(side * 0.17, 0.62, -0.26), Vector3.ZERO, hide, Vector3(1.2, 0.9, 0.6))  # breast plates
		for r in 3:   # ribs of gristle across the belly
			_part(_torso, _capsule(0.035, 0.3), Vector3(side * 0.12, 0.2 + r * 0.12, -0.22), Vector3(0, 0, side * 1.2), hide)
	for i in 6:       # a ridge of spines down the back
		_part(_torso, _cone(0.05, 0.2), Vector3(0, 0.95 - i * 0.14, 0.3 - i * 0.015), Vector3(PI / 2.0 - 0.4, 0, 0), _bone)
	# ---- arms: long, hanging, with hooked claws
	for side: float in [-1.0, 1.0]:
		var sh := Node3D.new()
		sh.position = Vector3(side * 0.56, 0.8, 0.0)
		_torso.add_child(sh)
		_part(sh, _capsule(0.15, 0.66), Vector3(0, -0.3, 0), Vector3.ZERO, hide)
		_part(sh, _sphere(0.16), Vector3(0, -0.2, -0.04), Vector3.ZERO, hide, Vector3(1.0, 1.5, 1.0))           # bicep
		var el := Node3D.new()
		el.position = Vector3(0, -0.6, 0)
		sh.add_child(el)
		_part(el, _capsule(0.11, 0.6), Vector3(0, -0.28, 0), Vector3.ZERO, hide)
		_part(el, _sphere(0.13), Vector3(0, -0.14, 0), Vector3.ZERO, hide, Vector3(1.0, 1.6, 1.0))              # forearm
		_part(el, _sphere(0.1), Vector3(0, -0.6, 0), Vector3.ZERO, hide, Vector3(1.0, 0.8, 1.2))
		for c in 4:
			var a := (c - 1.5) * 0.35
			_part(el, _cone(0.022, 0.28), Vector3(sin(a) * 0.08, -0.78, -0.05 - cos(a) * 0.03), Vector3(0.35, a, PI), _bone)
		_arms.append({"shoulder": sh, "elbow": el, "side": side})
	# ---- head: the swollen octopus skull
	_head = Node3D.new()
	_head.position = Vector3(0, 1.08, -0.12)
	_torso.add_child(_head)
	_part(_head, _sphere(0.3), Vector3(0, 0.24, 0.14), Vector3(-0.55, 0, 0), hide, Vector3(1.0, 1.55, 1.2))   # mantle
	for side: float in [-1.0, 1.0]:
		_part(_head, _sphere(0.12), Vector3(side * 0.13, 0.18, 0.02), Vector3(-0.5, 0, 0), hide, Vector3(0.8, 1.6, 1.0))   # ridges of the skull
	_part(_head, _sphere(0.2), Vector3(0, -0.02, -0.1), Vector3.ZERO, hide, Vector3(1.05, 0.9, 0.8))          # face
	_part(_head, _capsule(0.055, 0.4), Vector3(0, 0.06, -0.22), Vector3(0, 0, PI / 2.0), hide)                # brow
	for side: float in [-1.0, 1.0]:
		_part(_head, _cone(0.05, 0.22), Vector3(side * 0.2, 0.05, -0.05), Vector3(0, 0, -side * 1.3), hide)   # finned ears
	# the eyes
	_eyes = Node3D.new()
	_eyes.position = Vector3(0, 0.0, -0.25)
	_head.add_child(_eyes)
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = Color(1.0, 0.08, 0.04)
	glow.disable_fog = true
	for s in [-1.0, 1.0]:
		_part(_eyes, _sphere(0.04), Vector3(s * 0.085, 0, 0), Vector3(0, 0, -s * 0.25), glow, Vector3(1.3, 0.42, 0.8))
		var halo := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(0.32, 0.32)
		halo.mesh = q
		var hm: StandardMaterial3D = preload("res://assets/materials/wisp.tres").duplicate()
		hm.albedo_color = Color(1.0, 0.1, 0.05, 0.8)
		halo.material_override = hm
		halo.position = Vector3(s * 0.085, 0, -0.02)
		_eyes.add_child(halo)
	var eye_light := OmniLight3D.new()
	eye_light.light_color = Color(1.0, 0.1, 0.05)
	eye_light.light_energy = 1.0
	eye_light.omni_range = 3.0
	eye_light.position = Vector3(0, -0.1, -0.6)
	eye_light.light_cull_mask = 1                  # lights the corridor, not itself
	_eyes.add_child(eye_light)
	# the beard of tentacles (the "jaw": it flares open when it screams)
	_jaw = Node3D.new()
	_jaw.position = Vector3(0, -0.12, -0.2)
	_head.add_child(_jaw)
	for i in 9:
		var u := (i - 4) / 4.0
		var length := 0.95 - absf(u) * 0.4
		var root := Vector3(u * 0.15, -absf(u) * 0.03 * 0.0 + 0.02 * absf(u), -0.02 + absf(u) * 0.06)
		var joints := _tentacle(_jaw, root, Vector3(0.3, 0, u * 0.25), 7, length / 7.0, 0.05, 0.012, false, signf(u))
		_face_tentacles.append({"joints": joints, "u": u, "i": i})
	# ---- wings, from high on the back
	for side: float in [-1.0, 1.0]:
		var pivot := Node3D.new()
		pivot.position = Vector3(side * 0.18, 0.86, 0.26)
		_torso.add_child(pivot)
		_wing(pivot, side)
		_wings.append({"pivot": pivot, "side": side})
	# ---- long spined tentacles coiling from its back
	var specs := [[0.3, 0.72, 2.1, 0.0], [0.26, 0.35, 1.25, 1.7]]
	for spec in specs:
		for side: float in [-1.0, 1.0]:
			var joints := _tentacle(_torso, Vector3(side * spec[0], spec[1], 0.2), Vector3(0, 0, side * spec[2]), 11, 0.16, 0.1, 0.022, true, side)
			_back_tentacles.append({"joints": joints, "side": side, "phase": spec[3] + (0.0 if side < 0.0 else 0.8), "curl": 0.16 if spec[1] > 0.5 else 0.22})
	# ---- black mist pooling round its feet
	var smoke := CPUParticles3D.new()
	_smoke = smoke
	smoke.amount = 90
	smoke.lifetime = 2.2
	smoke.local_coords = false
	smoke.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	smoke.emission_box_extents = Vector3(0.8, 0.35, 0.8)
	smoke.position = Vector3(0, 0.35, 0.0)
	smoke.direction = Vector3(0, 1, 0)
	smoke.spread = 70.0
	smoke.gravity = Vector3(0, 0.15, 0)
	smoke.initial_velocity_min = 0.05
	smoke.initial_velocity_max = 0.25
	smoke.scale_amount_min = 1.2
	smoke.scale_amount_max = 2.6
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 0.0))
	ramp.set_color(1, Color(1, 1, 1, 0.0))
	ramp.add_point(0.25, Color(1, 1, 1, 0.85))
	ramp.add_point(0.7, Color(1, 1, 1, 0.5))
	smoke.color_ramp = ramp
	var sq := QuadMesh.new()
	sq.size = Vector2(1.0, 1.0)
	sq.material = preload("res://assets/materials/smoke.tres")
	smoke.mesh = sq
	add_child(smoke)


## A chain of tapering segments hanging along its local -Y, rotated at the
## root by `rot`. Returns the joints (each the parent of the next).
func _tentacle(parent: Node3D, at: Vector3, rot: Vector3, count: int, seg: float, r0: float, r1: float, spined: bool, side: float) -> Array:
	var joints: Array = []
	var p := parent
	for j in count:
		var jt := Node3D.new()
		jt.position = at if j == 0 else Vector3(0, -seg, 0)
		if j == 0:
			jt.rotation = rot
			jt.set_meta("base", rot)
		p.add_child(jt)
		var r := lerpf(r0, r1, float(j) / maxf(count - 1, 1))
		_part(jt, _capsule(r, seg + r * 1.6), Vector3(0, -seg / 2.0, 0), Vector3.ZERO, _hide)
		if spined and j > 0 and j < count - 1:
			var s := 1.0 if side >= 0.0 else -1.0
			_part(jt, _cone(r * 0.45, r * 2.2), Vector3(s * r * 0.9, -seg * 0.5, 0), Vector3(0, 0, -s * PI / 2.0), _bone)
			_part(jt, _cone(r * 0.35, r * 1.6), Vector3(0, -seg * 0.5, r * 0.9), Vector3(PI / 2.0, 0, 0), _bone)
		joints.append(jt)
		p = jt
	return joints


## A ragged bat wing in its own plane: arm, four finger bones, and the membrane
## between them scalloped from tip to tip.
func _wing(pivot: Node3D, side: float) -> void:
	var s := side
	var wrist := Vector2(0.75, 0.55)
	var tips := [Vector2(1.35, 1.3), Vector2(1.9, 0.6), Vector2(1.8, -0.2), Vector2(1.2, -0.78)]
	var tail := Vector2(0.18, -0.55)
	var outline: Array[Vector2] = [Vector2.ZERO, wrist, tips[0]]
	var chain: Array = tips.duplicate()
	chain.append(tail)
	var hub := Vector2(0.85, 0.25)
	for k in range(1, chain.size()):
		var a: Vector2 = chain[k - 1]
		var b: Vector2 = chain[k]
		var ctrl := ((a + b) * 0.5).lerp(hub, 0.38)
		for t in [0.25, 0.5, 0.75, 1.0]:
			outline.append(a.lerp(ctrl, t).lerp(ctrl.lerp(b, t), t))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3(0, 0, -1))
	for k in outline.size():
		var a: Vector2 = outline[k]
		var b: Vector2 = outline[(k + 1) % outline.size()]
		var tri := [hub, a, b] if s > 0.0 else [hub, b, a]
		for v: Vector2 in tri:
			st.set_uv(v / 2.0)
			st.add_vertex(Vector3(v.x * s, v.y, 0))
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = _membrane
	mi.layers = 2
	pivot.add_child(mi)
	# the bones over it
	_bone_between(pivot, Vector3.ZERO, Vector3(wrist.x * s, wrist.y, 0.0), 0.06, _hide)
	for tp: Vector2 in tips:
		_bone_between(pivot, Vector3(wrist.x * s, wrist.y, 0.0), Vector3(tp.x * s, tp.y, 0.0), 0.028, _hide)
	_bone_between(pivot, Vector3(tips[0].x * s, tips[0].y, 0), Vector3((tips[0].x + 0.12) * s, tips[0].y + 0.28, 0), 0.03, _bone)   # the hook at the top
	_bone_between(pivot, Vector3(wrist.x * s, wrist.y, 0), Vector3((wrist.x - 0.05) * s, wrist.y + 0.2, -0.05), 0.03, _bone)         # thumb claw


func _bone_between(parent: Node3D, a: Vector3, b: Vector3, r: float, mat: Material) -> void:
	var d := b - a
	var mi := _part(parent, _capsule(r, d.length() + r), (a + b) * 0.5, Vector3.ZERO, mat)
	mi.basis = Basis(Quaternion(Vector3.UP, d.normalized()))


func _animate(delta: float) -> void:
	var sp := 1.0 if _moving else 0.0
	_gait += delta * (7.0 if _moving else 0.0)
	var hunting := state == State.HUNT or _scare
	var breathe := sin(_t * (2.2 if hunting else 1.2))
	_body.position.y = absf(sin(_gait)) * 0.07 * sp + breathe * 0.012
	_torso.scale = Vector3(1.0 + breathe * 0.015, 1.0, 1.0 + breathe * 0.02)
	# hunched, leaning into the chase
	var lean := -0.18 - (0.12 * sp if hunting else 0.0)
	if _scare:
		lean = -0.42
	_torso.rotation.x = lerpf(_torso.rotation.x, lean, 1.0 - exp(-6.0 * delta)) if delta > 0.0 else lean
	_torso.rotation.z = sin(_gait) * 0.05 * sp
	for leg in _legs:
		var ph: float = _gait + leg.phase
		(leg.hip as Node3D).rotation.x = sin(ph) * 0.55 * sp
		(leg.knee as Node3D).rotation.x = -(maxf(0.0, sin(ph + 1.2)) * 0.9 * sp + 0.12)
	for arm in _arms:
		var ph: float = _gait + (PI if arm.side < 0.0 else 0.0)
		var sh: Node3D = arm.shoulder
		var el: Node3D = arm.elbow
		if _scare:
			sh.rotation = Vector3(1.35 + sin(_t * 11.0) * 0.05, 0, arm.side * 0.65)
			el.rotation.x = 0.55
		else:
			var reach := 0.3 if hunting else 0.05
			sh.rotation.x = reach - sin(ph) * 0.45 * sp + sin(_t * 0.9 + arm.side) * 0.04
			sh.rotation.z = arm.side * 0.2
			el.rotation.x = 0.3 + (0.25 if hunting else 0.0) + sin(ph) * 0.12 * sp
	if _scare:
		_head.rotation = Vector3(0.28 + sin(_t * 17.0) * 0.03, 0, sin(_t * 13.0) * 0.04)
	else:
		if state != State.LISTEN:
			_head.rotation.x = 0.16 + sin(_gait) * 0.06 * sp + sin(_t * 0.7) * 0.06
		_head.rotation.y = sin(_t * 0.5) * 0.25 * (1.0 - sp)
	# the beard: it writhes, and flares open when it screams
	var fl := 1.0 if _scare else _jaw_open
	for ft in _face_tentacles:
		var js: Array = ft.joints
		var u: float = ft.u
		for j in js.size():
			var jt: Node3D = js[j]
			var w := sin(_t * (3.2 if hunting else 2.0) + ft.i * 0.9 + j * 0.7) * (0.14 + fl * 0.2)
			var w2 := sin(_t * 1.7 + ft.i * 1.3 + j * 0.5) * 0.1
			if j == 0:
				jt.rotation = Vector3(0.3 + fl * 0.9 + w * 0.5, 0, u * (0.25 + fl * 0.7) + w2)
			else:
				jt.rotation = Vector3(w - fl * 0.12, 0, w2 * 0.6)
	# wings: half-folded down the corridors, flung wide when it screams
	var want := 1.0 if (_scare or state == State.EMERGING or state == State.HALTED or _jaw_open > 0.5) else 0.0
	_spread = move_toward(_spread, want, delta * (3.0 if want > _spread else 0.8))
	if _scare:
		_spread = 1.0
	for wg in _wings:
		var pv: Node3D = wg.pivot
		var s: float = wg.side
		var fold := lerpf(1.2, 0.12, _spread)
		var flap := sin(_t * (1.3 + _spread * 3.0)) * (0.05 + _spread * 0.1)
		pv.rotation = Vector3(0.1, -s * fold, s * (0.12 + _spread * 0.25 + flap))
	# the spined tentacles on its back coil and lash
	var lash := 1.8 if _scare else (1.3 if hunting else 1.0)
	for bt in _back_tentacles:
		var js: Array = bt.joints
		var s: float = bt.side
		for j in js.size():
			var jt: Node3D = js[j]
			var k := float(j) / js.size()
			var wz := sin(_t * 1.5 * lash + j * 0.6 + bt.phase) * 0.14 * lash
			var wx := sin(_t * 1.1 * lash + j * 0.5 + bt.phase * 1.7) * 0.2 * lash
			if j == 0:
				var base: Vector3 = jt.get_meta("base")
				jt.rotation = base + Vector3(wx * 0.4 - 0.2, 0, wz * 0.4)
			else:
				jt.rotation = Vector3(wx, 0, s * bt.curl * (0.4 + k * 1.6) + wz)


# ================================================================ the jumpscare
## Lunge into his face: eyes level with his, a hand's breadth away, wings
## thrown open, arms spread, the beard of tentacles flared. `cam` is his camera.
func jumpscare(cam: Camera3D) -> void:
	_scare = true
	state = State.FEEDING
	_jaw_open = 1.0
	var f := cam.global_position - global_position
	f.y = 0.0
	if f.length() < 0.01:
		f = cam.global_transform.basis.z
		f.y = 0.0
	f = -f.normalized()                  # from him, towards where it stands
	_heading = atan2(f.x, f.z)
	rotation.y = _heading
	_animate(0.0)                        # strike the pose now so the eyes are where they'll be
	var eyes_off := _eyes.global_position - global_position
	var end_at := cam.global_position + f * 0.9 - eyes_off
	var start_at := cam.global_position + f * 2.4 - eyes_off
	global_position = start_at
	var tw := create_tween()
	tw.tween_property(self, "global_position", end_at, 0.12).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	# a sickly light on its face so he sees every inch of it
	_scare_light = OmniLight3D.new()
	_scare_light.light_color = Color(0.85, 0.35, 0.25)
	_scare_light.light_energy = 1.6
	_scare_light.omni_range = 2.6
	_scare_light.light_cull_mask = 2       # only its hide
	_scare_light.position = Vector3(0.1, -0.75, -0.8)    # from below: the brow and skull in shadow
	_head.add_child(_scare_light)
	_screech(0.75)


func _process(_delta: float) -> void:
	if _scare_light:
		_scare_light.light_energy = 1.2 + randf() * 1.0


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
