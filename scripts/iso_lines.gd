@tool
class_name IsoLines
extends RefCounted
## Marching-squares helpers for drawing smooth shapes from a grid of cells.
## A "field" is sampled at cell centres with a one-cell border (clamped).


## 1.0 where `pred(x, y)` is true, else 0.0, then softened with a 3x3 blur.
static func field(w: int, h: int, pred: Callable, blur := true) -> PackedFloat32Array:
	var fw := w + 2
	var fh := h + 2
	var raw := PackedFloat32Array()
	raw.resize(fw * fh)
	for sy in fh:
		for sx in fw:
			raw[sy * fw + sx] = 1.0 if pred.call(clampi(sx - 1, 0, w - 1), clampi(sy - 1, 0, h - 1)) else 0.0
	return smooth(raw, fw, fh) if blur else raw


## Arbitrary per-cell values (e.g. a distance field), padded the same way.
static func values(w: int, h: int, fn: Callable, blur := true) -> PackedFloat32Array:
	var fw := w + 2
	var fh := h + 2
	var raw := PackedFloat32Array()
	raw.resize(fw * fh)
	for sy in fh:
		for sx in fw:
			raw[sy * fw + sx] = fn.call(clampi(sx - 1, 0, w - 1), clampi(sy - 1, 0, h - 1))
	return smooth(raw, fw, fh) if blur else raw


static func smooth(raw: PackedFloat32Array, fw: int, fh: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(fw * fh)
	var k := [1.0, 2.0, 1.0]
	for sy in fh:
		for sx in fw:
			var acc := 0.0
			for dy in 3:
				var ny := clampi(sy + dy - 1, 0, fh - 1)
				for dx in 3:
					acc += raw[ny * fw + clampi(sx + dx - 1, 0, fw - 1)] * k[dx] * k[dy]
			out[sy * fw + sx] = acc / 16.0
	return out


static func _pos(sx: int, sy: int, cell: float) -> Vector2:
	return Vector2(sx - 0.5, sy - 0.5) * cell


static func _cross(pa: Vector2, va: float, pb: Vector2, vb: float, iso: float) -> Vector2:
	if pb.x < pa.x or (pb.x == pa.x and pb.y < pa.y):
		var tp := pa
		pa = pb
		pb = tp
		var tv := va
		va = vb
		vb = tv
	var t := clampf((iso - va) / (vb - va), 0.0, 1.0)
	return pa + (pb - pa) * t


## Filled region where field >= iso, as one triangle batch.
static func fill(ci: CanvasItem, f: PackedFloat32Array, w: int, h: int, cell: float, iso: float, col: Color) -> void:
	var fw := w + 2
	var pts := PackedVector2Array()
	var idx := PackedInt32Array()
	for sy in h + 1:
		for sx in w + 1:
			var v := [f[sy * fw + sx], f[sy * fw + sx + 1], f[(sy + 1) * fw + sx + 1], f[(sy + 1) * fw + sx]]
			var p := [_pos(sx, sy, cell), _pos(sx + 1, sy, cell), _pos(sx + 1, sy + 1, cell), _pos(sx, sy + 1, cell)]
			var poly := PackedVector2Array()
			for i in 4:
				var j := (i + 1) % 4
				var ins: bool = v[i] >= iso
				if ins:
					poly.append(p[i])
				if ins != (v[j] >= iso):
					poly.append(_cross(p[i], v[i], p[j], v[j], iso))
			if poly.size() < 3:
				continue
			var base := pts.size()
			pts.append_array(poly)
			for i in range(1, poly.size() - 1):
				idx.append(base)
				idx.append(base + i)
				idx.append(base + i + 1)
	if idx.size() > 0:
		var cols := PackedColorArray()
		cols.resize(pts.size())
		cols.fill(col)
		RenderingServer.canvas_item_add_triangle_array(ci.get_canvas_item(), idx, pts, cols)


## Line segments along field == iso. `wobble` gives a hand-drawn waver.
static func segments(f: PackedFloat32Array, w: int, h: int, cell: float, iso: float, wobble := 0.0) -> PackedVector2Array:
	var fw := w + 2
	var seg := PackedVector2Array()
	for sy in h + 1:
		for sx in w + 1:
			var v := [f[sy * fw + sx], f[sy * fw + sx + 1], f[(sy + 1) * fw + sx + 1], f[(sy + 1) * fw + sx]]
			var p := [_pos(sx, sy, cell), _pos(sx + 1, sy, cell), _pos(sx + 1, sy + 1, cell), _pos(sx, sy + 1, cell)]
			var hits := PackedVector2Array()
			for i in 4:
				var j := (i + 1) % 4
				if (v[i] >= iso) != (v[j] >= iso):
					var q := _cross(p[i], v[i], p[j], v[j], iso)
					hits.append(Ink.wobble(q, wobble) if wobble > 0.0 else q)
			for k in range(0, hits.size() - 1, 2):
				seg.append(hits[k])
				seg.append(hits[k + 1])
	return seg


static func contour(ci: CanvasItem, f: PackedFloat32Array, w: int, h: int, cell: float, iso: float, col: Color, width: float, wobble := 0.0) -> void:
	var seg := segments(f, w, h, cell, iso, wobble)
	if seg.size() > 0:
		ci.draw_multiline(seg, col, width)


## Dotted version (small dashes centred on each segment).
static func dotted(ci: CanvasItem, f: PackedFloat32Array, w: int, h: int, cell: float, iso: float, col: Color, width: float, spacing := 7.0) -> void:
	var seg := segments(f, w, h, cell, iso)
	var dots := PackedVector2Array()
	for k in range(0, seg.size(), 2):
		var a := seg[k]
		var b := seg[k + 1]
		var n := int(a.distance_to(b) / spacing) + 1
		var d := (b - a).normalized() * 1.4
		for t in n:
			var q := a.lerp(b, (t + 0.5) / n)
			dots.append(q - d)
			dots.append(q + d)
	if dots.size() > 0:
		ci.draw_multiline(dots, col, width)
