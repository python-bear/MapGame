extends Node2D
## A tentacle breaking the surface, seen from above.
##
## Modes
##   GUARD   placed in the level; sways in place and slaps away ships that
##           come too close (knockback, no death). Set `rise_radius` > 0 to keep
##           it hidden until the ship approaches.
##   CHASER  spawned by the level; hunts the ship through open water using the
##           level's flow field. Touching the ship drags it under.
##   CLOSE   spawned for the ending; closes on `target` and never lets go.
##   WATCHER seen far off, standing out of the water, watching. It sinks away
##           the moment you come close. Harmless — for now.

enum Mode { GUARD, CHASER, CLOSE, WATCHER }

signal caught_ship

@export var mode: Mode = Mode.GUARD
@export var length := 92.0
@export var thickness := 14.0
## Resting direction (radians) a GUARD tentacle leans towards.
@export var lean := -1.2
@export var sway := 0.6
## GUARD only: stay submerged until the ship is this close (0 = always up).
@export var rise_radius := 0.0
## GUARD: don't fade into uncharted water (guards the level raises on purpose).
var always_visible := false
## > 0: sink away by itself after this many seconds.
var lifetime := 0.0

var speed := 120.0
var target := Vector2.ZERO
var emerge := 0.0            ## 0 = under water, 1 = fully risen
var level: Node              ## CHASER: provides flow_dir(pos)

var _t := 0.0
var _vel := Vector2.ZERO
var _risen := false
var _reach := 0.0            ## extra lean toward the ship
var _ship: Node2D
var _splash: Array = []      ## ring ripples {r, a}
var _submerging := false
var _slap_cool := 0.0
var _warn := 0.0             ## 0..1: a dark shape swelling under the water before it rises
var _bubbles: Array = []


func _ready() -> void:
	_t = randf() * 10.0
	if mode == Mode.GUARD and rise_radius <= 0.0:
		emerge = 1.0
		_risen = true
	add_to_group("tentacles")


## Rise out of the water. First a dark shape swells beneath the surface and
## bubbles break (the warning), then it bursts up.
func rise(duration := 0.9, warning := 0.7) -> void:
	if _risen:
		return
	_risen = true
	var tw := create_tween()
	if warning > 0.0:
		tw.tween_property(self, "_warn", 1.0, warning)
	tw.tween_callback(func():
		_splash.append({"r": 4.0, "a": 1.0})
		_splash.append({"r": 0.0, "a": 1.0}))
	tw.tween_property(self, "emerge", 1.0, duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "_warn", 0.0, 0.4)


func submerge(duration := 1.2) -> void:
	_submerging = true
	var tw := create_tween()
	tw.tween_property(self, "emerge", 0.0, duration).set_ease(Tween.EASE_IN)
	tw.tween_callback(queue_free)


## After a slap a guard sinks back for a moment — the window to slip past.
func _recoil() -> void:
	_slap_cool = 2.2
	var tw := create_tween()
	tw.tween_property(self, "emerge", 0.3, 0.35)
	tw.tween_interval(1.0)
	tw.tween_property(self, "emerge", 1.0, 0.8).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func is_dangerous() -> bool:
	return emerge > 0.75 and not _submerging and mode != Mode.WATCHER


func _physics_process(delta: float) -> void:
	_t += delta
	if lifetime > 0.0:
		lifetime -= delta
		if lifetime <= 0.0 and not _submerging:
			submerge(1.1)
	_slap_cool = maxf(0.0, _slap_cool - delta)
	if _ship == null:
		_ship = get_tree().get_first_node_in_group("player") as Node2D
	for s in _splash:
		s.r += delta * 38.0
		s.a -= delta * 0.7
	_splash = _splash.filter(func(s): return s.a > 0.0)
	if _warn > 0.05 and randf() < _warn * 0.6:
		_bubbles.append({"p": Vector2.from_angle(randf() * TAU) * randf() * thickness * 1.8, "r": 1.0, "a": 1.0})
	for b in _bubbles:
		b.r += delta * 6.0
		b.a -= delta * 1.6
	_bubbles = _bubbles.filter(func(b): return b.a > 0.0)
	if mode == Mode.GUARD and not always_visible and level and "_reveal" in level and level._reveal:
		# guards lurk unseen in uncharted water
		modulate.a = move_toward(modulate.a, level._reveal.amount_at(global_position), delta * 2.0)
	match mode:
		Mode.GUARD:
			_guard(delta)
		Mode.CHASER:
			_chase(delta)
		Mode.CLOSE:
			position = position.move_toward(target, speed * delta)
			lean = (target - position).angle()
		Mode.WATCHER:
			if _ship:
				var to_ship := _ship.global_position - global_position
				lean = lerp_angle(lean, to_ship.angle(), 1.0 - exp(-1.5 * delta))
				if not _submerging and emerge > 0.9 and to_ship.length() < 240.0:
					Music.sfx("splash", 0.35, 0.7)
					submerge(0.8)
	queue_redraw()


