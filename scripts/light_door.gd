@tool
extends Node3D
## A door of light in the outer wall: an old door with blinding white light
## leaking round its edges, and a sign carved over it.
##
## The real one (`fake` = false) opens by itself when he comes near with the
## last key — the light floods the corridor, and nothing follows him into it.
## The false ones open onto white — and put him back somewhere in the maze.
## Each false one is wrong in one small way:
##   variant 0  the light is the wrong colour
##   variant 1  it doesn't light the floor, and it hums
##   variant 2  the sign over it is different, and something whispers behind it

signal entered            ## the real door: he walked into the light
signal fooled             ## a false door: he opened it

@export var fake := false
@export var variant := 0

var is_open := false
var armed := false         ## the real door only opens once this is true
var _leaf: AnimatableBody3D
var _leaf_angle := 0.0
var _hinge := Vector3.ZERO
var _w := 1.56
var _h := 2.66
var _light: OmniLight3D
var _spill: SpotLight3D
var _glow: MeshInstance3D
var _audio: AudioStreamPlayer3D
var _outward := Vector3.FORWARD
var _area: Area3D
var _t := 0.0
var _busy := false


## `p`: centre of the doorway on the floor. `outward`: out of the maze.
func setup(p: Vector3, outward: Vector3, width: float, height: float) -> void:
	position = p
	_outward = outward
	_w = width - 0.04
	_h = height - 0.04
	# work in local space where -Z is out of the maze
	basis = Basis.looking_at(outward, Vector3.UP)
	var white := Color(1.0, 0.98, 0.93)
	var tint: Color = Color(0.86, 1.0, 0.9) if fake and variant == 0 else white
	# the light behind: a blinding plane just beyond the threshold
	var plane := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(_w + 0.5, _h + 0.4)
	plane.mesh = qm
	var pm := StandardMaterial3D.new()
	pm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pm.albedo_color = tint
	pm.disable_fog = true
	pm.cull_mode = BaseMaterial3D.CULL_DISABLED
	plane.material_override = pm
	plane.position = Vector3(0, _h / 2.0, -0.45)
	add_child(plane)
	# and the floor beyond the threshold, white too
	var sill := MeshInstance3D.new()
	var sq := QuadMesh.new()
	sq.size = Vector2(_w + 0.5, 0.5)
	sill.mesh = sq
	sill.material_override = pm
	sill.rotation.x = -PI / 2.0
	sill.position = Vector3(0, 0.012, -0.25)
	add_child(sill)
	# the door leaf, dark against it, light showing round the edges
	_hinge = Vector3(-_w / 2.0, 0, -0.1)
	_leaf = AnimatableBody3D.new()
	_leaf.sync_to_physics = true
	_leaf.set_meta("interact_target", self)
	add_child(_leaf)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(_w - 0.08, _h - 0.06, 0.12)
	cs.shape = bs
	_leaf.add_child(cs)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = bs.size
	mi.mesh = bm
	mi.material_override = preload("res://assets/materials/door_wood.tres")
	_leaf.add_child(mi)
	_set_leaf(0.0)
	# the sign carved over it
	_sign(tint)
	# the glow through the fog
	_glow = MeshInstance3D.new()
	var hq := QuadMesh.new()
	hq.size = Vector2(4.2, 4.2)
	_glow.mesh = hq
	var gm: StandardMaterial3D = preload("res://assets/materials/wisp.tres").duplicate()
	gm.albedo_color = Color(tint, 0.55)
	_glow.material_override = gm
	_glow.position = Vector3(0, _h / 2.0, 0.15)
	add_child(_glow)
	# light spilling onto the floor (the false one of variant 1 doesn't)
	if not (fake and variant == 1):
		_light = OmniLight3D.new()
		_light.light_color = tint
		_light.light_energy = 1.6
		_light.omni_range = 6.0
		_light.position = Vector3(0, 1.3, 1.0)
		add_child(_light)
	_audio = AudioStreamPlayer3D.new()
	_audio.unit_size = 3.0
	_audio.max_distance = 16.0
	_audio.position = Vector3(0, 1.4, -0.3)
	add_child(_audio)
	if fake and variant >= 1:
		var st: AudioStream = load("res://assets/sfx/%s.ogg" % ("hum" if variant == 1 else "whisper")).duplicate()
		if st is AudioStreamOggVorbis:
			(st as AudioStreamOggVorbis).loop = true
		_audio.stream = st
		_audio.volume_db = -4.0
		_audio.autoplay = true
	# behind it: the white, and a wall so he can't walk out into nothing
	var stop := StaticBody3D.new()
	var scs := CollisionShape3D.new()
	var sbs := BoxShape3D.new()
	sbs.size = Vector3(_w + 1.0, 3.6, 0.4)
	scs.shape = sbs
	scs.position = Vector3(0, 1.8, -0.75)
	stop.add_child(scs)
	add_child(stop)
	if not fake:
		_area = Area3D.new()
		var acs := CollisionShape3D.new()
		var ab := BoxShape3D.new()
		ab.size = Vector3(_w, 2.4, 0.7)
		acs.shape = ab
		acs.position = Vector3(0, 1.2, -0.25)
		_area.add_child(acs)
		_area.monitoring = false
		add_child(_area)
		_area.body_entered.connect(func(b): if b.is_in_group("player"): entered.emit())


