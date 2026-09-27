#!/usr/bin/env python3
"""
Finale labyrinth — "Waking" (three keys).

13 x 13 cells. Regions (x east, y south):
  sanctum   x5-7  y0-1   the Door of Light (X, north wall) behind the Black gate (K)
  west wing x0-3  y0-6   the Stone Key, behind the Iron gate (I): follow the right wisps
  east wing x9-12 y0-6   the Black Key, behind the Stone gate (T): the beast sleeps here
  silent    x0-1  y10-11 the Iron Key: the door (Q) shuts behind you
  main      the rest     a braided labyrinth; false doors of light (F) in its outer wall;
                         corridors that remember you (d: a door that becomes a wall,
                         e: a wall that becomes a door)

Writes levels/level3/level3_data.gd.   Usage: python3 tools/gen_level3.py [--preview]
"""
import random, sys, os, collections

N = 13
W = 2 * N + 1
rng = random.Random(4417)
g = [['#' if (x % 2 == 0 or y % 2 == 0) else ' ' for x in range(W)] for y in range(W)]
for y in range(0, W, 2):
    for x in range(0, W, 2):
        g[y][x] = '+'

def lat(c): return (2 * c[0] + 1, 2 * c[1] + 1)
def edge(a, b):
    (ax, ay), (bx, by) = lat(a), lat(b)
    return ((ax + bx) // 2, (ay + by) // 2)
def setc(c, ch):
    x, y = lat(c); g[y][x] = ch
def seted(a, b, ch=' '):
    x, y = edge(a, b); g[y][x] = ch
def carve(*cells):
    for a, b in zip(cells, cells[1:]):
        seted(a, b)
def room(x0, y0, x1, y1):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            if x < x1: seted((x, y), (x + 1, y))
            if y < y1: seted((x, y), (x, y + 1))

def region(c):
    x, y = c
    if 5 <= x <= 7 and y <= 1: return 'sanctum'
    if x <= 3 and y <= 6: return 'west'
    if x >= 9 and y <= 6: return 'east'
    if x <= 1 and 10 <= y <= 11: return 'silent'
    return 'main'

# ------------------------------------------------------------------ sanctum
room(5, 0, 7, 1)
x, y = edge((6, 0), (6, -1)); g[y][x] = 'X'
seted((6, 1), (6, 2), 'K')

# ------------------------------------------------------------------ west wing: the wisps
TRUE = [(3, 5), (2, 5), (2, 4), (1, 4), (1, 3), (1, 2), (2, 2), (2, 1), (1, 1), (0, 1), (0, 0)]
FALSE1 = [(3, 5), (3, 4), (3, 3), (3, 2), (3, 1), (3, 0), (2, 0), (1, 0)]
FALSE2 = [(3, 5), (3, 6), (2, 6), (1, 6), (0, 6), (0, 5), (0, 4), (0, 3), (0, 2)]
carve(*TRUE); carve(*FALSE1); carve(*FALSE2)
carve((3, 3), (2, 3)); carve((1, 6), (1, 5))
seted((3, 5), (4, 5), 'I')
setc((0, 0), '2')

# ------------------------------------------------------------------ east wing: the beast's hall
room(10, 1, 11, 2)
carve((9, 5), (9, 4), (9, 3)); seted((9, 3), (9, 2), 'D'); carve((9, 2), (10, 2))
carve((9, 2), (9, 1), (9, 0), (10, 0), (11, 0), (12, 0), (12, 1), (11, 1))
carve((12, 1), (12, 2), (12, 3), (12, 4), (11, 4), (11, 5), (12, 5), (12, 6), (11, 6))
carve((10, 2), (10, 3)); seted((10, 3), (10, 4), 'D'); carve((10, 4), (10, 5), (10, 6))
carve((10, 3), (11, 3)); carve((9, 5), (9, 6))
seted((10, 6), (10, 7), 'B')     # barred from the wing side: a way out, not in
seted((8, 5), (9, 5), 'T')
setc((11, 1), '3')
setc((12, 4), 'M')

# ------------------------------------------------------------------ the silent room
room(0, 10, 1, 11)
seted((1, 10), (2, 10), 'Q')
setc((0, 11), '1')

# ------------------------------------------------------------------ main: a braided maze
main = [(x, y) for y in range(N) for x in range(N) if region((x, y)) == 'main']
mains = set(main)
# the corridor of doors (alcoves above y=8, x=3..6) is built by hand: keep it out of the DFS
ALCOVES = [(3, 7), (4, 7), (5, 7), (6, 7)]
dfs_cells = mains - set(ALCOVES)
start = (6, 12)
seen = {start}; stack = [start]
while stack:
    c = stack[-1]
    nb = [(c[0] + dx, c[1] + dy) for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))]
    nb = [n for n in nb if n in dfs_cells and n not in seen]
    if not nb:
        stack.pop(); continue
    n = rng.choice(nb); seted(c, n); seen.add(n); stack.append(n)