func _guard(delta: float) -> void:
	if _ship == null:
		return
	var to_ship := _ship.global_position - global_position
	var d := to_ship.length()
	if not _risen and d < rise_radius:
		rise(0.7)
		Music.sfx("emerge", 0.6, randf_range(0.9, 1.1))
	# lean towards a nearby ship as if to grab it
	var want := 1.0 if d < length * 1.6 else 0.0
	_reach = move_toward(_reach, want, delta * 2.0)
	if not is_dangerous() or not _ship.has_method("knock"):
		return
	for p in _hit_points():
		var diff: Vector2 = _ship.global_position - p.pos
		if diff.length() < p.r + 11.0 and _slap_cool <= 0.0:
			_slap_cool = 0.6
			var n := diff.normalized() if diff.length() > 0.1 else Vector2.RIGHT
			_ship.global_position += n * (p.r + 12.0 - diff.length())
			_ship.knock(n * 260.0, 0.45)
			Music.sfx("splash", 0.8, randf_range(0.8, 1.0))
			_recoil()
			if level and level.has_method("shake"):
				level.shake(6.0)
			break


func _chase(delta: float) -> void:
	if _ship == null or level == null or emerge < 0.6:
		return
	var dir: Vector2 = level.flow_dir(global_position)
	var grid: MapGrid = level.grid
	var terrain := grid.speed_at(global_position)   # shallows slow them too
	_vel = _vel.lerp(dir * speed * (terrain if terrain > 0.0 else 1.0), 1.0 - exp(-3.5 * delta))
	# keep clear of each other
	for o in get_tree().get_nodes_in_group("tentacles"):
		if o != self and o.mode == Mode.CHASER:
			var away: Vector2 = global_position - o.global_position
			if away.length() < 46.0 and away.length() > 0.1:
				global_position += away.normalized() * (46.0 - away.length()) * 3.0 * delta
	var step := _vel * delta
	if grid.is_walkable(grid.cell_of(global_position + step)):
		global_position += step
	elif grid.is_walkable(grid.cell_of(global_position + Vector2(step.x, 0))):
		global_position.x += step.x
	elif grid.is_walkable(grid.cell_of(global_position + Vector2(0, step.y))):
		global_position.y += step.y
	var to_ship := _ship.global_position - global_position
	lean = lerp_angle(lean, to_ship.angle(), 1.0 - exp(-5.0 * delta))
	_reach = move_toward(_reach, 1.0 if to_ship.length() < 120.0 else 0.3, delta * 2.0)
	if is_dangerous():
		for p in _hit_points():
			if _ship.global_position.distance_to(p.pos) < p.r + 9.0:
				caught_ship.emit()
				break


## Circles that count as "touching the tentacle": its base and lower body.
func _hit_points() -> Array:
	var pts := _spine()
	var out := [{"pos": global_position, "r": thickness * 1.3}]
	if pts.size() > 4:
		out.append({"pos": global_position + pts[pts.size() / 3], "r": thickness * 0.9})
	return out


## The tentacle's centre line, relative to its base.
func _spine() -> PackedVector2Array:
	var n := 16
	var pts := PackedVector2Array()
	var p := Vector2.ZERO
	var total := length * emerge * (1.0 + _reach * 0.25)
	var seg := total / n
	var base_a := lean + sin(_t * 1.3) * sway * 0.4
	for i in n + 1:
		var t := float(i) / n
		pts.append(p)
		var a := base_a + sin(_t * 2.2 - t * 4.0) * sway * t + t * t * t * 2.4 * (1.0 - _reach * 0.6)
		p += Vector2.from_angle(a) * seg
	return pts


