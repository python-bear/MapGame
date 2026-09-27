#!/usr/bin/env python3
"""
Level 2 layout generator — "The Drowned Chart" (night crossing).

West → east:
  * the Mainland: a long coast with a harbour cove where the ship starts
  * the Open Deep: nothing but water (and whatever is under it)
  * the Shoals: small islands, reefs hugging their shores, narrow channels
  * the Landing: the goal island, pier on its west shore, three tents

Checks the pier can be reached, prints route times, writes
levels/level2/level2_data.gd. After that the ASCII is the source of truth.

Usage:  python3 tools/gen_level2.py [--preview]
"""
import math, sys, heapq, os, random

W, H = 128, 56
SEED = 23
rng = random.Random(SEED)

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

T = [['.' for _ in range(W)] for _ in range(H)]
def inb(x, y): return 0 <= x < W and 0 <= y < H

def blob(cx, cy, rx, ry, wobble=0.3, ns=3.0):
    out = []
    for y in range(max(0, int(cy - ry * 1.6)), min(H, int(cy + ry * 1.6) + 2)):
        for x in range(max(0, int(cx - rx * 1.6)), min(W, int(cx + rx * 1.6) + 2)):
            dx, dy = (x - cx) / rx, (y - cy) / ry
            if math.sqrt(dx * dx + dy * dy) < 1.0 + (noise(x + cx * 5, y + cy * 3, ns) - 0.5) * 2 * wobble:
                out.append((x, y))
    return out

def put(cells, ch, only='.'):
    for x, y in cells:
        if inb(x, y) and (only is None or T[y][x] in only):
            T[y][x] = ch

# ------------------------------------------------------------------ the Mainland
for y in range(H):
    coast = 15 + 4.0 * math.sin(y * 0.21) + 3.0 * (noise(3, y, 5.0) - 0.5) * 2
    for x in range(W):
        if x < coast:
            T[y][x] = 'L'
# headlands and the harbour cove the ship leaves from
put(blob(19, 13, 5, 4, 0.25), 'L', None)
put(blob(18, 44, 6, 5, 0.25), 'L', None)
for (x, y) in blob(15, 29, 4.5, 3.6, 0.1):
    T[y][x] = '.'
start = (17, 29)

# ------------------------------------------------------------------ the Shoals
# Two staggered chains of small islands. Their gaps don't line up, so the
# crossing is a zig-zag and the player has to pick a way through.
def chain(x0, gaps, seed):
    r = random.Random(seed)
    y = 1.5
    while y < H - 1:
        if any(abs(y - g) < 3.4 for g in gaps):
            y += 1.0
            continue
        cx = x0 + r.uniform(-2.5, 2.5)
        put(blob(cx, y, r.uniform(2.2, 3.6), r.uniform(2.0, 2.8), 0.3, 2.5), 'L', None)
        y += r.uniform(3.0, 4.2)

chain(73, gaps=[9, 28, 47], seed=5)     # first chain: the middle gap is the Maw
chain(93, gaps=[18, 38], seed=9)        # second chain: gaps offset from the first
# a few loose islets between the chains
for (cx, cy, rx, ry) in [(83, 18, 1.8, 1.6), (84, 38, 2.0, 1.7), (62, 12, 1.6, 1.4), (60, 44, 1.8, 1.5)]:
    put(blob(cx, cy, rx, ry, 0.3, 2.5), 'L', None)

# ------------------------------------------------------------------ the Landing
put(blob(117, 29, 8.5, 15.0, 0.22, 4.0), 'L', None)
for y in range(H):              # it runs off the east edge of the chart
    for x in range(122, W):
        if 12 <= y <= 46:
            T[y][x] = 'L'
pier_y = 30
x = 100
while T[pier_y][x] != 'L':
    x += 1
shore = x
for px in range(shore - 5, shore):
    T[pier_y][px] = 'P'
berth = (shore - 3, pier_y - 1)           # G marks the north berth (the south one works too)
T[berth[1]][berth[0]] = 'G'

# ------------------------------------------------------------------ reefs, hugging the shores
def near_land(x, y, lo, hi):
    best = 99
    for dy in range(-hi, hi + 1):
        for dx in range(-hi, hi + 1):
            if inb(x + dx, y + dy) and T[y + dy][x + dx] == 'L':
                best = min(best, max(abs(dx), abs(dy)))
    return lo <= best <= hi

cands = [(x, y) for y in range(2, H - 2) for x in range(58, 112)
         if T[y][x] == '.' and near_land(x, y, 2, 3) and abs(y - pier_y) > 4]
