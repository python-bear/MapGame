extends CanvasLayer
## The finale's hotbar: three slots along the bottom of the screen for the
## Iron, Stone and Black keys. A key you pick up goes into its slot and into
## your hand. 1 / 2 / 3 or the mouse wheel swap between the keys you have.
## A gate opens only for the key in your hand.
##
## The key in hand is also shown in the world, held out in front of the camera.

signal selected_changed(key_name: String)

const ORDER := ["Iron", "Stone", "Black"]
const ICON := {
	"Iron": Color(0.66, 0.68, 0.74),
	"Stone": Color(0.76, 0.72, 0.63),
	"Black": Color(0.1, 0.08, 0.08),
}
const SLOT := 66.0
const GAP := 12.0

var camera: Camera3D                    ## set by the level: where to hold the key
var owned := {}                         ## key name -> true
var selected := -1                      ## index into ORDER, -1 = empty hand

var _hand: Font = preload("res://assets/fonts/Caveat.ttf")
var _draw: Control
var _t := 0.0
var _pop := [0.0, 0.0, 0.0]             ## a little jump when a slot changes
var _deny := [0.0, 0.0, 0.0]            ## a shake when you pick an empty slot
var _name_t := 0.0                      ## how long the key's name stays up
var _held: Node3D                       ## the key held out in front of the camera
var _held_models := {}
var _swap := 1.0                        ## 0 = lowered out of view, 1 = held up
var _hidden := false
var _wheel_cool := 0.0                  ## one swap per notch, even on a fast trackpad


func _ready() -> void:
	layer = 5
	_draw = Control.new()
	_draw.set_anchors_preset(Control.PRESET_FULL_RECT)
	_draw.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_draw.draw.connect(_on_draw)
	add_child(_draw)


## A key has been picked up: it goes into its slot, and into his hand.
func add_key(key_name: String) -> void:
	var i := ORDER.find(key_name)
	if i < 0:
		return
	owned[key_name] = true
	_pop[i] = 1.0
	select(i)


func has_selected(key_name: String) -> bool:
	return selected >= 0 and ORDER[selected] == key_name


func selected_name() -> String:
	return ORDER[selected] if selected >= 0 else ""


func slot_of(key_name: String) -> int:
	return ORDER.find(key_name) + 1


func select(i: int) -> void:
	if i < 0 or i >= ORDER.size():
		return
	if not owned.has(ORDER[i]):
		_deny[i] = 1.0
		return
	if i == selected:
		return
	selected = i
	_pop[i] = maxf(_pop[i], 0.6)
	_name_t = 2.2
	_swap = 0.0
	var music := get_node_or_null("/root/Music")
	if music:
		music.sfx("key", 0.35, 1.25)
	selected_changed.emit(ORDER[i])


## Step through the keys he has (dir = +1 / -1), skipping empty slots.
func cycle(dir: int) -> void:
	if owned.is_empty():
		return
	var i := selected
	for n in ORDER.size():
		i = posmod(i + dir, ORDER.size())
		if owned.has(ORDER[i]):
			select(i)
			return


## Everything off (the ending).
func hide_all() -> void:
	_hidden = true
	visible = false
	if _held:
		_held.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if _hidden or get_tree().paused:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var k: int = event.physical_keycode
		if k >= KEY_1 and k <= KEY_3:
			select(k - KEY_1)
			get_viewport().set_input_as_handled()
		elif k >= KEY_KP_1 and k <= KEY_KP_3:
			select(k - KEY_KP_1)
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN or event.button_index == MOUSE_BUTTON_WHEEL_UP:
			get_viewport().set_input_as_handled()
			if _wheel_cool > 0.0:
				return
			_wheel_cool = 0.18
			cycle(1 if event.button_index == MOUSE_BUTTON_WHEEL_DOWN else -1)


func _process(delta: float) -> void:
	_t += delta
	_wheel_cool -= delta
	for i in 3:
		_pop[i] = move_toward(_pop[i], 0.0, delta * 2.5)
		_deny[i] = move_toward(_deny[i], 0.0, delta * 3.0)
	_name_t = maxf(0.0, _name_t - delta)
	_draw.queue_redraw()
	_update_held(delta)


# ================================================================ the slots
func _on_draw() -> void:
	var sz := _draw.size
	var total := SLOT * 3.0 + GAP * 2.0
	var x0 := (sz.x - total) / 2.0
	var y0 := sz.y - SLOT - 62.0
	for i in 3:
		var kn: String = ORDER[i]
		var have := owned.has(kn)
		var sel := i == selected
		var lift := (6.0 if sel else 0.0) + sin(_pop[i] * PI) * 8.0
		var shake: float = sin(_deny[i] * 40.0) * 5.0 * _deny[i]
		var r := Rect2(Vector2(x0 + i * (SLOT + GAP) + shake, y0 - lift), Vector2(SLOT, SLOT))
		_draw.draw_rect(r, Color(0.06, 0.045, 0.035, 0.62 if have else 0.4))
		var border := Color(0.95, 0.82, 0.5, 0.95) if sel else Color(0.92, 0.87, 0.74, 0.35 if have else 0.18)
		_draw.draw_rect(r, border, false, 3.0 if sel else 1.5)
		if sel:
			_draw.draw_rect(r.grow(4.0), Color(0.95, 0.8, 0.45, 0.18 + sin(_t * 3.0) * 0.06), false, 2.0)
		_key_icon(r.get_center(), kn, have)
		_label(r.position + Vector2(6, 20), str(i + 1), 20, Color(0.95, 0.9, 0.78, 0.8 if have else 0.35))
	if selected >= 0 and _name_t > 0.0:
		var a := clampf(_name_t / 0.5, 0.0, 1.0)
		var t := "the %s Key" % ORDER[selected]
		var w := _hand.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 28).x
		_label(Vector2((sz.x - w) / 2.0, y0 - 22.0), t, 28, Color(0.96, 0.9, 0.78, a))
	if not owned.is_empty():
		var hint := "1 2 3 / wheel — swap keys"
		var hw := _hand.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
		_label(Vector2((sz.x - hw) / 2.0, y0 + SLOT + 20.0), hint, 18, Color(0.92, 0.87, 0.74, 0.45))