const SKIN := Color(0.12, 0.07, 0.11, 0.98)
const SKIN_PALE := Color(0.34, 0.15, 0.19, 0.92)
const INK := Color(0.03, 0.01, 0.02, 1.0)
const FOAM := Color(0.9, 0.95, 0.98)
const SEA := Color(0.1, 0.2, 0.28)


func _draw() -> void:
	# the warning: something dark swelling under the surface, and bubbles
	if _warn > 0.0:
		var sw := _ellipse(Vector2.ZERO, thickness * 2.2 * _warn, thickness * 1.6 * _warn, lean, 0.12)
		draw_colored_polygon(sw, Color(0.02, 0.04, 0.07, 0.3 * _warn))
		for b in _bubbles:
			draw_arc(b.p, b.r, 0, TAU, 10, Color(FOAM, b.a * 0.8), 1.2, true)
	for s in _splash:
		_foam_ring(Vector2.ZERO, s.r, s.a * 0.8, 2.0, 1.7)
	if emerge <= 0.02:
		return
	_draw_mantle()
	# where the limb breaks the surface: a torn collar of foam
	var collar := thickness * (1.05 + 0.25 * emerge)
	_foam_ring(Vector2.ZERO, collar + 2.0 + sin(_t * 3.0) * 1.2, 0.75 * emerge, 1.6, 0.0)
	_foam_ring(Vector2.ZERO, collar + 7.0 + fmod(_t * 9.0, 8.0), (1.0 - fmod(_t * 9.0, 8.0) / 8.0) * 0.45 * emerge, 1.2, 2.3)
	_draw_limb()


## The body under the water: a dark mantle half out of the sea, the limb
## rising from its near edge and its one eye turned on the ship.
func _draw_mantle() -> void:
	var back := Vector2.from_angle(lean + PI)
	var c := back * thickness * 1.05
	var rx := thickness * 1.75 * (0.55 + 0.45 * emerge)
	var ry := thickness * 1.3 * (0.55 + 0.45 * emerge)
	var hump := _ellipse(c, rx, ry, lean, 0.06)
	draw_colored_polygon(hump, SKIN)
	# pale warts across the skin
	for k in 7:
		var q := c + Vector2(cos(k * 2.4) * rx * 0.6, sin(k * 1.7) * ry * 0.55).rotated(lean)
		draw_circle(q, 1.1 + (k % 3) * 0.5, Color(SKIN_PALE, 0.55))
	var outline := hump.duplicate()
	outline.append(hump[0])
	draw_polyline(outline, INK, 1.8, true)
	# the far half is still under the sea: water washes over it, and a line of
	# foam marks where it breaks the surface
	var cap := PackedVector2Array()
	for i in 13:
		var ang := deg_to_rad(105.0 + 150.0 * i / 12.0)
		cap.append(c + Vector2(cos(ang) * rx, sin(ang) * ry).rotated(lean))
	draw_colored_polygon(cap, Color(SEA, 0.55))
	var wa := cap[0]
	var wb := cap[cap.size() - 1]
	for k in 6:
		if k % 3 == 2:
			continue
		var p0 := wa.lerp(wb, k / 6.0) + back * sin(_t * 2.0 + k) * 1.2
		var p1 := wa.lerp(wb, (k + 1) / 6.0) + back * sin(_t * 2.0 + k + 1) * 1.2
		draw_line(p0, p1, Color(FOAM, 0.7 * emerge), 1.5, true)
	# the eye, set in the skin, watching the ship
	if emerge > 0.35:
		var ep := c - back * rx * 0.2
		var er := thickness * 0.62
		var look := Vector2.from_angle(lean)
		if _ship:
			look = (_ship.global_position - global_position).normalized()
		var lid := _ellipse(ep, er * 1.25, er * 0.72, lean + PI / 2.0, 0.0)
		draw_colored_polygon(lid, INK)
		var iris := _ellipse(ep, er * 1.05, er * 0.58, lean + PI / 2.0, 0.0)
		draw_colored_polygon(iris, Color(0.86, 0.7, 0.18, emerge))
		var pupil := _ellipse(ep + look * er * 0.22, er * 0.14, er * 0.52, look.angle(), 0.0)
		draw_colored_polygon(pupil, INK)
		draw_circle(ep - look.orthogonal() * er * 0.35 + Vector2(-1, -1), 1.2, Color(1, 1, 1, 0.7 * emerge))


