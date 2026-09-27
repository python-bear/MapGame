#!/usr/bin/env python3
"""
Procedural soundtrack + sound effects for Cartographer's Dream.

Every level gets a "set" of three stems that loop in sync:
    calm     – always playing, faint
    tension  – fades in as danger rises
    danger   – fades in when the player is in real trouble
The Music autoload (scripts/music.gd) crossfades them from a single 0..1
danger value. Each set is darker than the one before it: lower register,
more dissonant harmony, heavier percussion.

Writes OGG files to assets/music/ and assets/sfx/.  Needs numpy, scipy, ffmpeg.
    python3 tools/gen_music.py
To add a set for a new level, write a function like level2() and add it to SETS.
"""
import os, subprocess, tempfile
import numpy as np
from scipy.signal import lfilter, butter, sosfilt

SR = 32000
ROOT = os.path.join(os.path.dirname(__file__), '..')
rng = np.random.default_rng(1923)

# ================================================================ helpers
def note(name_or_midi):
    if isinstance(name_or_midi, (int, float)):
        return 440.0 * 2 ** ((name_or_midi - 69) / 12)
    names = {'C': 0, 'Db': 1, 'D': 2, 'Eb': 3, 'E': 4, 'F': 5, 'Gb': 6, 'G': 7, 'Ab': 8, 'A': 9, 'Bb': 10, 'B': 11}
    n, o = name_or_midi[:-1], int(name_or_midi[-1])
    return note(12 * (o + 1) + names[n])

def t_axis(dur):
    return np.arange(int(dur * SR)) / SR

def env_adsr(n, a, d, s, r):
    a, d, r = int(a * SR), int(d * SR), int(r * SR)
    e = np.full(n, s, dtype=np.float64)
    a = min(a, n); e[:a] = np.linspace(0, 1, a, endpoint=False)
    dd = min(d, max(0, n - a)); e[a:a + dd] = np.linspace(1, s, dd, endpoint=False)
    if r > 0:
        r = min(r, n); e[n - r:] *= np.linspace(1, 0, r)
    return e

def lowpass(x, hz, order=2):
    sos = butter(order, min(hz, SR * 0.45), 'low', fs=SR, output='sos')
    return sosfilt(sos, x)

def highpass(x, hz, order=2):
    sos = butter(order, hz, 'high', fs=SR, output='sos')
    return sosfilt(sos, x)

def bandpass(x, lo, hi, order=2):
    sos = butter(order, [lo, min(hi, SR * 0.45)], 'band', fs=SR, output='sos')
    return sosfilt(sos, x)

def saw(freq, t, harmonics=12):
    out = np.zeros_like(t)
    for k in range(1, harmonics + 1):
        if freq * k > SR * 0.45:
            break
        out += np.sin(2 * np.pi * freq * k * t) / k
    return out * 0.6

def add(buf, sig, at):
    i = int(at * SR) % len(buf)
    n = len(sig)
    end = i + n
    if end <= len(buf):
        buf[i:end] += sig
    else:  # wrap around so the loop stays seamless
        first = len(buf) - i
        buf[i:] += sig[:first]
        rest = sig[first:]
        while len(rest):
            m = min(len(rest), len(buf))
            buf[:m] += rest[:m]
            rest = rest[m:]

def reverb(x, seconds=3.0, mix=0.35, damp=3500):
    """Circular convolution with decaying noise, so the tail wraps into the loop start."""
    n = len(x)
    ir_len = min(int(seconds * SR), n)
    ir = rng.standard_normal(ir_len) * np.exp(-np.linspace(0, 7, ir_len))
    ir = lowpass(ir, damp)
    ir /= np.sqrt(np.sum(ir ** 2)) + 1e-9
    irp = np.zeros(n); irp[:ir_len] = ir
    wet = np.real(np.fft.ifft(np.fft.fft(x) * np.fft.fft(irp)))
    return x * (1 - mix) + wet * mix * 1.3

FADE = 2.0

def looped(fn, *args, **kw):
    """Render a continuous sound FADE seconds longer than the loop and fold the
    overhang back over the start, so it loops without a click."""
    x = fn(*args, **kw)
    n = int(LOOP * SR); f = int(FADE * SR)
    out = x[:n].copy()
    ramp = np.linspace(0, 1, f)
    out[:f] = out[:f] * ramp + x[n:n + f] * (1 - ramp)
    return out

