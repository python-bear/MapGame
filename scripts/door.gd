@tool
extends Node3D
## A thick wooden door on iron hinges. Interact (E / Space) to swing it open
## away from you, or shut it again. The beast smashes closed doors open.
## The leaf is an AnimatableBody3D, so walls, door and player all collide.

signal opened
signal closed
signal rattled             ## tried while locked

## Locks. `lock_name` "Iron" / "Stone" / "Black" needs that key in his hand
## (asked of the level via has_key()); "bar" opens only from the `bar_side` (a point on the
## side the bar is on); "shut" won't open at all until unlocked by the level.
var locked := false
var lock_name := ""
var bar_side := Vector3.INF

@export var open_angle := deg_to_rad(100.0)
@export var swing_time := 0.8

var is_open := false
## Current swing (radians). Drives the leaf's own transform so the physics
## body really moves (a moving parent wouldn't update an AnimatableBody3D).
var angle := 0.0:
	set(v):
		angle = v
		if _leaf:
			_leaf.transform = Transform3D(Basis(Vector3.UP, v), _hinge_pos) * Transform3D(Basis(), _leaf_offset)
var _hinge_pos := Vector3.ZERO
var _leaf_offset := Vector3.ZERO
var _leaf: AnimatableBody3D
var _busy := false
var _width := 1.56
var _audio: AudioStreamPlayer3D


## Called by the maze builder. `along_x`: the doorway spans the X axis.
func setup(center: Vector3, along_x: bool, width: float, height: float, thickness: float) -> void:
	_width = width
	position = center
	rotation.y = 0.0 if along_x else PI / 2.0
	_hinge_pos = Vector3(-width / 2.0, 0, 0)
	_leaf_offset = Vector3(width / 2.0, height / 2.0 + 0.02, 0)
	_leaf = AnimatableBody3D.new()
	_leaf.name = "Leaf"
	_leaf.sync_to_physics = true
	_leaf.set_meta("interact_target", self)
	add_child(_leaf)
	angle = 0.0
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(width, height, thickness)
	cs.shape = bs
	_leaf.add_child(cs)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = bs.size
	mi.mesh = bm
	mi.material_override = preload("res://assets/materials/door_wood.tres")
	_leaf.add_child(mi)
	# iron ring handles on both faces, and the hinge straps' knuckles
	var iron := StandardMaterial3D.new()
	iron.albedo_color = Color(0.12, 0.11, 0.11)
	iron.metallic = 0.6
	iron.roughness = 0.5
	for s in [-1.0, 1.0]:
		var ring := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 0.05
		tm.outer_radius = 0.075
		ring.mesh = tm
		ring.material_override = iron
		ring.rotation.x = PI / 2.0
		ring.position = Vector3(width / 2.0 - 0.18, -0.05, s * (thickness / 2.0 + 0.02))
		_leaf.add_child(ring)
	for hy in [-height * 0.28, height * 0.28]:
		var knuckle := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.045
		cm.bottom_radius = 0.045
		cm.height = 0.22
		knuckle.mesh = cm
		knuckle.material_override = iron
		knuckle.position = Vector3(-width / 2.0, hy, 0)
		_leaf.add_child(knuckle)
	_audio = AudioStreamPlayer3D.new()
	_audio.unit_size = 5.0
	_audio.max_distance = 30.0
	_audio.position = Vector3(0, 1.5, 0)
	add_child(_audio)


func prompt() -> String:
	if locked:
		match lock_name:
			"bar":
				return "lift the bar" if _on_bar_side(_player_pos()) else "it's barred from the other side"
			"shut":
				return "it won't open"
			_:
				if _has_key():
					return "unlock it with the %s Key" % lock_name
				var lv := get_tree().get_first_node_in_group("level3")
				if lv != null and lv.has_method("holds_key") and lv.holds_key(lock_name):
					return "locked — take out the %s Key (%d)" % [lock_name, lv.key_slot(lock_name)]
				return "locked — it wants a %s key" % lock_name.to_lower()
	return "close the door" if is_open else "open the door"


func _player_pos() -> Vector3:
	var p := get_tree().get_first_node_in_group("player") as Node3D
	return p.global_position if p else Vector3.ZERO


func _on_bar_side(from: Vector3) -> bool:
	return bar_side != Vector3.INF and Vector2(from.x - bar_side.x, from.z - bar_side.z).length() < \
		Vector2(from.x - (2.0 * global_position.x - bar_side.x), from.z - (2.0 * global_position.z - bar_side.z)).length()


