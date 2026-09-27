#!/usr/bin/env python3
"""
Procedural textures for the finale (tileable, with normal maps):
  stone_bricks  cool grey-blue coursed stone for the labyrinth walls (2 m tile)
  flagstones    worn floor slabs (2 m tile)
  wood_door     vertical oak planks with two iron straps and rivets
  wisp_glow     soft radial sprite for will-o'-the-wisps
  smoke         soft blotchy sprite for the beast's shroud and the dust
Writes PNGs into assets/textures/.   python3 tools/gen_textures.py
"""
import os
import numpy as np
from PIL import Image

OUT = os.path.join(os.path.dirname(__file__), '..', 'assets', 'textures')
os.makedirs(OUT, exist_ok=True)
rng = np.random.default_rng(7)


def tile_noise(size, cells, octaves=4, seed=0):
    """Tileable value noise in 0..1."""
    r = np.random.default_rng(seed)
    out = np.zeros((size, size))
    amp, total = 1.0, 0.0
    for o in range(octaves):
        n = cells * 2 ** o
        grid = r.random((n, n))
        xs = np.linspace(0, n, size, endpoint=False)
        x0 = np.floor(xs).astype(int); fx = xs - x0
        fx = fx * fx * (3 - 2 * fx)
        x1 = (x0 + 1) % n
        a = grid[np.ix_(x0, x0)]; b = grid[np.ix_(x0, x1)]
        c = grid[np.ix_(x1, x0)]; d = grid[np.ix_(x1, x1)]
        fy = fx[:, None]; fxx = fx[None, :]
        out += amp * ((a * (1 - fxx) + b * fxx) * (1 - fy) + (c * (1 - fxx) + d * fxx) * fy)
        total += amp; amp *= 0.5
    return out / total


def normal_from_height(h, strength=4.0):
    dx = (np.roll(h, -1, 1) - np.roll(h, 1, 1)) * 0.5
    dy = (np.roll(h, -1, 0) - np.roll(h, 1, 0)) * 0.5
    nx, ny = -dx * strength, dy * strength
    nz = np.ones_like(h)
    l = np.sqrt(nx ** 2 + ny ** 2 + nz ** 2)
    n = np.stack([nx / l, ny / l, nz / l], -1)
    return ((n * 0.5 + 0.5) * 255).astype(np.uint8)


def save(name, rgb, height=None, strength=4.0):
    Image.fromarray(np.clip(rgb * 255, 0, 255).astype(np.uint8)).save(os.path.join(OUT, name + '_albedo.png'))
    if height is not None:
        Image.fromarray(normal_from_height(height, strength)).save(os.path.join(OUT, name + '_normal.png'))
    print('wrote', name)


def stone_bricks(size=1024):
    # 2 m x 2 m: 8 courses of 0.25 m, bricks 0.5 m long (4 per row), staggered
    y, x = np.mgrid[0:size, 0:size] / size
    rows = 8
    row = np.floor(y * rows).astype(int)
    xo = (x + (row % 2) * 0.125) % 1.0
    cols = 4
    col = np.floor(xo * cols).astype(int)
    fy = y * rows - row
    fx = xo * cols - col
    edge = np.minimum(np.minimum(fx, 1 - fx) * 2.0, np.minimum(fy, 1 - fy))   # in brick-height units
    n1 = tile_noise(size, 8, 5, 1)
    n2 = tile_noise(size, 32, 3, 2)
    mortar = 0.055 + (n1 - 0.5) * 0.04
    bevel = np.clip((edge - mortar) / 0.08, 0, 1)
    brick_id = (row * 7 + col * 13) % 29
    tone = (np.sin(brick_id * 12.9898) * 43758.5453) % 1.0
    height = bevel * (0.75 + 0.25 * n2) + (n1 - 0.5) * 0.15 * bevel
    base = np.array([0.40, 0.43, 0.47])
    col_rgb = base[None, None, :] * (0.72 + 0.35 * tone[..., None]) * (0.85 + 0.3 * n2[..., None])
    col_rgb += np.array([-0.02, 0.0, 0.03])[None, None, :] * tone[..., None]
    # chips and cracks
    chips = tile_noise(size, 24, 3, 3) > 0.72
    height = np.where(chips & (bevel > 0), height * 0.6, height)
    mortar_rgb = np.array([0.22, 0.23, 0.24]) * (0.8 + 0.4 * n1[..., None])
    rgb = mortar_rgb * (1 - bevel[..., None]) + col_rgb * bevel[..., None]
    rgb *= (0.8 + 0.2 * np.clip(height, 0, 1))[..., None]
    moss = np.clip((tile_noise(size, 6, 4, 4) - 0.62) * 4, 0, 1) * (1 - y) ** 2
    rgb = rgb * (1 - moss[..., None] * 0.35) + np.array([0.18, 0.24, 0.17]) * moss[..., None] * 0.35
    save('stone_bricks', rgb, height, 6.0)


