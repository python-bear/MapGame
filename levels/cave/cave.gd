extends Node3D
## Level — "The Hollow". The cave before the labyrinth.
##
## He walks in out of the daylight, and the mouth closes behind him: the rock
## simply grows shut, and the painted hands by the entrance smoulder red.
## After that there is only his lantern, the passages winding down into the
## dark, and the paintings: hunters, hands, a map of this very cave, the thing
## with the eye and the arms (which is not quite the same the second time he
## looks at it), a heap of bones in a side chamber — and at the bottom, a door of
## cut stone with pale light round its edges. Through it is the labyrinth.
##
##   Level time starts on his first step and stops when he walks into the light.
##   Optional: look closely at every painting (the chapter screen keeps count).

const Data := preload("res://levels/cave/cave_data.gd")

@onready var cave: Node3D = $Cave
@onready var player: CharacterBody3D = $Player
@onready var overlay: CanvasLayer = $Overlay
@onready var hud: CanvasLayer = $HUD
@onready var env: Environment = $WorldEnvironment.environment

## How close, and how squarely, he must look at a painting to "see" it.
const LOOK_DIST := 5.0
const LOOK_DOT := 0.82
## Walk this far in (z) and the mouth closes.
const SEAL_TRIGGER_Z := 55.0

var _sealed := false
var _over := false
var _seen := {}
var _lantern: OmniLight3D
var _t := 0.0
var _shake := 0.0
var _bones_said := false
var _chamber_said := false
var _door_said := false
## the monster painting: 0 = not seen, 1 = seen, 2 = changed while he wasn't looking, 3 = he noticed
var _monster := 0
var _seal_rocks: Array[MeshInstance3D] = []
var _boost := 0.0                  ## a surge of dread that fades


func _ready() -> void:
	player.global_position = Data.SPAWN
	player.rotation.y = 0.0                    # facing north, into the dark
	hud.captures_mouse = true
	hud.show_completion_card = false
	hud.show_failure_card = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	player.prompt_changed.connect(overlay.set_prompt)
	overlay.player = player
	cave.door.entered.connect(_on_door_entered)
	_make_lantern()
	hud.set_objectives("the hollow", ["find the way on"], false, true)
	_update_notes()
	Music.play_set("level3", 3.0)
	Music.set_danger(0.0)
	await get_tree().create_timer(1.4).timeout
	overlay.say("A cave. Cool air, out of the dark — and something older than the jungle.", 3.5)


func _update_notes() -> void:
	hud.set_objective_notes(["cave paintings  %d / %d" % [_seen.size(), Data.PAINTINGS.size()]])


# ================================================================ loop
func _process(delta: float) -> void:
	_t += delta
	# the lantern flickers
	_lantern.light_energy = 1.35 + sin(_t * 11.0) * sin(_t * 7.3) * 0.12 + sin(_t * 2.1) * 0.05
	# the thing with the eye smoulders in the dark, very faintly, as if it were breathing
	if not _over:
		cave.set_glow("monster", 0.22 + sin(_t * 0.9) * 0.1)
	if _shake > 0.0:
		_shake = move_toward(_shake, 0.0, delta * 1.2)
		player.camera.h_offset = randf_range(-1, 1) * _shake * 0.06
		player.camera.v_offset = randf_range(-1, 1) * _shake * 0.06
	if _over:
		return
	var p := player.global_position
	if not _sealed and p.z < SEAL_TRIGGER_Z:
		_seal_the_mouth()
	_look_at_paintings()
	var room: Array = Data.ROOMS["painted"]
	var in_chamber: bool = Vector2(p.x - room[0].x, p.z - room[0].z).length() < room[1]
	if in_chamber and not _chamber_said:
		_chamber_said = true
		Music.sfx("whisper", 0.45, 0.8)
	var b: Vector3 = Data.BONES
	if not _bones_said and Vector2(p.x - b.x, p.z - b.z).length() < 3.2:
		_bones_said = true
		Music.sfx("heartbeat", 0.6)
		overlay.say("Bones. Old ones — and not all of them animal.", 3.5)
	var d: Vector3 = Data.DOOR
	if not _door_said and Vector2(p.x - d.x, p.z - d.z).length() < 7.0:
		_door_said = true
		overlay.say("A door. Cut stone, in the living rock… and light behind it.", 3.5)
	# a little unease near the thing with the eye, otherwise almost nothing
	var m: MeshInstance3D = cave.paintings.get("monster")
	var near_m := 1.0 - clampf((m.global_position.distance_to(p) - 3.0) / 9.0, 0.0, 1.0) if m else 0.0
	_boost = move_toward(_boost, 0.0, delta * 0.08)
	Music.set_danger(maxf(0.06 + near_m * 0.3, _boost))


func _make_lantern() -> void:
	# no hands, no lantern to see — just the warm light he carries
	_lantern = OmniLight3D.new()
	_lantern.light_color = Color(1.0, 0.7, 0.4)
	_lantern.light_energy = 1.35
	_lantern.omni_range = 9.0
	_lantern.omni_attenuation = 1.25
	_lantern.position = Vector3(0.28, -0.35, -0.15)
	player.camera.add_child(_lantern)


