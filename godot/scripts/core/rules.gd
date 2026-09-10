class_name Rules
extends RefCounted
## Pure game engine — a 1:1 port of the web prototype's src/rules.js.
## No nodes, no timers. Every mutation appends an event Dictionary to
## `events`; the UI animates from those. All randomness flows through `rng`,
## in exactly the same order as the JS engine, so a seed replays identically.

const PHASE_TITLE := "title"
const PHASE_FLOOR_INTRO := "floorIntro"
const PHASE_ROUND := "round"
const PHASE_REWARD := "reward"
const PHASE_GAME_OVER := "gameOver"
const PHASE_VICTORY := "victory"

var seed_text: String
var rng: SeededRng
var phase: String = PHASE_TITLE
var floor_index: int = 0
var player: Dictionary
var dealer: Dictionary = {}
var cylinder: Dictionary = {}
var round: Dictionary = {}
var rewards: Array = []
var round_number: int = 0
var next_starter: String = "player"
var stats: Dictionary
var events: Array = []
## Last illegal-action code ("" when the previous action succeeded).
var last_error: String = ""


func _init(seed_value: String) -> void:
	seed_text = seed_value
	rng = SeededRng.new(seed_value)
	player = {
		"hp": GameData.PLAYER_MAX_HP,
		"maxHp": GameData.PLAYER_MAX_HP,
		"items": GameData.STARTING_ITEMS.duplicate(),
		"relics": [],
		"cursed": false,
		"hipFlaskUsed": false,
	}
	stats = {
		"turns": 0, "playerPlays": 0, "playerBluffs": 0, "playerCallsRight": 0, "playerCallsWrong": 0,
		"cheatsUsed": 0, "cheatsCaught": 0, "shotsTaken": 0, "liveTaken": 0, "dealersBeaten": 0,
	}


static func other(who: String) -> String:
	return "dealer" if who == "player" else "player"


func current_floor() -> Dictionary:
	return GameData.FLOORS[floor_index]


# ---------------------------------------------------------------------------
# Floors & rounds
# ---------------------------------------------------------------------------

func start_floor() -> void:
	var floor: Dictionary = GameData.FLOORS[floor_index]
	var proto: Dictionary = GameData.DEALERS[floor["dealer"]]
	dealer = proto.duplicate()
	dealer["id"] = floor["dealer"]
	dealer["hp"] = floor["hp"]
	dealer["maxHp"] = floor["hp"]
	dealer["cursed"] = false
	dealer["healUsed"] = false
	dealer["memory"] = {"playerPlays": 0, "playerLies": 0}
	cylinder = _make_cylinder(floor["cylinder"])
	player["cursed"] = false
	round = {}
	phase = PHASE_FLOOR_INTRO
	next_starter = "player"
	_push({"type": "floorStart", "floor": floor["id"], "level": floor["level"], "dealer": floor["dealer"]})


func _make_cylinder(composition: Dictionary) -> Dictionary:
	var chambers: Array = []
	for i in range(composition["live"]):
		chambers.append(GameData.BULLET_LIVE)
	for i in range(composition["blank"]):
		chambers.append(GameData.BULLET_BLANK)
	for i in range(composition["curse"]):
		chambers.append(GameData.BULLET_CURSE)
	assert(chambers.size() == GameData.CYLINDER_SIZE, "cylinder composition must total 6")
	rng.shuffle(chambers)
	return {
		"chambers": chambers, "index": 0,
		"composition": composition.duplicate(), "base": composition.duplicate(),
		"spent": [], "knownNext": null,
	}


func _reload_cylinder(composition: Variant = null) -> void:
	var comp: Dictionary = composition if composition != null else cylinder["base"]
	cylinder = _make_cylinder(comp)
	_push({"type": "reload", "composition": comp.duplicate()})


func build_deck() -> Array:
	var spec: Dictionary = GameData.DECK_SPEC.duplicate()
	if has_relic("blackCat"):
		spec["J"] += 1
	var deck: Array = []
	var id := 0
	for rank in spec.keys():
		for i in range(spec[rank]):
			deck.append({"id": id, "rank": rank})
			id += 1
	return deck