def normalize(x, peak_db=-3.0):
    p = np.max(np.abs(x)) + 1e-9
    return x / p * 10 ** (peak_db / 20)

# ---------------------------------------------------------------- instruments
def pad(freqs, dur, bright=1200, amp=0.2, attack=1.5, release=2.0):
    t = t_axis(dur)
    out = np.zeros_like(t)
    for f in freqs:
        for det in (-0.12, 0.0, 0.13):
            ff = f * 2 ** (det / 12)
            out += saw(ff, t + rng.random() * 0.01, 8)
    out = lowpass(out, bright) / (len(freqs) * 3)
    out *= env_adsr(len(t), attack, 0.5, 0.85, release)
    return out * amp

def pluck(freq, dur=2.5, amp=0.25, bright=0.5):
    """Karplus-Strong: music box / kalimba / harp."""
    n = int(dur * SR)
    period = max(2, int(SR / freq))
    buf = rng.uniform(-1, 1, period)
    out = np.zeros(n)
    for i in range(n):
        out[i] = buf[i % period]
        buf[i % period] = bright * buf[i % period] + (1 - bright) * buf[(i + 1) % period]
        buf[i % period] *= 0.996
    return lowpass(out, 3200) * amp

def bellish(freq, dur=3.0, amp=0.25, partials=((1, 1), (2.0, .5), (2.76, .35), (5.4, .2), (8.9, .08))):
    t = t_axis(dur)
    out = np.zeros_like(t)
    for ratio, a in partials:
        out += a * np.sin(2 * np.pi * freq * ratio * t) * np.exp(-t * (1.2 + ratio * 0.6))
    return out * amp

def thump(freq=55, dur=0.6, amp=0.8, drop=2.0):
    t = t_axis(dur)
    f = freq * (1 + drop * np.exp(-t * 18))
    ph = 2 * np.pi * np.cumsum(f) / SR
    return np.sin(ph) * np.exp(-t * 7) * amp

def taiko(freq=70, dur=0.9, amp=0.9):
    t = t_axis(dur)
    body = thump(freq, dur, 1.0, 1.4)
    skin = lowpass(rng.standard_normal(len(t)), 900) * np.exp(-t * 25) * 0.6
    return (body + skin) * amp

def drone(freq, dur, amp=0.3, wobble=0.2):
    t = t_axis(dur)
    lfo = 1 + 0.004 * np.sin(2 * np.pi * wobble * t)
    ph = 2 * np.pi * freq * np.cumsum(lfo) / SR
    sig = np.sin(ph) + 0.35 * np.sin(2 * ph) + 0.15 * np.sin(3 * ph + 0.3)
    return sig * amp

def strings(freqs, dur, amp=0.15, trem=0.0, bright=2500, attack=2.0):
    t = t_axis(dur)
    out = np.zeros_like(t)
    for f in freqs:
        vib = 1 + 0.003 * np.sin(2 * np.pi * (5 + rng.random()) * t)
        for det in (-0.08, 0.07):
            ph = 2 * np.pi * f * 2 ** (det / 12) * np.cumsum(vib) / SR
            out += sum(np.sin(k * ph) / k for k in range(1, 7))
    out = lowpass(out, bright) / (len(freqs) * 2)
    if trem:
        out *= 0.55 + 0.45 * np.sin(2 * np.pi * trem * t)
    return out * env_adsr(len(t), attack, 0.3, 0.9, 1.5) * amp

def whale(f0, f1, dur, amp=0.12):
    t = t_axis(dur)
    f = f0 * (f1 / f0) ** (np.sin(np.linspace(0, np.pi, len(t))) ** 2)
    ph = 2 * np.pi * np.cumsum(f) / SR
    sig = np.sin(ph) + 0.3 * np.sin(2.01 * ph)
    return sig * env_adsr(len(t), dur * 0.3, 0.2, 0.9, dur * 0.4) * amp

def waves(dur, amp=0.12):
    t = t_axis(dur)
    noise = rng.standard_normal(len(t))
    swell = 0.5 + 0.5 * np.sin(2 * np.pi * t / 7.5) ** 2
    return lowpass(noise, 600) * swell * amp

