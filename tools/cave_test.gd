extends SceneTree
## Dev test: walk the cave ("The Hollow") from the mouth to the door, then on
## through the interlude into the finale. Saves screenshots along the way.
##   xvfb-run godot --path . --script res://tools/cave_test.gd -- <out_dir> [tour]
## `tour` also visits the bones and every painting (teleporting), for pictures.

const Data := preload("res://levels/cave/cave_data.gd")

var out_dir := "/tmp"
var mode := "run"
var game
var level
var player: CharacterBody3D


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0: out_dir = args[0]
	if args.size() > 1: mode = args[1]
	_run.call_deferred()


func _shot(name: String) -> void:
	await process_frame
	await process_frame
	root.get_viewport().get_texture().get_image().save_png(out_dir.path_join(name + ".png"))
	print("saved ", name, "  t=", game.format_time(game.level_time))


func _secs(t: float) -> void:
	await create_timer(t).timeout


func _face(target: Vector3) -> void:
	var to: Vector3 = target - player.camera.global_position
	player.rotation.y = atan2(-to.x, -to.z)
	var pitch := atan2(to.y, Vector2(to.x, to.z).length())
	player.get_node("Head").rotation.x = pitch
	player._pitch = pitch


func _interact() -> void:
	await physics_frame
	await physics_frame
	var ev := InputEventAction.new()
	ev.action = "interact"
	ev.pressed = true
	Input.parse_input_event(ev)
	await process_frame
	ev = InputEventAction.new()
	ev.action = "interact"
	ev.pressed = false
	Input.parse_input_event(ev)
	await process_frame


## Walk to a point (on the floor), steering straight at it.
func _walk_to(p: Vector3, reach := 0.7) -> bool:
	var stuck := 0
	var last := player.global_position
	while true:
		var to: Vector3 = p - player.global_position
		to.y = 0.0
		if to.length() < reach:
			return true
		player.rotation.y = atan2(-to.x, -to.z)
		player.get_node("Head").rotation.x = 0.0
		player._pitch = 0.0
		Input.action_press("move_up")
		await physics_frame
		if player.global_position.distance_to(last) < 0.005:
			stuck += 1
			if stuck > 120:
				Input.action_release("move_up")
				print("STUCK at ", player.global_position, " going to ", p)
				return false
		else:
			stuck = 0
		last = player.global_position
	return false


func _index_of(id: String) -> int:
	for i in game.LEVELS.size():
		if game.LEVELS[i]["id"] == id:
			return i
	return -1


func _look_at_painting(tex: String) -> void:
	for p: Dictionary in Data.PAINTINGS:
		if p.tex == tex:
			var n: Vector3 = p.normal
			var stand: Vector3 = p.pos + n * 3.0
			stand.y = p.pos.y - 1.5
			player.global_position = stand
			player.velocity = Vector3.ZERO
			await _secs(0.4)
			_face(p.pos)
			await _secs(0.6)


func _run() -> void:
	game = root.get_node("Game")
	game.show_timer = true
	game.current_level = _index_of("cave_hollow")
	print("cave is level ", game.current_level, " of ", game.LEVELS.size(), "; next: ", game.LEVELS[game.current_level + 1]["id"])
	var t_load := Time.get_ticks_msec()
	change_scene_to_file("res://levels/cave/cave.tscn")
	await _secs(2.0)
	level = current_scene
	player = level.get_node("Player")
	print("loaded in ~", Time.get_ticks_msec() - t_load - 2000, " ms (after the 2 s wait)")
	print("player at ", player.global_position, " on floor: ", player.is_on_floor())
	await _shot("c00_start")
	_face(player.global_position + Vector3(0, 1.4, 6))
	await _shot("c01_behind_daylight")
	if mode == "tour":
		for tex in ["hands", "hunt", "dragged", "monster", "cave_map", "land_map", "procession", "spiral"]:
			await _look_at_painting(tex)
			await _shot("t_" + tex)
		var b: Vector3 = Data.BONES
		player.global_position = b + Vector3(2.6, 0.2, 0.8)
		await _secs(0.5)
		_face(b + Vector3(0, 0.2, 0))
		await _secs(0.8)
		await _shot("t_bones")
		var r: Array = Data.ROOMS["painted"]
		player.global_position = r[0] + Vector3(0.5, 0.3, 2.5)
		await _secs(0.8)
		print("in the chamber at ", player.global_position)
		_face(r[0] + Vector3(0, 2.0, -6))
		await _shot("t_chamber")
		var d: Vector3 = Data.DOOR
		player.global_position = d + Vector3(0.8, 0.3, 8.0)
		await _secs(0.8)
		_face(d + Vector3(0, 1.4, 0))
		await _shot("t_door_far")
		player.global_position = d + Vector3(0, 0.3, 3.5)
		await _secs(0.5)
		_face(d + Vector3(0, 1.6, 0))
		await _shot("t_door_near")
		print("seen paintings: ", level._seen.keys())
		quit()
		return
	# ---- walk in; the mouth closes
	var route: Array = Data.ROUTE
	var i := 0
	var sealed_shot := false
	var t0 := Time.get_ticks_msec()
	for p: Vector3 in route:
		i += 1
		if not await _walk_to(p):
			await _shot("c_stuck")
			quit(1)
			return
		if level._sealed and not sealed_shot:
			sealed_shot = true
			Input.action_release("move_up")
			await _secs(1.5)
			_face(Vector3(Data.SEAL.x, 1.8, Data.SEAL.z))
			await _shot("c02_sealing")
			await _secs(2.5)
			await _shot("c03_sealed")
		if i == 22:
			await _shot("c04_passage")
	Input.action_release("move_up")
	print("walked to the door in ", game.format_time(game.level_time), " (real ", (Time.get_ticks_msec() - t0) / 1000.0, " s)")
	var door: Vector3 = Data.DOOR
	_face(door + Vector3(0, 1.4, 0))
	await _shot("c05_door_shut")
	await _interact()
	await _secs(2.6)
	await _shot("c06_door_open")
	var tc: float = game.level_time
	await _walk_to(door + Vector3(0, 0, -1.0), 0.3)
	Input.action_release("move_up")
	await _secs(0.8)
	print("entered: finished=", game.level_finished, " level time ", game.format_time(tc))
	await _shot("c07_into_light")
	await _secs(2.6)
	print("scene now: ", current_scene.scene_file_path)
	await _shot("c08_interlude")
	await _secs(2.5)
	await _shot("c09_interlude_2")
	# skip the rest
	Input.action_press("skip")
	await _secs(1.2)
	Input.action_release("skip")
	await _secs(3.0)
	print("scene now: ", current_scene.scene_file_path, "  level ", game.current_level, " = ", game.level_title())
	await _shot("c10_finale")
	quit()
