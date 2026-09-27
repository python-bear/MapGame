# Design reviews — as Alex Chen

Three rounds of play-and-review from the perspective of Alex Chen (senior game
designer; judges by playing; cares about how the player *learns*, whether the
map is the mechanic, and Teach → Test → Twist → Master). Each round lists what
Alex noticed, what we changed, and what's left for the next round.

---

## Round 1 — "The map is scenery"

**Played:** title → intro → Level 1 → Level 2 → Level 3 (after the team's
requested fixes: rustic UI, skip on endings, trail round Lookout Hill, trees
out of the water, third tent, skull doodles, bigger night crossing in Level 2,
longer halls in Level 3).

**One-sentence test.** "You walk/sail/run to the exit of three differently
styled maps." That's the honest description — and it's the warning sign. The
map is gorgeous, but it's the *environment*, not the *mechanic*.

**What does the player know at 0:30?** Everything. Tab shows the entire,
finished map of Level 1, including the goal, the washed-out bridge and both
routes. There's nothing to discover, so there's no decision: the player just
traces a line they can already see. The "trap" bridge can't trap anyone who
has looked at the map.

**What I liked.** The ink route trailing behind you; handwriting that isn't
his bleeding onto the page; the red "?" where the map ends. These all say "the
map is alive" — they're hints of the game this wants to be.

**Biggest lever (fix this first).** He's a cartographer who *falls asleep while
drawing*. So make the dream map unfinished: **the world only exists on paper
where you've been.** You start with the camp he'd already drawn, and the mark
the guide showed him on the summit — and blank paper in between. Walking inks
the land around you. Then give that one mechanic a clever interaction:

* **High ground shows more.** From a hilltop or the plateau you chart much
  further; in the jungle you can barely see past your hat. Now Lookout Hill is
  a real choice: spend time climbing to learn the land, or push on blind.
* **Tab shows *your* map** — only what you've charted. It's knowledge, not a
  cheat sheet. The washed-out bridge becomes a genuine discovery.
* **Notes appear when you find their places.**
* **Surveying is scored.** The completion card shows how much of the sheet you
  charted — a second goal for replays that pulls against the speedrun.

Also: each level should say its goal in one line when it starts (not a
tutorial — a destination).

**Changes made in Round 1**
1. Charting: the map is blank except what you've explored; ink spreads from
   you as you walk (soft, inky edge). Levels 1 and 2 both use it.
2. Sight depends on terrain: lowland 4.5 cells, jungle 3, plateau 7, summit 9.
3. Tab shows only your charted map; notes fade in as their places are charted.
4. The goal mark is always visible on the blank paper, so you know *where*, not *how*.
5. "Surveyed N% of the sheet" on the completion card.
6. A one-line goal under each level title.

**Left for Round 2:** Level 2 now uses the same reveal, but it doesn't *test*
anything new yet — the sea is just a bigger Level 1 with monsters.

---

## Round 2 — "Blind isn't a decision"

**Played:** Round 1 build.

**Level 1 now teaches.** I left camp with a blank sheet, saw the mark on the
summit, and immediately asked "which way?" — that's the question I want. I
climbed Lookout Hill *because* I wanted to see more, and the map rewarded me.
The washed-out bridge finally caught me out. Teach: ✔.

**Level 2 should *test* it — it doesn't yet.** At night the lantern shows four
cells. Crossing the Open Deep is "hold right for eight seconds" with nothing to
decide, and then the shoals are a maze I have to feel my way through in the
dark while the minute runs down. When I hit a dead end I didn't feel *outwitted*,
I felt *blindfolded*. Information has no value if you can't do anything to get
it.

**Clarity.** I was dragged under twice and wasn't sure why the second time. The
bells are wonderful, but nothing tells me they're counting down. A tentacle rose
right in front of me with no warning I could read at speed.

**Fixes (the "information costs something" round).**
* **Flares.** You carry three. Fire one (E / Space) and it arcs ahead of the
  ship and bursts, charting a wide circle of sea. Now the Open Deep has a
  decision in it: *spend a flare now to plan the shoals, or save it?*
* **Light wakes the deep.** Every flare also wakes something beneath where it
  burst. Information is a resource *and* a risk — the same mechanic, pulling
  two ways.
* **Readable threats.** Tentacles swell as a dark shape with bubbles before they
  rise (you get ~0.7 s to steer away).
* **Readable failure.** The failure card names the rule you broke: "one minute —
  the bell tolls at 30, 45, 50 and 55", or "a tentacle touched the hull — watch
  for dark shapes swelling under the water".
* **Flares on the HUD** as three small drawn flare icons, so the resource is
  always visible.

**Left for Round 3:** the finale throws the map away. The 3D labyrinth has no
map at all — the core mechanic vanishes at the moment it should pay off.

## Round 3 — "The finale forgets what the game is about"

**Played:** Round 2 build.

**Level 2 now tests.** Out in the Open Deep I had a real decision: fire a flare
to see the Teeth before I reached them, or keep it for the shoals. I fired one
early, saw the Maw, chose the top gap instead — and the thing my flare woke
chased me into it. That's the loop: *explore → discover → decide → pay for it.*
The warnings under the water made my deaths feel fair.

**Level 3 drops the mechanic.** Two levels have taught me that *the map is my
knowledge*, and then the finale — the level that should be the payoff — has no
map at all. It's a good-looking chase, but it's a different game. There's no
Twist, because the thing that should be twisted has gone.

**Fixes (the "your map lies" round).**
* **Your map comes with you.** Hold Tab and he looks at the page he's drawing:
  every corridor you've *seen* is inked, with doors, the exit if you've seen
  its light, and where you last saw the beast's eyes. Reading it while walking
  slows you down — knowledge costs time when something is hunting you.
* **The twist: the labyrinth moves.** Every so often, somewhere you *aren't
  looking*, a wall grinds down into the floor and another rises. Your map
  keeps showing the old wall until you see the place again — then the old line
  is struck through. The first time a remembered wall isn't there, the player
  thinks exactly: *"Wait… the map changed."*
* **Always a way out.** A wall only moves if the light can still be reached
  and it never happens within sight or close by.
* **"I want to play another level."** A *Chapters* page on the title screen
  (unlocked as you reach them) with your best times, so a player can jump
  straight back into the level they want to beat.

**Where it lands (Teach → Test → Twist → Master):**
| Level | Beat | What the map does |
|---|---|---|
| I. The Survey | Teach | Walking charts the land; high ground charts more. |
| II. The Drowned Chart | Test | Charting has a cost: flares show far, but wake the deep. |
| III. Waking | Twist | Your map follows you — and the labyrinth makes it wrong. |
| (next: a streets level) | Master | Would combine all three: limited flares/sight, a shifting map, and something that follows the roads you've drawn. |

**Still to consider (not done):** the one-sentence pitch is now *"A cartographer
dreams his way through maps that only exist where he's been — and then stop
being true."* A fourth "Master" level that combines everything would complete
the arc.