def crackle(dur, amp=0.05):
    n = int(dur * SR)
    out = np.zeros(n)
    for _ in range(int(dur * 9)):
        i = rng.integers(0, n - 400)
        out[i:i + 400] += rng.standard_normal(400) * np.exp(-np.arange(400) / 40) * rng.uniform(0.3, 1)
    return highpass(out, 1500) * amp + lowpass(rng.standard_normal(n), 300) * amp * 0.3

# ================================================================ sets
BPM = 64
BEAT = 60 / BPM
BAR = BEAT * 4
BARS = 8
LOOP = BAR * BARS   # 30 s


def blank():
    return np.zeros(int(LOOP * SR))

def menu():
    calm = blank()
    chords = [['D3', 'A3', 'E4'], ['Bb2', 'F3', 'D4'], ['F3', 'C4', 'A4'], ['C3', 'G3', 'E4']]
    for i, ch in enumerate(chords):
        add(calm, pad([note(n) for n in ch], BAR * 2 + 2, bright=700, amp=0.3, attack=2.5, release=2.5), i * BAR * 2)
    melody = ['A5', 'F5', 'E5', 'D5', 'E5', 'A4', 'D5', 'C5']
    for i, n in enumerate(melody):
        add(calm, pluck(note(n), 3.0, 0.16, 0.4), i * BAR + BEAT * (i % 2))
    calm += looped(crackle, LOOP + FADE, 0.035)
    return {'calm': normalize(reverb(calm, 3.5, 0.45), -9)}

def level1():
    """The Survey — warm D dorian, faint, curious. Dread creeps in near the ink's edge."""
    calm, tension, danger = blank(), blank(), blank()
    chords = [['D3', 'F3', 'A3', 'C4', 'E4'], ['G2', 'D3', 'B3', 'E4'], ['F2', 'C3', 'A3', 'E4'], ['C3', 'G3', 'D4', 'E4']]
    for i, ch in enumerate(chords):
        add(calm, pad([note(n) for n in ch], BAR * 2 + 1.5, bright=1100, amp=0.3), i * BAR * 2)
    scale = ['D5', 'E5', 'F5', 'G5', 'A5', 'B5', 'C6', 'D6']
    motif = [4, 2, 3, 1, 0, 2, 4, 6, 5, 4, 2, 1]
    times = [0, 1.5, 2, 3, 4.5, 6, 8, 9.5, 10, 11, 12.5, 14]
    for k in range(2):
        for m, tb in zip(motif, times):
            add(calm, pluck(note(scale[m]), 2.5, 0.14, 0.45), (tb + k * 16) * BEAT)
    # tension: heartbeat + a creeping minor second in the strings
    for b in range(BARS * 4):
        if b % 2 == 0:
            add(tension, thump(52, 0.5, 0.7), b * BEAT)
            add(tension, thump(48, 0.5, 0.45), b * BEAT + 0.28)
    tension += looped(strings, [note('D5'), note('Eb5')], LOOP + FADE, 0.12, trem=0, bright=2200, attack=6)
    tension += looped(drone, note('D2'), LOOP + FADE, 0.18)
    # danger: drums and a dissonant swell
    for b in range(BARS * 4):
        add(danger, taiko(66, 0.9, 0.8), b * BEAT)
        if b % 2:
            add(danger, taiko(90, 0.6, 0.45), b * BEAT + BEAT / 2)
    for i in range(4):
        add(danger, strings([note('D4'), note('Eb4'), note('Ab4')], BAR * 2, 0.16, trem=7, attack=1.2), i * BAR * 2)
    return {'calm': normalize(reverb(calm, 3.0, 0.4), -8),
            'tension': normalize(reverb(tension, 2.5, 0.3), -9),
            'danger': normalize(reverb(danger, 2.0, 0.25), -6)}

