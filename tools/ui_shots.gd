extends SceneTree
## Dev test: screenshots of intro, settings, pause.

var out_dir := "/tmp"

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	_run.call_deferred()

func _shot(name: String) -> void:
	await process_frame
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(out_dir.path_join(name + ".png"))
	print("saved ", name, "  fps ", Engine.get_frames_per_second())

func _secs(t: float) -> void:
	await create_timer(t).timeout

func _run() -> void:
	var game = root.get_node("Game")
	change_scene_to_file("res://scenes/intro.tscn")
	await _secs(2.5)
	await _shot("10_intro")
	change_scene_to_file("res://scenes/main_menu.tscn")
	await _secs(1.0)
	current_scene.get_node("Center/Menu/Settings").emit_signal("pressed")
	await _secs(0.5)
	await _shot("11_settings")
	current_scene._close_settings()
	current_scene._open_chapters()
	await _secs(0.5)
	await _shot("15_chapters")
	game.current_level = 0
	change_scene_to_file("res://levels/level1/level1.tscn")
	await _secs(1.8)
	await _shot("12_title_card")
	var p: Node2D = current_scene.get_node("Explorer")
	p.position = Vector2(46.0 * 32, 11.5 * 32)   # beside the Black Tarn
	await _secs(3.0)
	await _shot("13_tarn")
	var ev := InputEventAction.new()
	ev.action = "pause"
	ev.pressed = true
	Input.parse_input_event(ev)
	await _secs(0.5)
	await _shot("14_pause")
	quit()
