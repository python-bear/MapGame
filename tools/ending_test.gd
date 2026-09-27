extends SceneTree
## Dev test: screenshots through both endings.
var out_dir := "/tmp"
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0: out_dir = args[0]
	_run.call_deferred()

func _run() -> void:
	var game = root.get_node("Game")
	for kind in ["escape", "caught"]:
		game.ending = kind
		game.last_total = 3
		game.last_found = 1
		change_scene_to_file("res://scenes/ending.tscn")
		var t := 0.0
		var marks := [3.0, 9.0, 16.0, 22.0, 27.0, 33.0, 40.0] if kind == "escape" else [4.0, 10.0, 17.0, 24.0, 30.0, 36.0, 41.0, 46.0]
		for m in marks:
			await create_timer(m - t).timeout
			t = m
			root.get_viewport().get_texture().get_image().save_png(out_dir.path_join("end_%s_%02d.png" % [kind, int(m)]))
			print(kind, " ", m)
	quit()