def level2():
    """The Drowned Chart — C phrygian, lower and colder. The deep is listening."""
    calm, tension, danger = blank(), blank(), blank()
    calm += looped(drone, note('C2'), LOOP + FADE, 0.25, 0.1) + looped(drone, note('G2'), LOOP + FADE, 0.12, 0.07)
    chords = [['C3', 'Eb3', 'G3'], ['Db3', 'F3', 'Ab3'], ['Ab2', 'C3', 'Eb3', 'G3'], ['G2', 'B2', 'Db3', 'F3']]
    for i, ch in enumerate(chords):
        add(calm, pad([note(n) for n in ch], BAR * 2 + 2, bright=650, amp=0.28, attack=2.5), i * BAR * 2)
    for i, (a, b) in enumerate([('C4', 'G4'), ('Eb4', 'Db4'), ('G3', 'Db4')]):
        add(calm, whale(note(a), note(b), 5.5, 0.07), 3 + i * 9.5)
    for i, n in enumerate(['G4', 'Ab4', 'Eb4', 'C4', 'Db4', 'C4']):
        add(calm, bellish(note(n), 4.0, 0.08), i * BAR * 1.3 + 1)
    calm += looped(waves, LOOP + FADE, 0.10)
    # tension: low string ostinato + heartbeat
    pattern = ['C2', 'C2', 'Db2', 'C2', 'C2', 'G1', 'Ab1', 'C2']
    for b in range(BARS * 8):
        n = pattern[b % 8]
        seg = strings([note(n)], BEAT / 2 + 0.1, 0.35, bright=900, attack=0.02)
        add(tension, seg, b * BEAT / 2)
    for b in range(BARS * 4):
        add(tension, thump(46, 0.5, 0.8), b * BEAT)
        add(tension, thump(42, 0.5, 0.5), b * BEAT + 0.25)
    tension += looped(strings, [note('C5'), note('Db5')], LOOP + FADE, 0.1, trem=5.5, attack=5)
    # danger: pounding drums, brassy swells, a screeching cluster
    for b in range(BARS * 8):
        add(danger, taiko(58 if b % 4 else 48, 0.8, 0.9 if b % 2 == 0 else 0.55), b * BEAT / 2)
    for i, ch in enumerate([['C3', 'Db3', 'G3'], ['Db3', 'D3', 'Ab3'], ['C3', 'Db3', 'Gb3'], ['B2', 'C3', 'F3']]):
        seg = pad([note(n) for n in ch], BAR * 2, bright=2400, amp=0.5, attack=0.8, release=0.6)
        add(danger, seg, i * BAR * 2)
    danger += looped(strings, [note('B5'), note('C6'), note('Db6')], LOOP + FADE, 0.08, trem=11, bright=5000, attack=3)
    return {'calm': normalize(reverb(calm, 4.0, 0.45), -8),
            'tension': normalize(reverb(tension, 2.5, 0.3), -7),
            'danger': normalize(reverb(danger, 2.0, 0.25), -5)}

def drip(amp=0.2):
    t = t_axis(0.5)
    f = 1800 * np.exp(-t * 9) + 700
    ph = 2 * np.pi * np.cumsum(f) / SR
    return np.sin(ph) * np.exp(-t * 14) * amp

def level3():
    """Waking — the labyrinth. Almost silence: a sub drone, water dripping in the
    dark, a draught. The heartbeat is yours; the whine is what's coming."""
    calm, tension, danger = blank(), blank(), blank()
    calm += looped(drone, 27.5 * 2, LOOP + FADE, 0.35, 0.05) + looped(drone, 27.5 * 2 * 1.06, LOOP + FADE, 0.18, 0.03)
    wind = looped(lambda d: bandpass(rng.standard_normal(int(d * SR)), 250, 900) *
                  (0.5 + 0.5 * np.sin(2 * np.pi * t_axis(d) / 11.0) ** 2), LOOP + FADE)
    calm += wind * 0.05
    for i in range(9):
        add(calm, drip(rng.uniform(0.05, 0.14)), rng.uniform(0, LOOP))
    # tension: a slow heartbeat and a breathing cluster
    for b in range(int(LOOP / 1.0)):
        add(tension, thump(48, 0.45, 0.8), b * 1.0)
        add(tension, thump(44, 0.45, 0.5), b * 1.0 + 0.27)
    tension += looped(strings, [note('A2'), note('Bb2'), note('E3')], LOOP + FADE, 0.08, trem=0.3, bright=700, attack=4)
    # danger: fast heartbeat, a thin dissonant whine, low rumble
    for b in range(int(LOOP / 0.5)):
        add(danger, thump(52, 0.35, 0.9), b * 0.5)
        add(danger, thump(46, 0.35, 0.6), b * 0.5 + 0.18)
    danger += looped(strings, [note('Bb6'), note('B6'), note('E7')], LOOP + FADE, 0.06, trem=13, bright=9000, attack=2)
    danger += looped(lambda d: lowpass(rng.standard_normal(int(d * SR)), 90) * 1.5, LOOP + FADE) * 0.3
    return {'calm': normalize(reverb(calm, 5.0, 0.5), -10),
            'tension': normalize(reverb(tension, 3.0, 0.35), -9),
            'danger': normalize(reverb(danger, 2.0, 0.3), -7)}

