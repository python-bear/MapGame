extends SceneTree
## Dev test: play the finale start to finish.
##   xvfb-run godot --path . --script res://tools/finale_test.gd -- <out_dir> <mode>
## modes: run (the beast is real) | calm (the beast never wakes) | caught (take the Black Key and wait)

var out_dir := "/tmp"
var mode := "calm"
var game
var level
var maze: MazeBuilder
var player: CharacterBody3D
var t0 := 0

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

func _stop() -> void:
	for a in ["move_up", "move_down", "move_left", "move_right", "sprint"]:
		Input.action_release(a)

## Walk (or run) to a cell, opening any shut door on the way. Stops `short`
## metres from `aim` if given.
func _walk(cell: Vector2i, run := false, aim := Vector3.INF, short := 0.0) -> bool:
	var stuck := 0
	var last := player.global_position
	while not game.level_finished and Time.get_ticks_msec() - t0 < 240000:
		var here := maze.cell_of(player.global_position)
		var goal_pos := maze.cell_center(cell) if aim == Vector3.INF else aim
		if Vector2(player.global_position.x - goal_pos.x, player.global_position.z - goal_pos.z).length() < maxf(short, 0.4):
			_stop()
			return true
		var path := maze.path(here, cell)
		var target := goal_pos
		if not path.is_empty():
			var next: Vector2i = path[0]
			target = maze.cell_center(next)
			if maze.edge_kind(here, next) == "door":
				var door = maze.door_between(here, next)
				if door and not door.is_passable():
					var edge := (maze.cell_center(here) + maze.cell_center(next)) * 0.5
					var mid := maze.cell_center(here)
					if Vector2(player.global_position.x - mid.x, player.global_position.z - mid.z).length() > 0.5:
						target = mid
					else:
						_stop()
						_face(edge + Vector3(0, 1.4, 0))
						await _interact()
						await _secs(1.0)
						continue
		elif here != cell:
			print("NO PATH from ", here, " to ", cell)
			_stop()
			return false
		var to: Vector3 = target - player.global_position
		player.rotation.y = atan2(-to.x, -to.z)
		Input.action_press("move_up")
		if run:
			Input.action_press("sprint")
		else:
			Input.action_release("sprint")
		await physics_frame
		if player.global_position.distance_to(last) < 0.01:
			stuck += 1
			if stuck > 200:
				print("STUCK at ", here, " going to ", cell)
				_stop()
				return false
		else:
			stuck = 0
		last = player.global_position
	_stop()
	return false

func _gate(near: Vector2i, far: Vector2i) -> void:
	await _walk(near)
	var edge := (maze.cell_center(near) + maze.cell_center(far)) * 0.5
	_face(edge + Vector3(0, 1.4, 0))
	await _interact()
	await _secs(1.6)
	print("gate ", near, "->", far, " open=", maze.door_between(near, far).is_passable())

func _take(name: String) -> void:
	var k: Node3D = maze.keys[name]
	await _walk(maze.cell_of(k.global_position), false, k.global_position, 1.3)
	_face(k.global_position + Vector3(0, 1.05, 0))
	await _interact()
	print("took ", name, " held=", level.held.keys(), " t=", game.format_time(game.level_time))

