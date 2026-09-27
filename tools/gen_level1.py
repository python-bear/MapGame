#!/usr/bin/env python3
"""
Level 1 layout generator for Cartographer's Dream.

This is just a drafting aid: it sketches the jungle map from a few shapes
(rivers, hills, forests, trails), checks the level is solvable, and writes
the result as two ASCII layers into levels/level1/level1_data.gd.

After generating, the ASCII in level1_data.gd is the source of truth — you can
hand-edit it directly in Godot and never run this script again.

Usage:  python3 tools/gen_level1.py            (writes the .gd file)
        python3 tools/gen_level1.py --preview  (just prints the map)
"""
import math, sys, heapq, os

W, H = 64, 40
SEED = 7

# ---------------------------------------------------------------- noise
def _hash(x, y):
    n = (x * 374761393 + y * 668265263 + SEED * 1442695041) & 0xFFFFFFFF
    n = ((n ^ (n >> 13)) * 1274126177) & 0xFFFFFFFF
    return ((n ^ (n >> 16)) & 0xFFFF) / 65535.0

def noise(x, y, scale=4.0):
    x /= scale; y /= scale
    xi, yi = math.floor(x), math.floor(y)
    xf, yf = x - xi, y - yi
    sx = xf * xf * (3 - 2 * xf); sy = yf * yf * (3 - 2 * yf)
    a, b = _hash(xi, yi), _hash(xi + 1, yi)
    c, d = _hash(xi, yi + 1), _hash(xi + 1, yi + 1)
    return (a + (b - a) * sx) + ((c + (d - c) * sx) - (a + (b - a) * sx)) * sy

# ---------------------------------------------------------------- layers
terrain = [['.' for _ in range(W)] for _ in range(H)]
height = [[0 for _ in range(W)] for _ in range(H)]

def inb(x, y): return 0 <= x < W and 0 <= y < H

def blob(cx, cy, rx, ry, wobble=0.35, nscale=3.0):
    """Cells inside a noisy ellipse."""
    out = []
    for y in range(H):
        for x in range(W):
            dx, dy = (x - cx) / rx, (y - cy) / ry
            d = math.sqrt(dx * dx + dy * dy)
            if d < 1.0 + (noise(x + cx * 3, y + cy * 7, nscale) - 0.5) * 2 * wobble:
                out.append((x, y))
    return out

def polyline_cells(pts, width):
    out = set()
    for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
        steps = int(max(abs(x1 - x0), abs(y1 - y0)) * 4) + 1
        for i in range(steps + 1):
            t = i / steps
            px, py = x0 + (x1 - x0) * t, y0 + (y1 - y0) * t
            r = width / 2.0
            for y in range(int(py - r - 1), int(py + r + 2)):
                for x in range(int(px - r - 1), int(px + r + 2)):
                    if (x + 0.5 - px) ** 2 + (y + 0.5 - py) ** 2 <= r * r and inb(x, y):
                        out.add((x, y))
    return out

def set_t(cells, ch, only_on=None):
    for x, y in cells:
        if inb(x, y) and (only_on is None or terrain[y][x] in only_on):
            terrain[y][x] = ch

def set_h(cells, h):
    for x, y in cells:
        if inb(x, y):
            height[y][x] = max(height[y][x], h)

# --- elevation -------------------------------------------------------
# Lookout Hill (west), the Plateau (north-east) and the Summit on it.
set_h(blob(10, 13, 6.0, 5.0, 0.25), 1)
set_h(blob(49, 9, 17.0, 10.5, 0.22, 4.0), 1)
set_h(blob(55, 6, 8.0, 5.5, 0.2, 3.0), 2)
# keep plateau fully on the map's right/top
for y in range(H):
    for x in range(W):
        if height[y][x] >= 1 and x >= 34 and y <= 3:
            pass

# --- forests -----------------------------------------------------------
for (cx, cy, rx, ry) in [(8, 26, 7, 6), (16, 5, 7, 5), (30, 12, 6, 9),
                         (34, 33, 8, 5), (46, 32, 7, 5), (43, 13, 6, 5),
                         (58, 30, 6, 7), (4, 6, 4, 5), (52, 16, 5, 3)]:
    set_t(blob(cx, cy, rx, ry, 0.35, 2.5), 'f')

