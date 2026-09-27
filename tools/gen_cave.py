#!/usr/bin/env python3
"""
The cave before the finale ("The Hollow"): builds everything the level needs.

  * the cave itself: winding tunnels, a painted chamber, a bone alcove, a dead
    end and a loop, cut out of solid rock as a signed-distance field and meshed
    with marching cubes -> levels/cave/mesh/cave_<i>.obj (one per 16 m tile)
  * rough rock and packed-dirt textures (+ normal maps) -> assets/textures/
  * the ochre / dark red cave paintings (RGBA)            -> levels/cave/paintings/
  * where everything goes (paintings on flattened bits of wall, the bones,
    the mouth, the door, a walking route for the test bot) -> levels/cave/cave_data.gd

    python3 tools/gen_cave.py            (numpy, scipy, scikit-image, Pillow)

Coordinates are Godot world metres: x east, y up, z south. The mouth is at the
south edge, the door to the labyrinth near the north edge.
"""
import os
import math
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
from scipy import ndimage
from skimage import measure

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..')
LVL = os.path.join(ROOT, 'levels', 'cave')
TEX = os.path.join(ROOT, 'assets', 'textures')
for d in (os.path.join(LVL, 'mesh'), os.path.join(LVL, 'paintings'), TEX):
    os.makedirs(d, exist_ok=True)
rng = np.random.default_rng(11)

# ============================================================== the layout
# Each passage: control points (x, z, floor_y, half_width, height). They are
# smoothed into winding curves. Floors fall gently: the cave goes down.
PATHS = {
    # the mouth (starts past the south edge) winding north to the fork
    'A': [(32, 66, 0.0, 2.6, 4.2), (32, 61, 0.0, 2.3, 3.8), (30.5, 56, -0.2, 1.9, 3.2), (27, 50.5, -0.5, 1.8, 3.0),
          (29.5, 44.5, -0.8, 1.7, 2.9), (34, 39.5, -1.0, 1.8, 3.0), (31, 34, -1.1, 2.1, 3.3)],
    # west from the fork, to the bones
    'B': [(31, 34, -1.1, 2.1, 3.3), (25, 32.5, -1.3, 1.6, 2.8), (19.5, 35.5, -1.5, 1.6, 2.7), (14.5, 34.5, -1.6, 1.6, 2.7),
          (11.5, 30.5, -1.7, 1.8, 2.9)],
    # north from the fork to the painted chamber
    'C': [(31, 34, -1.1, 2.1, 3.3), (36, 29, -1.5, 1.7, 2.9), (34.5, 24, -1.9, 1.7, 3.0), (30.5, 20, -2.3, 1.9, 3.2)],
    # from the chamber east and north, winding, to the door
    'D': [(33, 12.5, -2.6, 1.9, 3.2), (39, 15, -2.9, 1.7, 3.0), (45, 17, -3.2, 1.7, 3.0), (49.5, 12.5, -3.6, 1.8, 3.1),
          (47.5, 7.5, -3.9, 1.9, 3.3), (46, 4.5, -4.0, 2.1, 3.7)],
    # a loop: from the chamber west and south, back into the bones passage
    'E': [(24, 13, -2.5, 1.7, 3.0), (19, 16.5, -2.2, 1.5, 2.7), (16, 22.5, -1.9, 1.5, 2.6), (17.5, 29, -1.6, 1.5, 2.6),
          (19.5, 35.5, -1.5, 1.6, 2.7)],
    # a dead end off the way to the door
    'F': [(45, 17, -3.2, 1.7, 3.0), (50.5, 22, -3.3, 1.5, 2.7), (54.5, 26.5, -3.4, 1.5, 2.6), (55.5, 31.5, -3.5, 1.8, 2.9)],
}
# rooms: (x, z, floor_y, radius, height)
ROOMS = {
    'painted': (29, 14, -2.5, 6.2, 5.6),
    'bones': (9.5, 27, -1.8, 3.5, 3.6),
    'mouth': (32, 61.5, 0.0, 3.2, 4.6),
}
DOOR = dict(x=46.0, z=4.0, floor=-4.0, width=1.7, height=2.7)   # the face of the door wall is at z = DOOR z
MOUTH_Z = 63.4        # the daylight plane
SEAL_Z = 58.0         # where the rock closes over the mouth
SPAWN = (32.0, 0.0, 60.2)

VOX = 0.25
X0, X1, Z0, Z1, Y0, Y1 = 0.0, 64.0, 0.0, 64.0, -7.0, 6.0
nx, nz, ny = int((X1 - X0) / VOX) + 1, int((Z1 - Z0) / VOX) + 1, int((Y1 - Y0) / VOX) + 1
xs = X0 + np.arange(nx) * VOX
zs = Z0 + np.arange(nz) * VOX
ys = Y0 + np.arange(ny) * VOX


def catmull(points, step=0.35):
    """Smooth a list of control points (tuples) into a dense curve."""
    P = np.array(points, float)
    P = np.vstack([P[0] * 2 - P[1], P, P[-1] * 2 - P[-2]])
    out = []
    for i in range(1, len(P) - 2):
        p0, p1, p2, p3 = P[i - 1], P[i], P[i + 1], P[i + 2]
        seg = np.hypot(*(p2[:2] - p1[:2]))
        n = max(2, int(seg / step))
        for t in np.linspace(0, 1, n, endpoint=False):
            t2, t3 = t * t, t * t * t
            out.append(0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (-p0 + 3 * p1 - 3 * p2 + p3) * t3))
    out.append(P[-2])
    return np.array(out)


CURVES = {k: catmull(v) for k, v in PATHS.items()}


def value_noise3(shape, cells, seed):
    r = np.random.default_rng(seed)
    g = r.random(tuple(max(2, int(s / cells) + 2) for s in shape))
    return ndimage.zoom(g, [s / (g.shape[i] - 1) * 1.0001 for i, s in enumerate(shape)], order=3)[:shape[0], :shape[1], :shape[2]]


