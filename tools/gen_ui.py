#!/usr/bin/env python3
"""
Rustic UI pieces for the theme: ink-and-paper toggle switches and a wax-seal
slider grabber. Writes PNGs into assets/ui/.   python3 tools/gen_ui.py
"""
import os, math, random
from PIL import Image, ImageDraw, ImageFilter

OUT = os.path.join(os.path.dirname(__file__), '..', 'assets', 'ui')
os.makedirs(OUT, exist_ok=True)
S = 4                       # supersample
INK = (58, 36, 20, 255)
INK_SOFT = (58, 36, 20, 140)
PAPER = (236, 222, 190, 255)
PAPER_DARK = (205, 186, 148, 255)
RED = (132, 34, 22, 255)
RED_DARK = (92, 22, 14, 255)


def wobbly_round_rect(d, box, r, width, fill=None, outline=INK, seed=0, wob=1.2):
    rnd = random.Random(seed)
    x0, y0, x1, y1 = box
    pts = []
    n = 90
    for i in range(n):
        a = i / n * 2 * math.pi
        # superellipse-ish capsule
        cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
        hw, hh = (x1 - x0) / 2, (y1 - y0) / 2
        ca, sa = math.cos(a), math.sin(a)
        px = cx + (hw - r) * (1 if ca > 0 else -1) * min(1, abs(ca) * 6) + r * ca
        py = cy + (hh - r) * (1 if sa > 0 else -1) * min(1, abs(sa) * 6) + r * sa
        px += rnd.uniform(-wob, wob) * S * 0.5
        py += rnd.uniform(-wob, wob) * S * 0.5
        pts.append((px, py))
    if fill:
        d.polygon(pts, fill=fill)
    d.line(pts + [pts[0]], fill=outline, width=width, joint='curve')


def seal(d, c, r, col, dark, seed):
    rnd = random.Random(seed)
    pts = []
    for i in range(40):
        a = i / 40 * 2 * math.pi
        rr = r * (1 + rnd.uniform(-0.07, 0.07))
        pts.append((c[0] + math.cos(a) * rr, c[1] + math.sin(a) * rr))
    d.polygon(pts, fill=dark)
    d.ellipse((c[0] - r * 0.78, c[1] - r * 0.78, c[0] + r * 0.78, c[1] + r * 0.78), fill=col)
    d.ellipse((c[0] - r * 0.55, c[1] - r * 0.55, c[0] + r * 0.55, c[1] + r * 0.55), outline=dark, width=max(1, int(r * 0.12)))
    # a little compass star pressed into the wax
    for k in range(4):
        a = k * math.pi / 2
        tip = (c[0] + math.cos(a) * r * 0.45, c[1] + math.sin(a) * r * 0.45)
        l = (c[0] + math.cos(a + 0.6) * r * 0.12, c[1] + math.sin(a + 0.6) * r * 0.12)
        rr = (c[0] + math.cos(a - 0.6) * r * 0.12, c[1] + math.sin(a - 0.6) * r * 0.12)
        d.polygon([tip, l, c, rr], fill=dark)
    d.ellipse((c[0] - r * 0.5, c[1] - r * 0.62, c[0] - r * 0.1, c[1] - r * 0.3), fill=(255, 190, 170, 60))


def toggle(name, on, hover=False, disabled=False):
    w, h = 64, 30
    im = Image.new('RGBA', (w * S, h * S), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    pad = 2 * S
    box = (pad, pad + S, w * S - pad, h * S - pad - S)
    fill = (176, 92, 60, 255) if on else PAPER_DARK
    if hover:
        fill = tuple(min(255, int(c * 1.08)) for c in fill[:3]) + (255,)
    wobbly_round_rect(d, box, (h * S - 2 * pad) / 2 - S, 2 * S, fill=fill, seed=3 if on else 5)
    # hatching inside the track (ink wash look)
    rnd = random.Random(7)
    for i in range(10):
        x = box[0] + 8 * S + i * 5 * S
        d.line((x, box[1] + 6 * S, x - 4 * S, box[3] - 6 * S), fill=(58, 36, 20, 45 if on else 30), width=S)
    r = (h * S - 2 * pad) / 2 - 2 * S
    cx = box[2] - r - 3 * S if on else box[0] + r + 3 * S
    cy = (box[1] + box[3]) / 2
    if on:
        seal(d, (cx, cy), r, RED, RED_DARK, 11)
    else:
        d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=PAPER, outline=INK, width=2 * S)
        d.ellipse((cx - r * 0.35, cy - r * 0.35, cx + r * 0.35, cy + r * 0.35), outline=INK_SOFT, width=S)
    im = im.resize((w, h), Image.LANCZOS)
    if disabled:
        a = im.split()[3].point(lambda v: v * 0.45)
        im.putalpha(a)
    im.save(os.path.join(OUT, name + '.png'))


def grabber(name, hi=False):
    s = 26
    im = Image.new('RGBA', (s * S, s * S), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    c = (s * S / 2, s * S / 2)
    seal(d, c, s * S / 2 - 2 * S, (160, 44, 28, 255) if hi else RED, RED_DARK, 21)
    im = im.resize((s, s), Image.LANCZOS)
    im.save(os.path.join(OUT, name + '.png'))


def track(name, filled):
    # a hand-inked groove, 9-sliced by the theme
    w, h = 48, 14
    im = Image.new('RGBA', (w * S, h * S), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    fill = (150, 78, 48, 255) if filled else PAPER_DARK
    wobbly_round_rect(d, (S, 2 * S, w * S - S, h * S - 2 * S), 4 * S, 2 * S, fill=fill, seed=13 if filled else 17, wob=0.6)
    im = im.resize((w, h), Image.LANCZOS)
    im.save(os.path.join(OUT, name + '.png'))


if __name__ == '__main__':
    toggle('toggle_on', True)
    toggle('toggle_off', False)
    toggle('toggle_on_hover', True, hover=True)
    toggle('toggle_off_hover', False, hover=True)
    toggle('toggle_on_disabled', True, disabled=True)
    toggle('toggle_off_disabled', False, disabled=True)
    grabber('seal_grabber')
    grabber('seal_grabber_hi', True)
    track('slider_track', False)
    track('slider_fill', True)
    print('wrote UI pieces to', os.path.normpath(OUT))