# ================================================================ the mouth closes
func _seal_the_mouth() -> void:
	_sealed = true
	Game.begin_level_timer()
	var seal: Vector3 = Data.SEAL
	var body := StaticBody3D.new()
	body.name = "Seal"
	var cs := CollisionShape3D.new()
	var bx := BoxShape3D.new()
	bx.size = Vector3(9.0, 7.0, 1.4)
	cs.shape = bx
	body.position = seal + Vector3(0, 2.5, 0.6)
	body.add_child(cs)
	add_child(body)
	Music.sfx("grind", 1.0, 0.65)
	Music.sfx("emerge", 0.8, 0.55)
	_boost = 0.55
	_shake = 0.8
	# the rock swells out of the walls and closes over the daylight
	var mat: ShaderMaterial = cave.rock_material.duplicate()
	mat.set_shader_parameter("lump", 0.45)
	var blobs := [
		[Vector3(-2.0, 0.6, 0.0), 1.9], [Vector3(2.0, 0.7, 0.3), 1.9], [Vector3(-1.6, 2.8, 0.4), 1.8],
		[Vector3(1.7, 2.9, 0.1), 1.8], [Vector3(0.0, 1.7, 0.6), 2.2], [Vector3(0.1, 3.6, 0.2), 1.6],
		[Vector3(0.0, 0.2, -0.3), 1.6],
	]
	for i in blobs.size():
		var mi := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 1.0
		sm.height = 2.0
		sm.radial_segments = 24
		sm.rings = 12
		mi.mesh = sm
		mi.material_override = mat
		mi.position = seal + blobs[i][0]
		mi.scale = Vector3.ONE * 0.05
		mi.rotation = Vector3(randf(), randf(), randf()) * TAU
		add_child(mi)
		_seal_rocks.append(mi)
		var tw := create_tween()
		tw.tween_interval(i * 0.18)
		tw.tween_property(mi, "scale", Vector3.ONE * float(blobs[i][1]), 2.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# the daylight goes
	var tw2 := create_tween().set_parallel(true)
	tw2.tween_property(cave.daylight_lamp, "light_energy", 0.0, 2.8)
	tw2.tween_property(cave.daylight.material_override, "albedo_color", Color(0, 0, 0), 2.8)
	# and the painted hands by the entrance smoulder, as if they had done it
	var glow := create_tween()
	glow.tween_method(func(g): cave.set_glow("hands", g), 0.0, 2.5, 1.2)
	glow.tween_interval(1.5)
	glow.tween_method(func(g): cave.set_glow("hands", g), 2.5, 0.0, 3.0)
	await get_tree().create_timer(3.0).timeout
	cave.daylight.visible = false
	cave.mouth_wall.queue_free()
	overlay.say("The way out is gone. The rock just… closed.", 3.5)
	await get_tree().create_timer(4.0).timeout
	if not _over:
		overlay.say("Down, then. There's nowhere else.", 3.0)


# ================================================================ paintings
func _look_at_paintings() -> void:
	var cam: Camera3D = player.camera
	var eye: Vector3 = cam.global_position
	var fwd: Vector3 = -cam.global_transform.basis.z
	for p: Dictionary in Data.PAINTINGS:
		var mi: MeshInstance3D = cave.paintings.get(p.tex)
		if mi == null:
			continue
		var to: Vector3 = mi.global_position - eye
		var dist := to.length()
		var facing: bool = dist < LOOK_DIST and fwd.dot(to / dist) > LOOK_DOT and (p.normal as Vector3).dot(-to) > 0.0
		if p.tex == "monster":
			_watch_monster(facing, dist)
		if facing and not _seen.has(p.tex):
			_seen[p.tex] = true
			_update_notes()
			Music.sfx("page", 0.35, 0.8)
			if p.tex != "monster" or _monster < 3:
				overlay.say(p.line, 4.0)


## The arms move while he isn't looking.
func _watch_monster(facing: bool, dist: float) -> void:
	match _monster:
		0:
			if facing:
				_monster = 1
		1:
			if not facing and dist > 7.0:
				_monster = 2
				cave.repaint("monster", "monster_b")
		2:
			if facing:
				_monster = 3
				Music.sfx("whisper", 0.7, 0.7)
				overlay.say("…The arms. They were not there before. They were not like that.", 3.5)


# ================================================================ the way on
func _on_door_entered() -> void:
	if _over:
		return
	_over = true
	player.frozen = true
	hud.tick_objective("find the way on")
	Game.complete_level()
	Game.record_landmarks(Game.LEVELS[Game.current_level]["id"], _seen.size(), Data.PAINTINGS.size())
	Game.last_found = _seen.size()
	Game.last_total = Data.PAINTINGS.size()
	Music.sfx("exit", 0.8, 0.8)
	Music.stop(2.0)
	var pale := Color(0.86, 0.9, 1.0)
	await overlay.fade_to(pale, 1.6)
	Game.change_scene("res://scenes/interlude.tscn", 0.3, pale)
