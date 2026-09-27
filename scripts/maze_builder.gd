@tool
class_name MazeBuilder
extends Node3D
## Builds the finale labyrinth from the ASCII in a data script
## (levels/level3/level3_data.gd): stone walls and pillars, the floor,
## wooden doors, will-o'-the-wisps, rubble, map pages, the doorway of light,
## and drifting dust in the void above. Runs in the editor too, so you can see
## edits to the ASCII (tick "Rebuild" in the Inspector).
##
## Also answers questions about the maze for the beast's pathfinding.

signal exit_reached
signal wall_shifted(key: String, up: bool)

@export var data_script: Script:
	set(v):
		data_script = v
		if is_inside_tree():
			build()
@export var wall_height := 3.6
@export var wall_thickness := 0.5
@export var door_width := 1.6
@export var door_height := 2.7
@export var rebuild := false:
	set(v):
		if is_inside_tree():
			build()

const CHUNK := 3   # cells per mesh chunk (keeps each chunk lit by few wisps)

var cell_size := 3.5
var rows: PackedStringArray = []
var n := 0                           # cells per side
var doors := {}                      # "x,y" lattice key -> Door node
var shifters := {}                   # "x,y" lattice key -> StaticBody3D (walls that sink / rise)
var ink_walls := {}                  # "x,y" lattice key -> StaticBody3D (walls he has drawn)
var keys := {}                       # "Iron"/"Stone"/"Black" -> key pickup
var light_doors: Array = []          # the real Door of Light first, then the false ones
var exit_door: Node3D
var start_cell := Vector2i.ZERO
var beast_cell := Vector2i.ZERO
var exit_cell := Vector2i.ZERO

var _stone: Material = preload("res://assets/materials/stone_wall.tres")
var _floor: Material = preload("res://assets/materials/floor.tres")
var _wisp_script: Script = preload("res://scripts/wisp_group.gd")
var _door_script: Script = preload("res://scripts/door.gd")
var _page_script: Script = preload("res://scripts/map_page.gd")
var _chunks := {}                    # Vector2i -> {"st": SurfaceTool, "body": StaticBody3D}
var _rng := RandomNumberGenerator.new()
var _page_count := 0
var _fake_count := 0
var _key_script: Script = preload("res://scripts/key_pickup.gd")
var _light_door_script: Script = preload("res://scripts/light_door.gd")
const DOOR_CHARS := ["D", "I", "T", "K", "Q", "B", "d"]
const GATES := {"I": "Iron", "T": "Stone", "K": "Black"}


func _ready() -> void:
	build()


# ================================================================ queries
func cell_center(c: Vector2i, y := 0.0) -> Vector3:
	return Vector3((c.x + 0.5) * cell_size, y, (c.y + 0.5) * cell_size)


func cell_of(p: Vector3) -> Vector2i:
	return Vector2i(clampi(floori(p.x / cell_size), 0, n - 1), clampi(floori(p.z / cell_size), 0, n - 1))


func _edge(a: Vector2i, b: Vector2i) -> Vector2i:
	return Vector2i(a.x + b.x + 1, a.y + b.y + 1)   # lattice coords of the shared edge


## "open", "door" or "wall" between two neighbouring cells.
## `with_ink`: count the walls he has drawn (the journal doesn't — they're his).
func edge_kind(a: Vector2i, b: Vector2i, with_ink := true) -> String:
	if b.x < 0 or b.y < 0 or b.x >= n or b.y >= n:
		return "wall"
	var e := _edge(a, b)
	if with_ink and ink_walls.has("%d,%d" % [e.x, e.y]):
		return "wall"
	var ch := rows[e.y][e.x]
	if ch in DOOR_CHARS:
		return "door"
	if ch == " " or ch == "j":
		return "open"
	return "wall"


func edge_key(a: Vector2i, b: Vector2i) -> String:
	var e := _edge(a, b)
	return "%d,%d" % [e.x, e.y]


func _set_char(x: int, y: int, ch: String) -> void:
	var row := rows[y]
	rows[y] = row.substr(0, x) + ch + row.substr(x + 1)


## Would every cell still be reachable if these lattice edges changed?
func all_connected() -> bool:
	var seen := {Vector2i(0, 0): true}
	var q: Array[Vector2i] = [Vector2i(0, 0)]
	var head := 0
	while head < q.size():
		var c := q[head]
		head += 1
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nb := c + d
			if not seen.has(nb) and nb.x >= 0 and nb.y >= 0 and nb.x < n and nb.y < n and edge_kind(c, nb) != "wall":
				seen[nb] = true
				q.append(nb)
	return seen.size() == n * n


## The cells either side of a lattice edge key.
func edge_cells(key: String) -> Array[Vector2i]:
	var p := key.split(",")
	var x := int(p[0])
	var y := int(p[1])
	if y % 2 == 0:   # horizontal edge between (x-1)/2,(y/2)-1 and (x-1)/2,y/2
		return [Vector2i((x - 1) / 2, y / 2 - 1), Vector2i((x - 1) / 2, y / 2)]
	return [Vector2i(x / 2 - 1, (y - 1) / 2), Vector2i(x / 2, (y - 1) / 2)]


func is_shifter_up(key: String) -> bool:
	var p := key.split(",")
	return rows[int(p[1])][int(p[0])] == "h"


## Sink (up = false) or raise (up = true) a shifting wall. Pathfinding changes
## at once; the stone takes `t` seconds to move.
func shift(key: String, up: bool, t := 2.6) -> void:
	var body: StaticBody3D = shifters.get(key)
	if body == null:
		return
	var p := key.split(",")
	_set_char(int(p[0]), int(p[1]), "h" if up else "j")
	var cs := body.get_child(0) as CollisionShape3D
	if up:
		cs.disabled = false
	var tw := create_tween()
	tw.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tw.tween_property(body, "position:y", 0.0 if up else -wall_height - 0.05, t).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if not up:
		tw.tween_callback(func(): cs.disabled = true)
	wall_shifted.emit(key, up)


