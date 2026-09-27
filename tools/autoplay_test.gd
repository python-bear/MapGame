extends SceneTree
## Dev test: screenshots + an autopilot run through Level 1.
##   xvfb-run godot --path . --script res://tools/autoplay_test.gd -- <out_dir> [north|south]

var out_dir := "/tmp"
var route := ""
var lookahead := 0
var frame := 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	if args.size() > 1:
		route = args[1]
	if args.size() > 2:
		lookahead = int(args[2])   # >0 = cut corners like a human
	_run.call_deferred()


var shooting := false
func _shot(name: String) -> void:
	shooting = true
	await process_frame
	await process_frame
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(out_dir.path_join(name + ".png"))
	print("saved ", name)
	await process_frame
	shooting = false


func _wait(frames: int) -> void:
	for i in frames:
		await process_frame


func _run() -> void:
	var game = root.get_node("Game")
	change_scene_to_file("res://scenes/main_menu.tscn")
	await _wait(90)
	await _shot("01_menu")
	game.show_timer = true
	for i in game.LEVELS.size():
		if game.LEVELS[i]["id"] == "level1_expedition":
			game.current_level = i
	change_scene_to_file("res://levels/level1/level1.tscn")
	await _wait(120)
	await _shot("02_level_start")
	Input.action_press("map_view")
	await _wait(90)
	await _shot("03_overview")
	Input.action_release("map_view")
	await _wait(60)

	var level := current_scene
	var grid: MapGrid = level._grid
	var player: Node2D = level.get_node("Explorer")
	var targets: Array = []
	for w in level.ROUTE:
		targets.append(Vector2i(w.cell))
	var camp := grid.cell_of(level._start - Vector2(0, 28))
	var shot_at := {1: "04_river", 3: "05_changed", 4: "06_survey_point"}
	_watch_frames()
	var t0 := Time.get_ticks_msec()
	for k in targets.size():
		var ok := await _walk_to(grid, player, targets[k], t0, game)
		print("reached ", level.ROUTE[k].name, " ok=", ok, " t=", game.format_time(game.level_time))
		if shot_at.has(k):
			await _wait(20)
			await _shot(shot_at[k])
		if not ok:
			break
	await _wait(60)
	await _shot("06b_return_begins")
	print("leg: ", level.leg, " prompt=", level.hud._ctx.text if level.hud._ctx else "none", " vis=", level.hud._ctx.get_global_rect() if level.hud._ctx else Rect2())
	var ok2 := await _walk_to(grid, player, camp, t0, game)
	print("camp ok=", ok2)
	await _shot("06c_the_cave")
	print("finished: ", game.level_finished, "  level time: ", game.format_time(game.level_time))
	await _wait(150)
	await _shot("07_complete")
	level.get_node("HUD")._on_continue()
	await create_timer(4.0).timeout
	await _shot("08_next")
	quit()


## The longest frame while walking (a stall when the map changes shows here).
var worst_frame := 0
func _watch_frames() -> void:
	var last := Time.get_ticks_usec()
	while true:
		await process_frame
		var now := Time.get_ticks_usec()
		if shooting:
			last = now
			continue
		if now - last > worst_frame:
			worst_frame = now - last
			print("  longest frame so far: %d ms" % (worst_frame / 1000))
		last = now


func _walk_to(grid: MapGrid, player: Node2D, goal: Vector2i, t0: int, game) -> bool:
	var path: Array = []
	var i := 0
	var replan := 0
	var stuck := 0
	var last := player.position
	while not game.level_finished:
		if replan <= 0:
			path = _solve(grid, grid.cell_of(player.position), goal, {})
			i = 0
			replan = 60
		replan -= 1
		if path.size() <= 1 and grid.cell_of(player.position) == goal:
			var c := grid.cell_center(goal)
			if player.position.distance_to(c) < 8.0:
				break
		if i >= path.size():
			break
		var target: Vector2 = grid.cell_center(path[i])
		if player.position.distance_to(target) < 5.0:
			i += 1
			continue
		var v := (target - player.position).normalized()
		for a in ["move_left", "move_right", "move_up", "move_down"]:
			Input.action_release(a)
		if v.x < -0.05: Input.action_press("move_left", -v.x)
		if v.x > 0.05: Input.action_press("move_right", v.x)
		if v.y < -0.05: Input.action_press("move_up", -v.y)
		if v.y > 0.05: Input.action_press("move_down", v.y)
		await physics_frame
		if player.position.distance_to(last) < 0.05:
			stuck += 1
			if stuck > 240:
				print("STUCK at ", grid.cell_of(player.position), " heading to ", path[i])
				return false
		else:
			stuck = 0
		last = player.position
		if Time.get_ticks_msec() - t0 > 150000:
			print("TIMEOUT at ", grid.cell_of(player.position))
			return false
	for a in ["move_left", "move_right", "move_up", "move_down"]:
		Input.action_release(a)
	return true


func _solve(grid: MapGrid, s: Vector2i, g: Vector2i, blocked: Dictionary) -> Array:
	var dist := {s: 0.0}
	var prev := {}
	var open := [s]
	while open.size() > 0:
		var bi := 0
		for k in open.size():
			if dist[open[k]] < dist[open[bi]]:
				bi = k
		var c: Vector2i = open[bi]
		open.remove_at(bi)
		if c == g:
			break
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n := c + d
			if blocked.has(n) or not grid.can_enter(n, c):
				continue
			var nd: float = dist[c] + 1.0 / grid.speeds[grid.tile(n)]
			if nd < dist.get(n, 1e9):
				dist[n] = nd
				prev[n] = c
				if not open.has(n):
					open.append(n)
	var path := [g]
	while prev.has(path[-1]):
		path.append(prev[path[-1]])
	path.reverse()
	return path