def fbm3(shape, seed):
    out = np.zeros(shape, np.float32)
    amp, tot = 1.0, 0.0
    for o, cells in enumerate((24, 12, 6, 3)):
        out += amp * value_noise3(shape, cells, seed + o).astype(np.float32)
        tot += amp
        amp *= 0.5
    return out / tot - 0.5


# ---------------------------------------------------------- 2D fields per passage
GX, GZ = np.meshgrid(xs, zs, indexing='ij')                  # (nx, nz)
warp_x = (fbm3((nx, nz, 2), 3)[:, :, 0]) * 1.6               # wobble the walls sideways
warp_z = (fbm3((nx, nz, 2), 5)[:, :, 0]) * 1.6
WX, WZ = GX + warp_x, GZ + warp_z


def nearest_on_curve(curve):
    """Per (x,z) column: distance to the curve and the curve's floor/width/height there."""
    best = np.full(GX.shape, 1e9, np.float32)
    attrs = np.zeros(GX.shape + (3,), np.float32)
    for i in range(len(curve) - 1):
        a, b = curve[i], curve[i + 1]
        ab = b[:2] - a[:2]
        L2 = max(ab @ ab, 1e-9)
        t = np.clip(((WX - a[0]) * ab[0] + (WZ - a[1]) * ab[1]) / L2, 0, 1)
        px, pz = a[0] + ab[0] * t, a[1] + ab[1] * t
        d = np.hypot(WX - px, WZ - pz)
        closer = d < best
        best = np.where(closer, d, best)
        for k in range(3):
            attrs[..., k] = np.where(closer, a[2 + k] + (b[2 + k] - a[2 + k]) * t, attrs[..., k])
    return best, attrs


def section_sdf(dh, floor, half_w, height):
    """A tunnel's cross-section: an arch over a flat floor. <0 inside the cave."""
    Y = ys[None, None, :]
    y0 = floor[..., None] + height[..., None] * 0.5 - 0.35
    b = height[..., None] * 0.5 + 0.35
    a = half_w[..., None]
    e = np.sqrt((dh[..., None] / a) ** 2 + ((Y - y0) / b) ** 2) - 1.0
    s = e * np.minimum(a, b)
    return np.maximum(s, floor[..., None] - Y)


def smin(a, b, k=1.2):
    h = np.clip(0.5 + 0.5 * (b - a) / k, 0, 1)
    return b * (1 - h) + a * h - k * h * (1 - h)


print('carving the cave …')
sdf = np.full((nx, nz, ny), 4.0, np.float32)
floor_map = np.full((nx, nz), -9.0, np.float32)
for key, curve in CURVES.items():
    dh, at = nearest_on_curve(curve)
    s = section_sdf(dh, at[..., 0], at[..., 1], at[..., 2])
    sdf = smin(sdf, s.astype(np.float32))
    floor_map = np.where(dh < at[..., 1] + 1.0, np.maximum(floor_map, at[..., 0]), floor_map)
for key, (rx, rz, fl, rad, hh) in ROOMS.items():
    dh = np.hypot(WX - rx, WZ - rz).astype(np.float32)
    s = section_sdf(dh, np.full(dh.shape, fl, np.float32), np.full(dh.shape, rad, np.float32), np.full(dh.shape, hh, np.float32))
    sdf = smin(sdf, s.astype(np.float32), 1.6)
    floor_map = np.where(dh < rad + 1.0, np.maximum(floor_map, fl), floor_map)

# rough rock: big lumps on the walls and ceiling, much less on the floor
Y3 = ys[None, None, :]
height_above_floor = Y3 - floor_map[..., None]
wall_w = np.clip(height_above_floor / 0.8, 0.12, 1.0)
noise = fbm3(sdf.shape, 21) * 1.5 + fbm3(sdf.shape, 41) * 0.35
sdf += noise * 0.55 * wall_w

# stalactites in the high rooms, and a few boulders on the floor by the walls
def add_rock(center, radius, stretch=(1, 1, 1)):
    global sdf
    ix = slice(max(0, int((center[0] - radius * 3 - X0) / VOX)), min(nx, int((center[0] + radius * 3 - X0) / VOX) + 2))
    iz = slice(max(0, int((center[2] - radius * 3 - Z0) / VOX)), min(nz, int((center[2] + radius * 3 - Z0) / VOX) + 2))
    iy = slice(max(0, int((center[1] - radius * 3 * stretch[1] - Y0) / VOX)), min(ny, int((center[1] + radius * 3 * stretch[1] - Y0) / VOX) + 2))
    X, Z, Y = np.meshgrid(xs[ix], zs[iz], ys[iy], indexing='ij')
    d = np.sqrt(((X - center[0]) / stretch[0]) ** 2 + ((Y - center[1]) / stretch[1]) ** 2 + ((Z - center[2]) / stretch[2]) ** 2) - radius
    sdf[ix, iz, iy] = np.maximum(sdf[ix, iz, iy], -d * min(stretch))

for (rx, rz, fl, rad, hh) in (ROOMS['painted'], ROOMS['mouth']):
    for k in range(16 if rad > 5 else 6):
        a = rng.uniform(0, math.tau)
        r = rng.uniform(0.25, 0.8) * rad
        ceil = fl + hh - 0.4 - (r / rad) ** 2 * hh * 0.45
        length = min(rng.uniform(0.5, 1.4), ceil - (fl + 2.3))
        if length < 0.3:
            continue
        add_rock((rx + math.cos(a) * r, ceil - length * 0.4, rz + math.sin(a) * r), rng.uniform(0.12, 0.22), (1, length * 2.8, 1))
# boulders: tucked against the walls at a few bends
BOULDERS = []
for key, idx, side in (('A', 30, 1), ('A', 60, -1), ('C', 18, 1), ('D', 40, -1), ('D', 75, 1), ('E', 30, 1), ('F', 25, -1), ('B', 40, 1)):
    cv = CURVES[key]
    i = min(idx, len(cv) - 2)
    t = cv[i + 1][:2] - cv[i][:2]
    t /= np.linalg.norm(t)
    nrm2 = np.array([-t[1], t[0]]) * side
    BOULDERS.append(tuple(cv[i][:2] + nrm2 * (cv[i][3] + 0.2)))