## The labyrinth remembers: a door that is simply not there any more — a wall
## stands where it was. (Do it where he can't see.)
func door_to_wall(key: String) -> void:
	var d: Node3D = doors.get(key)
	if d:
		doors.erase(key)
		d.queue_free()
	var body: StaticBody3D = shifters.get(key)
	if body:
		body.position.y = 0.0
		(body.get_child(0) as CollisionShape3D).disabled = false
	var p := key.split(",")
	_set_char(int(p[0]), int(p[1]), "h")


## …and a door where there was only wall.
func wall_to_door(key: String) -> Node3D:
	var p := key.split(",")
	var x := int(p[0])
	var y := int(p[1])
	var body: StaticBody3D = shifters.get(key)
	if body:
		shifters.erase(key)
		body.queue_free()
	var pos := _lattice_pos(x, y)
	var along_x := y % 2 == 0
	var length := cell_size - (wall_thickness + 0.2)
	var jamb := (length - door_width) / 2.0
	var frame := StaticBody3D.new()
	frame.name = "Frame_%d_%d" % [x, y]
	frame.position = pos
	add_child(frame)
	var axis := Vector3(1, 0, 0) if along_x else Vector3(0, 0, 1)
	var parts := []
	for s: float in [-1.0, 1.0]:
		parts.append([axis * s * (door_width / 2.0 + jamb / 2.0) + Vector3(0, wall_height / 2.0, 0),
			Vector3(jamb, wall_height, wall_thickness) if along_x else Vector3(wall_thickness, wall_height, jamb)])
	var lh := wall_height - door_height
	parts.append([Vector3(0, door_height + lh / 2.0, 0),
		Vector3(door_width + 0.02, lh, wall_thickness) if along_x else Vector3(wall_thickness, lh, door_width + 0.02)])
	for pt in parts:
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = pt[1]
		cs.shape = bs
		cs.position = pt[0]
		frame.add_child(cs)
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = pt[1]
		mi.mesh = bm
		mi.position = pt[0]
		mi.material_override = _stone
		frame.add_child(mi)
	var door := Node3D.new()
	door.set_script(_door_script)
	door.name = "Door_%d_%d" % [x, y]
	add_child(door)
	door.setup(pos, along_x, door_width - 0.04, door_height - 0.04, 0.14)
	doors[key] = door
	_set_char(x, y, "D")
	return door


func door_between(a: Vector2i, b: Vector2i) -> Node:
	var e := _edge(a, b)
	return doors.get("%d,%d" % [e.x, e.y])


## Breadth-first path of cells from `from` to `to` (doors count as passable,
## locked ones don't). `forbidden`: cells it may not enter.
func path(from: Vector2i, to: Vector2i, forbidden := {}) -> Array[Vector2i]:
	var prev := {from: from}
	var q: Array[Vector2i] = [from]
	var head := 0
	while head < q.size():
		var c := q[head]
		head += 1
		if c == to:
			break
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nb := c + d
			if prev.has(nb) or forbidden.has(nb):
				continue
			var k := edge_kind(c, nb)
			if k == "wall":
				continue
			if k == "door":
				var dr = door_between(c, nb)
				if dr and dr.locked:
					continue
			prev[nb] = c
			q.append(nb)
	var out: Array[Vector2i] = []
	if not prev.has(to):
		return out
	var c := to
	while c != from:
		out.push_front(c)
		c = prev[c]
	return out


# ================================================================ build
func build() -> void:
	if data_script == null:
		return
	for c in get_children():
		remove_child(c)
		c.queue_free()   # (free() mid-edit could crash the editor)
	doors.clear()
	keys.clear()
	light_doors.clear()
	exit_door = null
	_fake_count = 0
	shifters.clear()
	ink_walls.clear()
	_chunks.clear()
	_page_count = 0
	_rng.seed = 1923
	var consts := data_script.get_script_constant_map()
	cell_size = consts.get("CELL", 3.5)
	rows = PackedStringArray(consts["MAZE"])
	n = (rows.size() - 1) / 2
	var size := n * cell_size

	for y in rows.size():
		for x in rows[y].length():
			var ch := rows[y][x]
			var ex := x % 2 == 0
			var ey := y % 2 == 0
			if ex and ey:
				_pillar(x, y)
			elif ex != ey:
				match ch:
					"#":
						_wall_segment(x, y)
					"D", "Q", "B":
						_doorway(x, y, true)
						if ch == "B":
							doors["%d,%d" % [x, y]].make_gate("bar")
							doors["%d,%d" % [x, y]].locked = true
							doors["%d,%d" % [x, y]].lock_name = "bar"
					"I", "T", "K":
						_doorway(x, y, true)
						var gate = doors["%d,%d" % [x, y]]
						gate.make_gate(GATES[ch])
						gate.locked = true
						gate.lock_name = GATES[ch]
					"d":
						_doorway(x, y, true)
						_shifting_wall(x, y, false)
					"e":
						_shifting_wall(x, y, true)
					"X":
						_light_doorway(x, y, false)
					"F":
						_light_doorway(x, y, true)
					"h":
						_shifting_wall(x, y, true)
					"j":
						_shifting_wall(x, y, false)
			else:
				var c := Vector2i(x / 2, y / 2)
				match ch:
					"S":
						start_cell = c
					"M":
						beast_cell = c
					"w":
						_wisps(c)
					"p":
						_page(c)
					"r":
						_rubble(c)
					"1", "2", "3":
						_key(c, ["Iron", "Stone", "Black"][int(ch) - 1])
	_floor_and_void(size)
	_commit_chunks()
	_link_portals()
	_decorate()


func _chunk_for(p: Vector3) -> Dictionary:
	var k := Vector2i(floori(p.x / (cell_size * CHUNK)), floori(p.z / (cell_size * CHUNK)))
	if not _chunks.has(k):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var body := StaticBody3D.new()
		body.name = "Walls_%d_%d" % [k.x, k.y]
		add_child(body)
		_chunks[k] = {"st": st, "body": body, "count": 0}
	return _chunks[k]


## One solid stone block: added to its chunk's mesh and collision.
func _block(center: Vector3, size: Vector3) -> void:
	var ch := _chunk_for(center)
	var box := BoxMesh.new()
	box.size = size
	(ch.st as SurfaceTool).append_from(box, 0, Transform3D(Basis(), center))
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	shape.shape = bs
	shape.position = center
	(ch.body as StaticBody3D).add_child(shape)
	ch.count += 1


