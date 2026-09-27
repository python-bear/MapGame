extends SceneTree
## Dev test for Level 2.
##   xvfb-run godot --path . --script res://tools/level2_test.gd -- <out_dir> <mode>
## modes: run (bot sails to the dock), idle (circle until the minute is up), maw / north / south routes

var out_dir := "/tmp"
var mode := "run"

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0: out_dir = args[0]
	if args.size() > 1: mode = args[1]
	_run.call_deferred()

func _shot(name: String) -> void:
	await process_frame
	await process_frame
	root.get_viewport().get_texture().get_image().save_png(out_dir.path_join(name + ".png"))
	print("saved ", name)

func _secs(t: float) -> void:
	await create_timer(t).timeout

func _press(v: Vector2) -> void:
	for a in ["move_left", "move_right", "move_up", "move_down"]:
		Input.action_release(a)
	if v.x < -0.05: Input.action_press("move_left", -v.x)
	if v.x > 0.05: Input.action_press("move_right", v.x)
	if v.y < -0.05: Input.action_press("move_up", -v.y)
	if v.y > 0.05: Input.action_press("move_down", v.y)

func _run() -> void:
	var game = root.get_node("Game")
	game.show_timer = true
	for i in game.LEVELS.size():
		if game.LEVELS[i]["id"] == "level2_beacons":
			game.current_level = i
	change_scene_to_file("res://levels/level2/level2.tscn")
	await _secs(1.5)
	var level := current_scene
	var ship: Node2D = level.get_node("Ship")
	var grid: MapGrid = level.grid
	if mode == "shots":
		await _shot("20_start")
		Input.action_press("map_view")
		await _secs(1.5)
		await _shot("21_chart")
		Input.action_release("map_view")
		await _secs(1.0)
	if mode == "doom":
		level._wave_i = 99   # no hunters: just wait out the minute
		mode = "idle"
	if mode == "idle":
		var shot_doom := false
		var t0 := Time.get_ticks_msec()
		var shots_done := {}
		while not game.level_finished and Time.get_ticks_msec() - t0 < 150000:
			var a := Time.get_ticks_msec() / 1400.0
			_press(Vector2.from_angle(a))
			await physics_frame
			for k in [[8.0, "22a_shadow"], [34.5, "22b_watchers"], [50.0, "22c_hunt"], [63.0, "22d_attack"]]:
				if game.level_time > k[0] and not shots_done.has(k[1]):
					shots_done[k[1]] = true
					await _shot(k[1])
			if level.phase == 2 and not shot_doom:
				shot_doom = true
				await _secs(1.6)
				await _shot("26_doom_ring")
		_press(Vector2.ZERO)
		print("idle result: finished=", game.level_finished, " time=", game.format_time(game.level_time), " phase=", level.phase)
		await _secs(3.5)
		await _shot("23_dragged")
		quit()
		return
	# route to the dock
	var blocked := {}
	var box := {"maw": Rect2i(66, 22, 14, 12), "north": Rect2i(66, 0, 14, 14), "south": Rect2i(66, 42, 14, 14)}
	for k in box:
		if (mode == "north" and k != "north") or (mode == "south" and k != "south"):
			var r: Rect2i = box[k]
			for y in range(r.position.y, r.end.y):
				for x in range(r.position.x, r.end.x):
					blocked[Vector2i(x, y)] = true
	for g in level.get_node("Obstacles").get_children():
		if g.get("mode") != null:   # guard tentacles: steer clear like a person would
			var gc := grid.cell_of(g.position)
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					blocked[gc + Vector2i(dx, dy)] = true
	# waypoints: each beacon (greedy nearest first), then the berth
	var todo: Array = level.get_node("Beacons").get_children()
	var legs: Array = []
	var from := ship.position
	while todo.size() > 0:
		todo.sort_custom(func(x, y): return x.position.distance_to(from) < y.position.distance_to(from))
		var bc: Node2D = todo.pop_front()
		legs.append(bc)
		from = bc.position
	var t0 := Time.get_ticks_msec()
	var shot_mid := false
	var flared := 0
	var leg := 0
	var path: Array = []
	var i := 0
	var replan := 0.0
	while not game.level_finished and Time.get_ticks_msec() - t0 < 200000:
		while leg < legs.size() and legs[leg].lit:
			print("lit ", legs[leg].title, " at ", game.format_time(game.level_time))
			await _shot("29_beacon_%d" % leg)
			leg += 1
			replan = 0.0
		replan -= 1.0 / 60.0
		if replan <= 0.0:
			replan = 2.0
			var goal := grid.find("G")
			if leg < legs.size():
				goal = _water_near(grid, legs[leg].position)
			path = _solve(grid, grid.cell_of(ship.position), goal, blocked)
			i = 0
		for j in range(i, mini(i + 5, path.size())):
			if ship.position.distance_to(grid.cell_center(path[j])) < 26.0:
				i = j + 1
		i = mini(i, path.size() - 1)
		var target := grid.cell_center(path[mini(i + 1, path.size() - 1)])
		_press((target - ship.position).normalized())
		await physics_frame
		if mode != "noflare" and flared == 0 and game.level_time > 4.0:
			flared = 1
			level.fire_flare()
		if flared == 1 and game.level_time > 5.0:
			flared = 2
			await _shot("28_" + mode + "_flare")
		if game.level_time > 33.0 and not shot_mid:
			shot_mid = true
			await _shot("24_" + mode + "_mid")
		if OS.get_environment("L2DEBUG") != "" and Engine.get_physics_frames() % 60 == 0:
			print("t=%.1f cell=%s leg=%d" % [game.level_time, grid.cell_of(ship.position), leg])
	_press(Vector2.ZERO)
	print(mode, " result: phase=", level.phase, " time=", game.format_time(game.level_time))
	await _secs(2.5)
	await _shot("25_" + mode + "_end")
	if level.phase == 3:
		level.get_node("HUD")._on_continue()
		await _secs(4.0)
		print("after continue: scene=", current_scene.scene_file_path, " level=", game.current_level)
		await _shot("27_into_finale")
	quit()