for bx, bz in BOULDERS:
    fl = floor_map[int((bx - X0) / VOX), int((bz - Z0) / VOX)]
    add_rock((bx, fl + 0.1, bz), rng.uniform(0.45, 0.75), (1.3, 0.7, 1.1))

# the door: a flat face of rock across the end of the passage, with a doorway
# cut through it into the light
DX, DZ, DF = DOOR['x'], DOOR['z'], DOOR['floor']
Xg, Zg = GX[..., None], GZ[..., None]
region = (np.abs(Xg - DX) < 5.0) & (Zg < DZ + 2.5)
sdf = np.where(region, np.maximum(sdf, DZ - Zg), sdf)
box = np.maximum(np.maximum(np.abs(Xg - DX) - (DOOR['width'] / 2 + 0.25), np.abs(Zg - (DZ - 1.2)) - 1.25),
                 np.maximum(DF - Y3, Y3 - (DF + DOOR['height'] + 0.25)))
sdf = np.minimum(sdf, box)


# ---------------------------------------------------------- paintings: find the wall, flatten it
def sample(p):
    """Trilinear sample of the SDF at a world point."""
    fx, fz, fy = (p[0] - X0) / VOX, (p[2] - Z0) / VOX, (p[1] - Y0) / VOX
    return ndimage.map_coordinates(sdf, [[fx], [fz], [fy]], order=1, mode='nearest')[0]


def floor_at(x, z):
    return float(floor_map[int(round((x - X0) / VOX)), int(round((z - Z0) / VOX))])


# (texture, anchor x, z, direction to the wall (degrees; 0 = east, 90 = south), centre height, w, h, his thought)
PAINTINGS = [
    ('hands', 30.2, 55.5, 180, 1.55, 1.7, 1.2,
     "Hands. Dozens of them, blown in red around the fingers. Children's, some of them."),
    ('hunt', 28.4, 47.6, 0, 1.6, 2.4, 1.3,
     "A hunt. Deer, and little men with spears. Someone lived here, once."),
    ('dragged', 9.0, 27.2, 180, 1.7, 2.1, 1.5,
     "People, and long arms reaching out of a circle. The arms are pulling them in."),
    ('monster', 28.8, 14.0, 270, 2.35, 3.4, 2.4,
     "It has no face. Just the eye, and the arms. They painted it bigger than anything else."),
    ('cave_map', 29.0, 14.0, 318, 1.75, 2.0, 1.8,
     "A map. Of this cave — the bends, the rooms… and a door, at the end, with the sign over it."),
    ('land_map', 29.0, 14.0, 218, 1.7, 2.1, 1.6,
     "Rivers, and a ring of hills. That bend is where we made camp. I drew that bend yesterday."),
    ('procession', 43.0, 16.6, 270, 1.6, 2.6, 1.2,
     "A line of people walking into the ring. None of them are walking out."),
    ('spiral', 55.4, 31.2, 0, 1.55, 1.7, 1.6,
     "Spirals, going in and in. I keep thinking they are moving."),
]
placed = []
for tex, ax, az, deg, hgt, w, h, line in PAINTINGS:
    fl = floor_at(ax, az)
    if sample(np.array([ax, fl + hgt, az])) > 0:
        print('  !! painting %s anchor is inside rock' % tex)
    d = np.array([math.cos(math.radians(deg)), 0.0, math.sin(math.radians(deg))])
    p = np.array([ax, fl + hgt, az])
    for step in range(200):
        if sample(p) > 0.0:
            break
        p = p + d * 0.05
    hit = p - d * 0.05
    n_in = -d                                                  # from the wall into the cave
    tang = np.array([-n_in[2], 0.0, n_in[0]])
    # flatten: blend the rock towards the plane through `hit`
    X, Z, Y = np.meshgrid(xs, zs, ys, indexing='ij', sparse=True)
    rel_x, rel_y, rel_z = X - hit[0], Y - hit[1], Z - hit[2]
    u = rel_x * tang[0] + rel_z * tang[2]
    v = rel_y
    dd = rel_x * n_in[0] + rel_z * n_in[2]
    e = np.sqrt((u / (w / 2 + 0.7)) ** 2 + (v / (h / 2 + 0.6)) ** 2)
    # cut away rock in front of the plane, but only ever fill a thin skin behind
    # it (so a passage on the other side of the wall is never sealed)
    wgt = np.clip((1.25 - e) / 0.45, 0, 1) * np.clip((1.8 - dd) / 0.6, 0, 1) * np.clip((dd + 0.9) / 0.4, 0, 1)
    wgt = wgt * wgt * (3 - 2 * wgt)
    plane = -dd
    sdf = (sdf * (1 - wgt) + plane * wgt).astype(np.float32)
    placed.append(dict(tex=tex, pos=hit + n_in * 0.03, normal=n_in, size=(w, h), line=line))
    print('  painting %-10s at (%.1f, %.1f, %.1f)' % (tex, *hit))

# check every part of the cave can be walked to (at chest height above the floor)
iy = np.clip(((floor_map + 1.2 - Y0) / VOX).astype(int), 0, ny - 1)
sl = np.take_along_axis(sdf, iy[..., None], 2)[..., 0]
lab, _ = ndimage.label(sl < -0.3)
def cell(x, z):
    return int((x - X0) / VOX), int((z - Z0) / VOX)
home = lab[cell(SPAWN[0], SPAWN[2])]
for name, (x, z) in {'fork': (31, 34), 'bones': (9.5, 27), 'painted room': (29, 14), 'dead end': (55.5, 31.5),
                     'loop': (16, 22.5), 'door': (DOOR['x'], DOOR['z'] + 1.0)}.items():
    ok = lab[cell(x, z)] == home and home != 0
    print('  reach %-12s %s' % (name, 'ok' if ok else '!! BLOCKED'))
    if not ok:
        raise SystemExit('the cave is cut in two - move a painting or a boulder')
if os.environ.get('CAVE_DEBUG'):
    img = np.where(sl < 0, 220, 30).astype(np.uint8).T
    Image.fromarray(img).resize((nx * 3, nz * 3), Image.NEAREST).save(os.environ['CAVE_DEBUG'])