def flagstones(size=1024):
    # irregular slabs via jittered grid voronoi (tileable)
    pts = []
    n = 5
    for j in range(n):
        for i in range(n):
            pts.append(((i + rng.uniform(0.2, 0.8)) / n, (j + rng.uniform(0.2, 0.8)) / n))
    pts = np.array(pts)
    y, x = np.mgrid[0:size, 0:size] / size
    d1 = np.full((size, size), 9.0); d2 = np.full((size, size), 9.0); idx = np.zeros((size, size), int)
    for k, (px, py) in enumerate(pts):
        for ox in (-1, 0, 1):
            for oy in (-1, 0, 1):
                d = np.sqrt((x - px - ox) ** 2 + (y - py - oy) ** 2)
                closer = d < d1
                d2 = np.where(closer, d1, np.minimum(d2, d))
                idx = np.where(closer, k, idx)
                d1 = np.where(closer, d, d1)
    gap = d2 - d1
    n1 = tile_noise(size, 8, 5, 5)
    bevel = np.clip((gap - 0.006) / 0.03, 0, 1)
    tone = (np.sin(idx * 78.233) * 43758.5453) % 1.0
    height = bevel * (0.7 + 0.3 * n1)
    slab = np.array([0.30, 0.31, 0.33]) * (0.75 + 0.4 * tone[..., None]) * (0.8 + 0.35 * n1[..., None])
    grime = np.array([0.12, 0.12, 0.12])
    rgb = grime * (1 - bevel[..., None]) + slab * bevel[..., None]
    save('flagstones', rgb, height, 5.0)


def wood_door(size=1024):
    # planks run vertically; this texture maps onto the whole door face
    y, x = np.mgrid[0:size, 0:size] / size
    planks = 6
    p = np.floor(x * planks).astype(int)
    fx = x * planks - p
    grain_n = tile_noise(size, 16, 4, 6)
    grain = np.sin((x * 90 + grain_n * 6 + p * 1.7) * np.pi) * 0.5 + 0.5
    rings = tile_noise(size, 4, 3, 7)
    seam = np.clip(np.minimum(fx, 1 - fx) / 0.03, 0, 1)
    tone = 0.85 + 0.25 * ((np.sin(p * 91.7) * 999) % 1.0)
    wood = np.array([0.36, 0.22, 0.12])[None, None, :] * (tone * (0.75 + 0.25 * grain + 0.2 * (rings - 0.5)))[..., None]
    height = seam * (0.85 + 0.15 * grain)
    rgb = wood * (0.5 + 0.5 * seam[..., None])
    # two iron straps with rivets
    for cy in (0.22, 0.78):
        strap = np.abs(y - cy) < 0.035
        rust = tile_noise(size, 20, 3, 8)
        iron = np.array([0.16, 0.15, 0.15]) + np.array([0.18, 0.08, 0.02]) * np.clip(rust - 0.5, 0, 1)[..., None]
        rgb = np.where(strap[..., None], iron, rgb)
        height = np.where(strap, 1.15, height)
        for k in range(7):
            rx = (k + 0.5) / 7
            rivet = (x - rx) ** 2 + (y - cy) ** 2 < 0.012 ** 2
            rgb = np.where(rivet[..., None], np.array([0.3, 0.29, 0.28]), rgb)
            height = np.where(rivet, 1.35, height)
    save('wood_door', rgb, height, 5.0)


def sprite(name, size, fn):
    y, x = np.mgrid[0:size, 0:size] / (size - 1) * 2 - 1
    rgba = fn(x, y)
    Image.fromarray(np.clip(rgba * 255, 0, 255).astype(np.uint8), 'RGBA').save(os.path.join(OUT, name + '.png'))
    print('wrote', name)


def wisp(x, y):
    r = np.sqrt(x ** 2 + y ** 2)
    a = np.clip(np.exp(-r * r * 9) + np.exp(-r * 3.2) * 0.35, 0, 1) * (r < 1)
    return np.stack([np.ones_like(r), np.ones_like(r) * 0.97, np.ones_like(r) * 0.92, a], -1)


def smoke(x, y):
    r = np.sqrt(x ** 2 + y ** 2)
    n = tile_noise(x.shape[0], 4, 4, 9)
    a = np.clip(1 - r, 0, 1) ** 1.5 * (0.55 + 0.45 * n)
    return np.stack([np.ones_like(r), np.ones_like(r), np.ones_like(r), a], -1)


if __name__ == '__main__':
    stone_bricks()
    flagstones()
    wood_door()
    sprite('wisp_glow', 128, wisp)
    sprite('smoke', 128, smoke)
