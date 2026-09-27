# Cartographer's Dream

**video**: https://youtu.be/D9L1EtlrO38

A cartographer falls asleep over his map by the campfire and dreams of maps — which slowly turn to nightmare.
Top-down map levels, then a first-person cave and a first-person horror finale. Built as a speedrunning game.

**Engine:** Godot 4.4 (Compatibility renderer, so it also runs on the web and older GPUs).
Open `project.godot` in Godot and press **F5**.

**The one mechanic:** *the map.* Across the three levels the cartographer's greatest strength — understanding the world by mapping it — slowly becomes useless:

| Level | The map… | What that means in play |
|---|---|---|
| I. The Survey | **helps you** | Walking charts the land; plan a route across it. Then, halfway, part of it changes — and the way home is different again. |
| II. The Drowned Chart | **becomes unreliable** | At night your lantern charts only a little. After the first beacon an uncharted island rises; after the second a channel silts shut and an island starts to drift. *"The map isn't describing the ocean any more."* |
| III. Waking | **cannot be trusted** | Your journal map works — until the silent room, when the ink runs: *"I cannot map this place."* Corridors change behind you; false doors of light send you elsewhere. |

(`docs/design_reviews.md` has the three review rounds as judge Alex Chen that shaped the earlier versions.)

## What's here

- **Title screen** — Begin, Chapters (unlocked as you reach them, with best times and optional finds), Settings, Quit.
- **Settings** — *Show speedrun timer* (**off by default**), Fullscreen, Music and Sound volume, **Brightness** (lifts the dark parts of the picture; a gamma curve over the whole screen, costing nothing when left at 1). The timer and Brightness can also be changed from the pause menu, mid-level.
- **Intro** — an animated, woodcut-style film (dark, medieval) of why he goes to the isle: the King's commission, the chart with its blank edge, his lost master's drowned journal, the Codex of the Ringed Eye, and the harbour where he boards the ship — until, on the ninth night, the chart becomes the sea (Level 1). Space / Enter for the next line, hold to skip.
- **Arrival** — after the crossing, a second film (`scenes/arrival.tscn`, same script as the intro): the isle rising out of the dawn fog, and Harrow's Landing, where his master's tents still stand beside a post carved with the ring and the eye. Not timed — but with the timer on it stays on screen, paused, through the intro, the interludes and the endings.
- **Every level** opens with its title and a one-line goal in his handwriting, and keeps a small checklist top-left.
- The story, in order: **Level 1 — "The Drowned Chart"** (Arv) — he dreams the crossing from home to the island · **Level 2 — "The Survey"** (Jay) — the island's jungle, and the camp that becomes a cave · **Level 3 — "The Hollow"** (Owen, 3D cave) — trapped inside · **Level 4 — "Waking"** (Owen, the 3D finale, two endings) — the escape. (The folders keep their original names: the sea is `levels/level2/`, the jungle `levels/level1/`.)
- **Holding Tab** to study your map (or chart, or journal) stops you where you stand.
- **Interludes** — between the later levels: a few lines of the dream, then an illustrated page from the Codex of the Ringed Eye about the monster (`scenes/interlude.gd`; `Game.next_level()` goes through it automatically).
- **Endings** — staged scenes at the campfire (hold Space to skip).
- **Adaptive music** — faint at first, swelling as danger rises, darker with each level; silent when it matters most.

### Level 1 at a glance — The Drowned Chart (`levels/level2/`)

He dreams the crossing: the voyage out to the island.

Night. **The Mainland** (harbour) → **the Open Deep** → **the Teeth** and **the Shoals** (two chains of islands) → **Harrow's Landing** (pier, three tents).