## A little key: a ring, a shaft, two teeth. Empty slots show a faint outline.
func _key_icon(c: Vector2, kn: String, have: bool) -> void:
	var col: Color = ICON[kn]
	if not have:
		col = Color(0.92, 0.87, 0.74, 0.14)
	var bow := c + Vector2(-14, 0)
	var line := Color(0.0, 0.0, 0.0, 0.55) if have else Color(0, 0, 0, 0)
	if have and kn == "Black":
		# the black key glows red at the edges
		_draw.draw_arc(bow, 11.0, 0, TAU, 24, Color(0.9, 0.15, 0.08, 0.55 + sin(_t * 4.0) * 0.2), 7.0, true)
		_draw.draw_line(bow + Vector2(9, 0), c + Vector2(20, 0), Color(0.9, 0.15, 0.08, 0.5), 7.0, true)
	if have:
		_draw.draw_arc(bow, 9.5, 0, TAU, 24, line, 6.5, true)
		_draw.draw_line(bow + Vector2(9, 0), c + Vector2(20, 0), line, 6.5, true)
	_draw.draw_arc(bow, 9.5, 0, TAU, 24, col, 4.0, true)
	_draw.draw_line(bow + Vector2(9, 0), c + Vector2(20, 0), col, 4.0, true)
	_draw.draw_rect(Rect2(c + Vector2(10, 1), Vector2(4, 9)), col)
	_draw.draw_rect(Rect2(c + Vector2(16, 1), Vector2(4, 6)), col)


func _label(at: Vector2, t: String, size: int, col: Color) -> void:
	_draw.draw_string_outline(_hand, at, t, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 5, Color(0.08, 0.05, 0.03, col.a * 0.85))
	_draw.draw_string(_hand, at, t, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


# ================================================================ the key in hand
func _update_held(delta: float) -> void:
	if camera == null or _hidden:
		return
	if _held == null:
		_held = Node3D.new()
		_held.name = "HeldKey"
		camera.add_child(_held)
		for kn: String in ORDER:
			var m := _key_model(kn)
			m.visible = false
			_held.add_child(m)
			_held_models[kn] = m
	var want := selected_name()
	# lower the old key, swap, raise the new one
	_swap = move_toward(_swap, 1.0, delta * 4.0)
	for kn: String in _held_models:
		(_held_models[kn] as Node3D).visible = kn == want and _swap > 0.35
	var up := smoothstep(0.35, 1.0, _swap) if _swap > 0.35 else 0.0
	var sway := Vector3(sin(_t * 1.3) * 0.004, sin(_t * 2.1) * 0.004, 0.0)
	_held.position = Vector3(0.27, -0.36 + up * 0.13, -0.5) + sway
	_held.rotation = Vector3(0.25, 1.35, -0.35 + sin(_t * 0.8) * 0.03)


func _key_model(kn: String) -> Node3D:
	var root := Node3D.new()
	root.scale = Vector3.ONE * 0.5
	var col: Color = {"Iron": Color(0.42, 0.42, 0.45), "Stone": Color(0.62, 0.6, 0.55), "Black": Color(0.03, 0.03, 0.035)}[kn]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.metallic = 0.7 if kn != "Stone" else 0.0
	mat.roughness = 0.35 if kn != "Stone" else 0.9
	mat.emission_enabled = true
	mat.emission = {"Iron": Color(0.25, 0.3, 0.4), "Stone": Color(0.45, 0.45, 0.4), "Black": Color(0.45, 0.03, 0.03)}[kn]
	mat.emission_energy_multiplier = 0.45
	mat.no_depth_test = true            # always drawn over the world: it's in his hand
	mat.disable_fog = true
	mat.render_priority = 10
	var bow := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.06
	tm.outer_radius = 0.1
	bow.mesh = tm
	bow.rotation.x = PI / 2.0
	bow.position = Vector3(-0.2, 0, 0)
	bow.material_override = mat
	root.add_child(bow)
	var shaft := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.018
	cm.bottom_radius = 0.018
	cm.height = 0.34
	shaft.mesh = cm
	shaft.rotation.z = PI / 2.0
	shaft.position = Vector3(0.05, 0, 0)
	shaft.material_override = mat
	root.add_child(shaft)
	for i in 2:
		var bit := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.04, 0.09 - i * 0.03, 0.02)
		bit.mesh = bm
		bit.position = Vector3(0.18 + i * 0.05, -0.05 + i * 0.015, 0)
		bit.material_override = mat
		root.add_child(bit)
	return root
