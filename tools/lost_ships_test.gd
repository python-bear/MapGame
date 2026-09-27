extends SceneTree
## Dev test: visit each lost ship in Level 2 and screenshot the note it gives.
func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var game = root.get_node("Game")
	game.current_level = 1
	change_scene_to_file("res://levels/level2/level2.tscn")
	await create_timer(1.5).timeout
	var level := current_scene
	var ship: Node2D = level.get_node("Ship")
	var k := 0
	for ls in level.get_node("LostShips").get_children():
		ship.position = ls.position + Vector2(30, 0)
		await create_timer(2.5).timeout
		print(ls.title, " done=", ls.done, " answered=", level._answered)
		root.get_viewport().get_texture().get_image().save_png("/tmp/l2/30_lost_%d.png" % k)
		k += 1
	print("hidden bar cell now: ", level.grid.tile_xy(96, 27))
	quit()