func begin_round() -> String:
	if phase != PHASE_FLOOR_INTRO and phase != PHASE_ROUND:
		return _fail("wrongPhase")
	var deck: Array = rng.shuffle(build_deck())
	var table_rank: String = rng.pick(GameData.RANKS)
	var player_hand: Array = deck.slice(0, GameData.HAND_SIZE)
	var dealer_hand: Array = deck.slice(GameData.HAND_SIZE, GameData.HAND_SIZE * 2)
	deck = deck.slice(GameData.HAND_SIZE * 2)
	round_number += 1
	round = {
		"number": round_number,
		"tableRank": table_rank,
		"hands": {"player": player_hand, "dealer": dealer_hand},
		"deck": deck,
		"pile": [],
		"lastPlay": null,
		"claimed": {"player": 0, "dealer": 0},
		"turn": next_starter,
		"phase": "play",
		"cheatUsedThisTurn": false,
		"pact": null,
		"revealed": {"player": player["cursed"], "dealer": dealer["cursed"]},
		"peekedDealerCard": null,
	}
	player["cursed"] = false
	dealer["cursed"] = false
	cylinder["knownNext"] = null
	if has_relic("markedDeck") and dealer_hand.size() > 0:
		round["peekedDealerCard"] = rng.pick(dealer_hand)
	phase = PHASE_ROUND
	_push({
		"type": "roundStart", "number": round_number, "tableRank": table_rank,
		"starter": round["turn"], "revealed": round["revealed"].duplicate(),
	})
	return ""


# ---------------------------------------------------------------------------
# Queries
# ---------------------------------------------------------------------------

func has_relic(id: String) -> bool:
	return player["relics"].has(id)


static func is_truthful(card: Dictionary, table_rank: String) -> bool:
	return card["rank"] == table_rank or card["rank"] == GameData.JOKER


static func play_is_lie(cards: Array, table_rank: String) -> bool:
	for c in cards:
		if not is_truthful(c, table_rank):
			return true
	return false


static func truthful_count(cards: Array, table_rank: String) -> int:
	var n := 0
	for c in cards:
		if is_truthful(c, table_rank):
			n += 1
	return n


func next_chamber_odds() -> Dictionary:
	var cyl := cylinder
	var remaining: int = cyl["chambers"].size() - cyl["index"]
	var live: int = cyl["composition"]["live"] - cyl["spent"].count(GameData.BULLET_LIVE)
	var curse: int = cyl["composition"]["curse"] - cyl["spent"].count(GameData.BULLET_CURSE)
	var blank: int = cyl["composition"]["blank"] - cyl["spent"].count(GameData.BULLET_BLANK)
	return {"remaining": remaining, "live": live, "blank": blank, "curse": curse,
		"pLive": (float(live) / remaining) if remaining > 0 else 0.0}


func cheat_detect_chance(cheat_id: String) -> float:
	if not GameData.CHEATS.has(cheat_id):
		return 0.0
	if cheat_id == "mirror" and has_relic("loadedDice"):
		return 0.0
	var p: float = GameData.CHEATS[cheat_id]["baseDetect"] * dealer["focus"]
	if has_relic("leatherGloves"):
		p *= GameData.LEATHER_GLOVES_MULTIPLIER
	return minf(0.95, p)


func legal_actions() -> Dictionary:
	if round.is_empty() or phase != PHASE_ROUND or round["turn"] != "player":
		return {"play": false, "call": false, "pass": false, "cheats": []}
	var hand: Array = round["hands"]["player"]
	var cheats: Array = []
	for id in GameData.CHEAT_IDS:
		if player["items"][id] > 0 and not round["cheatUsedThisTurn"] and GameData.CHEATS[id]["phases"].has(round["phase"]):
			cheats.append(id)
	if round["phase"] == "play":
		return {"play": hand.size() > 0, "call": false, "pass": false, "cheats": cheats}
	return {"play": false, "call": true, "pass": hand.size() > 0, "cheats": cheats}


# ---------------------------------------------------------------------------
# Actions (return "" on success or an error code)
# ---------------------------------------------------------------------------

func _fail(code: String) -> String:
	last_error = code
	return code


func _assert_turn(who: String, round_phase: String) -> String:
	if phase != PHASE_ROUND:
		return "wrongPhase"
	if round["turn"] != who:
		return "notYourTurn"
	if round["phase"] != round_phase:
		return "wrongRoundPhase"
	return ""