assert seen == dfs_cells, "main not all carved"
# braid most dead ends so it loops
def opens(c):
    x, y = lat(c); out = []
    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        n = (c[0] + dx, c[1] + dy)
        if n in dfs_cells and g[y + dy][x + dx] != '#':
            out.append(n)
    return out
for c in sorted(dfs_cells, key=lambda c: rng.random()):
    if len(opens(c)) == 1 and rng.random() < 0.8:
        x, y = lat(c)
        closed = [(c[0] + dx, c[1] + dy) for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))
                  if (c[0] + dx, c[1] + dy) in dfs_cells and g[y + dy][x + dx] == '#']
        if closed:
            seted(c, rng.choice(closed))
# the corridor of doors: three doors, and a fourth that isn't there yet
carve((3, 8), (4, 8), (5, 8), (6, 8))
for a in ALCOVES[:3]:
    seted(a, (a[0], 8), 'D')
seted(ALCOVES[3], (6, 8), 'e')
# (the alcoves are closed rooms)
for a in ALCOVES:
    for b in ALCOVES:
        if abs(a[0] - b[0]) == 1:
            seted(a, b, '#')

setc(start, 'S')
# false doors of light, in the outer wall
for c, d in (((0, 8), (-1, 8)), ((3, 12), (3, 13)), ((12, 9), (13, 9))):
    x, y = edge(c, d); g[y][x] = 'F'
# a corridor that forgets its door: (11,11)|(11,10) (checked for loops below)
seted((11, 11), (11, 10), 'd')

# when you come out of the silent room, the way you came is gone:
# walls rise across the corridor north and south, and one sinks to the east
seted((2, 10), (2, 11), 'j'); seted((2, 9), (2, 10), 'j'); seted((2, 10), (3, 10), 'h')

# pages, wisps, rubble
for c in [(4, 3), (2, 9), (12, 12)]:
    setc(c, 'p')
for c in [(4, 0), (8, 1), (6, 4), (4, 6), (8, 6), (1, 8), (5, 9), (9, 9), (12, 8), (3, 11), (8, 11), (10, 12),
          (1, 3), (2, 6), (10, 0), (12, 6), (6, 0), (6, 10)]:
    setc(c, 'w')
for c in [(7, 3), (11, 12), (0, 12), (7, 9), (12, 11)]:
    setc(c, 'r')

rows = [''.join(r) for r in g]

# ------------------------------------------------------------------ checks
def kind(a, b):
    if not (0 <= b[0] < N and 0 <= b[1] < N): return '#'
    x, y = edge(a, b); return rows[y][x]
def reach(frm, passable):
    seen = {frm}; q = collections.deque([frm])
    while q:
        c = q.popleft()
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            n = (c[0] + dx, c[1] + dy)
            if n not in seen and kind(c, n) in passable:
                seen.add(n); q.append(n)
    return seen
free = reach(start, ' Ddej')
assert all(region(c) == 'main' for c in free - set(ALCOVES)), "a wing leaks into the main maze"
everything = reach(start, ' DdeQITKBj')
after_iron = reach(start, ' DdeQITKBh')
assert len(after_iron) == N * N, 'the iron change cuts the maze'
missing = [(x, y) for y in range(N) for x in range(N) if (x, y) not in everything]
assert not missing, "unreachable: %s" % missing
# the forgetting door must be on a loop
no_d = reach(start, ' Dej')
assert (11, 10) in no_d and (11, 11) in no_d, "closing the 'd' door would cut the maze"

if __name__ == '__main__':
    for r in rows: print(r)
    if '--preview' not in sys.argv:
        out = os.path.join(os.path.dirname(__file__), '..', 'levels', 'level3', 'level3_data.gd')
        with open(out, 'w') as f:
            f.write('''# Finale — "Waking": the labyrinth (three keys). Generated by tools/gen_level3.py.
#
# A grid of cells 3.5 m across. Characters sit on a (2N+1) x (2N+1) lattice:
#   corners   (even, even)  '+'  a stone pillar
#   edges     (odd/even)    '#'  wall     ' '  open     'D'  wooden door
#                           'I' 'T' 'K'  gates: iron, stone, black (need that key)
#                           'Q'  the silent room's door (it shuts behind you)
#                           'B'  a door barred on the wing side (opens only from there)
#                           'd'  a door that becomes a wall     'e'  a wall that becomes a door
#                           'X'  the Door of Light (outer wall)  'F'  a false door of light
#                           'h'  a wall that can sink            'j'  a gap a wall can rise into
#   cells     (odd, odd)    ' '  floor     'S'  where you wake     'M'  where the beast sleeps
#                           '1' '2' '3'  the Iron, Stone and Black keys
#                           'w'  will-o'-the-wisps   'p'  a torn page   'r'  rubble
extends RefCounted

const CELL := 3.5
const MAZE := [
''')
            for r in rows: f.write('\t"%s",\n' % r)
            f.write(']\n')
        print('wrote', os.path.normpath(out))