| Feature | How it plays |
|---|---|
| **Three beacons** | Sail close to each lighthouse to light it. The pier stays dark — you can't dock — until all three are lit |
| **Routes** | Through the Teeth: the top gap (long, safe), **the Maw** (fast, narrow, guarded), the bottom gap (choked with rocks). Through the Shoals: a north gap narrowed by a **sandbar** (shallow water — you run aground), a south gap, and a channel that looks like a way through and ends in a sandbar |
| **The ocean changes** | 1st beacon: an island rises where the chart shows open sea. 2nd beacon: the Maw silts shut, and an island starts to **drift** up and down the approach to the Landing |
| **Tentacles** | One creature under the chart: a dark mantle breaks the surface, its single eye on the ship, and the limb rises out of the foam beside it |
| **Tension** | 0:00–0:30 nothing obvious: rings on the water · 0:30–0:45 tentacles stand far off, watching, and sink when you come near; something knocks beneath the ship · 0:45–1:00 they hunt you, and rise in the channels ahead · 1:00+ they erupt all round the ship — at 1:15 the sea takes it |
| **Don't hug the edges** | Sail along the chart's edge, or creep through the shallows, and they come up ahead of you there |
| **Lost ships** (3, optional) | Sail alongside to signal. One's log reveals that a sandbar isn't really there (a hidden shortcut through the Shoals), one tells a story, one carries a message from another cartographer |
| Flares (3) | **E / Space**: chart a wide circle ahead. Before 0:45 the light shows you a watcher; after, it wakes a hunter |

### Level 2 at a glance — The Survey (`levels/level1/`)

| Feature | How it plays |
|---|---|
| **The expedition route** | Five places, **in order**: the old stone marker → the river crossing → the abandoned campsite → the hilltop → the final surveying point. Only the next one is named. Terrain decides your route: trails fast (×1.3), jungle slow (×0.5), marsh very slow |
| **Survey markers** (6, optional) | Stakes drawn on his map (S1–S6). Walk to one to record it. **Two aren't where the map says** — at the drawn spot: *"not here"*; the real stake is nearby |
| **The map changes** | At the abandoned campsite: the rope bridge he crossed is gone, a path he never drew runs north through the jungle, and jungle covers open ground |
| **Return to camp before nightfall** | At the surveying point the goal becomes RETURN TO CAMP, and the way back has changed again (the west stairs have fallen in, the east bridge is gone, the washed-out bridge is whole). 90 s of dusk: the light cools and your sight shrinks. Night falls → start again |
| **The camp is gone** | Coming back, a few steps from camp, the camp isn't there: a cave mouth is drawn where the tents and fire were, with a note in his hand beside it. Walk into it to finish — the cave is the next level |
| **Perfect map** (optional) | Finish without setting foot in dead-end terrain (the delta marsh, under the sheer cliffs, the far corner of the Green Deep, the spur to the washed-out bridge) |
| The pen (2 ink) | **E / Space** facing a river: ink a bridge of up to 4 cells — or mend a broken one |
| Charting | Ink spreads round you as you walk; high ground shows much more, jungle much less. **Tab**: your map |

### Level 3 at a glance — The Hollow (3D cave)

First person, no body, only the warm light of the lantern he carries. **FIND THE WAY ON.**

| Feature | How it plays |
|---|---|
| **The mouth closes** | He starts in the daylight at the cave mouth. A few steps in, the rock swells out of the walls and seals it behind him — and the painted hands by the entrance smoulder red |
| **Winding passages** | Rough stone and packed earth, sloping down. A fork: west to a side chamber, north to the painted chamber; a loop back round; a dead end; and east, down to the door |
| **Cave paintings** (8, optional) | Ochre and dark red: hands, a hunt, people dragged into a ring, the thing with the eye and the arms (faintly glowing, and not quite the same the second time you look), a **map of this cave** showing the door, a map of the country they walked through, a procession into the ring, spirals. Look at one up close to read his thought on it |
| **The bones** | A heap of old bones in the western side chamber |
| **The door** | Cut stone set in the living rock, an oak door, pale light round its edges and the ring-and-eye sign over it. **E / Space** to open; walk into the light → interlude → the finale |

The cave is generated by `python3 tools/gen_cave.py` (numpy, scipy, scikit-image, Pillow): passages and rooms as a signed-distance field, meshed with marching cubes into `levels/cave/mesh/`, plus the rock and dirt textures, the paintings (`levels/cave/paintings/`) and `levels/cave/cave_data.gd` (where the paintings, bones, mouth and door are). Edit the `PATHS` / `ROOMS` / `PAINTINGS` tables at the top and re-run; it refuses to write a cave that can't be walked through. Timings and his thoughts are in `levels/cave/cave.gd`.