func _has_key() -> bool:
	var lv := get_tree().get_first_node_in_group("level3")
	return lv != null and lv.has_key(lock_name)


## Level-driven locks (the silent room).
func lock_shut() -> void:
	if is_open:
		_swing(0.0, 0.35, "door_close")
		is_open = false
		closed.emit()
	locked = true
	lock_name = "shut"


func unlock() -> void:
	locked = false


## Left a crack open, as if someone had just gone through.
func set_ajar(a := 0.3) -> void:
	if is_open:
		return
	_play("creak")
	var tw := create_tween()
	tw.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tw.tween_property(self, "angle", a, 2.0).set_trans(Tween.TRANS_SINE)


## Iron bands and a lock plate, for the three gates.
func make_gate(kind: String) -> void:
	var iron := StandardMaterial3D.new()
	iron.albedo_color = Color(0.1, 0.1, 0.1)
	iron.metallic = 0.7
	iron.roughness = 0.45
	var plate := StandardMaterial3D.new()
	plate.albedo_color = {"Iron": Color(0.45, 0.45, 0.48), "Stone": Color(0.62, 0.6, 0.55), "Black": Color(0.02, 0.02, 0.02), "bar": Color(0.3, 0.2, 0.12)}.get(kind, Color(0.3, 0.3, 0.3))
	plate.metallic = 0.3
	plate.roughness = 0.5
	if kind == "Black":
		plate.emission_enabled = true
		plate.emission = Color(0.3, 0.0, 0.0)
		plate.emission_energy_multiplier = 0.4
	var h := 2.66
	for y: float in ([-0.8, 0.0, 0.8] if kind != "bar" else [0.1]):
		var band := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(_width, 0.1 if kind != "bar" else 0.16, 0.2)
		band.mesh = bm
		band.material_override = iron if kind != "bar" else plate
		band.position = Vector3(_width / 2.0, y, 0)
		_leaf.add_child(band)
	if kind != "bar":
		for s: float in [-1.0, 1.0]:
			var lp := MeshInstance3D.new()
			var pm := BoxMesh.new()
			pm.size = Vector3(0.28, 0.36, 0.04)
			lp.mesh = pm
			lp.material_override = plate
			lp.position = Vector3(_width - 0.3, 0.05, s * 0.1)
			_leaf.add_child(lp)


## Can something walk through right now?
func is_passable() -> bool:
	return absf(angle) > 1.0


func interact(from: Vector3) -> void:
	if _busy:
		return
	if locked:
		var can := false
		match lock_name:
			"bar":
				can = _on_bar_side(from)
			"shut":
				can = false
			_:
				can = _has_key()
		if not can:
			_play("lock")
			rattled.emit()
			return
		locked = false
		_play("unlock")
		await get_tree().create_timer(0.5).timeout
	if is_open:
		# don't slam it on someone standing in the doorway
		for p in get_tree().get_nodes_in_group("player"):
			var local := to_local(p.global_position)
			if absf(local.z) < 0.6 and absf(local.x) < _width * 0.7:
				return
		_swing(0.0, swing_time, "door_close")
		is_open = false
		closed.emit()
	else:
		_open_away_from(from, swing_time, "door_open")


## The beast doesn't bother with handles.
func bash(from: Vector3) -> void:
	if is_open and is_passable():
		return
	_busy = false
	_open_away_from(from, 0.22, "door_bash")


func _open_away_from(from: Vector3, t: float, sound: String) -> void:
	var side := signf(to_local(from).z)
	if side == 0.0:
		side = 1.0
	_swing(open_angle * side, t, sound)
	is_open = true
	opened.emit()


func _swing(to_angle: float, t: float, sound: String) -> void:
	_busy = true
	_play(sound)
	var tw := create_tween()
	tw.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tw.tween_property(self, "angle", to_angle, t).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT if sound != "door_close" else Tween.EASE_IN)
	tw.tween_callback(func(): _busy = false)


func _play(name: String) -> void:
	var path := "res://assets/sfx/%s.ogg" % name
	if not ResourceLoader.exists(path):
		return
	_audio.stream = load(path)
	var music := get_node_or_null("/root/Music")   # (tool script: no autoload names)
	var vol: float = music.sfx_volume if music else 1.0
	_audio.volume_db = linear_to_db(maxf(vol, 0.0001))
	_audio.pitch_scale = randf_range(0.92, 1.05)
	_audio.play()