SETS = {'menu': menu, 'level1': level1, 'level2': level2, 'level3': level3}

# ================================================================ sfx
def sfx_bell():
    s = bellish(note('Ab4'), 5.0, 0.5, ((1, 1), (2.0, .6), (2.4, .45), (3.0, .3), (4.2, .25), (5.4, .12)))
    return normalize(reverb(np.concatenate([s, np.zeros(SR)]), 2.5, 0.3), -3)

def sfx_splash():
    n = int(1.4 * SR); t = np.arange(n) / SR
    s = bandpass(rng.standard_normal(n), 300, 4500) * np.exp(-t * 4) * (1 - np.exp(-t * 60))
    s += lowpass(rng.standard_normal(n), 250) * np.exp(-t * 3) * 0.8
    return normalize(s, -3)

def sfx_emerge():
    n = int(2.0 * SR); t = np.arange(n) / SR
    rise = bandpass(rng.standard_normal(n), 150, 2500) * np.sin(np.pi * np.clip(t / 1.4, 0, 1)) ** 2
    groan = np.sin(2 * np.pi * np.cumsum(70 + 25 * np.sin(t * 3)) / SR) * env_adsr(n, 0.4, 0.3, 0.7, 0.8) * 0.5
    return normalize(rise + lowpass(groan, 400), -4)

def sfx_thud():
    n = int(0.8 * SR); t = np.arange(n) / SR
    s = thump(60, 0.8, 1.0, 1.0) + lowpass(rng.standard_normal(n), 800) * np.exp(-t * 20) * 0.5
    creak = np.sin(2 * np.pi * np.cumsum(300 + 80 * np.sin(t * 40)) / SR) * np.exp(-t * 6) * 0.15
    return normalize(s + creak, -3)

def sfx_roar():
    n = int(4.0 * SR); t = np.arange(n) / SR
    growl = lowpass(rng.standard_normal(n), 180) * (0.6 + 0.4 * np.sin(2 * np.pi * 13 * t))
    sub = np.sin(2 * np.pi * np.cumsum(38 - 8 * t / 4) / SR)
    s = (growl * 2.5 + sub) * env_adsr(n, 0.6, 0.5, 0.8, 1.5)
    return normalize(reverb(s, 3.0, 0.4), -2)

def sfx_ink():
    n = int(2.5 * SR); t = np.arange(n) / SR
    s = bandpass(rng.standard_normal(n), 200, 1800) * np.sin(np.pi * t / 2.5) ** 2
    return normalize(reverb(s, 2.0, 0.4), -6)

def sfx_breath():
    # two slow, wet breaths; silent at both ends so it loops cleanly
    d = 3.2; n = int(d * SR); t = np.arange(n) / SR
    env = np.sin(np.pi * np.clip(t / 1.4, 0, 1)) ** 2 * (t < 1.4) * 0.8 + \
          np.sin(np.pi * np.clip((t - 1.6) / 1.5, 0, 1)) ** 2 * (t >= 1.6) * 1.0
    air = bandpass(rng.standard_normal(n), 180, 1400) * env
    growl = np.sin(2 * np.pi * np.cumsum(62 + 10 * np.sin(t * 31)) / SR) * env * (0.6 + 0.4 * np.sin(2 * np.pi * 23 * t))
    return normalize(air + lowpass(growl, 300) * 0.8, -3)

def sfx_screech():
    d = 1.3; n = int(d * SR); t = np.arange(n) / SR
    f = 900 + 700 * np.sin(np.pi * t / d) + 60 * np.sin(2 * np.pi * 37 * t)
    ph = 2 * np.pi * np.cumsum(f) / SR
    carrier = np.sin(ph + 3.0 * np.sin(ph * 1.51))
    s = (carrier * 0.7 + bandpass(rng.standard_normal(n), 1500, 6000) * 0.5) * env_adsr(n, 0.08, 0.3, 0.8, 0.5)
    s = np.tanh(s * 3)
    return normalize(reverb(np.concatenate([s, np.zeros(SR)]), 2.0, 0.35), -2)