### Level 4 (finale) at a glance — the map cannot be trusted

**FIND THE DOOR OF LIGHT.** It's behind the **Black gate**; the Black Key is behind the **Stone gate**; the Stone Key is behind the **Iron gate**; the Iron Key is in a small room in the south-west.

| Key / feature | How it plays |
|---|---|
| **The Iron Key — the silent room** | The door shuts behind you. The music stops. Take the key and every light goes out; the door opens again. Nothing seems to have changed — but outside, the corridors are not the ones you came in by. From now on your journal map (Tab) is ruined: *"I cannot map this place."* |
| **The Stone Key — follow the lights** | Inside the Iron gate three groups of wisps set off three ways. Two flicker and hurry off into dead ends, and go out when you catch them. One moves steadily, turns slowly, and **waits for you** |
| **The Black Key — the beast** | You hear it breathing in the east wing. Take the key and it rises out of the dark: a winged, tentacle-faced colossus with red eyes, bat wings (half-folded in the corridors, flung wide when it screams), long spined tentacles from its back and black mist round its feet |
| **The key hotbar** | Three slots at the bottom of the screen for the Iron, Stone and Black keys. A key you pick up goes into your hand (you see it held out in front of you). **1 / 2 / 3** or the **mouse wheel** swap keys. A gate opens only for the key in your hand; with the wrong one out it tells you which number to press |
| **Final chase** | The fog thickens, every wisp goes out, the music stops; only the Black Key's red glow in your hand. Then breathing behind you. Objective: **ESCAPE** |
| **Sound** | Running (Shift) is loud (~20 m, as sound travels through the maze), doors ~13 m, walking ~4 m, standing still silent. The beast also sees you if you're close and in line with it. It moves at **0.9× your walking speed**, so you can always get away if you keep moving; running tires you. When it loses you it searches nearby and **stops to listen** — then it hears twice as far. Doors hold it ~1.3 s |
| **The labyrinth remembers** | A corridor with three doors has four the next time you come back, and the time after that one stands ajar. A door you walked through becomes a wall |
| **Joined doors** (west wall ↔ east wall) | Two doors glowing violet, each with the same spinning spiral carved over it. Open one and a swirl turns behind it; walk in and you step out of the other one, across the labyrinth, with a violet rush and a lurch of the lens. **Nothing resets** — keys, pages, ink and the timer all carry on |
| **The dud** (south wall, near where you wake) | Looks just like the Door of Light. Open it: bricks. The light was painted on the stone, and it gutters out. It does nothing, ever again |
| **The Door of Light** | Approach with the Black Key and it opens by itself; white light spills into the corridor. **The beast stops. It will not cross the light** |
| **Caught** | A black blink, and it's in your face: wings thrown open, claws spread, its beard of tentacles flared, lit from below, roaring. Then blood on the lens |
| **Dressing** | Cobwebs in the upper corners (a few with spiders that creep about), slumped skeletons, heaps of bones and lone skulls, rusted chains swaying from the walls. Placed from their own random seed, so the walls never change |
| Also | Wooden doors (E / Space), a barred door out of the east wing (lift the bar from inside), ink walls (Q / right-click, 2), three torn pages |

### The story and the Warden

