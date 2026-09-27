@tool
extends Node3D
## One of the three keys, hanging in the air above the floor, turning slowly.
## Look at it and interact (E / Space) to take it.

signal taken(key: Node3D)

@export var key_name := "Iron"      ## "Iron", "Stone" or "Black"

var _t := 0.0
var _root: Node3D
var _light: OmniLight3D
var _body: StaticBody3D
var gone := false


func _ready() -> void:
	_root = Node3D.new()
	_root.position.y = 1.05
	add_child(_root)
	var col: Color = {"Iron": Color(0.42, 0.42, 0.45), "Stone": Color(0.62, 0.6, 0.55), "Black": Color(0.03, 0.03, 0.035)}[key_name]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.metallic = 0.7 if key_name != "Stone" else 0.0
	mat.roughness = 0.35 if key_name != "Stone" else 0.9
	mat.emission_enabled = true
	mat.emission = {"Iron": Color(0.25, 0.3, 0.4), "Stone": Color(0.45, 0.45, 0.4), "Black": Color(0.35, 0.02, 0.02)}[key_name]
	mat.emission_energy_multiplier = 0.35
	# the bow (a ring), the shaft, the bit
	var bow := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.06
	tm.outer_radius = 0.1
	bow.mesh = tm
	bow.rotation.x = PI / 2.0
	bow.position = Vector3(-0.2, 0, 0)
	bow.material_override = mat
	_root.add_child(bow)
	var shaft := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.018
	cm.bottom_radius = 0.018
	cm.height = 0.34
	shaft.mesh = cm
	shaft.rotation.z = PI / 2.0
	shaft.position = Vector3(0.05, 0, 0)
	shaft.material_override = mat
	_root.add_child(shaft)
	for i in 2:
		var bit := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.04, 0.09 - i * 0.03, 0.02)
		bit.mesh = bm
		bit.position = Vector3(0.18 + i * 0.05, -0.05 + i * 0.015, 0)
		bit.material_override = mat
		_root.add_child(bit)
	# a faint glow so it can be found in the dark
	var halo := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.9, 0.9)
	halo.mesh = q
	var hm: StandardMaterial3D = preload("res://assets/materials/wisp.tres").duplicate()
	hm.albedo_color = Color(0.9, 0.3, 0.2, 0.5) if key_name == "Black" else Color(0.85, 0.9, 1.0, 0.45)
	halo.material_override = hm
	_root.add_child(halo)
	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.25, 0.15) if key_name == "Black" else Color(0.8, 0.85, 1.0)
	_light.light_energy = 0.7
	_light.omni_range = 3.2
	_root.add_child(_light)
	_body = StaticBody3D.new()
	_body.collision_layer = 2          # the look-ray sees it; feet don't
	_body.collision_mask = 0
	_body.set_meta("interact_target", self)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(0.8, 0.8, 0.8)
	cs.shape = bs
	cs.position.y = 1.05
	_body.add_child(cs)
	add_child(_body)


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_t += delta
	if _root:
		_root.rotation.y = _t * 0.9
		_root.position.y = 1.05 + sin(_t * 1.7) * 0.05


## The light it gives off (the silent room puts it out).
func set_glow(on: bool) -> void:
	if _light:
		_light.visible = on


func prompt() -> String:
	return "" if gone else "take the %s Key" % key_name


func interact(_from: Vector3) -> void:
	if gone:
		return
	gone = true
	var music := get_node_or_null("/root/Music")
	if music:
		music.sfx("key", 1.0)
	_body.queue_free()
	var tw := create_tween()
	tw.tween_property(_root, "scale", Vector3.ONE * 0.01, 0.35).set_ease(Tween.EASE_IN)
	tw.tween_callback(func(): _root.visible = false)
	taken.emit(self)