func _draw_limb() -> void:
	var spine := _spine()
	var n := spine.size()
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	var widths := PackedFloat32Array()
	for i in n:
		var t := float(i) / (n - 1)
		var dir := (spine[mini(i + 1, n - 1)] - spine[maxi(i - 1, 0)]).normalized()
		var nrm := Vector2(-dir.y, dir.x)
		var w := thickness * pow(1.0 - t, 0.8) * (0.6 + 0.4 * emerge) + 0.7
		# a slow peristaltic bulge runs up the limb
		w *= 1.0 + 0.12 * sin(t * 9.0 - _t * 6.0)
		widths.append(w)
		left.append(spine[i] + nrm * w)
		right.append(spine[i] - nrm * w)
	var body := left.duplicate()
	for i in range(right.size() - 1, -1, -1):
		body.append(right[i])
	if Geometry2D.triangulate_polygon(body).size() > 0:
		draw_colored_polygon(body, SKIN)
	# the paler underside
	var under := PackedVector2Array()
	for i in n:
		under.append(right[i].lerp(spine[i], 0.25))
	for i in range(n - 1, -1, -1):
		under.append(right[i])
	if Geometry2D.triangulate_polygon(under).size() > 0:
		draw_colored_polygon(under, SKIN_PALE)
	# hooked barbs along the back
	for i in range(1, n - 2, 2):
		var dir := (spine[i + 1] - spine[i]).normalized()
		var nrm := Vector2(-dir.y, dir.x)
		var h := widths[i] * 0.7 + 1.5
		var b0 := left[i] - dir * h * 0.5
		var tip := left[i] + nrm * h - dir * h * 0.6
		draw_colored_polygon(PackedVector2Array([b0, tip, left[i] + dir * h * 0.4]), INK)
	draw_polyline(left, INK, 2.0, true)
	draw_polyline(right, INK, 2.0, true)
	# a wet sheen along the back
	var sheen := PackedVector2Array()
	for i in range(1, n - 3):
		sheen.append(spine[i].lerp(left[i], 0.55))
	draw_polyline(sheen, Color(0.75, 0.62, 0.72, 0.35), 1.4, true)
	# red-rimmed suckers along the underside
	for i in range(2, n - 2, 2):
		var q := right[i].lerp(spine[i], 0.42)
		var r := widths[i] * 0.34 + 0.6
		draw_circle(q, r, Color(0.72, 0.36, 0.36, 0.95))
		draw_circle(q, r * 0.45, Color(0.12, 0.02, 0.03, 0.95))
		draw_arc(q, r, 0, TAU, 8, INK, 0.8, true)
	# the tip curls into a hook
	var tip_dir := (spine[n - 1] - spine[n - 3]).normalized()
	var hook := PackedVector2Array()
	for k in 6:
		var a := tip_dir.angle() + k * 0.5
		hook.append(spine[n - 1] + Vector2.from_angle(a) * (3.5 - k * 0.4))
	draw_polyline(hook, INK, 1.8, true)


## A slightly lumpy ellipse (rotated by `rot`), as a polygon.
func _ellipse(c: Vector2, rx: float, ry: float, rot: float, lumpy: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 24:
		var a := TAU * i / 24.0
		var k := 1.0 + lumpy * sin(a * 3.0 + 1.1) + lumpy * 0.6 * sin(a * 5.0 + _t * 0.8)
		pts.append(c + Vector2(cos(a) * rx * k, sin(a) * ry * k).rotated(rot))
	return pts


## Foam: a ring of short white strokes with gaps, wobbling.
func _foam_ring(c: Vector2, r: float, alpha: float, width: float, phase: float) -> void:
	if r <= 0.5 or alpha <= 0.01:
		return
	var n := 14
	for i in n:
		if (i + int(phase * 3.0)) % 4 == 3:
			continue
		var a0 := TAU * i / n + phase
		var a1 := a0 + TAU / n * 0.7
		var r0 := r * (1.0 + 0.08 * sin(i * 2.3 + _t * 2.0))
		draw_arc(c, r0, a0, a1, 4, Color(FOAM, alpha), width, true)
