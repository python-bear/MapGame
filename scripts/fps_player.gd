extends CharacterBody3D
## First-person player for the finale. No body, no model — just eyes.
## WASD / left stick to walk, mouse / right stick to look,
## E or Space to open doors and read pages.

signal prompt_changed(text: String)

@export var speed := 5.0
@export var accel := 30.0
@export var mouse_sensitivity := 0.0022
@export var pad_sensitivity := 2.6
@export var pan_sensitivity := 0.02       ## two-finger trackpad drag
@export var key_turn_speed := 2.4         ## radians/s for the , and . keys
@export var reach := 2.6
## Shift / left stick click: run. Loud, and it doesn't last.
@export var run_speed := 7.8
@export var stamina_max := 6.0
## How far (m, as sound travels through the maze) he can be heard.
const NOISE_WALK := 4.0
const NOISE_RUN := 20.0

var stamina := 6.0
var running := false
var _rest := 0.0

var frozen := false
var speed_mult := 1.0

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera

var _pitch := 0.0
var _bob := 0.0
var _step_timer := 0.0
var _focus: Object
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)


func _ready() -> void:
	add_to_group("player")


## Looking is read in _input (before any UI can swallow it), so mice,
## trackpads and tablets all work.
func _input(event: InputEvent) -> void:
	if frozen or get_tree().paused:
		return
	if event is InputEventMouseMotion:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			_look(event.screen_relative * mouse_sensitivity)
	elif event is InputEventPanGesture:
		# two-finger drag on a trackpad also looks around
		_look(event.delta * pan_sensitivity)
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if frozen:
		return
	if event.is_action_pressed("interact") and _focus != null:
		get_viewport().set_input_as_handled()
		_focus.interact(global_position)


func _look(d: Vector2) -> void:
	rotate_y(-d.x)
	_pitch = clampf(_pitch - d.y, deg_to_rad(-85), deg_to_rad(85))
	head.rotation.x = _pitch


## How far away he can be heard right now (0 = silent).
func noise_radius() -> float:
	var v := Vector2(velocity.x, velocity.z).length()
	if v < 0.4:
		return 0.0
	return NOISE_RUN if running else NOISE_WALK


## Turn to face something (used when the beast gets you).
func face(target: Vector3, t := 0.25) -> void:
	var flat := Vector3(target.x, global_position.y, target.z)
	var yaw := atan2(-(flat - global_position).x, -(flat - global_position).z)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "rotation:y", yaw, t)
	var dy := target.y - camera.global_position.y
	var dist := Vector2(target.x - global_position.x, target.z - global_position.z).length()
	tw.tween_property(head, "rotation:x", atan2(dy, dist), t)


func _physics_process(delta: float) -> void:
	var input := Vector2.ZERO
	if not frozen:
		input = Input.get_vector("move_left", "move_right", "move_up", "move_down")
		var pad := Input.get_vector("look_left", "look_right", "look_up", "look_down")
		if pad.length() > 0.1:
			_look(pad * pad_sensitivity * delta)
		var turn := Input.get_axis("turn_left", "turn_right")
		if turn != 0.0:
			_look(Vector2(turn * key_turn_speed * delta, 0.0))
	if input.length() > 0.1:
		Game.begin_level_timer()
	var dir := (transform.basis * Vector3(input.x, 0, input.y))
	dir.y = 0.0
	if dir.length() > 1.0:
		dir = dir.normalized()
	var want_run := not frozen and speed_mult > 0.0 and Input.is_action_pressed("sprint") and input.length() > 0.1 and stamina > 0.0
	if want_run and not running and stamina < 0.8:
		want_run = false                  # too winded to start again yet
	running = want_run
	if running:
		stamina = maxf(0.0, stamina - delta)
		_rest = 1.0
	else:
		_rest -= delta
		if _rest <= 0.0:
			stamina = minf(stamina_max, stamina + delta * 1.0)
	var target := dir * (run_speed if running else speed) * speed_mult
	var h := Vector3(velocity.x, 0, velocity.z).move_toward(target, accel * delta)
	velocity.x = h.x
	velocity.z = h.z
	velocity.y = 0.0 if is_on_floor() else velocity.y - _gravity * delta
	move_and_slide()
	_head_bob(delta)
	_update_focus()


func _head_bob(delta: float) -> void:
	var v := Vector2(velocity.x, velocity.z).length()
	if v > 0.5 and is_on_floor():
		_bob += delta * v * 1.9
		_step_timer -= delta
		if _step_timer <= 0.0:
			_step_timer = 2.4 / maxf(v, 1.0)
			Music.sfx("step%d" % (randi() % 3 + 1), 0.6 if running else 0.35, randf_range(0.9, 1.1))
	else:
		_bob = lerpf(_bob, roundf(_bob / PI) * PI, 1.0 - exp(-8.0 * delta))
	camera.position = Vector3(cos(_bob * 0.5) * 0.03, absf(sin(_bob)) * 0.05, 0)


## What are we looking at, within arm's reach?
func _update_focus() -> void:
	var from := camera.global_position
	var to := from - camera.global_transform.basis.z * reach
	var q := PhysicsRayQueryParameters3D.create(from, to, 1 | 2, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	var target: Object = null
	if not hit.is_empty() and hit.collider.has_meta("interact_target"):
		target = hit.collider.get_meta("interact_target")
	if frozen:
		target = null
	if target != _focus:
		_focus = target
	prompt_changed.emit(_focus.prompt() if _focus != null else "")
