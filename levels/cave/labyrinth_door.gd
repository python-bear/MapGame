@tool
extends Node3D
## The way on: a doorway of cut stone set into the raw rock at the end of the
## cave — the labyrinth's own grey bricks — with an old oak door, and pale
## light leaking round its edges. The sign over it is the one he will see
## again over the Door of Light.
##
## E / Space opens it; the light floods out; walking into it ends the level.

signal entered

var is_open := false
var _w := 1.7
var _h := 2.7
var _leaf: AnimatableBody3D
var _hinge := Vector3.ZERO
var _inner: OmniLight3D
var _outer: OmniLight3D
var _glow: MeshInstance3D
var _back: StandardMaterial3D
var _area: Area3D
var _t := 0.0

const PALE := Color(0.86, 0.9, 1.0)


## `at`: centre of the doorway on the floor, on the face of the rock.
## The door faces +Z (south, back into the cave).
func setup(at: Vector3, size: Vector2) -> void:
	position = at
	_w = size.x
	_h = size.y
	var stone: Material = preload("res://assets/materials/stone_wall.tres")
	# the dressed stone front, wider than the passage so its edges sink into the rock
	var total_w := 6.4
	var top := 4.8
	var side_w := (total_w - _w) / 2.0
	for s: float in [-1.0, 1.0]:
		_slab(Vector3(s * (_w / 2.0 + side_w / 2.0), top / 2.0 - 0.3, 0.12), Vector3(side_w, top, 0.6), stone)
	_slab(Vector3(0, _h + (top - 0.3 - _h) / 2.0, 0.12), Vector3(_w + 0.02, top - 0.3 - _h, 0.6), stone)
	# a worn threshold and a floor of flags into the light
	_slab(Vector3(0, -0.12, -1.27), Vector3(_w + 0.3, 0.3, 2.36), preload("res://assets/materials/floor.tres"), false)
	# the light behind the door
	_back = StandardMaterial3D.new()
	_back.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_back.albedo_color = Color(1.25, 1.3, 1.45)
	_back.disable_fog = true
	var back := MeshInstance3D.new()
	var bq := QuadMesh.new()
	bq.size = Vector2(_w + 0.9, _h + 0.6)
	back.mesh = bq
	back.material_override = _back
	back.position = Vector3(0, _h / 2.0, -2.2)
	add_child(back)
	_inner = OmniLight3D.new()
	_inner.light_color = PALE
	_inner.light_energy = 2.2
	_inner.omni_range = 3.2
	_inner.position = Vector3(0, 1.4, -1.3)
	add_child(_inner)
	# the pale light that shows where the door is from down the passage
	_outer = OmniLight3D.new()
	_outer.light_color = PALE
	_outer.light_energy = 0.45
	_outer.omni_range = 7.0
	_outer.omni_attenuation = 1.3
	_outer.position = Vector3(0, 1.6, 1.1)
	add_child(_outer)
	_glow = MeshInstance3D.new()
	var gq := QuadMesh.new()
	gq.size = Vector2(3.4, 3.4)
	_glow.mesh = gq
	var gm: StandardMaterial3D = preload("res://assets/materials/wisp.tres").duplicate()
	gm.albedo_color = Color(PALE, 0.28)
	_glow.material_override = gm
	_glow.position = Vector3(0, _h / 2.0, 0.5)
	add_child(_glow)
	_sign()
	# the door: oak, iron-strapped, hung on the left, opening inwards
	_hinge = Vector3(-_w / 2.0 + 0.02, 0, -0.08)
	_leaf = AnimatableBody3D.new()
	_leaf.sync_to_physics = true
	_leaf.set_meta("interact_target", self)
	add_child(_leaf)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(_w - 0.08, _h - 0.06, 0.14)
	cs.shape = bs
	_leaf.add_child(cs)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = bs.size
	mi.mesh = bm
	mi.material_override = preload("res://assets/materials/door_wood.tres")
	_leaf.add_child(mi)
	_set_leaf(0.0)
	# nothing beyond the light
	var stop := StaticBody3D.new()
	var scs := CollisionShape3D.new()
	var sbs := BoxShape3D.new()
	sbs.size = Vector3(_w + 1.0, 3.6, 0.4)
	scs.shape = sbs
	scs.position = Vector3(0, 1.8, -2.45)
	stop.add_child(scs)
	add_child(stop)
	_area = Area3D.new()
	var acs := CollisionShape3D.new()
	var ab := BoxShape3D.new()
	ab.size = Vector3(_w, 2.4, 0.6)
	acs.shape = ab
	acs.position = Vector3(0, 1.2, -0.9)
	_area.add_child(acs)
	_area.monitoring = false
	add_child(_area)
	_area.body_entered.connect(func(b): if b.is_in_group("player"): entered.emit())


func _slab(p: Vector3, s: Vector3, mat: Material, collide := true) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = s
	mi.mesh = bm
	mi.material_override = mat
	mi.position = p
	add_child(mi)
	if collide:
		var body := StaticBody3D.new()
		body.position = p
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = s
		cs.shape = bs
		body.add_child(cs)
		add_child(body)


## The ring with the eye in it, cut over the door and filled with light.
func _sign() -> void:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = PALE
	mat.disable_fog = true
	var root := Node3D.new()
	root.position = Vector3(0, _h + 0.55, 0.43)
	add_child(root)
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.15
	tm.outer_radius = 0.2
	ring.mesh = tm
	ring.rotation.x = PI / 2.0
	ring.material_override = mat
	root.add_child(ring)
	var dot := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.06
	sm.height = 0.12
	dot.mesh = sm
	dot.material_override = mat
	root.add_child(dot)


func _set_leaf(a: float) -> void:
	_leaf.transform = Transform3D(Basis(Vector3.UP, a), _hinge) * Transform3D(Basis(), Vector3((_w - 0.08) / 2.0 + 0.02, _h / 2.0, 0))


func prompt() -> String:
	return "" if is_open else "open the door"


func interact(_from: Vector3) -> void:
	open()


func open() -> void:
	if is_open:
		return
	is_open = true
	var music := get_node_or_null("/root/Music")
	if music:
		music.sfx("door_open", 1.0, 0.8)
		music.sfx("creak", 0.7, 0.85)
	var tw := create_tween().set_parallel(true)
	tw.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tw.tween_method(_set_leaf, 0.0, 1.7, 2.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(_outer, "light_energy", 1.6, 2.0)
	tw.tween_property(_outer, "omni_range", 12.0, 2.0)
	tw.tween_property(_inner, "light_energy", 4.0, 2.0)
	tw.tween_property(_glow, "scale", Vector3.ONE * 1.8, 2.2)
	tw.tween_property(_glow.material_override, "albedo_color:a", 0.6, 2.2)
	_area.monitoring = true


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_t += delta
	if not is_open:
		_outer.light_energy = 0.45 + sin(_t * 1.1) * 0.06
