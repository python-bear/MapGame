@tool
extends Node3D
## A few will-o'-the-wisps hanging in the air together, drifting slowly,
## sharing one pale light.

@export var count := 3
@export var radius := 0.7
@export var light_range := 7.5
@export var light_energy := 1.6

var _wisps: Array[MeshInstance3D] = []
var _params := []
var _light: OmniLight3D
var _t := 0.0
var _home := Vector3.ZERO

## Guides (the Stone Key's puzzle). An honest group leads somewhere and waits
## for you; a lying one drifts off without looking back, flickering, and goes
## out when you catch up with it at the dead end.
var guide_path: Array = []          ## world positions, in order
var honest := false
var guiding := false
var follower: Node3D
var _gi := 0
var _dead := false
var _fade := 1.0


func _ready() -> void:
	_home = position
	_t = randf() * 100.0
	count = 3 + (hash(name) % 2)
	var mat: Material = preload("res://assets/materials/wisp.tres")
	for i in count:
		var mi := MeshInstance3D.new()
		var q := QuadMesh.new()
		var s := randf_range(0.35, 0.55)
		q.size = Vector2(s, s)
		mi.mesh = q
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		# a hot little core
		var core := MeshInstance3D.new()
		var cq := QuadMesh.new()
		cq.size = Vector2(s, s) * 0.35
		core.mesh = cq
		core.material_override = mat
		mi.add_child(core)
		_wisps.append(mi)
		_params.append({
			"r": randf_range(0.25, radius), "w": randf_range(0.25, 0.6) * (1 if randf() < 0.5 else -1),
			"a": randf() * TAU, "b": randf_range(0.1, 0.3), "bw": randf_range(0.6, 1.3),
		})
	_light = OmniLight3D.new()
	_light.light_color = Color(0.86, 0.9, 1.0)
	_light.light_energy = light_energy
	_light.omni_range = light_range
	_light.omni_attenuation = 1.3
	_light.shadow_enabled = false
	add_child(_light)


## Turned off by the level when far from the player (fog hides it anyway),
## so only a handful of lights are ever live at once.
func set_lit(on: bool) -> void:
	if _light:
		_light.visible = on


func light_node() -> OmniLight3D:
	return _light


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_t += delta
	if guiding and not guide_path.is_empty():
		_guide(delta)
	var wander := 0.5 if not guiding else (0.12 if honest else 0.35)
	# the whole group wanders a little around where it was placed
	position = _home + Vector3(sin(_t * 0.21) * wander, sin(_t * 0.37) * 0.15, cos(_t * 0.17) * wander)
	if guiding and not honest:
		position += Vector3(sin(_t * 13.0), sin(_t * 17.0) * 0.5, cos(_t * 11.0)) * 0.06   # a nervous jitter
	for i in _wisps.size():
		var p: Dictionary = _params[i]
		# the honest group turns slowly, all together
		var w: float = 0.35 if (guiding and honest) else p.w
		var a: float = p.a + _t * w
		_wisps[i].position = Vector3(cos(a) * p.r, sin(_t * p.bw + p.a) * p.b, sin(a) * p.r)
		_wisps[i].scale = Vector3.ONE * _fade
	var flicker := 0.9 + 0.1 * sin(_t * 7.3) * sin(_t * 3.1)
	if guiding and not honest:
		flicker = 0.55 + 0.45 * absf(sin(_t * 9.1) * sin(_t * 5.3 + 1.0))
	elif guiding and honest:
		flicker = 1.0
	_light.light_energy = light_energy * flicker * _fade


func start_guiding(who: Node3D) -> void:
	follower = who
	guiding = true
	_gi = 0


func _guide(delta: float) -> void:
	if _dead:
		_fade = move_toward(_fade, 0.0, delta * 1.2)
		if _fade <= 0.0:
			visible = false
		return
	var target: Vector3 = guide_path[_gi]
	var flat := Vector2(target.x - _home.x, target.z - _home.z)
	var near_player := follower != null and Vector2(follower.global_position.x - _home.x, follower.global_position.z - _home.z).length() < 5.0
	var sp := 2.0 if honest else 1.5
	if honest and not near_player and _gi > 0:
		sp = 0.0            # it waits for you
	if flat.length() > 0.05:
		var step := minf(sp * delta, flat.length())
		var d := flat.normalized() * step
		_home += Vector3(d.x, 0, d.y)
	elif _gi < guide_path.size() - 1:
		_gi += 1
	elif not honest and follower and Vector2(follower.global_position.x - _home.x, follower.global_position.z - _home.z).length() < 3.2:
		_dead = true       # a dead end — and the light goes out


## The final chase: every light in the labyrinth goes out.
func extinguish(t := 2.0) -> void:
	var tw := create_tween()
	tw.tween_property(self, "_fade", 0.0, t)
	tw.tween_callback(func(): visible = false)
