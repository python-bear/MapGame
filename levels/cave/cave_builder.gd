@tool
extends Node3D
## Builds the cave from what tools/gen_cave.py made: the rock (one mesh per
## 16 m tile, with trimesh collision), the paintings on the walls, the pile of
## bones, the daylight at the mouth and the door to the labyrinth.
## Runs in the editor too, so the level can be seen there.

const Data := preload("res://levels/cave/cave_data.gd")

@export var rebuild := false:
	set(v):
		if is_inside_tree():
			build()

var rock_material: ShaderMaterial = preload("res://assets/materials/cave_rock.tres")
var paintings := {}          ## tex name -> MeshInstance3D
var door: Node3D
var daylight: MeshInstance3D
var daylight_lamp: OmniLight3D
var mouth_wall: StaticBody3D


func _ready() -> void:
	build()


func build() -> void:
	for c in get_children():
		c.free()
	paintings.clear()
	_rock()
	for p: Dictionary in Data.PAINTINGS:
		_painting(p)
	_bones(Data.BONES)
	_mouth()
	door = Node3D.new()
	door.set_script(preload("res://levels/cave/labyrinth_door.gd"))
	door.name = "LabyrinthDoor"
	add_child(door)
	door.setup(Data.DOOR, Data.DOOR_SIZE)


# ================================================================ rock
func _rock() -> void:
	for path: String in Data.CHUNKS:
		var mesh := load(path) as Mesh
		if mesh == null:
			push_warning("cave: missing %s (run tools/gen_cave.py)" % path)
			continue
		var body := StaticBody3D.new()
		body.name = path.get_file().get_basename()
		add_child(body)
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = rock_material
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		body.add_child(mi)
		if not Engine.is_editor_hint():
			var cs := CollisionShape3D.new()
			cs.shape = mesh.create_trimesh_shape()
			body.add_child(cs)


# ================================================================ paintings
func _painting(p: Dictionary) -> void:
	var mi := MeshInstance3D.new()
	mi.name = "Painting_" + p.tex
	var q := QuadMesh.new()
	q.size = p.size
	mi.mesh = q
	var n: Vector3 = p.normal
	mi.position = p.pos
	mi.basis = Basis.looking_at(-n, Vector3.UP)      # the quad's front (+Z) faces into the cave
	mi.material_override = painting_material(p.tex, p.size)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	paintings[p.tex] = mi


func painting_material(tex: String, size: Vector2) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/cave_painting.gdshader")
	m.set_shader_parameter("paint", load("res://levels/cave/paintings/%s.png" % tex))
	m.set_shader_parameter("rock_albedo", rock_material.get_shader_parameter("rock_albedo"))
	m.set_shader_parameter("rock_normal", rock_material.get_shader_parameter("rock_normal"))
	m.set_shader_parameter("size", size)
	return m


## Swap what a painting shows (the arms move when he isn't looking).
func repaint(tex: String, to: String) -> void:
	var mi: MeshInstance3D = paintings.get(tex)
	if mi:
		(mi.material_override as ShaderMaterial).set_shader_parameter("paint", load("res://levels/cave/paintings/%s.png" % to))


func set_glow(tex: String, g: float) -> void:
	var mi: MeshInstance3D = paintings.get(tex)
	if mi:
		(mi.material_override as ShaderMaterial).set_shader_parameter("glow", g)


