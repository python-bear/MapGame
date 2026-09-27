class_name SheetBaker
extends RefCounted
## Bakes a hand-drawn map or chart (thousands of ink strokes, drawn by
## GDScript) into a texture, so it isn't redrawn every frame.
##
## Redrawing the whole sheet takes a noticeable fraction of a second, so the
## ways a map is going to change are baked in advance, at load, while the
## level's title is on screen: each change is rendered once and only the part
## of the sheet it touches is kept, as a small "patch" sprite laid over the
## sheet. When the change happens in play, the patch simply fades in.

## Render `drawing` over a copy of `paper` into an image of the whole sheet.
func render(host: Node, drawing: Node2D, paper: ColorRect, sheet: Rect2, scale: float) -> Image:
	var vp := SubViewport.new()
	vp.size = Vector2i((sheet.size * scale).ceil())
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	host.add_child(vp)
	vp.canvas_transform = Transform2D(0.0, Vector2(scale, scale), 0.0, -sheet.position * scale)
	# the bake gets its own copy of the paper; the live paper stays underneath,
	# so uncharted areas show the very same sheet with no ink on it
	vp.add_child(paper.duplicate())
	var parent := drawing.get_parent()
	var index := drawing.get_index()
	drawing.reparent(vp, false)
	drawing.show()
	drawing.queue_redraw()
	await host.get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	drawing.reparent(parent, false)          # keep the renderer for the next bake
	parent.move_child(drawing, index)
	drawing.hide()
	vp.queue_free()
	return img


## The whole sheet as a sprite (mipmapped, so the zoomed-out map stays crisp).
func sheet_sprite(img: Image, sheet: Rect2, scale: float) -> Sprite2D:
	img.generate_mipmaps()
	var s := Sprite2D.new()
	s.name = "BakedSheet"
	s.centered = false
	s.position = sheet.position
	s.scale = Vector2.ONE / scale
	s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	s.texture = ImageTexture.create_from_image(img)
	return s


## Cut the part of `img` covering `world_rect` out as a hidden patch sprite that
## sits exactly over the sheet, charted by the same reveal material.
func patch(img: Image, world_rect: Rect2, sheet: Rect2, scale: float, sheet_material: ShaderMaterial) -> Sprite2D:
	var px := Rect2i(((world_rect.position - sheet.position) * scale).floor(), (world_rect.size * scale).ceil())
	px = px.intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	var sub := img.get_region(px)
	sub.generate_mipmaps()
	var s := Sprite2D.new()
	s.name = "Patch"
	s.centered = false
	s.position = sheet.position + Vector2(px.position) / scale
	s.scale = Vector2.ONE / scale
	s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	s.texture = ImageTexture.create_from_image(sub)
	if sheet_material:
		var m := sheet_material.duplicate() as ShaderMaterial
		m.set_shader_parameter("sheet_pos", s.position)
		m.set_shader_parameter("sheet_size", Vector2(px.size) / scale)
		s.material = m
	s.visible = false
	return s


## The world-space rectangle covering these cells, grown by `margin` cells
## (the ink of a change spreads a little beyond the cells themselves).
static func cells_rect(cells: Array, margin: float) -> Rect2:
	var r := Rect2()
	var first := true
	for c in cells:
		var cr := Rect2(Vector2(c) * MapGrid.CELL, Vector2.ONE * MapGrid.CELL)
		r = cr if first else r.merge(cr)
		first = false
	return r.grow(margin * MapGrid.CELL)