func _commit_chunks() -> void:
	for k in _chunks:
		var ch: Dictionary = _chunks[k]
		var st: SurfaceTool = ch.st   # BoxMesh already carries flat normals + tangents
		var mi := MeshInstance3D.new()
		mi.mesh = st.commit()
		mi.material_override = _stone
		(ch.body as StaticBody3D).add_child(mi)


func _lattice_pos(x: int, y: int) -> Vector3:
	return Vector3(x * 0.5 * cell_size, 0.0, y * 0.5 * cell_size)


func _pillar(x: int, y: int) -> void:
	var p := _lattice_pos(x, y)
	var h := wall_height + 0.25 + _rng.randf_range(-0.1, 0.2)
	var t := wall_thickness + 0.2
	_block(p + Vector3(0, h / 2.0, 0), Vector3(t, h, t))
	# a capstone
	_block(p + Vector3(0, h + 0.08, 0), Vector3(t + 0.12, 0.16, t + 0.12))


## A wall between two pillars. Tops are ragged: a few courses missing here and there.
func _wall_segment(x: int, y: int) -> void:
	var p := _lattice_pos(x, y)
	var along_x := y % 2 == 0          # horizontal edge
	var length := cell_size - (wall_thickness + 0.2)
	var pieces := 1 if _rng.randf() < 0.6 else 3
	for i in pieces:
		var seg_len := length / pieces
		var offset := -length / 2.0 + seg_len * (i + 0.5)
		var h := wall_height + _rng.randf_range(-0.15, 0.1)
		if pieces == 3 and i == 1 and _rng.randf() < 0.7:
			h -= _rng.randf_range(0.3, 0.8)   # a gap where stones have fallen
		var c := p + (Vector3(offset, h / 2.0, 0) if along_x else Vector3(0, h / 2.0, offset))
		var s := Vector3(seg_len, h, wall_thickness) if along_x else Vector3(wall_thickness, h, seg_len)
		_block(c, s)


## A wall that can sink into the floor or rise out of it: its own body, not
## merged into the chunk meshes.
func _shifting_wall(x: int, y: int, up: bool) -> void:
	var p := _lattice_pos(x, y)
	var along_x := y % 2 == 0
	var length := cell_size - (wall_thickness + 0.2) + 0.02
	var size := Vector3(length, wall_height, wall_thickness) if along_x else Vector3(wall_thickness, wall_height, length)
	var body := StaticBody3D.new()
	body.name = "Shift_%d_%d" % [x, y]
	body.position = Vector3(p.x, 0.0 if up else -wall_height - 0.05, p.z)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	cs.position.y = wall_height / 2.0
	cs.disabled = not up
	body.add_child(cs)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position.y = wall_height / 2.0
	mi.material_override = _stone
	body.add_child(mi)
	var audio := AudioStreamPlayer3D.new()
	audio.name = "Audio"
	audio.unit_size = 6.0
	audio.max_distance = 45.0
	audio.position.y = 1.5
	body.add_child(audio)
	add_child(body)
	shifters["%d,%d" % [x, y]] = body