# solid rock all round the edge of the volume, so the mesh is closed
sdf[0, :, :] = sdf[-1, :, :] = 1
sdf[:, 0, :] = sdf[:, -1, :] = 1
sdf[:, :, 0] = sdf[:, :, -1] = 1

# ---------------------------------------------------------- mesh it
print('meshing …')
verts, faces, _, _ = measure.marching_cubes(sdf, level=0.0, spacing=(VOX, VOX, VOX))
verts = verts[:, [0, 2, 1]] + np.array([X0, Y0, Z0])          # (x, z, y) index order -> world x, y, z
gx, gz, gy = np.gradient(sdf, VOX)
coords = [(verts[:, 0] - X0) / VOX, (verts[:, 2] - Z0) / VOX, (verts[:, 1] - Y0) / VOX]
nrm = -np.stack([ndimage.map_coordinates(g, coords, order=1) for g in (gx, gy, gz)], -1)
nrm /= np.linalg.norm(nrm, axis=1, keepdims=True) + 1e-9          # points into the open cave
# wind every triangle counter-clockwise seen from the cave side (OBJ convention)
fn = np.cross(verts[faces[:, 1]] - verts[faces[:, 0]], verts[faces[:, 2]] - verts[faces[:, 0]])
flip = (fn * nrm[faces].mean(1)).sum(1) < 0
faces[flip] = faces[flip][:, [0, 2, 1]]
# drop the outside of the block (faces whose normal points out of the volume's hull are never seen)
print('  %d vertices, %d triangles' % (len(verts), len(faces)))

TILE = 16.0
for f in os.listdir(os.path.join(LVL, 'mesh')):
    if f.startswith('cave_') and f.endswith('.obj'):
        os.remove(os.path.join(LVL, 'mesh', f))
cent = verts[faces].mean(1)
tiles = np.floor((cent[:, 0] - X0) / TILE).astype(int) * 10 + np.floor((cent[:, 2] - Z0) / TILE).astype(int)
chunks = []
for t in sorted(set(tiles.tolist())):
    fsel = faces[tiles == t]
    used, inv = np.unique(fsel.ravel(), return_inverse=True)
    fl = inv.reshape(-1, 3) + 1
    name = 'cave_%02d.obj' % t
    with open(os.path.join(LVL, 'mesh', name), 'w') as fh:
        fh.write('# generated by tools/gen_cave.py\no cave_%02d\n' % t)
        fh.write(''.join('v %.3f %.3f %.3f\n' % tuple(v) for v in verts[used]))
        fh.write(''.join('vn %.3f %.3f %.3f\n' % tuple(v) for v in nrm[used]))
        fh.write(''.join('f %d//%d %d//%d %d//%d\n' % (a, a, b, b, c, c) for a, b, c in fl))
    chunks.append(name)
print('  %d tiles' % len(chunks))


# ================================================================ textures
def tile_noise(size, cells, octaves=4, seed=0):
    r = np.random.default_rng(seed)
    out = np.zeros((size, size))
    amp, total = 1.0, 0.0
    for o in range(octaves):
        n = cells * 2 ** o
        grid = r.random((n, n))
        xs_ = np.linspace(0, n, size, endpoint=False)
        x0 = np.floor(xs_).astype(int)
        fx = xs_ - x0
        fx = fx * fx * (3 - 2 * fx)
        x1 = (x0 + 1) % n
        a = grid[np.ix_(x0, x0)]; b = grid[np.ix_(x0, x1)]
        c = grid[np.ix_(x1, x0)]; d = grid[np.ix_(x1, x1)]
        fy = fx[:, None]; fxx = fx[None, :]
        out += amp * ((a * (1 - fxx) + b * fxx) * (1 - fy) + (c * (1 - fxx) + d * fxx) * fy)
        total += amp
        amp *= 0.5
    return out / total


def normal_from_height(h, strength=4.0):
    dx = (np.roll(h, -1, 1) - np.roll(h, 1, 1)) * 0.5
    dy = (np.roll(h, -1, 0) - np.roll(h, 1, 0)) * 0.5
    nx_, ny_ = -dx * strength, dy * strength
    nz_ = np.ones_like(h)
    l = np.sqrt(nx_ ** 2 + ny_ ** 2 + nz_ ** 2)
    return ((np.stack([nx_ / l, ny_ / l, nz_ / l], -1) * 0.5 + 0.5) * 255).astype(np.uint8)


def save_tex(name, rgb, height, strength):
    Image.fromarray(np.clip(rgb * 255, 0, 255).astype(np.uint8)).save(os.path.join(TEX, name + '_albedo.png'))
    Image.fromarray(normal_from_height(height, strength)).save(os.path.join(TEX, name + '_normal.png'))
    print('wrote', name)


def worley(size, n, seed):
    """Tileable cellular noise: distance to nearest and second-nearest point."""
    r = np.random.default_rng(seed)
    pts = r.random((n, 2))
    y, x = np.mgrid[0:size, 0:size] / size
    d1 = np.full((size, size), 9.0)
    d2 = np.full((size, size), 9.0)
    for px, py in pts:
        for ox in (-1, 0, 1):
            for oy in (-1, 0, 1):
                d = np.sqrt((x - px - ox) ** 2 + (y - py - oy) ** 2)
                d2 = np.where(d < d1, d1, np.minimum(d2, d))
                d1 = np.minimum(d1, d)
    return d1, d2