func play(who: String, card_ids: Array) -> String:
	var err := _assert_turn(who, "play")
	if err != "":
		return _fail(err)
	var hand: Array = round["hands"][who]
	var ids: Array = []
	for id in card_ids:
		if not ids.has(id):
			ids.append(id)
	if ids.size() < 1 or ids.size() > GameData.MAX_PLAY:
		return _fail("badCount")
	var cards: Array = []
	for id in ids:
		var found: Variant = null
		for c in hand:
			if c["id"] == id:
				found = c
				break
		if found == null:
			return _fail("cardNotInHand")
		cards.append(found)
	var remaining: Array = []
	for c in hand:
		if not ids.has(c["id"]):
			remaining.append(c)
	round["hands"][who] = remaining
	var lie := play_is_lie(cards, round["tableRank"])
	var pact: Variant = round["pact"] if (round["pact"] != null and round["pact"]["by"] == who) else null
	var entry := {"by": who, "cards": cards, "claim": cards.size(), "lie": lie, "pact": pact}
	round["pile"].append(entry)
	round["lastPlay"] = entry
	round["claimed"][who] += cards.size()
	round["turn"] = other(who)
	round["phase"] = "respond"
	round["cheatUsedThisTurn"] = false
	stats["turns"] += 1
	if who == "player":
		stats["playerPlays"] += 1
		if lie:
			stats["playerBluffs"] += 1
	_push({"type": "play", "by": who, "count": cards.size(), "tableRank": round["tableRank"], "handLeft": remaining.size()})
	last_error = ""
	return ""


func respond(who: String, action: String) -> String:
	var err := _assert_turn(who, "respond")
	if err != "":
		return _fail(err)
	if action == "pass":
		if round["hands"][who].size() == 0:
			return _fail("mustCall")
		_push({"type": "pass", "by": who})
		var lp: Dictionary = round["lastPlay"]
		if lp["pact"] != null:
			if lp["lie"]:
				_push({"type": "pactStrike", "by": lp["by"], "target": who})
				_damage(who, 2, "pact")
				round["pact"] = null
				if _check_match_end():
					return ""
			else:
				_push({"type": "pactFizzle", "by": lp["by"]})
				round["pact"] = null
		round["turn"] = who
		round["phase"] = "play"
		round["cheatUsedThisTurn"] = false
		last_error = ""
		return ""
	if action == "call":
		_resolve_challenge(who)
		last_error = ""
		return ""
	return _fail("badAction")


func _resolve_challenge(challenger: String) -> void:
	var lp: Dictionary = round["lastPlay"]
	var liar: bool = lp["lie"]
	var shooter: String = lp["by"] if liar else challenger
	if challenger == "player":
		if liar:
			stats["playerCallsRight"] += 1
		else:
			stats["playerCallsWrong"] += 1
	if lp["by"] == "player":
		dealer["memory"]["playerPlays"] += 1
		if liar:
			dealer["memory"]["playerLies"] += 1
	var shown: Array = []
	for c in lp["cards"]:
		shown.append(c.duplicate())
	_push({"type": "reveal", "by": lp["by"], "challenger": challenger, "cards": shown,
		"tableRank": round["tableRank"], "lie": liar, "shooter": shooter})
	if lp["pact"] != null and liar:
		_push({"type": "pactBackfire", "by": lp["by"]})
		_set_hp(lp["by"], 0, "pact")
		round["pact"] = null
		_end_round(shooter)
		return
	round["pact"] = null
	fire(shooter, 1, "challenge")
	_end_round(shooter)


func _end_round(shooter: String) -> void:
	round["phase"] = "over"
	next_starter = shooter
	if _check_match_end():
		return
	_push({"type": "roundEnd", "nextStarter": shooter})
	begin_round()


func _check_match_end() -> bool:
	if player["hp"] <= 0:
		phase = PHASE_GAME_OVER
		round["phase"] = "over"
		_push({"type": "gameOver", "floor": current_floor()["id"], "stats": stats.duplicate()})
		return true
	if dealer["hp"] <= 0:
		round["phase"] = "over"
		stats["dealersBeaten"] += 1
		_push({"type": "dealerDefeated", "dealer": dealer["id"], "floor": current_floor()["id"]})
		_heal("player", GameData.FLOOR_CLEAR_HEAL, "floorClear")
		if has_relic("snakeOil"):
			_heal("player", 1, "snakeOil")
		if floor_index >= GameData.FLOORS.size() - 1:
			phase = PHASE_VICTORY
			_push({"type": "victory", "stats": stats.duplicate()})
		else:
			phase = PHASE_REWARD
			rewards = _roll_rewards()
			var offer: Array = []
			for r in rewards:
				offer.append(r.duplicate())
			_push({"type": "rewardOffer", "rewards": offer})
		return true
	return false