Anno Domini 1348. The King's chart shows every coast of the kingdom but one: a blank at the western edge, where the monks wrote *Hic habitat Custos* — here dwells the Warden. Seven winters ago the cartographer's old master, **Elias Vane**, sailed to fill it; the sea gave back only his journal (a labyrinth drawn over and over, the ring and the eye, and *"It does not want to be drawn."*). The King sends his cartographer to finish the map. (Vane is the "E. Vane" whose message is scratched on a lost ship's rail in the crossing, Level 1.)

**The Warden (Custos)** came out of the western sea before there were kings; the fisher-folk called it *the Eye that Walks*. The **Brothers of the Ringed Eye** built **the Knot** — the labyrinth — to hold it: three gates (iron, stone, and black iron that weeps when touched) and one door blessed with light, which it will not cross. It is blind to all but sound, so the Brothers walked the Knot in silence. And: *whosoever maps the Knot is mapped by it, and is made a wall within it, forever.* This lore is told in the intro and on the Codex pages between levels, and ties into the finale's keys, sound-hunting beast and Door of Light.

### Endings

- **Escape** — white. He wakes beside the campfire. The others lie round it and will not wake; their eyes are open, all turned to his map. The map is finished — and in its corner, in a hand not his, the ring and the eye, and the ink runs like blood. *What is drawn, the Warden knows:* out beyond the tents, red eyes open in the dark.
- **Caught** — a jumpscare, blood on the lens, black. Then the campfire: him sitting upright among the sleepers, eyes open, the labyrinth on his map and something moving under the paper. The fire gutters and the dark between the trees reaches for him. At dawn: a cold fire, an empty bedroll, and the map in the ashes — with one wall more in the labyrinth than there was.

**Controls:** WASD / arrows / left stick to walk or steer · **Shift** run (Level 3) · **Tab / M** (hold) your map · **E / Space** bridges (L1), flares (L2), doors, keys & pages (L3) · **Q** ink a wall (L3) · look (L3) with the mouse, trackpad (or two-finger drag), **,** / **.** or the right stick · **R** restart · **Esc** pause.

## Music

`scripts/music.gd` is autoloaded as **Music**. Each level has a *set* of three stems that loop in sync:

| Stem | When you hear it |
|---|---|
| `calm` | Always, quietly |
| `tension` | Fades in as danger rises |
| `danger` | Fades in when the player is in real trouble |

A level calls `Music.play_set("level2")` once and `Music.set_danger(x)` (0–1) whenever it likes. One-shot sounds: `Music.sfx("bell")` (also `splash`, `emerge`, `thud`, `roar`, `ink`, `step1-3`, `page`, `exit`, `splat`, `key`, `lock`, `unlock`, `lights_out`, `creak`, `heartbeat`, `rustle`, `whisper`; loops `hum`, `fire`). The finale's doors and beast play theirs in 3D (`door_open`, `door_close`, `door_bash`, `breath`, `screech`).

| Set | Feel |
|---|---|
| `menu` | Music box, soft pad, campfire crackle |
| `level1` | Warm D dorian, faint; a heartbeat and a creeping minor second near the goal |
| `level2` | Cold C phrygian, lower; drones, whale-like calls, bells, waves → string ostinato → pounding drums |
| `level3` | Near-silence: a sub drone, dripping water, a draught → a slow heartbeat → a fast heartbeat and a thin whine as the beast closes in |

All music and sounds are generated by `tools/gen_music.py` (numpy + scipy + ffmpeg). To give Level 3 or 4 their own set, add a `level3()` function there (make it darker still), add it to `SETS`, run the script, then call `Music.play_set("level3")` in your level. You can also replace any `.ogg` in `assets/music/` with a real recording — keep the file names and the stems the same length so they stay in sync.

## Speedrun timer

- Starts on the first movement input in a level, stops when you reach the goal (or die).
- Always runs in the background; the setting only decides whether it's shown.
- Per-level bests are saved to `user://records.cfg`. A full run's total ("run") is also tracked from *Begin*.

## Project layout

```
project.godot
scripts/
  game.gd              Autoload "Game": settings, timer, best times, level order, fades, input map, fail/complete
  music.gd             Autoload "Music": adaptive stems + sound effects
  map_grid.gd          Terrain grid + movement rules (reusable for any top-down level)
  map_renderer.gd      Draws a MapGrid as a hand-inked land survey (Level 1; @tool, renders in the editor)
  sea_chart_renderer.gd  Draws a MapGrid as a nautical chart (Level 2; @tool)
  iso_lines.gd         Marching-squares helpers for smooth coastlines and contours
  map_note.gd          Draggable handwritten notes / region names / ominous notes / skull & tentacle doodles
  explorer.gd          Level 1 player (on foot)
  ship.gd              Level 2 player (the ship)
  tentacle.gd          Guard / hunting / closing / watching tentacles
  beacon.gd            Level 2 lighthouses to light
  lost_ship.gd         Level 2 ships adrift (optional; each answers differently)
  drifting_island.gd   Level 2 islands that appear or move (they write themselves into the grid)
  sea_omens.gd         The sea level's first half-minute: rings on the water
  sea_current.gd       (unused now — the sea's currents were removed)
  sheet_baker.gd       Bakes a map/chart into a texture, and pre-renders its coming changes as patches (no stalls when the map changes)
  chart_reveal.gd      The charting mask: what's been inked, fed to shaders/chart_reveal.gdshader
  flare.gd             Level 2 flares
  labyrinth_journal.gd The finale's map (Tab) and what he has seen
  maze_builder.gd      Builds the 3D labyrinth from ASCII (walls, doors, wisps, exit); pathfinding for the beast (@tool)
  fps_player.gd        First-person player (no body), running + stamina, noise, interaction ray
  door.gd              Swinging wooden door (AnimatableBody3D leaf); gates, bars, locks, ajar
  wisp_group.gd        A cluster of will-o'-the-wisps with one light; guides (honest or lying)
  beast.gd             The beast: body, animation, jumpscare, sound-based hunting AI (hunt / search / listen / halt)
  key_hotbar.gd        The finale's key hotbar (3 slots, 1 2 3 / wheel) and the key held in front of the camera
  light_door.gd        Doors in the outer wall: the Door of Light, the joined portal pair, the dud
  fps_overlay.gd       Prompt, his thoughts, stamina, page text, blood splatter, flashes, fades
  map_page.gd          Readable pages in the labyrinth
  ink_route.gd         The red dashed line of the route you've taken
  ink_bridge.gd        Level 1 inked bridges
  key_pickup.gd        The finale's keys
  light_door.gd        The finale's Door of Light, and the false ones
  ink.gd               Small pen-and-ink drawing helpers
scenes/
  main_menu.tscn, intro.tscn, interlude.tscn (lines between levels), ending.tscn (both endings, staged at the campfire), to_be_continued.tscn
  ui/hud.tscn          Timer, level title, hints, pause menu, level-complete and failure cards
levels/level1/         level1.tscn, level1.gd (route, markers, map changes, nightfall), level1_data.gd (THE MAP), expedition.gd, goal.gd
levels/level2/         level2.tscn, level2.gd (timeline, beacons, the changing sea, ambushes, lost ships), level2_data.gd (THE CHART)
levels/level3/         level3.tscn (fog, light, player, beast), level3.gd (keys, silent room, guides, memory, false doors, chase), level3_data.gd (THE LABYRINTH)
shaders/               parchment paper, vignette, chart reveal
assets/ui/             Rustic toggle and slider pieces (tools/gen_ui.py)
docs/design_reviews.md Three rounds of review as judge Alex Chen, and what changed
assets/fonts/          Caveat (handwriting) and IM Fell English — both SIL Open Font License
assets/music/, assets/sfx/   Generated audio (see Music)
assets/textures/, assets/materials/   Stone, flagstone and oak door textures (+ normal maps), wisp and smoke sprites
tools/
  gen_level1.py, gen_level2.py   Optional: sketch the first draft of the map and check it's solvable
  gen_level3.py        Builds the finale's labyrinth (wings, gates, silent room, remembering corridors) and checks it
  gen_level2_scene.py  Writes level2.tscn (notes, guard tentacles, beacons, lost ships, tents) from positions in cells
  gen_ui.py            Generates the rustic UI pieces
  gen_textures.py      Generates the finale's textures
  gen_cave.py          Builds the cave (mesh, textures, paintings, placements) and checks it can be walked
  gen_music.py         Generates all music and sound effects
  check_traps.py       Finds spots in a Level-1-style map you can walk into but not out of
  autoplay_test.gd     Dev test: a bot walks Level 1's route in order and back to camp, saving screenshots
  level2_test.gd       Dev test: a bot lights the beacons and docks (run), or waits out the clock (idle / doom)
  lost_ships_test.gd   Dev test: signal each lost ship in Level 2
  finale_test.gd       Dev test: the whole finale — calm (no beast), run (beast awake), caught, fakes (false doors)
  ending_test.gd       Dev test: screenshots through both endings
  ui_shots.gd          Dev test: screenshots of menus
```

## Editing the maps

**Level 1** — `levels/level1/level1_data.gd`, one character per 32 px cell:

```
.  open ground      p  trail (fast)      f  jungle (slow)     m  marsh (very slow)
~  water (blocked)  =  bridge            b  broken bridge     #  rock (blocked)
s  stairs — the only way between heights
S  start (camp)     G  goal
```

The `HEIGHT` layer uses `0`, `1`, `2`. After editing, run `python3 tools/check_traps.py` to make sure there are no stair spots you can get stuck in.
The route, survey markers (drawn vs. real positions), dead-end areas, the two map changes and the nightfall time are constants at the top of `level1.gd`.

**Level 2** — `levels/level2/level2_data.gd`:

```
.  open sea     ,  shallows (slower)     L  land     r  reef     w  wreck     P  pier
z  sandbar (too shallow to sail)
S  ship start   G  marks the pier's north berth (either side works)
```

Guard tentacles are nodes under **Obstacles**, beacons under **Beacons**, lost ships under **LostShips** in `level2.tscn` (or edit the lists in `tools/gen_level2_scene.py`). The timeline, the channels that can close, where new islands rise and the Maw are constants at the top of `level2.gd`.

**The finale** — `levels/level3/level3_data.gd`. The ASCII is a lattice: pillars at even/even, wall edges between them, cells at odd/odd.

```
+  pillar     #  wall     ' '  open     D  wooden door
I T K  the Iron / Stone / Black gates      Q  the silent room's door      B  door barred on one side
d  a door that becomes a wall     e  a wall that becomes a door
X  the Door of Light (outer wall) F  a false door (outer wall): the 1st and 2nd are a joined pair, the 3rd a dud
h  a wall that can sink    j  a gap a wall can rise into
S  start      M  where the beast sleeps     1 2 3  the Iron, Stone and Black keys
w  wisp group      p  torn page     r  rubble
```

It's generated by `python3 tools/gen_level3.py` (which also checks that every cell is reachable and that the changing walls never cut the maze). The wisps' paths, the silent room, the remembering corridors and the beast's waking spot are constants at the top of `level3.gd`.

Select the **Maze** node in `level3.tscn` and tick **Rebuild** to see edits. Beast tuning (speed when hunting / searching, how long doors hold it, how far it sees) is exported on the **Beast** node; fog density and the ambient light are in the scene's **WorldEnvironment**.

In either 2D scene, select the **Map** / **Chart** node and tick **Redraw** in the Inspector to see edits in the editor.

## Level order and adding levels

The level order lives in `Game.LEVELS` (`scripts/game.gd`): Drowned Chart → Survey → The Hollow → Waking. A level's optional `"finds"` names its optional collectables on the Chapters page. To show lines between a level and the next, add them to `TEXTS` in `scenes/interlude.gd` under the level's id — `Game.next_level()` goes by way of the interlude automatically.

**When a 2D map changes in play**, don't redraw the whole sheet (it stalls for a moment): render the change ahead of time with `SheetBaker` and show its patch — see `_prebake_changes()` in either map level. The street/ghoul level from the original plan could slot in before the finale — add it to `LEVELS` and it's picked up automatically. A level only needs to:

1. Instance `res://scenes/ui/hud.tscn` (timer, pause, restart, completion and failure cards come for free).
2. Call `Game.begin_level_timer()` on the player's first input.
3. Call `Game.complete_level()` when the player finishes, or `Game.fail_level("what happened")` if they die. Set `hud.completion_text` / `hud.failure_title` for custom lines.
4. Call `Music.play_set("...")` and feed `Music.set_danger()`.

The finale shows its own endings with `Game.show_ending("escape" | "caught")` (`scenes/ending.tscn`).

## Not done yet

- The street/ghoul level from the original plan — it would make a natural fourth "Master" level combining limited sight, a map that changes, and ghouls that follow the roads you've drawn.
- Music is procedural placeholder quality — good enough to feel the layering; swap in real recordings any time.
- The finale's chase and Level 1's nightfall are tuned against test bots, not people yet — playtest them. The knobs: `speed_ratio` / `bash_delay` on the Beast, `stamina_max` / `run_speed` on the Player, `NIGHTFALL` in `level1.gd`, `DOOM_TIME` in `level2.gd`.