def cave_rock(size=1024):
    """Rough broken stone: fractured plates with bulging faces, flakes and grit,
    grey stone mottled with reddish earth and damp dark patches (3 m tile)."""
    n1 = tile_noise(size, 5, 6, 31)
    n2 = tile_noise(size, 16, 5, 32)
    n3 = tile_noise(size, 48, 3, 33)
    grit = tile_noise(size, 180, 2, 36)
    # fractures: warped cellular edges, and only some of them open up
    warp = lambda img, amt, sd: ndimage.map_coordinates(
        img, [np.mgrid[0:size, 0:size][0] + (tile_noise(size, 6, 3, sd) - 0.5) * amt,
              np.mgrid[0:size, 0:size][1] + (tile_noise(size, 6, 3, sd + 1) - 0.5) * amt], order=1, mode='wrap')
    d1, d2 = worley(size, 22, 39)
    edge = warp(d2 - d1, size * 0.18, 70)
    showing = np.clip((tile_noise(size, 5, 3, 72) - 0.38) * 3.0, 0, 1)
    crack = (1 - np.clip(edge / 0.035, 0, 1)) * showing
    fd1, fd2 = worley(size, 80, 40)
    flakes = warp(np.clip((fd2 - fd1) / 0.03, 0, 1), size * 0.08, 74)
    ledges = np.floor(warp(tile_noise(size, 7, 3, 37), size * 0.1, 76) * 6) / 6
    height = n1 * 0.3 + n2 * 0.22 + ledges * 0.2 + flakes * 0.1 + n3 * 0.1 + grit * 0.06 - crack * 0.35
    stone = np.array([0.42, 0.39, 0.36])
    earth = np.array([0.40, 0.27, 0.17])
    mix = np.clip((tile_noise(size, 4, 4, 35) - 0.42) * 2.5, 0, 1)
    rgb = stone * (1 - mix[..., None]) + earth * mix[..., None]
    rgb = rgb * (0.66 + 0.5 * height[..., None]) * (0.82 + 0.36 * grit[..., None])
    damp = np.clip((tile_noise(size, 3, 3, 38) - 0.55) * 3, 0, 1)
    rgb *= (1 - damp[..., None] * 0.35) * (1 - crack[..., None] * 0.5)
    save_tex('cave_rock', rgb, height, 8.0)


def cave_dirt(size=1024):
    """Packed earth with grit and a few pebbles (2 m tile)."""
    n1 = tile_noise(size, 6, 5, 41)
    n2 = tile_noise(size, 64, 2, 42)
    height = n1 * 0.5 + n2 * 0.25
    yy, xx = np.mgrid[0:size, 0:size] / size
    peb = np.zeros((size, size))
    r = np.random.default_rng(43)
    for _ in range(140):
        cx, cy, rad = r.random(), r.random(), r.uniform(0.004, 0.018)
        for ox in (-1, 0, 1):
            for oy in (-1, 0, 1):
                d = np.sqrt((xx - cx - ox) ** 2 + (yy - cy - oy) ** 2) / rad
                peb = np.maximum(peb, np.clip(1 - d * d, 0, 1))
    height = height + peb * 0.6
    dirt = np.array([0.30, 0.22, 0.15]) * (0.7 + 0.5 * n1[..., None]) * (0.85 + 0.3 * n2[..., None])
    pebble = np.array([0.38, 0.36, 0.33]) * (0.8 + 0.4 * n2[..., None])
    rgb = dirt * (1 - (peb > 0.05)[..., None] * 0.9) + pebble * (peb > 0.05)[..., None] * 0.9
    save_tex('cave_dirt', rgb, height, 5.0)


# ================================================================ paintings
S = 1024
OCHRE = (178, 86, 34)
RED = (112, 22, 14)
BLACK = (28, 20, 16)


class Canvas:
    """Several pigment layers drawn as masks, then rubbed onto rough rock."""

    def __init__(self, w=S, h=S):
        self.w, self.h = w, h
        self.layers = []

    def layer(self, color):
        m = Image.new('L', (self.w, self.h), 0)
        self.layers.append((color, m))
        return ImageDraw.Draw(m)

    def save(self, name, seed=0):
        grain = tile_noise(max(self.w, self.h), 64, 3, 50 + seed)[:self.h, :self.w]
        blot = tile_noise(max(self.w, self.h), 8, 4, 60 + seed)[:self.h, :self.w]
        rgb = np.zeros((self.h, self.w, 3))
        alpha = np.zeros((self.h, self.w))
        for color, m in self.layers:
            m = m.filter(ImageFilter.GaussianBlur(2.2))
            a = np.asarray(m, float) / 255.0
            # pigment doesn't take evenly on stone: faded patches and grit
            a = a * np.clip(0.55 + 0.7 * blot, 0.25, 1.0) * np.clip(0.5 + grain * 0.9, 0, 1)
            a = np.clip(a * 1.25, 0, 0.92)
            c = np.array(color) / 255.0
            rgb = rgb * (1 - a[..., None]) + c * a[..., None]
            alpha = alpha + a * (1 - alpha)
        out = np.dstack([rgb / np.maximum(alpha[..., None], 1e-4), alpha])
        Image.fromarray(np.clip(out * 255, 0, 255).astype(np.uint8), 'RGBA').save(os.path.join(LVL, 'paintings', name + '.png'))
        print('wrote painting', name)


def wobbly(d, pts, width, r):
    pts = [(x + r.normal(0, 2), y + r.normal(0, 2)) for x, y in pts]
    d.line(pts, fill=255, width=width, joint='curve')
    for x, y in (pts[0], pts[-1]):
        d.ellipse([x - width / 2, y - width / 2, x + width / 2, y + width / 2], fill=255)


def tentacle(d, x, y, ang, length, w0, r, curl=2.5, seg=26):
    pts = []
    phase = r.uniform(0, math.tau)
    for i in range(seg + 1):
        t = i / seg
        a = ang + math.sin(t * curl * math.pi + phase) * 0.6 * t + t * t * r.uniform(-1.2, 1.2)
        x += math.cos(a) * length / seg
        y += math.sin(a) * length / seg
        pts.append((x, y))
    for i in range(seg):
        w = max(2, int(w0 * (1 - i / seg) ** 0.9))
        d.line([pts[i], pts[i + 1]], fill=255, width=w)
        d.ellipse([pts[i][0] - w / 2, pts[i][1] - w / 2, pts[i][0] + w / 2, pts[i][1] + w / 2], fill=255)
    return pts