## Draw a wall of ink across the edge between cells a and b. It's real for
## `life` seconds, then it runs and drains away.
func ink_wall(a: Vector2i, b: Vector2i, life := 12.0) -> void:
	var e := _edge(a, b)
	var key := "%d,%d" % [e.x, e.y]
	if ink_walls.has(key):
		return
	var p := _lattice_pos(e.x, e.y)
	var along_x := e.y % 2 == 0
	var length := cell_size - (wall_thickness + 0.2) + 0.04
	var size := Vector3(length, wall_height - 0.2, 0.3) if along_x else Vector3(0.3, wall_height - 0.2, length)
	var body := StaticBody3D.new()
	body.name = "Ink_%s" % key.replace(",", "_")
	body.position = p
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	cs.position.y = size.y / 2.0
	body.add_child(cs)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position.y = size.y / 2.0
	# wet black ink poured over the shape of stone: glossy, with the bricks
	# showing through as ripples
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.02, 0.02, 0.035)
	mat.roughness = 0.12
	mat.normal_enabled = true
	mat.normal_texture = preload("res://assets/textures/stone_bricks_normal.png")
	mat.normal_scale = 0.6
	mat.uv1_triplanar = true
	mat.uv1_world_triplanar = true
	mat.uv1_scale = Vector3(0.5, 0.5, 0.5)
	mat.rim_enabled = true
	mat.rim = 0.6
	mat.rim_tint = 0.0
	mat.emission_enabled = true
	mat.emission = Color(0.06, 0.08, 0.2)
	mat.emission_energy_multiplier = 0.08
	mi.material_override = mat
	body.add_child(mi)
	add_child(body)
	ink_walls[key] = body
	mi.scale = Vector3(1, 0.01, 1)
	mi.position.y = 0.0
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(mi, "scale:y", 1.0, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(mi, "position:y", size.y / 2.0, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.set_parallel(false)
	tw.tween_interval(life)
	tw.tween_callback(func(): ink_walls.erase(key); cs.disabled = true)
	tw.tween_property(mi, "scale:y", 0.01, 0.9).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(mi, "position:y", 0.0, 0.9).set_ease(Tween.EASE_IN)
	tw.tween_callback(body.queue_free)


## A wall with an opening: a wooden door, or (outer wall) the doorway of light.
func _doorway(x: int, y: int, with_door: bool) -> void:
	var p := _lattice_pos(x, y)
	var along_x := y % 2 == 0
	var length := cell_size - (wall_thickness + 0.2)
	var jamb := (length - door_width) / 2.0
	var h := wall_height
	var axis := Vector3(1, 0, 0) if along_x else Vector3(0, 0, 1)
	for s: float in [-1.0, 1.0]:
		var c := p + axis * s * (door_width / 2.0 + jamb / 2.0) + Vector3(0, h / 2.0, 0)
		_block(c, (Vector3(jamb, h, wall_thickness) if along_x else Vector3(wall_thickness, h, jamb)))
	var lintel_h := h - door_height
	var lc := p + Vector3(0, door_height + lintel_h / 2.0, 0)
	_block(lc, (Vector3(door_width + 0.02, lintel_h, wall_thickness) if along_x else Vector3(wall_thickness, lintel_h, door_width + 0.02)))
	if with_door:
		var door := Node3D.new()
		door.set_script(_door_script)
		door.name = "Door_%d_%d" % [x, y]
		add_child(door)
		door.setup(p, along_x, door_width - 0.04, door_height - 0.04, 0.14)
		doors["%d,%d" % [x, y]] = door
	else:
		_exit_light(p, along_x)


## A doorway of light in the outer wall: the real one ("X") or a false one ("F").
func _light_doorway(x: int, y: int, fake: bool) -> void:
	var p := _lattice_pos(x, y)
	var along_x := y % 2 == 0
	var length := cell_size - (wall_thickness + 0.2)
	var jamb := (length - door_width) / 2.0
	var h := wall_height
	var axis := Vector3(1, 0, 0) if along_x else Vector3(0, 0, 1)
	for s: float in [-1.0, 1.0]:
		var c := p + axis * s * (door_width / 2.0 + jamb / 2.0) + Vector3(0, h / 2.0, 0)
		_block(c, (Vector3(jamb, h, wall_thickness) if along_x else Vector3(wall_thickness, h, jamb)))
	var lintel_h := h - door_height
	_block(p + Vector3(0, door_height + lintel_h / 2.0, 0), (Vector3(door_width + 0.02, lintel_h, wall_thickness) if along_x else Vector3(wall_thickness, lintel_h, door_width + 0.02)))
	var outward: Vector3
	if along_x:
		outward = Vector3(0, 0, -1) if p.z < 1.0 else Vector3(0, 0, 1)
	else:
		outward = Vector3(-1, 0, 0) if p.x < 1.0 else Vector3(1, 0, 0)
	var ld := Node3D.new()
	ld.set_script(_light_door_script)
	ld.name = ("FalseDoor_%d" % _fake_count) if fake else "DoorOfLight"
	ld.fake = fake
	ld.variant = _fake_count
	# the false doors, in the order they appear in the data: the first two are
	# a joined pair of portals, the third is a dud painted to look like the exit
	ld.role = "exit" if not fake else ("dud" if _fake_count == 2 else "portal")
	add_child(ld)
	ld.setup(p, outward, door_width, door_height)
	if fake:
		_fake_count += 1
		light_doors.append(ld)
	else:
		exit_door = ld
		light_doors.push_front(ld)
		exit_cell = cell_of(p - outward * 1.0)
		ld.entered.connect(func(): exit_reached.emit())


## Join the portal doors in pairs: each lets out of the other.
func _link_portals() -> void:
	var ps: Array = light_doors.filter(func(d): return d.role == "portal")
	for i in range(0, ps.size() - 1, 2):
		ps[i].partner = ps[i + 1]
		ps[i + 1].partner = ps[i]


func _key(c: Vector2i, key_name: String) -> void:
	var k := Node3D.new()
	k.set_script(_key_script)
	k.name = key_name + "Key"
	k.key_name = key_name
	k.position = cell_center(c)
	add_child(k)
	keys[key_name] = k


func _exit_light(p: Vector3, along_x: bool) -> void:
	var outward := Vector3(0, 0, -1) if along_x and p.z < 1.0 else (Vector3(0, 0, 1) if along_x else (Vector3(-1, 0, 0) if p.x < 1.0 else Vector3(1, 0, 0)))
	var root := Node3D.new()
	root.name = "DoorwayOfLight"
	add_child(root)
	root.position = p
	# the light itself: a blinding plane just beyond the threshold
	var quad := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(door_width + 0.4, door_height + 0.3)
	quad.mesh = qm
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.98, 0.93)
	mat.disable_fog = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	quad.material_override = mat
	quad.position = outward * (wall_thickness * 0.5 + 0.05) + Vector3(0, door_height / 2.0, 0)
	if not along_x:
		quad.rotation.y = PI / 2.0
	root.add_child(quad)
	# its glow on the corridor
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.97, 0.9)
	light.light_energy = 3.0
	light.omni_range = 9.0
	light.position = -outward * 1.2 + Vector3(0, 1.6, 0)
	root.add_child(light)
	# a halo sprite so it reads through the fog
	var halo := MeshInstance3D.new()
	var hq := QuadMesh.new()
	hq.size = Vector2(5.0, 5.0)
	halo.mesh = hq
	halo.material_override = preload("res://assets/materials/wisp.tres")
	halo.position = Vector3(0, door_height / 2.0, 0) - outward * 0.2
	root.add_child(halo)
	# stop the player walking out into nothing
	var stop := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(door_width + 1, wall_height, 0.4) if along_x else Vector3(0.4, wall_height, door_width + 1)
	cs.shape = bs
	cs.position = outward * (wall_thickness * 0.5 + 0.3) + Vector3(0, wall_height / 2.0, 0)
	stop.add_child(cs)
	root.add_child(stop)
	# stepping into the doorway ends the dream
	var area := Area3D.new()
	var acs := CollisionShape3D.new()
	var abox := BoxShape3D.new()
	abox.size = Vector3(door_width, 2.4, 0.8) if along_x else Vector3(0.8, 2.4, door_width)
	acs.shape = abox
	acs.position = Vector3(0, 1.2, 0)
	area.add_child(acs)
	root.add_child(area)
	area.body_entered.connect(_on_exit_body)
	exit_cell = cell_of(p - outward * 1.0)


func _on_exit_body(b: Node) -> void:
	if b.is_in_group("player"):
		exit_reached.emit()


func _wisps(c: Vector2i) -> void:
	var g := Node3D.new()
	g.set_script(_wisp_script)
	g.name = "Wisps_%d_%d" % [c.x, c.y]
	g.position = cell_center(c, 2.3) + Vector3(_rng.randf_range(-0.6, 0.6), 0, _rng.randf_range(-0.6, 0.6))
	add_child(g)


