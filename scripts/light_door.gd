@tool
extends Node3D
## A door in the outer wall. Three kinds (`role`):
##
##   "exit"    the Door of Light: an old door with blinding white light leaking
##             round its edges and an eye carved over it. It opens by itself
##             when he comes near with the last key — the light floods the
##             corridor, and nothing follows him into it.
##   "portal"  one of a pair of joined doors. Violet light, a spiral carved over
##             it (the same spiral on both), and when it opens: a turning swirl.
##             Walk into it and you step out of its partner, across the
##             labyrinth — with everything you carry. Nothing resets.
##   "dud"     looks just like the Door of Light. Open it: bricks. The light
##             was only painted on the stone. It does nothing, ever again.

signal entered            ## exit: he walked into the light
signal traversed          ## portal: he walked into the swirl
signal fooled             ## dud: he opened it

@export var fake := false  ## (anything but the real exit)
@export var variant := 0
@export_enum("exit", "portal", "dud") var role := "exit"

const WHITE := Color(1.0, 0.98, 0.93)
const VIOLET := Color(0.62, 0.36, 1.0)

var partner: Node3D        ## portal: the door it lets out of
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
var _plane: MeshInstance3D
var _sill: MeshInstance3D
var _bricks: MeshInstance3D
var _vortex_mat: ShaderMaterial
var _audio: AudioStreamPlayer3D
var _outward := Vector3.FORWARD
var _area: Area3D
var _t := 0.0
var _busy := false
var _dead := false          ## dud: opened, and nothing there


## `p`: centre of the doorway on the floor. `outward`: out of the maze.
func setup(p: Vector3, outward: Vector3, width: float, height: float) -> void:
	position = p
	_outward = outward
	_w = width - 0.04
	_h = height - 0.04
	fake = role != "exit"
	# work in local space where -Z is out of the maze
	basis = Basis.looking_at(outward, Vector3.UP)
	var portal := role == "portal"
	var tint: Color = VIOLET if portal else WHITE
	# what's behind: a blinding plane (or the swirl) just beyond the threshold
	_plane = MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(_w + 0.5, _h + 0.4)
	_plane.mesh = qm
	var pm := StandardMaterial3D.new()
	pm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pm.albedo_color = tint
	pm.disable_fog = true
	pm.cull_mode = BaseMaterial3D.CULL_DISABLED
	if portal:
		_vortex_mat = ShaderMaterial.new()
		_vortex_mat.shader = preload("res://shaders/portal_vortex.gdshader")
		_vortex_mat.set_shader_parameter("aspect", qm.size.y / qm.size.x)
		_plane.material_override = _vortex_mat
	else:
		_plane.material_override = pm
	_plane.position = Vector3(0, _h / 2.0, -0.45)
	add_child(_plane)
	# and the floor beyond the threshold
	_sill = MeshInstance3D.new()
	var sq := QuadMesh.new()
	sq.size = Vector2(_w + 0.5, 0.5)
	_sill.mesh = sq
	_sill.material_override = pm
	_sill.rotation.x = -PI / 2.0
	_sill.position = Vector3(0, 0.012, -0.25)
	add_child(_sill)
	# the dud: bricks behind the paint, hidden until it's opened
	if role == "dud":
		_bricks = MeshInstance3D.new()
		var bm0 := BoxMesh.new()
		bm0.size = Vector3(_w + 0.3, _h + 0.3, 0.2)
		_bricks.mesh = bm0
		_bricks.material_override = preload("res://assets/materials/stone_wall.tres")
		_bricks.position = Vector3(0, _h / 2.0, -0.32)
		_bricks.visible = false
		add_child(_bricks)
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
	if portal:
		_portal_runes()
	_set_leaf(0.0)
	# the sign carved over it
	if portal:
		_spiral_sign()
	else:
		_sign(tint)
	# the glow through the fog
	_glow = MeshInstance3D.new()
	var hq := QuadMesh.new()
	hq.size = Vector2(4.2, 4.2)
	_glow.mesh = hq
	var gm: StandardMaterial3D = preload("res://assets/materials/wisp.tres").duplicate()
	gm.albedo_color = Color(tint, 0.3 if portal else 0.55)
	_glow.material_override = gm
	_glow.position = Vector3(0, _h / 2.0, 0.15)
	add_child(_glow)
	# light spilling onto the floor
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
	if portal:
		var st: AudioStream = load("res://assets/sfx/hum.ogg").duplicate()
		if st is AudioStreamOggVorbis:
			(st as AudioStreamOggVorbis).loop = true
		_audio.stream = st
		_audio.volume_db = -8.0
		_audio.pitch_scale = 0.7
		_audio.autoplay = true
	# behind it: a wall so he can't walk out into nothing
	var stop := StaticBody3D.new()
	var scs := CollisionShape3D.new()
	var sbs := BoxShape3D.new()
	sbs.size = Vector3(_w + 1.0, 3.6, 0.4)
	scs.shape = sbs
	scs.position = Vector3(0, 1.8, -0.75)
	stop.add_child(scs)
	add_child(stop)
	if role != "dud":
		_area = Area3D.new()
		var acs := CollisionShape3D.new()
		var ab := BoxShape3D.new()
		ab.size = Vector3(_w, 2.4, 0.7)
		acs.shape = ab
		acs.position = Vector3(0, 1.2, -0.25)
		_area.add_child(acs)
		_area.monitoring = false
		add_child(_area)
		if portal:
			_area.body_entered.connect(func(b): if b.is_in_group("player"): traversed.emit())
		else:
			_area.body_entered.connect(func(b): if b.is_in_group("player"): entered.emit())