# a few clearings punched back out of the jungle
for (cx, cy, r) in [(4, 34, 3.2), (27, 20, 2.4), (39, 30, 2.0)]:
    set_t(blob(cx, cy, r, r, 0.2), '.')

# --- marsh at the river delta -----------------------------------------
set_t(blob(22, 36, 5, 3, 0.4, 2.0), 'm')

# --- rivers (height 0 only) --------------------------------------------
main_river = [(19, -1), (21, 5), (19, 11), (23, 17), (21, 23), (26, 29), (24, 35), (27, 41)]
tributary = [(65, 23), (57, 25), (49, 23), (41, 26), (33, 25), (26, 29)]
river = polyline_cells(main_river, 2.6) | polyline_cells(tributary, 2.2)
tarn = blob(41, 11, 3.2, 2.4, 0.15)   # the Black Tarn, up on the plateau
for x, y in river:
    height[y][x] = 0
set_t(river, '~')
set_t(tarn, '~')

# --- rocks along cliff faces ---------------------------------------------
for (x, y) in [(33, 8), (34, 16), (47, 1), (47, 2), (61, 12), (62, 13), (13, 9), (6, 17),
               (38, 19), (39, 19), (45, 20), (44, 3), (29, 36), (30, 37), (60, 36), (11, 37)]:
    if terrain[y][x] != '~':
        terrain[y][x] = '#'

# --- trails ---------------------------------------------------------------
def trail(pts):
    for x, y in polyline_cells(pts, 1.5):
        if terrain[y][x] not in '~#':
            terrain[y][x] = 'p'

def bridge(x, y, horizontal, ch='='):
    """Lay a straight bridge across the water that contains (x, y)."""
    dx, dy = (1, 0) if horizontal else (0, 1)
    for sgn in (1, -1):
        cx, cy = x, y
        while inb(cx, cy) and terrain[cy][cx] in '~=b':
            terrain[cy][cx] = ch
            cx += dx * sgn; cy += dy * sgn

# camp -> north along the west bank -> north bridge -> plateau west stairs
trail([(4, 34), (5, 30), (3, 22), (1.8, 16), (1.6, 11), (2.6, 7.4), (5, 5.4), (9, 5), (13, 5.6),
       (16, 7), (24, 7), (29, 6), (34, 7), (38, 6)])   # curves west and north round Lookout Hill
# camp -> east -> south bridge -> through the jungle, east along the tributary
trail([(4, 34), (10, 33), (17, 31), (29, 31), (33, 29), (41, 29), (48, 28), (53, 28), (58, 27)])
# the washed-out tributary crossing (the trail still leads there...)
trail([(41, 29), (43, 27), (43, 19)])
# far-east crossing of the tributary, up the south stairs
trail([(58, 27), (58, 19), (57, 16), (56, 13)])
# plateau: west stairs -> north rim -> summit
trail([(38, 6), (44, 5), (48, 7)])
# summit trail to the ruins
trail([(49, 7), (54, 5), (58, 4)])

bridge(20, 7, True)          # north rope bridge
bridge(24, 31, True)         # south bridge (delta)
bridge(58, 24, False)        # east bridge over the tributary
bridge(43, 24, False, 'b')   # washed out — impassable, drawn as broken planks

# --- slopes (stairs) -----------------------------------------------------
def make_slope(cells):
    for x, y in cells:
        terrain[y][x] = 's'

def boundary_cells_near(px, py, upper, r=2.6):
    """Upper-level cells next to a lower-level cell, near a point."""
    out = []
    for y in range(H):
        for x in range(W):
            if height[y][x] != upper or (x - px) ** 2 + (y - py) ** 2 > r * r:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if inb(nx, ny) and height[ny][nx] == upper - 1:
                    out.append((x, y)); break
    return out

slopes = [
    (32, 6, 1),   # plateau west stairs (north route)
    (57, 17, 1),  # plateau south stairs (south route)
    (48, 7, 2),   # summit west stairs
    (56, 12, 2),  # summit south stairs
    (8, 18, 1),   # Lookout Hill south
    (13, 8, 1),   # Lookout Hill north-east
    (44, 20, 1),  # stairs past the washed-out bridge
]
for (px, py, up) in slopes:
    cells = boundary_cells_near(px, py, up)
    assert cells, "no cliff edge near stairs at %s" % ((px, py),)
    make_slope(cells)