func _page(c: Vector2i) -> void:
	var pg := Node3D.new()
	pg.set_script(_page_script)
	pg.name = "Page_%d_%d" % [c.x, c.y]
	add_child(pg)
	pg.position = cell_center(c) + Vector3(_rng.randf_range(-0.8, 0.8), 0.01, _rng.randf_range(-0.8, 0.8))
	pg.index = _page_count
	_page_count += 1


## A few fallen stones heaped against a wall (no collision; they're low).
func _rubble(c: Vector2i) -> void:
	var base := cell_center(c)
	var side := Vector3([-1.0, 1.0][_rng.randi() % 2] * (cell_size * 0.5 - wall_thickness), 0, _rng.randf_range(-1.0, 1.0))
	if _rng.randf() < 0.5:
		side = Vector3(side.z, 0, side.x)
	var mi := MeshInstance3D.new()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 7:
		var box := BoxMesh.new()
		box.size = Vector3(_rng.randf_range(0.25, 0.5), _rng.randf_range(0.14, 0.26), _rng.randf_range(0.2, 0.4))
		var b := Basis(Vector3.UP, _rng.randf() * TAU).rotated(Vector3.RIGHT, _rng.randf_range(-0.3, 0.3))
		var pos := side * 0.9 + Vector3(_rng.randf_range(-0.5, 0.5), box.size.y * 0.4 + (0.18 if i > 4 else 0.0), _rng.randf_range(-0.5, 0.5))
		st.append_from(box, 0, Transform3D(b, pos))
	mi.mesh = st.commit()
	mi.material_override = _stone
	mi.position = base
	add_child(mi)


func _floor_and_void(size: float) -> void:
	var fl := StaticBody3D.new()
	fl.name = "Floor"
	add_child(fl)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(size + 2, 0.4, size + 2)
	cs.shape = bs
	cs.position = Vector3(size / 2.0, -0.2, size / 2.0)
	fl.add_child(cs)
	# the floor mesh in chunks too, so wisp light stays local
	var chunks := ceili(float(n) / CHUNK)
	for j in chunks:
		for i in chunks:
			var w := minf(CHUNK, n - i * CHUNK) * cell_size
			var d := minf(CHUNK, n - j * CHUNK) * cell_size
			var pm := PlaneMesh.new()
			pm.size = Vector2(w, d)
			var mi := MeshInstance3D.new()
			mi.mesh = pm
			mi.material_override = _floor
			mi.position = Vector3(i * CHUNK * cell_size + w / 2.0, 0.0, j * CHUNK * cell_size + d / 2.0)
			fl.add_child(mi)
	# dust drifting in the void above the walls
	var dust := CPUParticles3D.new()
	dust.name = "Dust"
	dust.amount = 180
	dust.lifetime = 14.0
	dust.preprocess = 14.0
	dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	dust.emission_box_extents = Vector3(size / 2.0 + 6, 2.5, size / 2.0 + 6)
	dust.position = Vector3(size / 2.0, wall_height + 3.0, size / 2.0)
	dust.direction = Vector3(1, 0.1, 0.3)
	dust.spread = 180.0
	dust.gravity = Vector3.ZERO
	dust.initial_velocity_min = 0.05
	dust.initial_velocity_max = 0.25
	dust.scale_amount_min = 0.6
	dust.scale_amount_max = 2.0
	var dq := QuadMesh.new()
	dq.size = Vector2(0.5, 0.5)
	var dm := StandardMaterial3D.new()
	dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	dm.albedo_texture = preload("res://assets/textures/smoke.png")
	dm.albedo_color = Color(0.5, 0.52, 0.56, 0.05)
	dq.material = dm
	dust.mesh = dq
	add_child(dust)


# ================================================================ dressing
## Cobwebs in the corners, the bones of those who didn't find the way out,
## rusted chains hanging from the walls, and a few spiders. Placed with their
## own random numbers so the walls themselves never change.
var _deco_rng := RandomNumberGenerator.new()
static var _web_tex: ImageTexture
var _web_mat: StandardMaterial3D
var _bone_mat: StandardMaterial3D
var _socket_mat: StandardMaterial3D
var _iron_mat: StandardMaterial3D


func _decorate() -> void:
	_deco_rng.seed = 4242
	_web_mat = StandardMaterial3D.new()
	_web_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_web_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_web_mat.albedo_texture = _web_texture()
	_web_mat.albedo_color = Color(0.9, 0.9, 0.94, 0.95)
	_web_mat.roughness = 1.0
	_web_mat.emission_enabled = true
	_web_mat.emission = Color(0.5, 0.52, 0.58)
	_web_mat.emission_energy_multiplier = 0.15
	_web_mat.emission_texture = _web_mat.albedo_texture
	_bone_mat = StandardMaterial3D.new()
	_bone_mat.albedo_color = Color(0.7, 0.66, 0.56)
	_bone_mat.roughness = 0.85
	_socket_mat = StandardMaterial3D.new()
	_socket_mat.albedo_color = Color(0.02, 0.015, 0.012)
	_socket_mat.roughness = 1.0
	_iron_mat = StandardMaterial3D.new()
	_iron_mat.albedo_color = Color(0.16, 0.12, 0.1)
	_iron_mat.metallic = 0.6
	_iron_mat.roughness = 0.7
	_corner_webs()
	_bones_everywhere()
	_hanging_chains()


func _ch(x: int, y: int) -> String:
	if y < 0 or y >= rows.size() or x < 0 or x >= rows[y].length():
		return ""
	return rows[y][x]


# ---------------------------------------------------------------- cobwebs
## A web hung in the upper corner where two walls meet (and a few low ones by
## the floor), sometimes with its spider.
func _corner_webs() -> void:
	var spots: Array = []
	for y in range(0, rows.size(), 2):
		for x in range(0, rows[y].length(), 2):
			for sx: int in [-1, 1]:
				for sz: int in [-1, 1]:
					if _ch(x + sx, y) == "#" and _ch(x, y + sz) == "#" and _ch(x + sx, y + sz) != "":
						spots.append([x, y, sx, sz])
	var high := 0
	var low := 0
	var spiders := 0
	for sp in spots:
		var r := _deco_rng.randf()
		if r < 0.2 and high < 48:
			high += 1
			var web := _web(sp[0], sp[1], sp[2], sp[3], _deco_rng.randf_range(0.9, 1.5), _deco_rng.randf_range(1.0, 1.6), false)
			if spiders < 9 and _deco_rng.randf() < 0.25:
				spiders += 1
				_spider(web)
		elif r < 0.27 and low < 16:
			low += 1
			_web(sp[0], sp[1], sp[2], sp[3], _deco_rng.randf_range(0.5, 0.8), _deco_rng.randf_range(0.45, 0.7), true)


