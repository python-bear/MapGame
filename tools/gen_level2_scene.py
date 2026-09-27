#!/usr/bin/env python3
"""Writes levels/level2/level2.tscn: notes, guard tentacles, lights, HUD.
Positions are in chart cells; guards snap to the nearest open water."""
import re, os
ROOT = os.path.join(os.path.dirname(__file__), '..')
rows = re.findall(r'\t"([^"]*)"', open(os.path.join(ROOT, 'levels/level2/level2_data.gd')).read())
H, W = len(rows), len(rows[0])
C = 32

def water(x, y):
    return 0 <= x < W and 0 <= y < H and rows[y][x] in '.,'

def snap(x, y):
    best = None
    for r in range(0, 6):
        for dy in range(-r, r + 1):
            for dx in range(-r, r + 1):
                cx, cy = int(x) + dx, int(y) + dy
                if water(cx, cy) and all(water(cx + a, cy + b) for a in (-1, 0, 1) for b in (-1, 0, 1)):
                    return cx + 0.5, cy + 0.5
    return x, y

def v(x, y): return "Vector2(%d, %d)" % (round(x * C), round(y * C))

NOTES = [  # name, text, style, x, y, size, rotation, reveal
    ("Mainland", "The Mainland", 1, 7, 18, 30, 0, 0),
    ("Harbour", "the last harbour —\nits lamps went out behind us", 0, 9, 33.5, 20, -0.04, 0),
    ("Deep", "The Open Deep", 1, 42, 20, 34, 0, 0),
    ("NoBottom", "no soundings. no bottom.\nnothing to steer by but the stars", 0, 45, 34, 20, 0.03, 0),
    ("Teeth", "The Teeth", 1, 73.5, 1.6, 28, 0, 0),
    ("Maw", "the Maw", 1, 67.5, 32.6, 22, 0, 0),
    ("MawNote", "the straight way is\nnever the safe way", 0, 66, 25, 20, -0.05, 0),
    ("Shoals", "The Shoals", 1, 88, 54.4, 28, 0, 0),
    ("Landing", "Harrow's Landing", 1, 118, 10, 26, 0, 0),
    ("Tents", "three tents on the shore —\nthey look like ours", 0, 117, 40, 20, 0.03, 0),
    ("Monsters", "here be monsters", 0, 36, 40.6, 22, -0.05, 0),
    ("KnowsShip", "IT KNOWS YOUR SHIP", 2, 56, 28, 28, -0.1, 170),
    ("Down", "down, down, down", 2, 52, 44, 26, 0.12, 150),
    ("Welcome", "welcome home", 2, 105, 38, 26, -0.08, 180),
    ("DoodleW", "", 4, 30, 50, 26, -0.3, 220),
    ("DoodleE", "", 4, 60, 5, 26, 0.35, 220),
    ("WayThrough", "a way through?", 0, 90.5, 26.0, 20, -0.04, 0),
]
GUARDS = [  # name, x, y, lean, rise_radius
    ("MawNorth", 73, 27.2, -1.3, 200), ("MawSouth", 74, 31.0, 1.8, 200),
    ("TopGap", 72, 8.5, 0.3, 0), ("BottomGap", 73, 47.5, -0.4, 0),
    ("EastGapN", 93, 18, 2.6, 180), ("EastGapS", 93, 38, -2.4, 180),
    ("LandingN", 104, 23, 2.0, 0), ("LandingS", 104, 37, -2.0, 0),
    ("Stray1", 84, 28, 1.0, 0), ("Stray2", 82, 8, -2.0, 0), ("Stray3", 83, 46, 0.8, 0),
]
BEACONS = [  # name, title, x, y  (on islands; the ship lights them by coming close)
    ("NorthBeacon", "the North Beacon", 62.3, 12.2),
    ("SouthBeacon", "the South Beacon", 60.0, 44.3),
    ("ShoalBeacon", "the Shoal Beacon", 83.6, 18.6),
]
LOST_SHIPS = [  # name, title, reward, x, y  (optional)
    ("Constance", "the Constance", "route", 54.5, 4.5),
    ("Albatross", "the Albatross", "story", 40.5, 47.5),
    ("Meridian", "the Meridian", "message", 80.5, 50.5),
]
TENTS = [(111.5, 27.6), (111.2, 33.4), (113.6, 30.5)]

sx = sy = None
for y, r in enumerate(rows):
    if 'S' in r:
        sx, sy = r.index('S') + 0.5, y + 0.5