# ================================================================ the bones
## A heap of old bones against the wall, a few skulls on top.
func _bones(at: Vector3) -> void:
	var root := StaticBody3D.new()
	root.name = "Bones"
	root.position = at
	add_child(root)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var bone := StandardMaterial3D.new()
	bone.albedo_color = Color(0.56, 0.5, 0.4)
	bone.roughness = 0.9
	var old := bone.duplicate() as StandardMaterial3D
	old.albedo_color = Color(0.38, 0.32, 0.24)
	for i in 70:
		var mi := MeshInstance3D.new()
		var cm := CapsuleMesh.new()
		cm.radius = rng.randf_range(0.025, 0.05)
		cm.height = rng.randf_range(0.25, 0.6)
		cm.radial_segments = 8
		cm.rings = 2
		mi.mesh = cm
		var r := sqrt(rng.randf()) * 1.1
		var a := rng.randf() * TAU
		var y := maxf(0.03, (1.0 - r / 1.1) * 0.5 + rng.randf_range(-0.05, 0.08))
		mi.position = Vector3(cos(a) * r, y, sin(a) * r)
		mi.rotation = Vector3(rng.randf_range(1.1, 2.0), rng.randf() * TAU, rng.randf_range(-0.4, 0.4))
		mi.material_override = bone if i % 3 else old
		root.add_child(mi)
		# knobbly ends on the long bones
		if cm.height > 0.42:
			for s: float in [-1.0, 1.0]:
				var k := MeshInstance3D.new()
				var sm := SphereMesh.new()
				sm.radius = cm.radius * 1.5
				sm.height = sm.radius * 2.0
				sm.radial_segments = 8
				sm.rings = 4
				k.mesh = sm
				k.position = Vector3(0, s * cm.height * 0.45, 0)
				k.material_override = mi.material_override
				mi.add_child(k)
	# ribs
	for i in 7:
		var rib := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 0.17
		tm.outer_radius = 0.2
		tm.rings = 12
		tm.ring_segments = 6
		rib.mesh = tm
		rib.scale = Vector3(1.0, 1.0, 0.55)
		rib.position = Vector3(0.35 + i * 0.07, 0.22, -0.3 + rng.randf_range(-0.03, 0.03))
		rib.rotation = Vector3(0, 0, PI / 2 + rng.randf_range(-0.15, 0.15))
		rib.material_override = old
		root.add_child(rib)
	for s in 4:
		var skull := _skull(bone if s % 2 else old)
		var a := s * 1.7 + 0.4
		var r := 0.25 + s * 0.18
		skull.position = Vector3(cos(a) * r, (1.0 - r / 1.1) * 0.5 + 0.12, sin(a) * r)
		skull.rotation = Vector3(rng.randf_range(-0.3, 0.3), rng.randf() * TAU, rng.randf_range(-0.4, 0.4))
		root.add_child(skull)
	# don't walk through it
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 1.0
	cyl.height = 0.6
	cs.shape = cyl
	cs.position.y = 0.3
	root.add_child(cs)


func _skull(mat: Material) -> Node3D:
	var s := Node3D.new()
	var cr := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.11
	sm.height = 0.22
	cr.mesh = sm
	cr.scale = Vector3(0.9, 0.9, 1.15)
	cr.material_override = mat
	s.add_child(cr)
	var face := MeshInstance3D.new()
	var fm := BoxMesh.new()
	fm.size = Vector3(0.13, 0.1, 0.08)
	face.mesh = fm
	face.position = Vector3(0, -0.05, -0.09)
	face.material_override = mat
	s.add_child(face)
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.03, 0.02, 0.02)
	for x: float in [-0.04, 0.04]:
		var eye := MeshInstance3D.new()
		var em := SphereMesh.new()
		em.radius = 0.03
		em.height = 0.05
		eye.mesh = em
		eye.position = Vector3(x, -0.01, -0.125)
		eye.material_override = dark
		s.add_child(eye)
	var nose := MeshInstance3D.new()
	var nm := SphereMesh.new()
	nm.radius = 0.015
	nm.height = 0.04
	nose.mesh = nm
	nose.position = Vector3(0, -0.06, -0.13)
	nose.material_override = dark
	s.add_child(nose)
	return s


# ================================================================ the mouth
## Daylight at the mouth (and an invisible wall: the dream doesn't let him out).
func _mouth() -> void:
	var m: Vector3 = Data.MOUTH
	daylight = MeshInstance3D.new()
	daylight.name = "Daylight"
	var q := QuadMesh.new()
	q.size = Vector2(9, 7)
	daylight.mesh = q
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.6, 1.5, 1.3)
	mat.disable_fog = true
	daylight.material_override = mat
	daylight.position = m + Vector3(0, 2.2, 0)
	daylight.basis = Basis.looking_at(Vector3(0, 0, 1), Vector3.UP)   # faces into the cave (-Z)
	add_child(daylight)
	daylight_lamp = OmniLight3D.new()
	daylight_lamp.light_color = Color(1.0, 0.93, 0.8)
	daylight_lamp.light_energy = 2.2
	daylight_lamp.omni_range = 16.0
	daylight_lamp.omni_attenuation = 1.4
	daylight_lamp.position = m + Vector3(0, 2.4, -1.6)
	add_child(daylight_lamp)
	mouth_wall = StaticBody3D.new()
	mouth_wall.name = "MouthWall"
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = Vector3(10, 8, 0.6)
	cs.shape = b
	mouth_wall.position = m + Vector3(0, 3, -0.7)
	mouth_wall.add_child(cs)
	add_child(mouth_wall)