def sfx_step(seed):
    r = np.random.default_rng(seed)
    n = int(0.25 * SR); t = np.arange(n) / SR
    s = lowpass(r.standard_normal(n), 1400 + seed * 200) * np.exp(-t * 38) + np.sin(2 * np.pi * 95 * t) * np.exp(-t * 30) * 0.5
    grit = highpass(r.standard_normal(n), 3000) * np.exp(-t * 60) * 0.25
    return normalize(s + grit, -8)

def sfx_door_open():
    d = 1.6; n = int(d * SR); t = np.arange(n) / SR
    f = 180 + 140 * np.sin(np.pi * t / d) ** 2 + 25 * np.sin(2 * np.pi * 9 * t)
    ph = 2 * np.pi * np.cumsum(f) / SR
    creak = np.sign(np.sin(ph)) * (0.5 + 0.5 * np.sin(2 * np.pi * 43 * t)) * env_adsr(n, 0.15, 0.3, 0.7, 0.5)
    creak = bandpass(creak, 300, 2500) * 0.5
    thunk = np.concatenate([lowpass(rng.standard_normal(int(0.2 * SR)), 500) * np.exp(-np.arange(int(0.2 * SR)) / SR * 30), np.zeros(n - int(0.2 * SR))])
    return normalize(reverb(creak + thunk, 1.2, 0.3), -4)

def sfx_door_close():
    n = int(1.0 * SR); t = np.arange(n) / SR
    s = thump(70, 1.0, 1.0, 1.2) + lowpass(rng.standard_normal(n), 900) * np.exp(-t * 25) * 0.6
    latch = np.zeros(n); i = int(0.12 * SR)
    latch[i:i + 400] = highpass(rng.standard_normal(400), 2500) * np.exp(-np.arange(400) / 60)
    return normalize(reverb(s + latch * 0.5, 1.5, 0.3), -3)

def sfx_door_bash():
    n = int(1.6 * SR); t = np.arange(n) / SR
    crash = lowpass(rng.standard_normal(n), 2500) * np.exp(-t * 9)
    boom = thump(55, 1.6, 1.3, 2.5)
    crack = highpass(rng.standard_normal(n), 2000) * np.exp(-t * 30) * 0.7
    return normalize(reverb(np.tanh((crash + boom + crack) * 1.5), 2.0, 0.35), -1)

def sfx_page():
    n = int(0.7 * SR); t = np.arange(n) / SR
    s = bandpass(rng.standard_normal(n), 2000, 8000) * (0.4 + 0.6 * np.abs(np.sin(2 * np.pi * 7 * t))) * env_adsr(n, 0.05, 0.2, 0.6, 0.3)
    return normalize(s, -8)

def sfx_exit():
    n = int(4.0 * SR); t = np.arange(n) / SR
    s = np.zeros(n)
    for k, f in enumerate([659.3, 987.8, 1318.5, 1661.2, 1975.5]):   # E major, rising
        s += np.sin(2 * np.pi * f * t) * np.clip((t - k * 0.25) * 2, 0, 1) * np.exp(-np.clip(t - k * 0.25, 0, None) * 0.8) * 0.3
    s += bandpass(rng.standard_normal(n), 3000, 9000) * np.sin(np.pi * t / 4.0) * 0.08
    return normalize(reverb(s, 3.0, 0.5), -4)

def sfx_splat():
    n = int(1.0 * SR); t = np.arange(n) / SR
    s = lowpass(rng.standard_normal(n), 1200) * np.exp(-t * 12) + thump(40, 1.0, 1.2, 1.5)
    return normalize(np.tanh(s * 2), -2)

def sfx_flare():
    n = int(2.2 * SR); t = np.arange(n) / SR
    hiss = bandpass(rng.standard_normal(n), 1800, 9000) * np.clip(t / 0.05, 0, 1) * np.exp(-np.clip(t - 0.5, 0, None) * 2.5) * 0.5
    pop = np.zeros(n); i = int(0.5 * SR)
    pop[i:i + int(0.6 * SR)] = (lowpass(rng.standard_normal(int(0.6 * SR)), 1500) * np.exp(-np.arange(int(0.6 * SR)) / SR * 9)
                                + thump(90, 0.6, 0.8, 1.5))
    crackle_ = highpass(rng.standard_normal(n), 3000) * (rng.random(n) < 0.004) * 3.0 * (t > 0.5) * np.exp(-np.clip(t - 0.5, 0, None) * 1.5)
    return normalize(reverb(hiss + pop + crackle_, 2.5, 0.4), -3)

