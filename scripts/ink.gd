@tool
class_name Ink
extends RefCounted
## Little helpers for drawing in a hand-inked map style.
## All functions take the CanvasItem to draw on as the first argument.

const INK := Color(0.23, 0.14, 0.08, 0.92)
const INK_FAINT := Color(0.3, 0.2, 0.12, 0.35)
const RED_INK := Color(0.55, 0.1, 0.07, 0.9)
const BLUE_INK := Color(0.16, 0.3, 0.42, 0.95)
const PAPER := Color(0.91, 0.85, 0.71)


## Deterministic 0..1 hash of a 2D point (so wobbles don't shimmer).
static func hash2(x: float, y: float, s: float = 0.0) -> float:
	var h := sin(x * 127.1 + y * 311.7 + s * 74.7) * 43758.5453
	return h - floor(h)


static func wobble(p: Vector2, amount: float, s: float = 0.0) -> Vector2:
	var q := p.snapped(Vector2(0.5, 0.5))
	return p + Vector2(hash2(q.x, q.y, s) - 0.5, hash2(q.y, q.x, s + 9.0) - 0.5) * 2.0 * amount


## A slightly wobbly pen line.
static func line(ci: CanvasItem, a: Vector2, b: Vector2, col: Color = INK, w: float = 1.6, amount: float = 0.8) -> void:
	var n := maxi(2, int(a.distance_to(b) / 14.0) + 1)
	var pts := PackedVector2Array()
	for i in n + 1:
		var t := float(i) / n
		var p := a.lerp(b, t)
		if i > 0 and i < n:
			p = wobble(p, amount)
		pts.append(p)
	ci.draw_polyline(pts, col, w, true)


static func dashed(ci: CanvasItem, a: Vector2, b: Vector2, col: Color = INK, w: float = 1.4, dash: float = 7.0, gap: float = 5.0) -> void:
	var d := a.distance_to(b)
	if d < 0.01:
		return
	var dir := (b - a) / d
	var t := 0.0
	while t < d:
		ci.draw_line(a + dir * t, a + dir * minf(t + dash, d), col, w, true)
		t += dash + gap


static func compass_rose(ci: CanvasItem, c: Vector2, r: float, font: Font, col: Color = INK) -> void:
	ci.draw_arc(c, r * 0.72, 0.0, TAU, 64, col, 1.4, true)
	ci.draw_arc(c, r * 0.78, 0.0, TAU, 64, col, 0.8, true)
	for i in 32:
		var a := TAU * i / 32.0
		var l := 0.05 if i % 4 else 0.1
		ci.draw_line(c + Vector2.from_angle(a) * r * 0.72, c + Vector2.from_angle(a) * r * (0.72 + l), col, 1.0, true)
	for i in 8:
		var a := TAU * i / 8.0 - PI / 2.0
		var long := r if i % 2 == 0 else r * 0.55
		var tip := c + Vector2.from_angle(a) * long
		var left := c + Vector2.from_angle(a - PI / 2.0) * r * 0.12
		var right := c + Vector2.from_angle(a + PI / 2.0) * r * 0.12
		ci.draw_colored_polygon(PackedVector2Array([c, tip, left]), col)
		ci.draw_colored_polygon(PackedVector2Array([c, tip, right]), Color(col, col.a * 0.25))
		ci.draw_polyline(PackedVector2Array([left, tip, right]), col, 1.0, true)
	ci.draw_circle(c, r * 0.06, col)
	if font:
		var fs := int(r * 0.34)
		var w := font.get_string_size("N", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		ci.draw_string(font, c + Vector2(-w / 2.0, -r - 6.0), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


## Text centred on a point, optionally rotated.
static func text(ci: CanvasItem, font: Font, pos: Vector2, s: String, size: int, col: Color = INK, angle: float = 0.0) -> void:
	var sz := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size)
	ci.draw_set_transform(pos, angle, Vector2.ONE)
	ci.draw_string(font, Vector2(-sz.x / 2.0, sz.y * 0.3), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Multi-line text centred on a point.
## `halo` paints a soft paper-coloured outline first so notes stay legible
## over trees and contour lines.
static func multiline(ci: CanvasItem, font: Font, pos: Vector2, s: String, size: int, col: Color = INK, angle: float = 0.0, halo: float = 0.0) -> void:
	var lines := s.split("\n")
	var lh := font.get_height(size) * 0.85
	ci.draw_set_transform(pos, angle, Vector2.ONE)
	var y0 := -lh * (lines.size() - 1) / 2.0
	for i in lines.size():
		var w := font.get_string_size(lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		var at := Vector2(-w / 2.0, y0 + i * lh + size * 0.3)
		if halo > 0.0:
			ci.draw_string_outline(font, at, lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, size, int(size * 0.35), Color(PAPER, halo))
		ci.draw_string(font, at, lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