def hand(d, cx, cy, scale, ang, r):
    """A hand, fingers up when ang = 0, as a filled shape."""
    ca, sa = math.cos(ang), math.sin(ang)

    def tr(px, py):
        return (cx + (px * ca - py * sa) * scale, cy + (px * sa + py * ca) * scale)
    palm = [tr(math.cos(t) * 0.42, 0.42 + math.sin(t) * 0.45) for t in np.linspace(0, math.tau, 24, endpoint=False)]
    d.polygon(palm, fill=255)
    w = max(3, int(scale * 0.2))
    for fx, ln, fa in ((-0.3, 0.55, -0.15), (-0.1, 0.7, -0.05), (0.1, 0.72, 0.03), (0.3, 0.6, 0.12), (0.42, 0.45, 1.0)):
        bx, by = tr(fx, 0.05 if fx < 0.4 else 0.45)
        a = ang + fa - math.pi / 2
        ex, ey = bx + math.cos(a) * ln * scale, by + math.sin(a) * ln * scale
        d.line([(bx, by), (ex, ey)], fill=255, width=w)
        d.ellipse([ex - w / 2, ey - w / 2, ex + w / 2, ey + w / 2], fill=255)


def paint_hands():
    r = np.random.default_rng(1)
    c = Canvas(S, int(S * 0.72))
    red, ochre = c.layer(RED), c.layer(OCHRE)
    spray = Image.new('L', (c.w, c.h), 0)
    sd = ImageDraw.Draw(spray)
    holes = Image.new('L', (c.w, c.h), 0)
    hd = ImageDraw.Draw(holes)
    for i in range(11):
        cx, cy = r.uniform(120, c.w - 120), r.uniform(130, c.h - 110)
        sc = r.uniform(70, 120) * (0.6 if i % 4 == 0 else 1.0)
        a = r.uniform(-0.5, 0.5)
        sd.ellipse([cx - sc * 1.3, cy - sc * 1.5, cx + sc * 1.3, cy + sc * 1.2], fill=int(r.uniform(150, 255)))
        hand(hd, cx, cy, sc, a, r)
    spray = spray.filter(ImageFilter.GaussianBlur(28))
    stencil = np.asarray(spray, float) * (1 - np.asarray(holes.filter(ImageFilter.GaussianBlur(1.5)), float) / 255.0)
    target = c.layers[0][1] if r.random() < 0.5 else c.layers[1][1]
    c.layers[0] = (RED, Image.fromarray(np.clip(stencil, 0, 255).astype(np.uint8)))
    # a few positive prints in ochre
    for i in range(4):
        hand(ochre, r.uniform(100, c.w - 100), r.uniform(100, c.h - 100), r.uniform(50, 70), r.uniform(-0.6, 0.6), r)
    c.save('hands', 1)


def deer(d, x, y, s, r, facing=1):
    body = [(x - 0.5 * s * facing, y), (x + 0.4 * s * facing, y - 0.05 * s)]
    d.ellipse([min(body[0][0], body[1][0]), y - 0.22 * s, max(body[0][0], body[1][0]), y + 0.18 * s], fill=255)
    hx, hy = x + 0.62 * s * facing, y - 0.38 * s
    d.line([(x + 0.35 * s * facing, y - 0.1 * s), (hx, hy)], fill=255, width=int(s * 0.14))
    d.ellipse([hx - 0.1 * s, hy - 0.07 * s, hx + 0.1 * s, hy + 0.07 * s], fill=255)
    for k in (-1, 1):                       # antlers
        d.line([(hx, hy), (hx - 0.1 * s * facing + k * 0.08 * s, hy - 0.35 * s)], fill=255, width=max(2, int(s * 0.03)))
        d.line([(hx - 0.05 * s * facing + k * 0.04 * s, hy - 0.18 * s), (hx + k * 0.16 * s, hy - 0.25 * s)], fill=255, width=max(2, int(s * 0.025)))
    for lx in (-0.38, -0.25, 0.22, 0.34):   # legs, mid-run
        kx = x + lx * s * facing
        d.line([(kx, y + 0.1 * s), (kx + r.uniform(-0.12, 0.12) * s, y + 0.55 * s)], fill=255, width=max(3, int(s * 0.05)))
    d.line([(x - 0.5 * s * facing, y - 0.05 * s), (x - 0.62 * s * facing, y - 0.18 * s)], fill=255, width=max(2, int(s * 0.04)))