## Where someone stepping out of this door stands, and which way they face
## (into the maze).
func arrival_point(dist := 1.7) -> Vector3:
	return global_position + global_transform.basis.z * dist


func inward() -> Vector3:
	return global_transform.basis.z


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
	var dot := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.05
	sm.height = 0.1
	dot.mesh = sm
	dot.material_override = mat
	root.add_child(dot)


## A glowing spiral over a portal door — the same on both of the pair, so he
## can tell they belong together.
func _spiral_sign() -> void:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.8, 0.6, 1.0)
	mat.disable_fog = true
	var root := Node3D.new()
	root.name = "Spiral"
	root.position = Vector3(0, _h + 0.45, 0.28)
	add_child(root)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 40
	for i in n:
		var t := float(i) / n
		var a := t * TAU * 2.2
		var r := 0.03 + t * 0.17
		var ball := SphereMesh.new()
		ball.radius = 0.018 + t * 0.012
		ball.height = ball.radius * 2.0
		ball.radial_segments = 6
		ball.rings = 3
		st.append_from(ball, 0, Transform3D(Basis(), Vector3(cos(a) * r, sin(a) * r, 0)))
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	root.add_child(mi)


## Violet runes cut into both faces of a portal door's leaf.
func _portal_runes() -> void:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.7, 0.45, 1.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 51
	for face: float in [-1.0, 1.0]:
		for i in 7:
			var r := MeshInstance3D.new()
			var b := BoxMesh.new()
			b.size = Vector3(rng.randf_range(0.05, 0.16), 0.03, 0.01) if i % 2 == 0 else Vector3(0.03, rng.randf_range(0.08, 0.2), 0.01)
			r.mesh = b
			r.material_override = mat
			r.position = Vector3(rng.randf_range(-0.35, 0.35), 0.55 - i * 0.2, face * 0.065)
			r.rotation.z = rng.randf_range(-0.6, 0.6)
			_leaf.get_child(1).add_child(r)


func _set_leaf(a: float) -> void:
	_leaf_angle = a
	_leaf.transform = Transform3D(Basis(Vector3.UP, a), _hinge) * Transform3D(Basis(), Vector3(_w / 2.0, _h / 2.0 + 0.02, 0))


func prompt() -> String:
	if _busy or is_open or _dead:
		return ""
	match role:
		"portal":
			return "open the door"
		"dud":
			return "open the door"
	return "the light is on the other side" if not armed else ""


func interact(_from: Vector3) -> void:
	if _busy or is_open or _dead:
		return
	match role:
		"portal":
			open_portal()
		"dud":
			_open_dud()


## A portal door swings open onto the swirl, and stays open.
func open_portal(t := 0.8) -> void:
	if is_open or role != "portal":
		return
	is_open = true
	_busy = true
	var tw := create_tween().set_parallel(true)
	tw.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tw.tween_method(_set_leaf, _leaf_angle, 1.75, t).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(_light, "light_energy", 2.2, t)
	tw.chain().tween_callback(func(): _busy = false)
	_area.monitoring = true
	_play("door_open", 0.9, 0.8)
	_play("grind", 0.5, 0.6)


## The dud: bricks behind the paint. The light gutters and dies.
func _open_dud() -> void:
	_busy = true
	_dead = true
	_play("door_open", 0.9, 0.9)
	var tw := create_tween()
	tw.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tw.tween_method(_set_leaf, 0.0, 1.6, 0.6).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func(): _busy = false)
	await get_tree().create_timer(0.12).timeout
	_bricks.visible = true
	_plane.visible = false
	_sill.visible = false
	# the light gutters, and goes out
	for i in 4:
		_light.light_energy = 0.3 if i % 2 == 0 else 1.2
		await get_tree().create_timer(0.08).timeout
	var t2 := create_tween().set_parallel(true)
	t2.tween_property(_light, "light_energy", 0.0, 0.5)
	t2.tween_property(_glow.material_override, "albedo_color:a", 0.0, 0.6)
	_play("thud", 0.8, 0.8)
	fooled.emit()


## The real door: it opens by itself when he comes close with the last key.
func open() -> void:
	if is_open or role != "exit":
		return
	is_open = true
	_play("exit", 1.0)
	var tw := create_tween().set_parallel(true)
	tw.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tw.tween_method(_set_leaf, 0.0, 1.75, 2.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(_light, "light_energy", 5.0, 2.5)
	tw.tween_property(_light, "omni_range", 13.0, 2.5)
	tw.tween_property(_glow, "scale", Vector3.ONE * 2.2, 2.5)
	# white light spilling into the maze
	_spill = SpotLight3D.new()
	_spill.light_color = WHITE
	_spill.light_energy = 0.0
	_spill.spot_range = 18.0
	_spill.spot_angle = 50.0
	_spill.position = Vector3(0, 2.2, -0.2)
	_spill.rotation.x = -0.25
	_spill.rotate_object_local(Vector3.UP, PI)          # face into the maze
	add_child(_spill)
	tw.tween_property(_spill, "light_energy", 6.0, 2.0)
	_area.monitoring = true


func _play(name: String, vol: float, pitch := 1.0) -> void:
	var music := get_node_or_null("/root/Music")
	if music:
		music.sfx(name, vol, pitch)


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_t += delta
	if _light and not is_open and not _dead:
		_light.light_energy = 1.6 + sin(_t * (2.6 if role == "portal" else 1.3)) * (0.35 if role == "portal" else 0.15)
	if role == "portal":
		var sp := get_node_or_null("Spiral") as Node3D
		if sp:
			sp.rotation.z = -_t * 1.2