# start and goal
terrain[34][4] = 'S'
terrain[4][59] = 'G'

# ---------------------------------------------------------------- solver
SPEED = {'.': 1.0, 'p': 1.25, 'f': 0.5, 'm': 0.45, 's': 0.8, '=': 1.1, 'S': 1.0, 'G': 1.0}

def passable(x, y):
    return terrain[y][x] in SPEED

def can_step(ax, ay, bx, by):
    if not passable(bx, by):
        return False
    ha, hb = height[ay][ax], height[by][bx]
    if ha == hb:
        return True
    if abs(ha - hb) == 1 and (terrain[ay][ax] == 's' or terrain[by][bx] == 's'):
        return True
    return False

def find(ch):
    for y in range(H):
        for x in range(W):
            if terrain[y][x] == ch:
                return x, y

def solve(block=None):
    sx, sy = find('S'); gx, gy = find('G')
    dist = {(sx, sy): 0.0}; prev = {}
    pq = [(0.0, sx, sy)]
    while pq:
        d, x, y = heapq.heappop(pq)
        if (x, y) == (gx, gy):
            path = [(x, y)]
            while path[-1] in prev:
                path.append(prev[path[-1]])
            return d, path[::-1]
        if d > dist[(x, y)]:
            continue
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if not inb(nx, ny) or (block and (nx, ny) in block):
                continue
            if can_step(x, y, nx, ny):
                nd = d + 1.0 / SPEED[terrain[ny][nx]]
                if nd < dist.get((nx, ny), 1e9):
                    dist[(nx, ny)] = nd; prev[(nx, ny)] = (x, y)
                    heapq.heappush(pq, (nd, nx, ny))
    return None, []

def render(path=()):
    ps = set(path)
    rows = []
    for y in range(H):
        rows.append(''.join('*' if (x, y) in ps and terrain[y][x] not in 'SG' else terrain[y][x]
                            for x in range(W)))
    return rows

TEMPLATE_HEAD = '''# Level 1 — "The Survey" (the jungle map he actually drew)
#
# Two ASCII layers, one character per 32px map cell. Edit freely; keep every
# row the same length. The level reloads these on scene start.
#
# TERRAIN legend
#   .  open ground         p  cut trail (fast)       f  jungle (slow)
#   m  marsh (very slow)   ~  river / lake (blocked) =  bridge
#   #  rock (blocked)      b  broken bridge (blocked)
#   s  stairs / slope — the only way between heights
#   S  start (camp)        G  goal (where the ink ends)
#
# HEIGHT legend: 0 lowland, 1 plateau, 2 summit.
# You can only step between different heights on an "s" cell.
extends RefCounted

'''


if __name__ == '__main__':
    cost, path = solve()
    assert path, "Level is not solvable!"
    print("fastest route cost:", round(cost, 1), "cells:", len(path))
    for r in render(path):
        print(r)
    print()
    for y in range(H):
        print(''.join(str(height[y][x]) for x in range(W)))
    # how much slower is each bridge-less alternative?
    bridges = {(x, y) for y in range(H) for x in range(W) if terrain[y][x] == '='}
    north = {b for b in bridges if b[1] < 15}
    south = {b for b in bridges if b[1] >= 15}
    print("north route only:", solve(south)[0])
    print("south route only:", solve(north)[0])

    if '--preview' not in sys.argv:
        out = os.path.join(os.path.dirname(__file__), '..', 'levels', 'level1', 'level1_data.gd')
        os.makedirs(os.path.dirname(out), exist_ok=True)
        with open(out, 'w') as f:
            f.write(TEMPLATE_HEAD)
            f.write('const TERRAIN := [\n')
            for r in render():
                f.write('\t"%s",\n' % r)
            f.write(']\n\n')
            f.write('const HEIGHT := [\n')
            for y in range(H):
                f.write('\t"%s",\n' % ''.join(str(height[y][x]) for x in range(W)))
            f.write(']\n')
        print("wrote", os.path.normpath(out))