out = []
out.append('''[gd_scene load_steps=14 format=3]

[ext_resource type="Script" path="res://levels/level2/level2.gd" id="1_level"]
[ext_resource type="Shader" path="res://shaders/parchment.gdshader" id="2_paper"]
[ext_resource type="Script" path="res://scripts/sea_chart_renderer.gd" id="3_chart"]
[ext_resource type="Script" path="res://levels/level2/level2_data.gd" id="4_data"]
[ext_resource type="Script" path="res://scripts/map_note.gd" id="5_note"]
[ext_resource type="Script" path="res://scripts/ink_route.gd" id="6_route"]
[ext_resource type="Script" path="res://scripts/tentacle.gd" id="7_tentacle"]
[ext_resource type="Script" path="res://scripts/ship.gd" id="9_ship"]
[ext_resource type="Shader" path="res://shaders/vignette.gdshader" id="10_vig"]
[ext_resource type="PackedScene" path="res://scenes/ui/hud.tscn" id="11_hud"]
[ext_resource type="Script" path="res://scripts/beacon.gd" id="12_beacon"]
[ext_resource type="Script" path="res://scripts/lost_ship.gd" id="13_lost"]

[sub_resource type="ShaderMaterial" id="ShaderMaterial_paper"]
shader = ExtResource("2_paper")
shader_parameter/paper_color = Color(0.86, 0.82, 0.7, 1)
shader_parameter/stain_color = Color(0.46, 0.42, 0.32, 1)
shader_parameter/rect_size = Vector2(4376, 2072)
shader_parameter/stain_amount = 0.75
shader_parameter/edge_burn = 0.9
shader_parameter/grain = 0.05
shader_parameter/seed = 7.0

[sub_resource type="ShaderMaterial" id="ShaderMaterial_vig"]
shader = ExtResource("10_vig")
shader_parameter/dread = 0.35
shader_parameter/strength = 0.95
shader_parameter/warm = Color(0.1, 0.08, 0.1, 1)
shader_parameter/cold = Color(0.01, 0.03, 0.07, 1)

[node name="Level2" type="Node2D"]
script = ExtResource("1_level")

[node name="Paper" type="ColorRect" parent="."]
material = SubResource("ShaderMaterial_paper")
offset_left = -140.0
offset_top = -140.0
offset_right = 4236.0
offset_bottom = 1932.0
mouse_filter = 2

[node name="Chart" type="Node2D" parent="."]
script = ExtResource("3_chart")
data_script = ExtResource("4_data")
tents = Array[Vector2]([%s])

[node name="Notes" type="Node2D" parent="."]

''' % ', '.join('Vector2(%s, %s)' % t for t in TENTS))
for (name, text, style, x, y, size, rot, reveal) in NOTES:
    s = '[node name="%s" type="Node2D" parent="Notes"]\nposition = %s\n' % (name, v(x, y))
    if rot: s += 'rotation = %s\n' % rot
    s += 'script = ExtResource("5_note")\ntext = "%s"\n' % text
    if style: s += 'style = %d\n' % style
    s += 'font_size = %d\n' % size
    if reveal: s += 'reveal_radius = %s\n' % float(reveal)
    out.append(s + '\n')
out.append('[node name="Beacons" type="Node2D" parent="."]\n\n')
for (name, title, x, y) in BEACONS:
    out.append('[node name="%s" type="Node2D" parent="Beacons"]\nposition = %s\nscript = ExtResource("12_beacon")\ntitle = "%s"\n\n' % (name, v(x, y), title))
out.append('[node name="LostShips" type="Node2D" parent="."]\n\n')
for (name, title, reward, x, y) in LOST_SHIPS:
    gx, gy = snap(x, y)
    out.append('[node name="%s" type="Node2D" parent="LostShips"]\nposition = %s\nscript = ExtResource("13_lost")\ntitle = "%s"\nreward = "%s"\n\n' % (name, v(gx, gy), title, reward))
out.append('''[node name="Route" type="Node2D" parent="."]
script = ExtResource("6_route")
color = Color(0.55, 0.12, 0.08, 0.55)

[node name="Obstacles" type="Node2D" parent="."]

''')
for (name, x, y, lean, rise) in GUARDS:
    gx, gy = snap(x, y)
    s = '[node name="%s" type="Node2D" parent="Obstacles"]\nposition = %s\nscript = ExtResource("7_tentacle")\nlean = %s\n' % (name, v(gx, gy), lean)
    if rise: s += 'rise_radius = %s\n' % float(rise)
    out.append(s + '\n')
out.append('''[node name="Hunters" type="Node2D" parent="."]

[node name="Ship" type="Node2D" parent="."]
position = %s
script = ExtResource("9_ship")
route_path = NodePath("../Route")

[node name="Camera" type="Camera2D" parent="."]
position = %s
zoom = Vector2(1.8, 1.8)

[node name="Overlay" type="CanvasLayer" parent="."]
layer = 5

[node name="Gloom" type="ColorRect" parent="Overlay"]
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
mouse_filter = 2
color = Color(0.02, 0.05, 0.09, 0)

[node name="Vignette" type="ColorRect" parent="Overlay"]
material = SubResource("ShaderMaterial_vig")
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
mouse_filter = 2

[node name="HUD" parent="." instance=ExtResource("11_hud")]
controls_hint = "WASD / arrows — steer      E / Space — fire a flare      Tab — your chart      R — restart      Esc — pause"
''' % (v(sx, sy), v(sx, sy)))
open(os.path.join(ROOT, 'levels/level2/level2.tscn'), 'w').write(''.join(out))
print('wrote level2.tscn')
