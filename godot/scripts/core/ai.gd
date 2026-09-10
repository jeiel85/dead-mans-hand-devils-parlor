class_name DealerAI
extends RefCounted
## Dealer AI — port of src/ai.js. Pure functions over a Rules state; the only
## randomness is `state.rng`, consumed in the same order as the JS version.


static func _truthful(cards: Array, rank: String) -> Array:
	var out: Array = []
	for c in cards:
		if c["rank"] == rank or c["rank"] == GameData.JOKER:
			out.append(c)
	return out


static func _lies(cards: Array, rank: String) -> Array:
	var out: Array = []
	for c in cards:
		if c["rank"] != rank and c["rank"] != GameData.JOKER:
			out.append(c)
	return out


static func total_truthful_in_deck(state: Rules) -> int:
	var jokers: int = GameData.DECK_SPEC["J"] + (1 if state.has_relic("blackCat") else 0)
	return GameData.DECK_SPEC[state.round["tableRank"]] + jokers


## Probability estimate that the player's last play was a lie.
static func estimate_player_lie(state: Rules) -> float:
	var r: Dictionary = state.round
	var d: Dictionary = state.dealer
	var lp: Variant = r["lastPlay"]
	if lp == null or lp["by"] != "player":
		return 0.0
	if r["revealed"]["player"]:
		return 1.0 if lp["lie"] else 0.0
	var n: int = lp["claim"]
	var total := total_truthful_in_deck(state)
	var mine: int = _truthful(r["hands"]["dealer"], r["tableRank"]).size()
	var claimed_by_player: int = r["claimed"]["player"]
	if mine + claimed_by_player > total:
		return 1.0
	var remaining := total - mine
	var unseen: int = 20 - r["hands"]["dealer"].size()
	var expected_in_player_hand: float = (float(remaining) / maxi(1, unseen)) * 5.0
	var base: float = {1: 0.30, 2: 0.45, 3: 0.65}.get(n, 0.65)
	var p: float = base + 0.12 * (claimed_by_player - expected_in_player_hand)
	var mem: Dictionary = d["memory"]
	if mem["playerPlays"] >= 2:
		var ratio: float = float(mem["playerLies"]) / mem["playerPlays"]
		var weight: float = 0.5 if d["gimmick"] == "counter" else 0.2
		p += (ratio - 0.4) * weight
	return clampf(p, 0.02, 0.98)


static func next_live_chance(state: Rules) -> float:
	var cyl: Dictionary = state.cylinder
	var remaining: int = cyl["chambers"].size() - cyl["index"]
	if remaining <= 0:
		return float(cyl["composition"]["live"]) / cyl["chambers"].size()
	var spent_live: int = cyl["spent"].count("live")
	return float(cyl["composition"]["live"] - spent_live) / remaining


static func decide_respond(state: Rules) -> String:
	var r: Dictionary = state.round
	var d: Dictionary = state.dealer
	var hand: Array = r["hands"]["dealer"]
	if hand.size() == 0:
		return "call"
	var p_lie := estimate_player_lie(state)
	if p_lie >= 1.0:
		return "call"
	var p_live := next_live_chance(state)
	var score: float = p_lie + d["callBias"] - 0.25 * (p_live - 0.5)
	var mine: int = _truthful(hand, r["tableRank"]).size()
	if r["hands"]["player"].size() == 0:
		score += -0.35 if mine > 0 else 0.35
	if d["noise"] > 0:
		score += (state.rng.next() * 2.0 - 1.0) * d["noise"]
	return "call" if score >= 0.5 else "pass"


static func decide_play(state: Rules) -> Array:
	var r: Dictionary = state.round
	var d: Dictionary = state.dealer
	var hand: Array = r["hands"]["dealer"]
	var rank: String = r["tableRank"]
	var truth := _truthful(hand, rank)
	# Stable sort: non-jokers first, jokers last (JS sort by (isJoker) difference).
	var non_j: Array = []
	var jok: Array = []
	for c in truth:
		if c["rank"] == GameData.JOKER:
			jok.append(c)
		else:
			non_j.append(c)
	truth = non_j + jok
	var lie := _lies(hand, rank)
	var player_out: bool = r["hands"]["player"].size() == 0

	if player_out and truth.size() > 0:
		return _pick(truth, truth.size())

	var want_bluff: bool = lie.size() > 0 and (truth.size() == 0 or state.rng.chance(d["bluffRate"]))
	if not want_bluff:
		var k: int = 1 + state.rng.int_below(mini(2, truth.size()))
		return _pick(truth, k)
	var max_k: int = d["greed"] if d["gimmick"] == "aggressive" else 1 + state.rng.int_below(2)
	var k2: int = mini(max_k, lie.size())
	return _pick(lie, k2)


static func _pick(arr: Array, k: int) -> Array:
	var n: int = maxi(1, mini(mini(k, arr.size()), GameData.MAX_PLAY))
	var ids: Array = []
	for i in range(n):
		ids.append(arr[i]["id"])
	return ids