def stick_man(d, x, y, s, r, spear=True, lean=0.0, arms_up=False):
    hx, hy = x + lean * s * 0.3, y - 0.8 * s
    d.ellipse([hx - 0.1 * s, hy - 0.1 * s, hx + 0.1 * s, hy + 0.1 * s], fill=255)
    w = max(3, int(s * 0.06))
    d.line([(hx, hy + 0.08 * s), (x, y - 0.25 * s)], fill=255, width=w)
    d.line([(x, y - 0.25 * s), (x - 0.2 * s, y + 0.2 * s)], fill=255, width=w)
    d.line([(x, y - 0.25 * s), (x + 0.2 * s, y + 0.2 * s)], fill=255, width=w)
    sy = hy + 0.25 * s
    if arms_up:
        d.line([(hx - 0.25 * s, hy - 0.2 * s), (hx, sy), (hx + 0.25 * s, hy - 0.2 * s)], fill=255, width=w)
    else:
        d.line([(hx - 0.25 * s, sy + 0.12 * s), (hx, sy), (hx + 0.25 * s, sy - 0.05 * s)], fill=255, width=w)
    if spear:
        d.line([(hx + 0.25 * s - 0.4 * s, sy + 0.2 * s), (hx + 0.25 * s + 0.6 * s, sy - 0.3 * s)], fill=255, width=max(2, w // 2))


def paint_hunt():
    r = np.random.default_rng(2)
    c = Canvas(S, int(S * 0.55))
    ochre, red, black = c.layer(OCHRE), c.layer(RED), c.layer(BLACK)
    for i, (x, y, s) in enumerate(((620, 250, 190), (820, 200, 150), (760, 360, 130), (470, 330, 110))):
        deer(ochre if i % 2 == 0 else red, x, y, s, r, 1)
    for i, x in enumerate((110, 200, 290, 360)):
        stick_man(black if i == 2 else red, x, 360 + r.uniform(-30, 30), 150, r)
    for k in range(5):               # thrown spears in flight
        x0 = r.uniform(380, 520)
        y0 = r.uniform(180, 300)
        wobbly(black, [(x0, y0), (x0 + 110, y0 - 30)], 5, r)
    c.save('hunt', 2)


def paint_dragged():
    r = np.random.default_rng(3)
    c = Canvas(S, int(S * 0.72))
    ochre, red, black = c.layer(OCHRE), c.layer(RED), c.layer(BLACK)
    cx, cy = 760, 360
    for rad in (150, 115):
        black.ellipse([cx - rad, cy - rad, cx + rad, cy + rad], outline=255, width=16)
    red.ellipse([cx - 32, cy - 32, cx + 32, cy + 32], fill=255)
    people = [(140, 520, 150), (270, 470, 140), (380, 560, 130), (470, 440, 120)]
    for i, (x, y, s) in enumerate(people):
        stick_man(ochre, x, y, s, r, spear=False, lean=-0.8, arms_up=i % 2 == 0)
        # an arm from the circle to each of them
        pts = []
        sx, sy = cx - 120, cy + r.uniform(-60, 60)
        for k in range(20):
            t = k / 19
            pts.append((sx + (x + 25 - sx) * t, sy + (y - 0.6 * s - sy) * t + math.sin(t * math.pi * 3 + i) * 38 * (1 - t)))
        for k in range(19):
            w = int(26 * (1 - k / 19) + 5)
            red.line([pts[k], pts[k + 1]], fill=255, width=w)
    c.save('dragged', 3)


def paint_monster(alt=False):
    r = np.random.default_rng(4)
    c = Canvas(S, int(S * 0.7))
    ochre, red, black = c.layer(OCHRE), c.layer(RED), c.layer(BLACK)
    cx, cy = c.w / 2, c.h * 0.44
    red.ellipse([cx - 150, cy - 125, cx + 150, cy + 135], fill=255)
    # the eye
    ochre.ellipse([cx - 70, cy - 40, cx + 70, cy + 40], fill=255)
    black.ellipse([cx - 26, cy - 34, cx + 26, cy + 34], fill=255)
    rr = np.random.default_rng(40 if alt else 4)
    n = 9
    for i in range(n):
        a = math.pi * 0.05 + math.pi * 0.9 * i / (n - 1)
        if alt:
            a += rr.uniform(-0.25, 0.25) - 0.35    # they have moved — towards the viewer's left
        sx, sy = cx + math.cos(a) * 125, cy + math.sin(a) * 110
        tentacle(red, sx, sy, a, rr.uniform(260, 380), 46, rr, curl=rr.uniform(1.5, 3.5))
    for i in range(4):
        a = -math.pi * 0.2 - math.pi * 0.6 * i / 3
        sx, sy = cx + math.cos(a) * 120, cy + math.sin(a) * 100
        tentacle(red, sx, sy, a, rr.uniform(120, 190), 34, rr, curl=2)
    for k in range(60):                    # dots round it, like a halo
        a = rr.uniform(0, math.tau)
        rad = rr.uniform(210, 300)
        x, y = cx + math.cos(a) * rad * 1.3, cy + math.sin(a) * rad * 0.8
        ochre.ellipse([x - 9, y - 9, x + 9, y + 9], fill=255)
    # tiny people at its feet, for scale
    for i in range(6):
        stick_man(black, 120 + i * 150 + rr.uniform(-20, 20), c.h - 60, 70, rr, spear=False, arms_up=True)
    c.save('monster_b' if alt else 'monster', 5 if alt else 4)


def world_to_map(x, z, w, h, pad=70):
    return pad + (x - 0) / 64.0 * (w - 2 * pad), pad + (z - 0) / 64.0 * (h - 2 * pad)


def ring_sign(d, x, y, s):
    d.ellipse([x - s, y - s, x + s, y + s], outline=255, width=max(3, int(s * 0.25)))
    d.ellipse([x - s * 0.3, y - s * 0.3, x + s * 0.3, y + s * 0.3], fill=255)


def paint_cave_map():
    """A true map of this cave, drawn with a finger: the way to the door."""
    r = np.random.default_rng(6)
    c = Canvas(S, S)
    ochre, red, black = c.layer(OCHRE), c.layer(RED), c.layer(BLACK)
    for key, curve in CURVES.items():
        pts = [world_to_map(p[0], p[1], c.w, c.h) for p in curve[::3]]
        pts = [p for p in pts if 0 < p[1] < c.h]
        wobbly(red, pts, 20, r)
    for key, (rx, rz, fl, rad, hh) in ROOMS.items():
        if key == 'mouth':
            continue
        x, y = world_to_map(rx, rz, c.w, c.h)
        s = rad / 64 * (c.w - 140)
        red.ellipse([x - s, y - s, x + s, y + s], fill=255)
    # the mouth: a hand; the monster room: an eye; the bones: dots; the door: the sign
    mx, my = world_to_map(32, 60, c.w, c.h)
    hand(ochre, mx, my - 10, 55, math.pi, r)
    px, py = world_to_map(29, 14, c.w, c.h)
    ochre.ellipse([px - 30, py - 20, px + 30, py + 20], fill=255)
    black.ellipse([px - 10, py - 16, px + 10, py + 16], fill=255)
    bx, by = world_to_map(9.5, 27, c.w, c.h)
    for k in range(7):
        black.ellipse([bx - 36 + k * 11, by - 6 + (k % 2) * 12, bx - 26 + k * 11, by + 4 + (k % 2) * 12], fill=255)
    dx, dy = world_to_map(DOOR['x'], DOOR['z'] - 1.0, c.w, c.h)
    ring_sign(black, dx, dy - 25, 30)
    c.save('cave_map', 6)


def paint_land_map():
    """Rivers, hills, a camp: the country they walked through (Level 1's jungle)."""
    r = np.random.default_rng(7)
    c = Canvas(S, int(S * 0.8))
    ochre, red, black = c.layer(OCHRE), c.layer(RED), c.layer(BLACK)
    # the river, with its bend
    pts = []
    for k in range(40):
        t = k / 39
        pts.append((60 + t * (c.w - 120), c.h * 0.55 + math.sin(t * 5.5) * 120 + math.sin(t * 13) * 18))
    wobbly(red, pts, 18, r)
    # hills as concentric rings (the plateau)
    for (hx, hy, n) in ((c.w * 0.72, c.h * 0.25, 4), (c.w * 0.25, c.h * 0.22, 3)):
        for k in range(n):
            s = 35 + k * 30
            ochre.ellipse([hx - s * 1.4, hy - s, hx + s * 1.4, hy + s], outline=255, width=10)
    # the camp by the bend: a little fire of dots
    cx, cy = c.w * 0.36, c.h * 0.55 + math.sin(0.36 * 5.5) * 120 + 70
    for k in range(9):
        a = k / 9 * math.tau
        red.ellipse([cx + math.cos(a) * 30 - 8, cy + math.sin(a) * 30 - 8, cx + math.cos(a) * 30 + 8, cy + math.sin(a) * 30 + 8], fill=255)
    black.ellipse([cx - 12, cy - 12, cx + 12, cy + 12], fill=255)
    # the route: a line of footprints (dots) from the camp to the hills, and a hand at the end
    for k in range(18):
        t = k / 17
        x = cx + (c.w * 0.72 - cx) * t + math.sin(t * 9) * 25
        y = cy + (c.h * 0.25 + 130 - cy) * t
        black.ellipse([x - 6, y - 6, x + 6, y + 6], fill=255)
    ring_sign(black, c.w * 0.72, c.h * 0.25, 22)
    c.save('land_map', 7)


def paint_procession():
    r = np.random.default_rng(8)
    c = Canvas(S, int(S * 0.46))
    ochre, red, black = c.layer(OCHRE), c.layer(RED), c.layer(BLACK)
    gx_, gy_ = c.w - 150, c.h * 0.52
    ring_sign(black, gx_, gy_, 110)
    for i in range(8):
        x = 70 + i * 95
        s = 130 - i * 6
        stick_man(red if i % 3 else ochre, x, gy_ + 90 - i * 3, s, r, spear=False, lean=0.3)
    c.save('procession', 8)


def paint_spiral():
    r = np.random.default_rng(9)
    c = Canvas(S, S)
    ochre, red, black = c.layer(OCHRE), c.layer(RED), c.layer(BLACK)
    for (sx, sy, turns, sc, lay) in ((330, 380, 4.5, 230, red), (720, 620, 3.5, 180, ochre), (760, 250, 2.5, 110, red)):
        pts = []
        for k in range(300):
            t = k / 299
            a = t * turns * math.tau
            pts.append((sx + math.cos(a) * t * sc, sy + math.sin(a) * t * sc))
        wobbly(lay, pts, 16, r)
    for k in range(80):
        x, y = r.uniform(60, c.w - 60), r.uniform(60, c.h - 60)
        black.ellipse([x - 7, y - 7, x + 7, y + 7], fill=255)
    # in the middle of the big spiral: a small eye
    ochre.ellipse([300, 360, 360, 400], fill=255)
    black.ellipse([322, 362, 338, 398], fill=255)
    c.save('spiral', 9)


# ================================================================ data for the level
def v3(p):
    return 'Vector3(%.3f, %.3f, %.3f)' % tuple(p)


def route():
    """Walking route for the test bot: mouth -> fork -> painted chamber -> door."""
    pts = []
    for key in ('A', 'C'):
        pts += [p for p in CURVES[key][::4]]
    pts.append(np.array([29.5, 16.5, -2.5, 0, 0]))
    pts += [p for p in CURVES['D'][::4]]
    pts.append(np.array([DOOR['x'], DOOR['z'] + 1.0, DOOR['floor'], 0, 0]))
    out = []
    for p in pts:
        if p[1] > 61.5:
            continue
        out.append((p[0], p[2], p[1]))
    return out


def write_data():
    L = []
    L.append('extends RefCounted')
    L.append('## The cave\'s layout. GENERATED by tools/gen_cave.py - edit that and re-run it.')
    L.append('')
    L.append('const CHUNKS := [%s]' % ', '.join('"res://levels/cave/mesh/%s"' % c for c in chunks))
    L.append('const SPAWN := %s' % v3(SPAWN))
    L.append('## The daylight plane at the mouth, and where the rock seals it.')
    L.append('const MOUTH := %s' % v3((32.0, 0.0, MOUTH_Z)))
    L.append('const SEAL := %s' % v3((32.0, 0.0, SEAL_Z)))
    L.append('## The door to the labyrinth: centre of the doorway on the floor; the face of the wall is at z.')
    L.append('const DOOR := %s' % v3((DOOR['x'], DOOR['floor'], DOOR['z'])))
    L.append('const DOOR_SIZE := Vector2(%.2f, %.2f)' % (DOOR['width'], DOOR['height']))
    bx, bz = 9.0, 26.0
    L.append('const BONES := %s' % v3((bx, floor_at(bx, bz), bz)))
    L.append('## Rooms: name -> [centre on the floor, radius].')
    L.append('const ROOMS := {')
    for k, (rx, rz, fl, rad, hh) in ROOMS.items():
        L.append('\t"%s": [%s, %.1f],' % (k, v3((rx, fl, rz)), rad))
    L.append('}')
    L.append('const PAINTINGS := [')
    for p in placed:
        L.append('\t{"tex": "%s", "pos": %s, "normal": %s, "size": Vector2(%.2f, %.2f),' % (p['tex'], v3(p['pos']), v3(p['normal']), *p['size']))
        L.append('\t\t"line": "%s"},' % p['line'].replace('"', '\\"'))
    L.append(']')
    L.append('## A walking route from the mouth to the door (for tools/cave_test.gd).')
    L.append('const ROUTE := [')
    for p in route():
        L.append('\t%s,' % v3(p))
    L.append(']')
    with open(os.path.join(LVL, 'cave_data.gd'), 'w') as fh:
        fh.write('\n'.join(L) + '\n')
    print('wrote cave_data.gd')


if __name__ == '__main__':
    cave_rock()
    cave_dirt()
    paint_hands()
    paint_hunt()
    paint_dragged()
    paint_monster()
    paint_monster(alt=True)
    paint_cave_map()
    paint_land_map()
    paint_procession()
    paint_spiral()
    write_data()