# ---------------------------------------------------------------------------
# Revolver
# ---------------------------------------------------------------------------

func fire(who: String, count: int = 1, reason: String = "challenge") -> void:
	for i in range(count):
		var cyl := cylinder
		var bullet: String = cyl["chambers"][cyl["index"]]
		cyl["spent"].append(bullet)
		cyl["index"] += 1
		cyl["knownNext"] = null
		if who == "player":
			stats["shotsTaken"] += 1
		var effect := bullet
		if bullet == GameData.BULLET_LIVE:
			if who == "player" and has_relic("pocketBible") and rng.chance(GameData.POCKET_BIBLE_MISFIRE):
				effect = "misfire"
			else:
				if who == "player":
					stats["liveTaken"] += 1
				_damage(who, 1, reason)
		elif bullet == GameData.BULLET_CURSE:
			if who == "player":
				player["cursed"] = true
			else:
				dealer["cursed"] = true
		_push({"type": "fire", "who": who, "bullet": bullet, "effect": effect, "reason": reason,
			"chamber": cyl["index"], "hp": hp_of(who)})
		if cyl["index"] >= cyl["chambers"].size():
			_reload_cylinder()
		if hp_of(who) <= 0:
			break


func hp_of(who: String) -> int:
	return player["hp"] if who == "player" else dealer["hp"]


func _set_hp(who: String, hp: int, reason: String) -> void:
	var target: Dictionary = player if who == "player" else dealer
	var before: int = target["hp"]
	target["hp"] = clampi(hp, 0, target["maxHp"])
	if target["hp"] != before:
		_push({"type": "hp", "who": who, "from": before, "to": target["hp"], "reason": reason})


func _damage(who: String, amount: int, reason: String) -> void:
	var target: Dictionary = player if who == "player" else dealer
	var next: int = target["hp"] - amount
	if who == "player" and next <= 0 and has_relic("hipFlask") and not player["hipFlaskUsed"]:
		player["hipFlaskUsed"] = true
		next = 1
		_push({"type": "relicProc", "relic": "hipFlask"})
	_set_hp(who, next, reason)
	if who == "dealer":
		if dealer["gimmick"] == "mender" and not dealer["healUsed"] and dealer["hp"] == 1:
			dealer["healUsed"] = true
			_push({"type": "gimmick", "dealer": dealer["id"], "gimmick": "mender"})
			_heal("dealer", 1, "mender")
		if dealer["gimmick"] == "proprietor" and dealer["hp"] > 0:
			var c: Dictionary = cylinder["base"]
			var live: int = mini(5, c["live"] + 1)
			var curse: int = mini(c["curse"], GameData.CYLINDER_SIZE - live)
			var blank: int = GameData.CYLINDER_SIZE - live - curse
			_push({"type": "gimmick", "dealer": dealer["id"], "gimmick": "proprietor"})
			_reload_cylinder({"live": live, "blank": blank, "curse": curse})


func _heal(who: String, amount: int, reason: String) -> void:
	_set_hp(who, hp_of(who) + amount, reason)


# ---------------------------------------------------------------------------
# Cheats
# ---------------------------------------------------------------------------