rng.shuffle(cands)
reefs = []
for c in cands:
    if len(reefs) >= 26:
        break
    if all(abs(c[0] - a) + abs(c[1] - b) > 6 for a, b in reefs):
        reefs.append(c)
for (cx, cy) in reefs:
    put(blob(cx, cy, 1.3, 1.1, 0.4, 1.5), 'r')
# a couple of reefs off the Mainland's headlands, and the harbour mouth's rocks
for (cx, cy) in [(24, 15), (24, 44), (21, 24), (21, 35)]:
    put(blob(cx, cy, 1.2, 1.0, 0.4, 1.5), 'r')

# wrecks on the reefs
for (x, y) in reefs[:4]:
    if T[y][x] == 'r':
        T[y][x] = 'w'

T[start[1]][start[0]] = 'S'

# ------------------------------------------------------------------ routes
# The Teeth (first chain): the top gap is long but safe, the Maw is fast and
# narrow (and guarded), and the bottom gap is choked with rocks.
for x in (72, 73):
    for y in range(43, H):
        if T[y][x] == '.':
            T[y][x] = 'r'
# The second chain: a channel that looks like a way through, and ends in a
# sandbar (z: shallow water, the ship runs aground — blocked).
for y in (27, 28):
    for x in range(86, 97):
        if T[y][x] == 'L':
            T[y][x] = '.'
for y in range(25, 31):
    for x in (95, 96, 97):
        if T[y][x] in '.L':
            T[y][x] = 'z'
# the north gap of the second chain is narrowed by a sandbar
for y in range(15, 19):
    for x in range(89, 96):
        if T[y][x] == '.':
            T[y][x] = 'z'

# ------------------------------------------------------------------ shallows
for y in range(H):
    for x in range(W):
        if T[y][x] == '.' and any(inb(x + dx, y + dy) and T[y + dy][x + dx] == 'L'
                                  for dx in (-1, 0, 1) for dy in (-1, 0, 1)):
            T[y][x] = ','

# ------------------------------------------------------------------ solver
SPEED = {'.': 1.0, ',': 0.75, 'S': 1.0, 'G': 1.0}

def solve(goals, block=()):
    dist = {start: 0.0}; prev = {}
    pq = [(0.0, start)]
    while pq:
        d, c = heapq.heappop(pq)
        if c in goals:
            path = [c]
            while path[-1] in prev: path.append(prev[path[-1]])
            return d, path[::-1]
        if d > dist[c]: continue
        x, y = c
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (1, -1), (-1, 1), (-1, -1)):
            nx, ny = x + dx, y + dy
            if not inb(nx, ny) or T[ny][nx] not in SPEED or (nx, ny) in block: continue
            if dx and dy and (T[y][nx] not in SPEED or T[ny][x] not in SPEED): continue
            nd = d + math.hypot(dx, dy) / SPEED[T[ny][nx]]
            if nd < dist.get((nx, ny), 1e9):
                dist[(nx, ny)] = nd; prev[(nx, ny)] = c
                heapq.heappush(pq, (nd, (nx, ny)))
    return None, []

def rows(path=()):
    ps = set(path)
    return [''.join('*' if (x, y) in ps and T[y][x] not in 'SG' else T[y][x] for x in range(W)) for y in range(H)]

TEMPLATE_HEAD = '''# Level 2 — "The Drowned Chart" (a night crossing)
#
# One ASCII layer, one character per 32px chart cell. Keep rows equal length.
#
#   .  open sea            ,  shallows (slower sailing)
#   L  land (blocked)      r  reef / rocks (blocked)
#   w  wreck (blocked)     P  pier (blocked) — dock on either side of it
#   z  sandbar — water too shallow to sail (blocked)
#   S  where the ship starts
#   G  the north berth (marks the pier; the south side works too)
extends RefCounted

'''

if __name__ == '__main__':
    south = (berth[0], pier_y + 1)
    cost, path = solve({berth, south})
    assert path, "pier unreachable!"
    cps = 180 / 32
    print("fastest: %.1f cells ~ %.1f s at top speed" % (cost, cost / cps))
    for r in rows(path): print(r)
    if '--preview' not in sys.argv:
        out = os.path.join(os.path.dirname(__file__), '..', 'levels', 'level2', 'level2_data.gd')
        with open(out, 'w') as f:
            f.write(TEMPLATE_HEAD)
            f.write('const TERRAIN := [\n')
            for r in rows():
                f.write('\t"%s",\n' % r)
            f.write(']\n')
        print("wrote", os.path.normpath(out))