func _web(x: int, y: int, sx: int, sz: int, reach: float, h: float, by_floor: bool) -> MeshInstance3D:
	var corner := _lattice_pos(x, y) + Vector3(sx * 0.26, 0, sz * 0.26)
	var a := corner + Vector3(sx * reach, 0, 0)
	var b := corner + Vector3(0, 0, sz * reach)
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(a.distance_to(b), h)
	mi.mesh = q
	mi.material_override = _web_mat
	var top := wall_height - _deco_rng.randf_range(0.08, 0.35)
	var mid := (a + b) * 0.5
	mi.position = Vector3(mid.x, (h / 2.0 + 0.01) if by_floor else (top - h / 2.0), mid.z)
	var n := Vector3(sx, 0, sz).normalized()
	mi.basis = Basis.looking_at(n, Vector3.UP)
	if by_floor:
		mi.rotate_object_local(Vector3.FORWARD, PI)     # anchored along the floor, apex up
	add_child(mi)
	return mi


## A spider web texture: a triangle hung by its top edge, apex down — radial
## threads from a hub, a sagging spiral, a few broken strands.
func _web_texture() -> ImageTexture:
	if _web_tex:
		return _web_tex
	var s := 256
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 1, 1, 0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var hub := Vector2(128, 78)
	var anchors: Array[Vector2] = []
	var nr := 15
	for i in nr:
		# spread round the triangle: top edge, then down both sides to the apex
		var t := float(i) / (nr - 1)
		var p: Vector2
		if t < 0.5:
			var u := t / 0.5
			p = Vector2(4, 4).lerp(Vector2(252, 4), u) if i % 2 == 0 else Vector2(4, 4).lerp(Vector2(128, 250), u)
		else:
			var u := (t - 0.5) / 0.5
			p = Vector2(252, 4).lerp(Vector2(128, 250), u) if i % 2 == 0 else Vector2(4, 4).lerp(Vector2(252, 4), u)
		anchors.append(p)
	anchors.sort_custom(func(p1, p2): return (p1 - hub).angle() < (p2 - hub).angle())
	for p in anchors:
		_thread(img, hub, p, 1.0)
	for k in range(1, 12):
		var f := k / 12.0
		for i in anchors.size():
			if rng.randf() < 0.08:
				continue                                 # a broken strand
			var p1: Vector2 = hub.lerp(anchors[i], f * rng.randf_range(0.95, 1.05))
			var p2: Vector2 = hub.lerp(anchors[(i + 1) % anchors.size()], f * rng.randf_range(0.95, 1.05))
			if p1.distance_to(p2) > 120.0:
				continue
			var m := (p1 + p2) * 0.5
			m = m.lerp(hub, 0.06)                        # a little sag toward the hub
			_thread(img, p1, m, 0.8)
			_thread(img, m, p2, 0.8)
	img.generate_mipmaps()
	_web_tex = ImageTexture.create_from_image(img)
	return _web_tex


func _thread(img: Image, a: Vector2, b: Vector2, alpha: float) -> void:
	var steps := int(a.distance_to(b) * 1.5) + 1
	var sz := img.get_width()
	for i in steps + 1:
		var p := a.lerp(b, float(i) / steps)
		for o: Vector2i in [Vector2i.ZERO, Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1), Vector2i(1, 1)]:
			var x := int(p.x) + o.x
			var y := int(p.y) + o.y
			if x < 0 or y < 0 or x >= sz or y >= sz:
				continue
			var al := alpha * (1.0 if o == Vector2i.ZERO else (0.8 if o.x + o.y >= 0 and o != Vector2i(1, 1) else 0.45))
			var c := img.get_pixel(x, y)
			img.set_pixel(x, y, Color(1, 1, 1, maxf(c.a, al)))


## A fat black spider on its web. Now and then it creeps a little way and stops.
func _spider(web: MeshInstance3D) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var body := SphereMesh.new()
	body.radius = 0.045
	body.height = 0.09
	st.append_from(body, 0, Transform3D(Basis().scaled(Vector3(1.0, 1.25, 0.7)), Vector3(0, -0.05, 0)))
	var head := SphereMesh.new()
	head.radius = 0.025
	head.height = 0.05
	st.append_from(head, 0, Transform3D(Basis(), Vector3(0, 0.02, 0)))
	for side: float in [-1.0, 1.0]:
		for i in 4:
			var leg := CylinderMesh.new()
			leg.top_radius = 0.004
			leg.bottom_radius = 0.004
			leg.height = 0.13
			var bas := Basis(Vector3.FORWARD, -side * PI / 2.0 + (i - 1.5) * 0.35 * side)
			st.append_from(leg, 0, Transform3D(bas, Vector3(side * 0.06, 0.01 - i * 0.02, 0.01)))
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.03, 0.025, 0.02)
	m.roughness = 0.5
	mi.material_override = m
	var q: QuadMesh = web.mesh
	var home := Vector3(_deco_rng.randf_range(-0.15, 0.15) * q.size.x, _deco_rng.randf_range(0.0, 0.3) * q.size.y, 0.01)
	mi.position = home
	web.add_child(mi)
	if Engine.is_editor_hint():
		return
	var tw := mi.create_tween().set_loops()
	for k in 3:
		var to := home + Vector3(_deco_rng.randf_range(-0.12, 0.12), _deco_rng.randf_range(-0.18, 0.1), 0)
		tw.tween_interval(_deco_rng.randf_range(2.0, 6.0))
		tw.tween_property(mi, "position", to, _deco_rng.randf_range(0.4, 1.2)).set_trans(Tween.TRANS_SINE)
	tw.tween_interval(_deco_rng.randf_range(2.0, 5.0))
	tw.tween_property(mi, "position", home, 1.0).set_trans(Tween.TRANS_SINE)


