#!/usr/bin/env python3
"""Finds spots in a top-down level you can walk into but never get out of.
Usage: python3 tools/check_traps.py levels/level1/level1_data.gd"""
import re, sys, collections
src=open(sys.argv[1] if len(sys.argv)>1 else 'levels/level1/level1_data.gd').read()
def layer(name):
    block=src.split('const %s := ['%name)[1].split(']')[0]
    return re.findall(r'"([^"]*)"',block)
T=layer('TERRAIN'); H=[[int(c) for c in r] for r in layer('HEIGHT')]
W,Hh=len(T[0]),len(T)
C=32; HALF=7; STEP=4
WALK=set('.pfms=SG')
RELAX = True  # matches MapGrid.body_fits
def tile(cx,cy): return T[cy][cx] if 0<=cx<W and 0<=cy<Hh else 'X'
def el(cx,cy): return H[cy][cx] if 0<=cx<W and 0<=cy<Hh else 0
def can_enter(c,f,touch):
    if tile(*c) not in WALK: return False
    dh=abs(el(*c)-el(*f))
    if dh==0: return True
    return dh==1 and (tile(*c)=='s' or tile(*f)=='s' or touch)
def fits(px,py,f):
    cells=[((px+dx)//C,(py+dy)//C) for dx in(-HALF,HALF) for dy in(-HALF,HALF)]
    touch = RELAX and (tile(*f)=='s' or any(tile(*c)=='s' for c in cells))
    return all(can_enter(c,f,touch) for c in cells)
def nbrs(p):
    x,y=p; f=(x//C,y//C)
    for dx,dy in((STEP,0),(-STEP,0),(0,STEP),(0,-STEP)):
        if fits(x+dx,y+dy,f): yield (x+dx,y+dy)
def find(ch):
    for y,r in enumerate(T):
        if ch in r: return (r.index(ch)*C+16,y*C+16)
s=find('S'); s=(s[0],s[1]+28); s=(s[0]//STEP*STEP,s[1]//STEP*STEP)
g=find('G')
seen={s}; q=collections.deque([s]); edges=collections.defaultdict(list)
while q:
    p=q.popleft()
    for n in nbrs(p):
        edges[n].append(p)
        if n not in seen: seen.add(n); q.append(n)
goalnodes=[p for p in seen if abs(p[0]-g[0])<16 and abs(p[1]-g[1])<16]
print('reachable',len(seen),'goal reached',bool(goalnodes))
back=set(goalnodes); q=collections.deque(goalnodes)
while q:
    p=q.popleft()
    for n in edges[p]:
        if n not in back: back.add(n); q.append(n)
traps=[p for p in seen if p not in back]
print('trap nodes',len(traps))
cells=collections.Counter((x//C,y//C) for x,y in traps)
print(sorted(cells.items())[:40])
