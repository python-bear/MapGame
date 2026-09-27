@tool
extends Node3D
## A torn page lying on the floor. Look at it and interact to read it.

const TEXTS := [
	"A page from your own journal — but the hand is not yours:\n\n“The light is to the north. It always was.”",
	"A scrap of map. The corridors drawn on it do not match these ones.\nAs you watch, one of the ink lines moves.",
	"Your handwriting, shaking badly:\n\n“Do not let it see you stop.”",
]

signal was_read(page: Node)

var index := 0
var read := false


func _ready() -> void:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(0.32, 0.42)
	mi.mesh = pm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.86, 0.8, 0.64)
	mat.emission_enabled = true
	mat.emission = Color(0.35, 0.32, 0.25)
	mat.roughness = 1.0
	mi.material_override = mat
	mi.rotation.y = randf() * TAU
	mi.position.y = 0.012
	add_child(mi)
	var body := StaticBody3D.new()
	body.collision_layer = 2          # the look-ray sees it; feet don't
	body.collision_mask = 0
	body.set_meta("interact_target", self)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(0.6, 0.3, 0.6)
	cs.shape = bs
	cs.position.y = 0.15
	body.add_child(cs)
	add_child(body)


func prompt() -> String:
	return "read the page"


func interact(_from: Vector3) -> void:
	if not read:
		read = true
		was_read.emit(self)
	var music := get_node_or_null("/root/Music")   # (tool script: no autoload names)
	if music:
		music.sfx("page", 0.9)
	for o in get_tree().get_nodes_in_group("fps_overlay"):
		o.show_page(TEXTS[index % TEXTS.size()])