func _water_near(grid: MapGrid, p: Vector2) -> Vector2i:
	var best := grid.cell_of(p)
	var bd := 1e9
	var c0 := grid.cell_of(p)
	for dy in range(-4, 5):
		for dx in range(-4, 5):
			var c := c0 + Vector2i(dx, dy)
			if grid.is_walkable(c):
				var d := grid.cell_center(c).distance_to(p)
				if d < bd:
					bd = d
					best = c
	return best


func _solve(grid: MapGrid, s: Vector2i, g: Vector2i, blocked: Dictionary) -> Array:
	# BFS with a clearance preference: avoid cells touching land
	var dist := {s: 0.0}
	var prev := {}
	var open := [s]
	while open.size() > 0:
		var bi := 0
		for k in open.size():
			if dist[open[k]] < dist[open[bi]]: bi = k
		var c: Vector2i = open[bi]
		open.remove_at(bi)
		if c == g: break
		for d: Vector2i in [Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1),Vector2i(1,1),Vector2i(1,-1),Vector2i(-1,1),Vector2i(-1,-1)]:
			var n := c + d
			if blocked.has(n) or not grid.is_walkable(n): continue
			if d.x != 0 and d.y != 0 and (not grid.is_walkable(Vector2i(n.x, c.y)) or not grid.is_walkable(Vector2i(c.x, n.y))): continue
			var pen := 0.0
			for e: Vector2i in [Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1)]:
				if not grid.is_walkable(n + e) and n + e != g: pen += 1.5
			var nd: float = dist[c] + Vector2(d).length() + pen
			if nd < dist.get(n, 1e9):
				dist[n] = nd
				prev[n] = c
				if not open.has(n): open.append(n)
	var path := [g]
	while prev.has(path[-1]): path.append(prev[path[-1]])
	path.reverse()
	return path