func _run() -> void:
	game = root.get_node("Game")
	game.show_timer = true
	game.current_level = 2
	change_scene_to_file("res://levels/level3/level3.tscn")
	await _secs(2.0)
	level = current_scene
	maze = level.get_node("Maze")
	player = level.get_node("Player")
	var beast = level.get_node("Beast")
	t0 = Time.get_ticks_msec()
	await _shot("40_start")
	if mode == "fakes":
		for ld in maze.light_doors:
			var o: Vector3 = ld.global_position + ld.global_transform.basis.z * 3.2 + Vector3(0, 0.05, 0)
			player.global_position = o
			_face(ld.global_position + Vector3(0, 1.6, 0))
			await _secs(0.8)
			await _shot("50_door_%s" % ld.name)
		# a portal: open it, walk into the swirl, come out of its partner
		var f = maze.light_doors.filter(func(d): return d.role == "portal")[0]
		player.global_position = f.global_position + f.global_transform.basis.z * 1.6
		_face(f.global_position + Vector3(0, 1.3, 0))
		await _interact()
		await _secs(1.0)
		await _shot("51_portal_open")
		Input.action_press("move_up")
		await _secs(1.2)
		Input.action_release("move_up")
		await _shot("52_through")
		await _secs(1.5)
		print("portal: came out at ", maze.cell_of(player.global_position), " (partner ", f.partner.name, " at ", maze.cell_of(f.partner.arrival_point()), ")")
		await _shot("53_elsewhere")
		# the dud: bricks
		var dud = maze.light_doors.filter(func(d): return d.role == "dud")[0]
		player.global_position = dud.global_position + dud.global_transform.basis.z * 1.6
		_face(dud.global_position + Vector3(0, 1.3, 0))
		await _interact()
		await _secs(1.5)
		await _shot("54_dud")
		quit()
		return
	# ---- the silent room
	await _walk(Vector2i(1, 10))
	await _secs(1.5)
	print("silent room: phase=", level.phase, " door locked=", maze.doors[level.SILENT_DOOR].locked)
	await _take("Iron")
	await _secs(1.0)
	await _shot("41_lights_out")
	await _secs(4.5)
	print("door after key: locked=", maze.doors[level.SILENT_DOOR].locked, " open=", maze.doors[level.SILENT_DOOR].is_passable())
	await _shot("42_door_reopens")
	Input.action_press("map_view")
	await _secs(3.5)
	await _shot("43_journal_ruined")
	Input.action_release("map_view")
	# ---- the stone key
	await _gate(Vector2i(4, 5), Vector2i(3, 5))
	await _walk(Vector2i(3, 5))
	await _secs(2.0)
	_face(maze.cell_center(Vector2i(2, 5), 2.0))
	await _shot("44_guides")
	await _secs(2.0)
	for g in level._guides:
		print("guide honest=", g.honest, " at ", maze.cell_of(g.global_position))
	await _take("Stone")
	# ---- the black key
	await _gate(Vector2i(8, 5), Vector2i(9, 5))
	await _walk(Vector2i(11, 2))
	await _shot("45_beast_hall")
	await _take("Black")
	if mode == "calm":
		beast.process_mode = Node.PROCESS_MODE_DISABLED
	await _secs(1.2)
	_face(beast.global_position + Vector3(0, 1.2, 0))
	await _shot("46_it_wakes")
	if mode == "caught":
		var tc := Time.get_ticks_msec()
		while not level._over and Time.get_ticks_msec() - tc < 30000:
			await physics_frame
		await _secs(0.6)
		await _shot("47_caught")
		await _secs(6.0)
		await _shot("48_after_caught")
		print("caught result: over=", level._over, " scene=", current_scene.scene_file_path)
		quit()
		return
	# ---- escape
	level.beast.caught_player.connect(func(): print("CAUGHT at ", game.format_time(game.level_time), " cell ", maze.cell_of(player.global_position)))
	await _walk(Vector2i(6, 2), true)
	await _shot("47_chase")
	await _gate(Vector2i(6, 2), Vector2i(6, 1))
	if game.level_finished and not level.phase == 3 or not is_instance_valid(level):
		await _secs(5.0)
		await _shot("49_ending")
		quit()
		return
	await _walk(Vector2i(6, 0))
	await _secs(2.0)
	_face(maze.exit_door.global_position + Vector3(0, 1.4, 0))
	await _shot("48_the_light")
	_face(level.beast.global_position + Vector3(0, 1.2, 0))
	await _secs(0.3)
	print("beast state at the light: ", level.beast.state, " dist ", snappedf(player.global_position.distance_to(level.beast.global_position), 0.1))
	await _shot("48b_it_stops")
	var out: Vector3 = maze.exit_door.global_position + (maze.exit_door.global_position - maze.cell_center(Vector2i(6, 0))).normalized() * 1.0
	await _walk(Vector2i(6, 0), false, out, 0.1)
	await _secs(1.0)
	print(mode, " result: finished=", game.level_finished, " escaped=", level._over, " beast state=", beast.state, " t=", game.format_time(game.level_time))
	await _secs(3.0)
	await _shot("49_ending")
	quit()