## Returns the cheat event Dictionary, or {"error": code}.
func use_cheat(cheat_id: String, opts: Dictionary = {}) -> Dictionary:
	if phase != PHASE_ROUND:
		return {"error": _fail("wrongPhase")}
	if not GameData.CHEATS.has(cheat_id):
		return {"error": _fail("noSuchCheat")}
	var cheat: Dictionary = GameData.CHEATS[cheat_id]
	if round["turn"] != "player":
		return {"error": _fail("notYourTurn")}
	if not cheat["phases"].has(round["phase"]):
		return {"error": _fail("wrongRoundPhase")}
	if round["cheatUsedThisTurn"]:
		return {"error": _fail("cheatAlreadyUsed")}
	if not (player["items"][cheat_id] > 0):
		return {"error": _fail("noCharges")}

	if cheat_id == "bottomDeal":
		var card: Variant = _find_card(round["hands"]["player"], opts.get("cardId", -1))
		if card == null:
			return {"error": _fail("cardNotInHand")}
		if is_truthful(card, round["tableRank"]):
			return {"error": _fail("cardAlreadyTruthful")}

	player["items"][cheat_id] -= 1
	round["cheatUsedThisTurn"] = true
	stats["cheatsUsed"] += 1
	var p := cheat_detect_chance(cheat_id)
	var caught: bool = p > 0.0 and rng.chance(p)
	var result := {"type": "cheat", "cheat": cheat_id, "caught": caught, "detectChance": p}

	if not caught:
		if cheat_id == "mirror":
			cylinder["knownNext"] = cylinder["chambers"][cylinder["index"]]
			result["bullet"] = cylinder["knownNext"]
		elif cheat_id == "leadWeight":
			var before: String = cylinder["chambers"][cylinder["index"]]
			if before != GameData.BULLET_BLANK:
				cylinder["chambers"][cylinder["index"]] = GameData.BULLET_BLANK
				cylinder["composition"] = _recount(cylinder)
			cylinder["knownNext"] = GameData.BULLET_BLANK
			result["swapped"] = before != GameData.BULLET_BLANK
		elif cheat_id == "bottomDeal":
			var hand: Array = round["hands"]["player"]
			var idx := -1
			for i in range(hand.size()):
				if hand[i]["id"] == opts.get("cardId", -1):
					idx = i
					break
			var deck: Array = round["deck"]
			var take := _index_of_rank(deck, round["tableRank"])
			if take == -1:
				take = _index_of_rank(deck, GameData.JOKER)
			if take == -1:
				result["swapped"] = false
			else:
				var fresh: Dictionary = deck[take]
				deck.remove_at(take)
				deck.append(hand[idx])
				hand[idx] = fresh
				result["swapped"] = true
				result["newCard"] = fresh.duplicate()
		elif cheat_id == "pact":
			round["pact"] = {"by": "player"}
	_push(result)
	if caught:
		stats["cheatsCaught"] += 1
		var pulls := 2 if dealer["gimmick"] == "verdict" else 1
		if pulls == 2:
			_push({"type": "gimmick", "dealer": dealer["id"], "gimmick": "verdict"})
		fire("player", pulls, "caught")
		if player["hp"] <= 0:
			_check_match_end()
	last_error = ""
	return result


static func _find_card(hand: Array, id: int) -> Variant:
	for c in hand:
		if c["id"] == id:
			return c
	return null


static func _index_of_rank(deck: Array, rank: String) -> int:
	for i in range(deck.size()):
		if deck[i]["rank"] == rank:
			return i
	return -1


static func _recount(cyl: Dictionary) -> Dictionary:
	var counts := {"live": 0, "blank": 0, "curse": 0}
	for b in cyl["chambers"]:
		counts[b] += 1
	return counts


# ---------------------------------------------------------------------------
# Dealer turn
# ---------------------------------------------------------------------------

func dealer_act() -> Dictionary:
	if phase != PHASE_ROUND or round["turn"] != "dealer":
		return {"error": _fail("notYourTurn")}
	if round["phase"] == "play":
		var ids: Array = DealerAI.decide_play(self)
		play("dealer", ids)
		return {"action": "play", "count": ids.size()}
	var action: String = DealerAI.decide_respond(self)
	respond("dealer", action)
	return {"action": action}


# ---------------------------------------------------------------------------
# Rewards
# ---------------------------------------------------------------------------

func _roll_rewards() -> Array:
	var pool: Array = []
	for id in GameData.CHEAT_IDS:
		pool.append({"kind": "item", "id": id})
	for id in GameData.RELIC_IDS:
		if not has_relic(id):
			pool.append({"kind": "relic", "id": id})
	rng.shuffle(pool)
	var picks: Array = [{"kind": "heal", "id": "heal"}]
	picks.append(pool[0])
	picks.append(pool[1])
	return picks


func choose_reward(index: int) -> String:
	if phase != PHASE_REWARD:
		return _fail("wrongPhase")
	if index < 0 or index >= rewards.size():
		return _fail("noSuchReward")
	var reward: Dictionary = rewards[index]
	if reward["kind"] == "heal":
		_heal("player", 1, "reward")
	elif reward["kind"] == "item":
		player["items"][reward["id"]] += 1
	elif reward["kind"] == "relic":
		player["relics"].append(reward["id"])
		if reward["id"] == "cigaretteCase":
			player["maxHp"] += 1
			_heal("player", 1, "cigaretteCase")
	_push({"type": "rewardTaken", "reward": reward.duplicate()})
	rewards = []
	floor_index += 1
	start_floor()
	last_error = ""
	return ""


# ---------------------------------------------------------------------------
# Events
# ---------------------------------------------------------------------------

func _push(ev: Dictionary) -> void:
	events.append(ev)


func drain_events() -> Array:
	var out := events
	events = []
	return out