# ---------------------------------------------------------------- bones
## The ones who came before: slumped skeletons, heaps of bones, lone skulls.
func _bones_everywhere() -> void:
	var skip := ["S", "1", "2", "3", "p"]
	for cy in n:
		for cx in n:
			if _ch(cx * 2 + 1, cy * 2 + 1) in skip:
				continue
			if _deco_rng.randf() > 0.24:
				continue
			var c := Vector2i(cx, cy)
			var walls: Array[Vector3] = []
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if _ch(cx * 2 + 1 + d.x, cy * 2 + 1 + d.y) == "#":
					walls.append(Vector3(d.x, 0, d.y))
			var bone := SurfaceTool.new()
			bone.begin(Mesh.PRIMITIVE_TRIANGLES)
			var dark := SurfaceTool.new()
			dark.begin(Mesh.PRIMITIVE_TRIANGLES)
			var r := _deco_rng.randf()
			var center := cell_center(c)
			if walls.is_empty():
				_scattered(bone, dark, center)
			else:
				var w: Vector3 = walls[_deco_rng.randi() % walls.size()]
				var along := Vector3(-w.z, 0, w.x) * _deco_rng.randf_range(-0.9, 0.9)
				var base := center + w * (cell_size * 0.5 - 0.62) + along
				if r < 0.38:
					_skeleton(bone, dark, base, w)
				elif r < 0.72:
					_bone_pile(bone, dark, base + w * 0.12)
				elif r < 0.86:
					_skull(bone, dark, Transform3D(Basis(Vector3.UP, _deco_rng.randf() * TAU).rotated(Vector3.RIGHT, _deco_rng.randf_range(-0.3, 0.3)), base + w * 0.2 + Vector3(0, 0.09, 0)))
				else:
					_scattered(bone, dark, center)
			for pair in [[bone, _bone_mat], [dark, _socket_mat]]:
				var mi := MeshInstance3D.new()
				mi.mesh = (pair[0] as SurfaceTool).commit()
				mi.material_override = pair[1]
				add_child(mi)


func _long_bone(st: SurfaceTool, a: Vector3, b: Vector3, r := 0.02) -> void:
	var d := b - a
	var cap := CapsuleMesh.new()
	cap.radius = r
	cap.height = d.length() + r * 2.0
	cap.radial_segments = 6
	cap.rings = 2
	st.append_from(cap, 0, Transform3D(Basis(Quaternion(Vector3.UP, d.normalized())), (a + b) * 0.5))
	var knob := SphereMesh.new()
	knob.radius = r * 1.7
	knob.height = r * 3.4
	knob.radial_segments = 6
	knob.rings = 3
	st.append_from(knob, 0, Transform3D(Basis(), a))
	st.append_from(knob, 0, Transform3D(Basis(), b))


func _skull(st: SurfaceTool, dark: SurfaceTool, xf: Transform3D) -> void:
	var cr := SphereMesh.new()
	cr.radius = 0.1
	cr.height = 0.2
	cr.radial_segments = 10
	cr.rings = 6
	st.append_from(cr, 0, xf * Transform3D(Basis().scaled(Vector3(0.85, 0.9, 1.1)), Vector3(0, 0.02, 0.01)))
	var face := BoxMesh.new()
	face.size = Vector3(0.12, 0.08, 0.08)
	st.append_from(face, 0, xf * Transform3D(Basis(), Vector3(0, -0.04, -0.07)))
	var jaw := BoxMesh.new()
	jaw.size = Vector3(0.1, 0.03, 0.08)
	st.append_from(jaw, 0, xf * Transform3D(Basis(Vector3.RIGHT, 0.25), Vector3(0, -0.09, -0.07)))
	var eye := SphereMesh.new()
	eye.radius = 0.024
	eye.height = 0.048
	eye.radial_segments = 6
	eye.rings = 3
	for s: float in [-1.0, 1.0]:
		dark.append_from(eye, 0, xf * Transform3D(Basis(), Vector3(s * 0.035, -0.0, -0.1)))
	var nose := SphereMesh.new()
	nose.radius = 0.012
	nose.height = 0.03
	dark.append_from(nose, 0, xf * Transform3D(Basis(), Vector3(0, -0.04, -0.112)))


## Sat against the wall where he died, legs out, head fallen forward.
func _skeleton(st: SurfaceTool, dark: SurfaceTool, base: Vector3, wall: Vector3) -> void:
	var fwd := -wall
	var right := Vector3.UP.cross(fwd).normalized()
	var fr := Basis(right, Vector3.UP, fwd)
	base += wall * 0.18
	var P := func(x: float, y: float, z: float) -> Vector3: return base + fr * Vector3(x, y, z)
	var pelvis := SphereMesh.new()
	pelvis.radius = 0.1
	pelvis.height = 0.2
	st.append_from(pelvis, 0, Transform3D(fr.scaled(Vector3(1.4, 0.6, 0.9)), P.call(0, 0.09, 0.05)))
	# spine up to the wall, leaning back
	var neck: Vector3 = P.call(0, 0.62, -0.1)
	var hip: Vector3 = P.call(0, 0.12, 0.02)
	var vert := SphereMesh.new()
	vert.radius = 0.025
	vert.height = 0.05
	vert.radial_segments = 6
	vert.rings = 3
	for i in 9:
		st.append_from(vert, 0, Transform3D(Basis(), hip.lerp(neck, i / 8.0)))
	# ribs
	for i in 5:
		var at: Vector3 = hip.lerp(neck, 0.45 + i * 0.1)
		for s: float in [-1.0, 1.0]:
			var p1 := at + fr * Vector3(s * 0.1, -0.02, 0.05)
			var p2 := at + fr * Vector3(s * 0.12, -0.05, 0.14)
			var p3 := at + fr * Vector3(s * 0.04, -0.07, 0.19)
			_long_bone(st, at, p1, 0.009)
			_long_bone(st, p1, p2, 0.009)
			_long_bone(st, p2, p3, 0.009)
	# skull, fallen forward onto the chest
	var tilt := _deco_rng.randf_range(0.4, 0.8)
	var turn := _deco_rng.randf_range(-0.5, 0.5)
	var sk := Basis.looking_at(fwd, Vector3.UP)
	var skb := Basis(Vector3.UP, turn) * Basis(Vector3.RIGHT, -tilt)
	_skull(st, dark, Transform3D(sk * skb, neck + Vector3(0, 0.1, 0) + fwd * 0.06))
	# arms hanging to the floor
	for s: float in [-1.0, 1.0]:
		var sh: Vector3 = P.call(s * 0.17, 0.56, -0.07)
		var el: Vector3 = P.call(s * 0.24, 0.3, 0.02)
		var wr: Vector3 = P.call(s * (0.28 + _deco_rng.randf() * 0.1), 0.03, 0.14 + _deco_rng.randf() * 0.1)
		_long_bone(st, sh, el, 0.017)
		_long_bone(st, el, wr, 0.014)
	# legs out along the floor
	for s: float in [-1.0, 1.0]:
		var hp: Vector3 = P.call(s * 0.1, 0.07, 0.08)
		var kn: Vector3 = P.call(s * (0.18 + _deco_rng.randf() * 0.1), 0.05 + _deco_rng.randf() * 0.15, 0.48)
		var an: Vector3 = P.call(s * (0.22 + _deco_rng.randf() * 0.15), 0.03, 0.85)
		_long_bone(st, hp, kn, 0.022)
		_long_bone(st, kn, an, 0.018)