func _sign(tint: Color) -> void:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = tint
	mat.disable_fog = true
	var root := Node3D.new()
	root.position = Vector3(0, _h + 0.45, 0.28)
	add_child(root)
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.13
	tm.outer_radius = 0.17
	ring.mesh = tm
	ring.rotation.x = PI / 2.0
	ring.material_override = mat
	root.add_child(ring)
	if fake and variant == 2:
		# a cross through the ring, not an eye in it
		for a: float in [PI / 4.0, -PI / 4.0]:
			var bar := MeshInstance3D.new()
			var bb := BoxMesh.new()
			bb.size = Vector3(0.42, 0.035, 0.02)
			bar.mesh = bb
			bar.rotation.z = a
			bar.material_override = mat
			root.add_child(bar)
	else:
		var dot := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.05
		sm.height = 0.1
		dot.mesh = sm
		dot.material_override = mat
		root.add_child(dot)


func _set_leaf(a: float) -> void:
	_leaf_angle = a
	_leaf.transform = Transform3D(Basis(Vector3.UP, a), _hinge) * Transform3D(Basis(), Vector3(_w / 2.0, _h / 2.0 + 0.02, 0))


func prompt() -> String:
	if _busy or is_open:
		return ""
	return "open the door" if fake else ("the light is on the other side" if not armed else "")


func interact(_from: Vector3) -> void:
	if not fake or _busy:
		return
	_busy = true
	var tw := create_tween()
	tw.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tw.tween_method(_set_leaf, 0.0, 1.3, 0.5).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func(): fooled.emit())
	tw.tween_interval(1.2)
	tw.tween_method(_set_leaf, 1.3, 0.0, 0.6)
	tw.tween_callback(func(): _busy = false)
	_play("door_open", 0.9)


## The real door: it opens by itself when he comes close with the last key.
func open() -> void:
	if is_open or fake:
		return
	is_open = true
	_play("exit", 1.0)
	var tw := create_tween().set_parallel(true)
	tw.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tw.tween_method(_set_leaf, 0.0, 1.75, 2.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if _light:
		tw.tween_property(_light, "light_energy", 5.0, 2.5)
		tw.tween_property(_light, "omni_range", 13.0, 2.5)
	tw.tween_property(_glow, "scale", Vector3.ONE * 2.2, 2.5)
	# white light spilling into the maze
	_spill = SpotLight3D.new()
	_spill.light_color = Color(1.0, 0.98, 0.93)
	_spill.light_energy = 0.0
	_spill.spot_range = 18.0
	_spill.spot_angle = 50.0
	_spill.position = Vector3(0, 2.2, -0.2)
	_spill.rotation.x = -0.25
	_spill.rotate_object_local(Vector3.UP, PI)          # face into the maze
	add_child(_spill)
	tw.tween_property(_spill, "light_energy", 6.0, 2.0)
	_area.monitoring = true


func _play(name: String, vol: float) -> void:
	var music := get_node_or_null("/root/Music")
	if music:
		music.sfx(name, vol, 0.75 if fake else 1.0)


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_t += delta
	if _light and not is_open:
		_light.light_energy = 1.6 + sin(_t * 1.3) * 0.15