def sfx_grind():
    # stone grinding against stone, a long low scrape with a thud at the end
    d = 3.0; n = int(d * SR); t = np.arange(n) / SR
    env = np.clip(t / 0.3, 0, 1) * np.clip((d - 0.35 - t) / 0.4, 0, 1)
    rumble = lowpass(rng.standard_normal(n), 140) * 2.5
    scrape = bandpass(rng.standard_normal(n), 300, 1400) * (0.6 + 0.4 * np.sin(2 * np.pi * 7.3 * t) ** 2)
    stutter = (0.7 + 0.3 * np.sign(np.sin(2 * np.pi * 3.1 * t + np.sin(t * 5))))
    s = (rumble + scrape * 0.6) * env * stutter
    end = np.zeros(n); i = int((d - 0.4) * SR)
    th = thump(50, 0.45, 1.2, 0.8)[: n - i]
    end[i:i + len(th)] = th
    return normalize(reverb(s + end, 2.5, 0.35), -3)

def sfx_key():
    # a heavy old key lifted off stone: a scrape, then a ringing clink
    n = int(1.6 * SR); t = np.arange(n) / SR
    scrape = bandpass(rng.standard_normal(n), 1500, 6000) * np.exp(-t * 18) * 0.3
    ring = sum(np.sin(2 * np.pi * f * t) * a for f, a in ((1870, 1), (2930, .6), (4410, .35))) * np.exp(-np.clip(t - 0.12, 0, None) * 5) * (t > 0.12) * 0.4
    return normalize(reverb(scrape + ring, 1.5, 0.3), -5)

def sfx_lock():
    # a locked gate: iron rattling against iron
    n = int(0.8 * SR); t = np.arange(n) / SR
    s = np.zeros(n)
    for k in range(5):
        i = int((0.03 + k * 0.11 + rng.random() * 0.03) * SR)
        m = min(n - i, int(0.12 * SR))
        s[i:i + m] += bandpass(rng.standard_normal(m), 900, 5000) * np.exp(-np.arange(m) / SR * 40) * (1 - k * 0.12)
        s[i:i + m] += np.sin(2 * np.pi * 620 * np.arange(m) / SR) * np.exp(-np.arange(m) / SR * 30) * 0.4
    return normalize(reverb(s, 1.0, 0.25), -4)

def sfx_unlock():
    n = int(1.4 * SR); t = np.arange(n) / SR
    click = np.zeros(n)
    for at in (0.05, 0.32):
        i = int(at * SR); m = int(0.08 * SR)
        click[i:i + m] += highpass(rng.standard_normal(m), 1500) * np.exp(-np.arange(m) / SR * 60)
    clunk = np.concatenate([np.zeros(int(0.3 * SR)), thump(80, 1.1, 0.9, 1.0)])[:n]
    return normalize(reverb(click + clunk, 1.6, 0.35), -3)

def sfx_lights_out():
    # every light goes at once: a deep thump and the fizz of flames dying
    n = int(2.4 * SR); t = np.arange(n) / SR
    s = thump(38, 2.4, 1.3, 0.6) + bandpass(rng.standard_normal(n), 2500, 8000) * np.exp(-t * 3.5) * 0.25
    return normalize(reverb(s, 3.0, 0.45), -2)

def sfx_hum():
    # a wrong, beating drone for the false doors (loops)
    d = 4.0; n = int(d * SR); t = np.arange(n) / SR
    s = sum(np.sin(2 * np.pi * f * t) * a for f, a in ((110, .5), (110.5, .5), (165.25, .3), (233.1, .2)))
    s *= 0.7 + 0.3 * np.sin(2 * np.pi * 0.25 * t)
    return normalize(s, -9)

