# Level 2 — "The Drowned Chart" (a night crossing)
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

const TERRAIN := [
	"LLLLLLLLLLLLLLLLLL,,..................................................,LLLLLL,...........,,LLLL,,...............................",
	"LLLLLLLLLLLLLLLLLLL,..................................................,LLLLLL,,..........,LLLLLL,...............................",
	"LLLLLLLLLLLLLLLLLLL,,.................................................,LLLLLLL,......rr..,,LLLLL,...............................",
	"LLLLLLLLLLLLLLLLLLLL,.................................................,,,LLLL,,.........,,,,LLLL,...............................",
	"LLLLLLLLLLLLLLLLLLLL,,.............................................rrr..,,,,r,.........,,LLLL,,,,...............................",
	"LLLLLLLLLLLLLLLLLLLLL,.............................................rr......rwr.........,LLLLLL,.....r...........................",
	"LLLLLLLLLLLLLLLLLLLLL,......................................................rr.........,LLLLLL,,,..rrr..........................",
	"LLLLLLLLLLLLLLLLLLLLL,.................................................................,LLLLLLLL,,..r...........................",
	"LLLLLLLLLLLLLLLLLLLLL,.................................................................,,LLLLLLLL,,.............................",
	"LLLLLLLLLLLLLLLLLLLLL,,.....................................rrr.........................,,,,LLLLLL,.............................",
	"LLLLLLLLLLLLLLLLLLLLLL,,,...................................,rr,,...rrr,,,,,,,...........r.,LLLLL,,.............................",
	"LLLLLLLLLLLLLLLLLLLLLLLL,...................................,LLL,....r,,LLLLL,rrr.......rwr,LLLLL,................,,,....,,,,,,,",
	"LLLLLLLLLLLLLLLLLLLLLLLL,...................................,LLL,.....,LLLLLLL,...........,LLLLLL,...............,,L,,...,LLLLLL",
	"LLLLLLLLLLLLLLLLLLLLLLLL,...................................,LLL,.....,LLLLLLL,...........,,LLLLL,...............,LLL,,..,LLLLLL",
	"LLLLLLLLLLLLLLLLLLLLLLLLr...................................,,,,,.....,,LLLLLL,,...........,,LL,,,...............,LLLL,..,LLLLLL",
	"LLLLLLLLLLLLLLL,,LLLLLLrrr.......................................r.....,,LLLLLL,.........zzzzzzz................,,LLLL,,.,LLLLLL",
	"LLLLLLLLLLLLLL,,,LLLLL,,r.......................................rrr...,,LLLLLLL,.,,,,,...zzzzzzz...............,,LLLLLL,,,LLLLLL",
	"LLLLLLLLLLLLLL,.,,,,,,,..........................................r....,LLLLLLLL,,,LLL,...zzzzzzz...............,LLLLLLLL,LLLLLLL",
	"LLLLLLLLLLLLL,,......................................................r,LLLLLLL,,,LLLL,.rrrzzzzzz..............,,LLLLLLLLLLLLLLLL",
	"LLLLLLLLLLLL,,......................................................rw,LLLLLL,,.,,LLL,.rrr.....r.............,,LLLLLLLLLLLLLLLLL",
	"LLLLLLLLLLL,,.........................................................,LLLLL,,...,,,,,...,,,,,rrr............,LLLLLLLLLLLLLLLLLL",
	"LLLLLLLLLLL,........................................................,,,LLLL,,............,LLLL,r.............,LLLLLLLLLLLLLLLLLL",
	"LLLLLLLLLLL,.......................................................,,LLLLL,,.............,LLLLL,.............,LLLLLLLLLLLLLLLLLL",
	"LLLLLLLLLLL,.......................................................,LLLLLL,..............,LLLLL,.............,LLLLLLLLLLLLLLLLLL",
	"LLLLLLLLLLL,........rrr............................................,LLLLL,,..............,LLLLL,.rrr......r..,,LLLLLLLLLLLLLLLLL",
	"LLLLLLLLLLL,,........r.............................................,,,LL,,...............,,LLLLzzrrr.....rrr..,LLLLLLLLLLLLLLLLL",
	"LLLLLLLLLLLL,........................................................,,,,.................,LLLLzzz........r..,,LLLLLLLLLLLLLLLLL",
	"LLLLLLLLLLLL,.............................................................................,,,,,zzz..........,,LLLLLLLLLLLLLLLLLL",
	"LLLLLLLLLLL,,...........................................................................,,,,,,,zzz.........,,LLLLLLLLLLLLLLLLLLL",
	"LLLLLLLLLLL,.....S......................................................,,,,,...........,LLLLL,zzz.......G.,LLLLLLLLLLLLLLLLLLLL",
	"LLLLLLLLLLL,,...........................................................,LLL,,..........,LLLLLLzzz.....PPPPPLLLLLLLLLLLLLLLLLLLL",
	"LLLLLLLLLLLL,,.........................................................,,LLLL,..........,LLLLL,,...........,LLLLLLLLLLLLLLLLLLLL",
	"LLLLLLLLLLLLL,,,,,,....................................................,LLLLL,..........,LLLL,,,...........,LLLLLLLLLLLLLLLLLLLL",
	"LLLLLLLLLLLLLLLLLL,....................................................,,LLLL,..........,,,LLLL,...........,LLLLLLLLLLLLLLLLLLLL",
	"LLLLLLLLLLLLLLLLLL,,...................................................,,LLLL,......rr....,LLLL,...........,,LLLLLLLLLLLLLLLLLLL",
	"LLLLLLLLLLLLLLLLLLL,.r.................................................,LLLLL,.....rrr....,LLLL,............,LLLLLLLLLLLLLLLLLLL",
	"LLLLLLLLLLLLLLLLLLL,..................................................,,LLLL,,....,,r,,...,,LL,,............,,LLLLLLLLLLLLLLLLLL",
	"LLLLLLLLLLLLLLLLLLL,.................................................,,LLL,,,....,,LLL,....,r,,..............,LLLLLLLLLLLLLLLLLL",
	"LLLLLLLLLLLLLLLLLLL,.................................................,LLLL,......,LLLL,....rrr...............,LLLLLLLLLLLLLLLLLL",
	"LLLLLLLLLLLLLLLLLL,,,,...............................................,LLLL,..rrr.,,LLL,.,,,,r,,,.............,,LLLLLLLLLLLLLLLLL",
	"LLLLLLLLLLLLLLLLLLLLL,,..............................................,LLLL,...rr..,,,r,,,LLLLLL,,.............,,,LLLLLLLLLLLLLLL",
	"LLLLLLLLLLLLLLLLLLLLLL,,.............................................,LLLL,,........rrr,LLLLLLLL,...............,LLLLLLLLLLLLLLL",
	"LLLLLLLLLLLLLLLLLLLLLLL,..................................,,,,,.....,,LLLLL,,..........,,LLLLLLL,...............,,LLLLLLLLLLLLLL",
	"LLLLLLLLLLLLLLLLLLLLLLL,r.................................,LLL,.....,LLLLLLL,...........,,LLLLL,,,...............,,LLLLLL,LLLLLL",
	"LLLLLLLLLLLLLLLLLLLLLLLrrr................................,LLL,....r,LLLLLLL,............,,,,LLLL,,...............,,,,,,,,LLLLLL",
	"LLLLLLLLLLLLLLLLLLLLLLL,r.................................,LLL,...rrr,,LLLLL,...............,LLLLL,...........rw.........,LLLLLL",
	"LLLLLLLLLLLLLLLLLLLLLLL,..................................,,,,,....r..,,rr,,,.........r.,,,,,LLLLL,...........r..........,LLLLLL",
	"LLLLLLLLLLLLL,LLLLLLLL,,................................................rrr..........rrr,LLLLLLLL,,......................,,,,,,,",
	"LLLLLLLLLLLLL,,,LLLLL,,.....................................rrr........,rr............r,LLLLLL,LL,..............................",
	"LLLLLLLLLLLL,,.,,LLL,,..............................................,,,,Lr,,...........,LLLLLL,,,,.r............................",
	"LLLLLLLLLLLL,...,,L,,...............................................,LLLLLLrr..........,LLLLLLL,,.rrr...........................",
	"LLLLLLLLLLL,,....,,,................................................,LLLLLLrrr.........,LLLLLLLL,...............................",
	"LLLLLLLLLLL,,......................................................r,LLLLLL,r..........,,LLLLLLL,...............................",
	"LLLLLLLLLLLL,.....................................................rrrLLLLL,,............,,,,LLLL,...............................",
	"LLLLLLLLLLLL,.....................................................rr,,LLLr,................,,LLL,...............................",
	"LLLLLLLLLLLL,........................................................,,,rr..................,,,,,...............................",
]
