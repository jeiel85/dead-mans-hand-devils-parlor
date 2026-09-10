class_name GameData
extends RefCounted
## Static balance data — mirrors src/data.js of the web prototype and
## docs/GDD.md §6/§8. Keep the three in sync.

const RANKS := ["K", "Q", "A"]
const JOKER := "J"
const DECK_SPEC := {"K": 6, "Q": 6, "A": 6, "J": 2}
const HAND_SIZE := 5
const MAX_PLAY := 3
const CYLINDER_SIZE := 6
const CHALLENGE_SECONDS := 15
const PLAYER_MAX_HP := 3
const FLOOR_CLEAR_HEAL := 1

const BULLET_LIVE := "live"
const BULLET_BLANK := "blank"
const BULLET_CURSE := "curse"

## Cheat items: base detection chance × dealer focus. `phases`: when usable on the player's turn.
const CHEATS := {
	"mirror": {"baseDetect": 0.10, "phases": ["play", "respond"]},
	"bottomDeal": {"baseDetect": 0.15, "phases": ["play"]},
	"leadWeight": {"baseDetect": 0.25, "phases": ["play", "respond"]},
	"pact": {"baseDetect": 0.0, "phases": ["play"]},
}
const CHEAT_IDS := ["mirror", "bottomDeal", "leadWeight", "pact"]
const STARTING_ITEMS := {"mirror": 1, "bottomDeal": 1, "leadWeight": 1, "pact": 0}

const FLOORS := [
	{"id": "b1", "level": 1, "dealer": "jack", "hp": 1, "cylinder": {"live": 2, "blank": 4, "curse": 0}},
	{"id": "b2", "level": 2, "dealer": "martha", "hp": 2, "cylinder": {"live": 2, "blank": 4, "curse": 0}},
	{"id": "b3", "level": 3, "dealer": "dominic", "hp": 3, "cylinder": {"live": 3, "blank": 2, "curse": 1}},
	{"id": "b4", "level": 4, "dealer": "ida", "hp": 3, "cylinder": {"live": 3, "blank": 3, "curse": 0}},
	{"id": "b5", "level": 5, "dealer": "bela", "hp": 3, "cylinder": {"live": 3, "blank": 2, "curse": 1}},
	{"id": "b6", "level": 6, "dealer": "grimm", "hp": 4, "cylinder": {"live": 4, "blank": 2, "curse": 0}},
	{"id": "b7", "level": 7, "dealer": "devil", "hp": 4, "cylinder": {"live": 4, "blank": 1, "curse": 1}},
]

## focus: cheat-detection multiplier. bluffRate: chance to bluff when an honest
## play exists. callBias: added to the call score. noise: jitter. greed: max cards when aggressive.
const DEALERS := {
	"jack": {"focus": 0.5, "bluffRate": 0.50, "callBias": -0.15, "noise": 0.30, "greed": 2, "gimmick": "drunk"},
	"martha": {"focus": 0.8, "bluffRate": 0.60, "callBias": -0.05, "noise": 0.10, "greed": 3, "gimmick": "aggressive"},
	"dominic": {"focus": 1.0, "bluffRate": 0.30, "callBias": 0.05, "noise": 0.05, "greed": 2, "gimmick": "counter"},
	"ida": {"focus": 1.6, "bluffRate": 0.30, "callBias": 0.05, "noise": 0.05, "greed": 2, "gimmick": "hawkeye"},
	"bela": {"focus": 1.0, "bluffRate": 0.40, "callBias": 0.00, "noise": 0.10, "greed": 2, "gimmick": "mender"},
	"grimm": {"focus": 1.3, "bluffRate": 0.25, "callBias": 0.10, "noise": 0.05, "greed": 2, "gimmick": "verdict"},
	"devil": {"focus": 1.5, "bluffRate": 0.45, "callBias": 0.10, "noise": 0.05, "greed": 3, "gimmick": "proprietor"},
}

const RELIC_IDS := [
	"cigaretteCase", # +1 max HP, heal 1
	"hipFlask", # once per run, a lethal live round leaves you at 1 HP
	"leatherGloves", # cheat detection x0.6
	"markedDeck", # at round start, see one random dealer card
	"pocketBible", # 25% chance a live round against you misfires
	"snakeOil", # heal 1 when a floor is cleared
	"loadedDice", # the mirror is never detected
	"blackCat", # deck holds 3 jokers instead of 2
]

const LEATHER_GLOVES_MULTIPLIER := 0.6
const POCKET_BIBLE_MISFIRE := 0.25