def sfx_whisper():
    # breathy, almost-words (loops)
    d = 5.0; n = int(d * SR); t = np.arange(n) / SR
    s = np.zeros(n); r = np.random.default_rng(7)
    for k in range(9):
        at = r.random() * (d - 0.6); m = int(r.uniform(0.25, 0.55) * SR); i = int(at * SR)
        e = np.sin(np.pi * np.arange(m) / m) ** 2
        lo = r.uniform(900, 1800)
        s[i:i + m] += bandpass(r.standard_normal(m), lo, lo * 2.8) * e * r.uniform(0.4, 1.0)
    return normalize(reverb(s, 2.0, 0.5), -10)

def sfx_creak():
    d = 2.2; n = int(d * SR); t = np.arange(n) / SR
    f = 120 + 60 * t / d + 15 * np.sin(2 * np.pi * 5 * t)
    ph = 2 * np.pi * np.cumsum(f) / SR
    creak = np.sign(np.sin(ph)) * (0.5 + 0.5 * np.sin(2 * np.pi * 31 * t)) * env_adsr(n, 0.4, 0.4, 0.8, 0.6)
    return normalize(reverb(bandpass(creak, 250, 2200) * 0.5, 1.6, 0.35), -5)

def sfx_fire():
    # a small campfire (loops)
    d = 6.0; n = int(d * SR); t = np.arange(n) / SR
    roar = lowpass(rng.standard_normal(n), 400) * (0.6 + 0.4 * lowpass(rng.standard_normal(n), 2)) * 0.8
    pops = highpass(rng.standard_normal(n), 2500) * (rng.random(n) < 0.0009) * 6.0
    pops = lowpass(pops, 6000)
    return normalize(roar + pops, -8)

def sfx_heartbeat():
    n = int(1.1 * SR)
    s = np.zeros(n)
    for at, a in ((0.0, 1.0), (0.22, 0.7)):
        th = thump(48, 0.35, a, 0.6); i = int(at * SR)
        s[i:i + len(th)] += th[: n - i]
    return normalize(s, -3)

def sfx_rustle():
    # something moving under paper
    n = int(2.0 * SR); t = np.arange(n) / SR
    s = bandpass(rng.standard_normal(n), 1200, 7000) * (0.3 + 0.7 * np.abs(np.sin(2 * np.pi * 2.3 * t)) ** 3) * env_adsr(n, 0.3, 0.3, 0.8, 0.6)
    return normalize(s, -6)

SFX = {'key': sfx_key, 'lock': sfx_lock, 'unlock': sfx_unlock, 'lights_out': sfx_lights_out, 'hum': sfx_hum,
       'whisper': sfx_whisper, 'creak': sfx_creak, 'fire': sfx_fire, 'heartbeat': sfx_heartbeat, 'rustle': sfx_rustle,
       'grind': sfx_grind, 'flare': sfx_flare, 'breath': sfx_breath, 'screech': sfx_screech, 'step1': lambda: sfx_step(1), 'step2': lambda: sfx_step(2),
       'step3': lambda: sfx_step(3), 'door_open': sfx_door_open, 'door_close': sfx_door_close,
       'door_bash': sfx_door_bash, 'page': sfx_page, 'exit': sfx_exit, 'splat': sfx_splat,
       'bell': sfx_bell, 'splash': sfx_splash, 'emerge': sfx_emerge, 'thud': sfx_thud,
       'roar': sfx_roar, 'ink': sfx_ink}

# ================================================================ output
def write_ogg(path, x, quality=4):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    pcm = (np.clip(x, -1, 1) * 32767).astype(np.int16)
    with tempfile.NamedTemporaryFile(suffix='.raw', delete=False) as f:
        f.write(pcm.tobytes()); raw = f.name
    subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-f', 's16le', '-ar', str(SR), '-ac', '1', '-i', raw,
                    '-c:a', 'libvorbis', '-q:a', str(quality), path], check=True)
    os.unlink(raw)
    print('wrote', os.path.relpath(path, ROOT), '%.1fs' % (len(x) / SR))

if __name__ == '__main__':
    import sys
    only = sys.argv[1:]
    for name, fn in SETS.items():
        if only and name not in only:
            continue
        for layer, sig in fn().items():
            write_ogg(os.path.join(ROOT, 'assets', 'music', f'{name}_{layer}.ogg'), sig)
    if not only or 'sfx' in only or any(o in SFX for o in only):
        for name, fn in SFX.items():
            if only and 'sfx' not in only and name not in only:
                continue
            write_ogg(os.path.join(ROOT, 'assets', 'sfx', f'{name}.ogg'), fn())
