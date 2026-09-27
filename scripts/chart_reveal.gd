class_name ChartReveal
extends Node
## "The world only exists on paper where you've been."
##
## Keeps a small per-cell mask of how much of the map has been charted
## (0 = blank paper, 1 = inked) and feeds it to the reveal shader on the baked
## map sprite. Levels call reveal() as the player moves; map notes ask
## amount_at() to decide whether to show themselves.

signal charted_changed(fraction: float)

var width := 0
var height := 0
var cell := 32.0
var _img: Image
var _tex: ImageTexture
var _dirty := false
var _values := PackedFloat32Array()
var _total := 0.0
var _charted := 0.0


func setup(w: int, h: int, cell_size: float) -> void:
	width = w
	height = h
	cell = cell_size
	_values.resize(w * h)
	_values.fill(0.0)
	_img = Image.create(w, h, false, Image.FORMAT_L8)
	_img.fill(Color.BLACK)
	_tex = ImageTexture.create_from_image(_img)
	_total = float(w * h)
	add_to_group("chart_reveal")


func texture() -> Texture2D:
	return _tex


## Ink the map in a soft circle of `radius` cells around world position `pos`.
func reveal(pos: Vector2, radius: float) -> void:
	var cx := pos.x / cell
	var cy := pos.y / cell
	var r := radius + 1.0
	for y in range(maxi(0, floori(cy - r)), mini(height, ceili(cy + r) + 1)):
		for x in range(maxi(0, floori(cx - r)), mini(width, ceili(cx + r) + 1)):
			var d := Vector2(x + 0.5 - cx, y + 0.5 - cy).length()
			var v := clampf((radius - d) / 1.2 + 0.5, 0.0, 1.0)
			var i := y * width + x
			if v > _values[i]:
				_charted += v - _values[i]
				_values[i] = v
				_img.set_pixel(x, y, Color(v, v, v))
				_dirty = true


## 0..1 — how inked the map is at world position `pos`.
func amount_at(pos: Vector2) -> float:
	var x := floori(pos.x / cell)
	var y := floori(pos.y / cell)
	if x < 0 or y < 0 or x >= width or y >= height:
		return 1.0
	return _values[y * width + x]


## Fraction of the sheet charted, 0..1.
func fraction() -> float:
	return _charted / maxf(_total, 1.0)


func _process(_delta: float) -> void:
	if _dirty and _tex:
		_tex.update(_img)
		_dirty = false
		charted_changed.emit(fraction())


## Apply the reveal shader to the baked map sprite.
func attach_to(sprite: Sprite2D, sheet: Rect2, map_size: Vector2, fresh_ink := Color(0.12, 0.07, 0.04)) -> void:
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/chart_reveal.gdshader")
	mat.set_shader_parameter("mask", _tex)
	mat.set_shader_parameter("sheet_pos", sheet.position)
	mat.set_shader_parameter("sheet_size", sheet.size)
	mat.set_shader_parameter("map_size", map_size)
	mat.set_shader_parameter("fresh_ink", fresh_ink)
	sprite.material = mat