func _bone_pile(st: SurfaceTool, dark: SurfaceTool, base: Vector3) -> void:
	for i in _deco_rng.randi_range(8, 14):
		var a := _deco_rng.randf() * TAU
		var l := _deco_rng.randf_range(0.25, 0.45)
		var mid := base + Vector3(_deco_rng.randf_range(-0.3, 0.3), 0.03 + floorf(i / 4.0) * 0.035, _deco_rng.randf_range(-0.3, 0.3))
		var d := Vector3(cos(a), _deco_rng.randf_range(-0.15, 0.15), sin(a)) * l * 0.5
		_long_bone(st, mid - d, mid + d, _deco_rng.randf_range(0.014, 0.022))
	_skull(st, dark, Transform3D(Basis(Vector3.UP, _deco_rng.randf() * TAU).rotated(Vector3.FORWARD, _deco_rng.randf_range(-0.4, 0.4)), base + Vector3(0, 0.2, 0)))


func _scattered(st: SurfaceTool, dark: SurfaceTool, center: Vector3) -> void:
	for i in _deco_rng.randi_range(3, 5):
		var a := _deco_rng.randf() * TAU
		var mid := center + Vector3(_deco_rng.randf_range(-1.0, 1.0), 0.025, _deco_rng.randf_range(-1.0, 1.0))
		var d := Vector3(cos(a), 0.02, sin(a)) * _deco_rng.randf_range(0.12, 0.22)
		_long_bone(st, mid - d, mid + d, 0.017)
	if _deco_rng.randf() < 0.6:
		_skull(st, dark, Transform3D(Basis(Vector3.UP, _deco_rng.randf() * TAU).rotated(Vector3.FORWARD, _deco_rng.randf_range(-1.4, 1.4)), center + Vector3(_deco_rng.randf_range(-0.9, 0.9), 0.08, _deco_rng.randf_range(-0.9, 0.9))))


# ---------------------------------------------------------------- chains
## Rusted chains hanging from the tops of walls, a manacle at the end. They sway.
func _hanging_chains() -> void:
	var count := 0
	for y in rows.size():
		for x in rows[y].length():
			if (x % 2 == 0) == (y % 2 == 0) or _ch(x, y) != "#":
				continue
			if count >= 16 or _deco_rng.randf() > 0.07:
				continue
			var along_x := y % 2 == 0
			var s: float = [-1.0, 1.0][_deco_rng.randi() % 2]
			var nrm := Vector3(0, 0, s) if along_x else Vector3(s, 0, 0)
			var cell_side := _ch(x + int(nrm.x), y + int(nrm.z))
			if cell_side == "":
				continue
			var off: float = _deco_rng.randf_range(0.6, 1.1) * [-1.0, 1.0][_deco_rng.randi() % 2]
			var p := _lattice_pos(x, y) + nrm * (wall_thickness * 0.5 + 0.05) + (Vector3(off, 0, 0) if along_x else Vector3(0, 0, off))
			p.y = wall_height - 0.3
			_chain(p, _deco_rng.randi_range(14, 26), along_x)
			count += 1


func _chain(top: Vector3, links: int, along_x: bool) -> void:
	var pivot := Node3D.new()
	pivot.position = top
	add_child(pivot)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var link := TorusMesh.new()
	link.inner_radius = 0.016
	link.outer_radius = 0.036
	link.rings = 8
	link.ring_segments = 5
	for i in links:
		var b := Basis(Vector3.RIGHT, PI / 2.0).scaled(Vector3(1.0, 1.6, 1.0))
		if i % 2 == 1:
			b = Basis(Vector3.UP, PI / 2.0) * b
		st.append_from(link, 0, Transform3D(b, Vector3(0, -i * 0.075, 0)))
	var cuff := TorusMesh.new()
	cuff.inner_radius = 0.05
	cuff.outer_radius = 0.075
	st.append_from(cuff, 0, Transform3D(Basis(Vector3.RIGHT, PI / 2.0), Vector3(0, -links * 0.075 - 0.06, 0)))
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = _iron_mat
	pivot.add_child(mi)
	if Engine.is_editor_hint():
		return
	var ax := "rotation:x" if along_x else "rotation:z"
	var amp := _deco_rng.randf_range(0.02, 0.05)
	var per := _deco_rng.randf_range(2.5, 4.5)
	var tw := pivot.create_tween().set_loops()
	tw.tween_property(pivot, ax, amp, per).set_trans(Tween.TRANS_SINE)
	tw.tween_property(pivot, ax, -amp, per).set_trans(Tween.TRANS_SINE)
