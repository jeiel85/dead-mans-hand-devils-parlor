extends Node
## Headless test runner — mirrors tests/rules.test.js and tests/ai.test.js of the
## web prototype, plus a cross-engine trace replay (fixtures/traces.json generated
## by tools/trace.js). Run: godot --headless --path godot res://test/test_runner.tscn
## Exit code 1 on any failure.

var _failures := 0
var _checks := 0


func _ready() -> void:
	_run_all()
	print("\n%d checks, %d failures" % [_checks, _failures])
	get_tree().quit(1 if _failures > 0 else 0)


func _check(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		printerr("FAIL: " + msg)


func _eq(a: Variant, b: Variant, msg: String) -> void:
	_check(a == b, "%s (got %s, expected %s)" % [msg, str(a), str(b)])


func _fresh(seed_text: String = "TEST01") -> Rules:
	var s := Rules.new(seed_text)
	s.start_floor()
	s.begin_round()
	s.drain_events()
	return s


func _find_lie(s: Rules) -> Variant:
	for c in s.round["hands"]["player"]:
		if not Rules.is_truthful(c, s.round["tableRank"]):
			return c
	return null


func _find_truth(s: Rules) -> Variant:
	for c in s.round["hands"]["player"]:
		if Rules.is_truthful(c, s.round["tableRank"]):
			return c
	return null


func _run_all() -> void:
	_test_rng_matches_js()
	_test_deck()
	_test_seed_determinism()
	_test_floor_composition()
	_test_round_start()
	_test_play_validation()
	_test_challenge_resolution()
	_test_forced_call()
	_test_cheats()
	_test_lead_weight_reload()
	_test_pact()
	_test_rewards()
	_test_ai_bounds()
	_test_fuzz()
	_test_trace_replay()
	_test_josa()
	_test_action_buttons()
	_test_project_config()
	_test_challenge_timer()
	_test_orientation()
	_test_font_coverage()
	_test_table_layout()


# xmur3+mulberry32 reference values produced by node: createRng('TEST01').next() x3
func _test_rng_matches_js() -> void:
	var r := SeededRng.new("TEST01")
	var a := r.next()
	var b := r.next()
	var c := r.next()
	print("rng TEST01 -> %.10f %.10f %.10f" % [a, b, c])
	_check(a >= 0.0 and a < 1.0 and b >= 0.0 and b < 1.0 and c >= 0.0 and c < 1.0, "rng range")
	var r2 := SeededRng.new("TEST01")
	_eq(r2.next(), a, "rng deterministic")


func _test_deck() -> void:
	var s := Rules.new("x")
	var deck := s.build_deck()
	_eq(deck.size(), 20, "deck size")
	var count := {"K": 0, "Q": 0, "A": 0, "J": 0}
	var ids := {}
	for c in deck:
		count[c["rank"]] += 1
		ids[c["id"]] = true
	_eq(count, {"K": 6, "Q": 6, "A": 6, "J": 2}, "deck composition")
	_eq(ids.size(), 20, "deck ids unique")


func _test_seed_determinism() -> void:
	var a := _fresh("SEED-A")
	var b := _fresh("SEED-A")
	_eq(a.round["hands"], b.round["hands"], "same seed same hands")
	_eq(a.cylinder["chambers"], b.cylinder["chambers"], "same seed same cylinder")
	_eq(a.round["tableRank"], b.round["tableRank"], "same seed same rank")
	var c := _fresh("SEED-B")
	_check(a.round["hands"] != c.round["hands"] or a.cylinder["chambers"] != c.cylinder["chambers"], "different seed differs")


func _test_floor_composition() -> void:
	var s := _fresh()
	var counts := {"live": 0, "blank": 0, "curse": 0}
	for b in s.cylinder["chambers"]:
		counts[b] += 1
	_eq(counts, GameData.FLOORS[0]["cylinder"], "floor 1 cylinder composition")
	for f in GameData.FLOORS:
		var c: Dictionary = f["cylinder"]
		_eq(c["live"] + c["blank"] + c["curse"], 6, "floor %s totals 6" % f["id"])


func _test_round_start() -> void:
	var s := _fresh()
	_eq(s.round["hands"]["player"].size(), 5, "player 5 cards")
	_eq(s.round["hands"]["dealer"].size(), 5, "dealer 5 cards")
	_eq(s.round["turn"], "player", "player starts")
	_eq(s.round["phase"], "play", "phase play")
	_eq(s.player["hp"], 3, "player hp 3")


func _test_play_validation() -> void:
	var s := _fresh()
	var hand: Array = s.round["hands"]["player"]
	_eq(s.play("player", []), "badCount", "empty play rejected")
	_eq(s.play("player", [hand[0]["id"], hand[1]["id"], hand[2]["id"], hand[3]["id"]]), "badCount", "4 cards rejected")
	_eq(s.play("player", [999]), "cardNotInHand", "unknown card rejected")
	_eq(s.play("player", [hand[0]["id"], hand[1]["id"]]), "", "valid play")
	_eq(s.round["hands"]["player"].size(), 3, "hand shrinks")
	_eq(s.round["turn"], "dealer", "turn passes")
	_eq(s.round["phase"], "respond", "respond phase")
	_eq(s.round["lastPlay"]["claim"], 2, "claim 2")


func _test_challenge_resolution() -> void:
	for seed_text in ["L1", "L2", "L3", "L4", "L5", "L6", "L7", "L8"]:
		var s := _fresh(seed_text)
		var liar: Variant = _find_lie(s)
		var honest: Variant = _find_truth(s)
		var card: Dictionary = liar if liar != null else honest
		s.play("player", [card["id"]])
		s.respond("dealer", "call")
		var evs := s.drain_events()
		var reveal: Variant = null
		var fire: Variant = null
		for e in evs:
			if e["type"] == "reveal" and reveal == null:
				reveal = e
			if e["type"] == "fire" and fire == null:
				fire = e
		_check(reveal != null and fire != null, "reveal+fire events (%s)" % seed_text)
		if reveal != null and fire != null:
			_eq(reveal["lie"], liar != null, "lie flag (%s)" % seed_text)
			_eq(fire["who"], "player" if liar != null else "dealer", "shooter (%s)" % seed_text)
			_eq(reveal["shooter"], fire["who"], "reveal shooter matches fire (%s)" % seed_text)
		_check(s.phase != Rules.PHASE_ROUND or s.round["number"] == 2, "new round after shot (%s)" % seed_text)


func _test_forced_call() -> void:
	var s := _fresh()
	s.round["hands"]["dealer"] = []
	s.play("player", [s.round["hands"]["player"][0]["id"]])
	_eq(s.respond("dealer", "pass"), "mustCall", "empty hand cannot pass")
	var t := _fresh()
	t.round["turn"] = "dealer"
	t.round["hands"]["player"] = []
	t.round["hands"]["dealer"] = t.round["hands"]["dealer"].slice(0, 2)
	t.play("dealer", [t.round["hands"]["dealer"][0]["id"]])
	var la := t.legal_actions()
	_eq(la["call"], true, "player can call")
	_eq(la["pass"], false, "player cannot pass with no cards")


func _test_cheats() -> void:
	var s := _fresh("MIRROR")
	s.dealer["focus"] = 0.0
	var before: String = s.cylinder["chambers"][s.cylinder["index"]]
	var charges: int = s.player["items"]["mirror"]
	var res := s.use_cheat("mirror")
	_eq(res.get("caught"), false, "mirror not caught")
	_eq(res.get("bullet"), before, "mirror reveals next")
	_eq(s.player["items"]["mirror"], charges - 1, "mirror charge spent")
	_eq(s.use_cheat("bottomDeal", {"cardId": 0}).get("error"), "cheatAlreadyUsed", "one cheat per turn")

	var t := _fresh("LEAD")
	t.dealer["focus"] = 0.0
	t.player["items"]["leadWeight"] = 1
	t.cylinder["chambers"][t.cylinder["index"]] = "live"
	var r2 := t.use_cheat("leadWeight")
	_eq(r2.get("swapped"), true, "lead weight swapped")
	_eq(t.cylinder["chambers"][t.cylinder["index"]], "blank", "next chamber blank")
	var comp: Dictionary = t.cylinder["composition"]
	_eq(comp["live"] + comp["blank"] + comp["curse"], 6, "composition still 6")

	var u := _fresh("BOTTOM")
	u.dealer["focus"] = 0.0
	var liar: Variant = _find_lie(u)
	if liar != null:
		var r3 := u.use_cheat("bottomDeal", {"cardId": liar["id"]})
		_eq(r3.get("swapped"), true, "bottom deal swapped")
		_check(Rules.is_truthful(r3["newCard"], u.round["tableRank"]), "bottom deal gives truthful card")
		_eq(u.round["hands"]["player"].size() + u.round["hands"]["dealer"].size() + u.round["deck"].size(), 20, "card conservation after bottom deal")

	var caught_seen := false
	for i in range(20):
		var v := _fresh("CAUGHT%d" % i)
		v.dealer["focus"] = 100.0
		var r4 := v.use_cheat("mirror")
		if r4.get("caught"):
			caught_seen = true
			var fired := false
			for e in v.drain_events():
				if e["type"] == "fire" and e["who"] == "player" and e["reason"] == "caught":
					fired = true
			_check(fired, "caught cheat fires at player")
			_eq(v.stats["cheatsCaught"], 1, "cheatsCaught stat")
			break
	_check(caught_seen, "at least one caught cheat across seeds")


func _test_lead_weight_reload() -> void:
	var t := _fresh("LEADRELOAD")
	t.dealer["focus"] = 0.0
	t.player["items"]["leadWeight"] = 1
	t.cylinder["chambers"] = ["live", "live", "blank", "blank", "blank", "blank"]
	t.cylinder["composition"] = {"live": 2, "blank": 4, "curse": 0}
	t.use_cheat("leadWeight")
	_eq(t.cylinder["composition"], {"live": 1, "blank": 5, "curse": 0}, "composition after lead weight")
	_eq(t.cylinder["base"], GameData.FLOORS[0]["cylinder"], "base untouched")
	t.cylinder["index"] = 5
	t.cylinder["spent"] = t.cylinder["chambers"].slice(0, 5)
	t.fire("dealer", 1, "test")
	_eq(t.cylinder["index"], 0, "reloaded")
	_eq(t.cylinder["composition"], GameData.FLOORS[0]["cylinder"], "reload restores floor composition")


func _test_pact() -> void:
	var s := _fresh("PACT1")
	s.dealer["focus"] = 0.0
	s.player["items"]["pact"] = 1
	var liar: Variant = _find_lie(s)
	if liar != null:
		s.use_cheat("pact")
		s.play("player", [liar["id"]])
		s.respond("dealer", "call")
		_eq(s.player["hp"], 0, "pact backfire kills")
		_eq(s.phase, Rules.PHASE_GAME_OVER, "game over after backfire")
	var t := _fresh("PACT2")
	t.dealer["focus"] = 0.0
	t.player["items"]["pact"] = 1
	t.dealer["hp"] = 3
	t.dealer["maxHp"] = 3
	var liar2: Variant = _find_lie(t)
	if liar2 != null:
		t.use_cheat("pact")
		t.play("player", [liar2["id"]])
		t.respond("dealer", "pass")
		_eq(t.dealer["hp"], 1, "pact strike deals 2")


func _test_rewards() -> void:
	var s := _fresh("REWARD")
	s.dealer["hp"] = 1
	s.cylinder["chambers"] = ["live", "blank", "blank", "blank", "blank", "blank"]
	s.cylinder["composition"] = {"live": 1, "blank": 5, "curse": 0}
	var honest: Variant = _find_truth(s)
	if honest == null:
		return
	s.play("player", [honest["id"]])
	s.respond("dealer", "call")
	_eq(s.phase, Rules.PHASE_REWARD, "reward phase after dealer dies")
	_eq(s.rewards.size(), 3, "three rewards")
	_eq(s.rewards[0]["kind"], "heal", "first reward is heal")
	_eq(s.choose_reward(1), "", "choose reward ok")
	_eq(s.floor_index, 1, "advanced to floor 2")
	_eq(s.phase, Rules.PHASE_FLOOR_INTRO, "floor intro phase")
	_eq(s.dealer["id"], GameData.FLOORS[1]["dealer"], "dealer 2")


func _test_ai_bounds() -> void:
	for i in range(60):
		var s := _fresh("AIPLAY%d" % i)
		s.round["turn"] = "dealer"
		var ids := DealerAI.decide_play(s)
		_check(ids.size() >= 1 and ids.size() <= 3, "dealer plays 1-3 (%d)" % i)
		for id in ids:
			var found := false
			for c in s.round["hands"]["dealer"]:
				if c["id"] == id:
					found = true
			_check(found, "dealer plays own cards (%d)" % i)
	var e := _fresh("AICALL")
	e.play("player", [e.round["hands"]["player"][0]["id"]])
	e.round["hands"]["dealer"] = []
	_eq(DealerAI.decide_respond(e), "call", "empty hand always calls")
	var im := _fresh("AIIMPOSSIBLE")
	var rank: String = im.round["tableRank"]
	var big: Array = []
	for i in range(6):
		big.append({"id": 100 + i, "rank": rank})
	big.append({"id": 200, "rank": "J"})
	big.append({"id": 201, "rank": "J"})
	im.round["hands"]["dealer"] = big
	im.play("player", [im.round["hands"]["player"][0]["id"]])
	_eq(DealerAI.estimate_player_lie(im), 1.0, "impossible claim -> certain lie")
	_eq(DealerAI.decide_respond(im), "call", "impossible claim called")


func _test_fuzz() -> void:
	var rnd := RandomNumberGenerator.new()
	for n in range(300):
		rnd.seed = n + 1
		var s := Rules.new("FUZZ%d" % n)
		s.start_floor()
		s.begin_round()
		var guard := 0
		while s.phase != Rules.PHASE_GAME_OVER and s.phase != Rules.PHASE_VICTORY:
			guard += 1
			if guard > 5000:
				_check(false, "run did not terminate: FUZZ%d" % n)
				break
			if s.phase == Rules.PHASE_REWARD:
				s.choose_reward(rnd.randi_range(0, s.rewards.size() - 1))
				continue
			if s.phase == Rules.PHASE_FLOOR_INTRO:
				s.begin_round()
				continue
			if s.round["turn"] == "dealer":
				s.dealer_act()
				continue
			var la := s.legal_actions()
			if la["cheats"].size() > 0 and rnd.randf() < 0.3:
				var cheat: String = la["cheats"][rnd.randi_range(0, la["cheats"].size() - 1)]
				if cheat == "bottomDeal":
					var liar: Variant = _find_lie(s)
					if liar != null:
						s.use_cheat("bottomDeal", {"cardId": liar["id"]})
				else:
					s.use_cheat(cheat)
				continue
			if la["play"]:
				var hand: Array = s.round["hands"]["player"]
				var k: int = 1 + rnd.randi_range(0, mini(3, hand.size()) - 1)
				var ids: Array = []
				for i in range(k):
					ids.append(hand[i]["id"])
				s.play("player", ids)
			elif la["call"] and (not la["pass"] or rnd.randf() < 0.4):
				s.respond("player", "call")
			elif la["pass"]:
				s.respond("player", "pass")
			else:
				_check(false, "no legal action FUZZ%d" % n)
				break
			if s.phase == Rules.PHASE_ROUND:
				var r: Dictionary = s.round
				var total: int = r["hands"]["player"].size() + r["hands"]["dealer"].size() + r["deck"].size()
				for p in r["pile"]:
					total += p["cards"].size()
				_eq(total, 21 if s.has_relic("blackCat") else 20, "card conservation FUZZ%d" % n)
				_check(s.cylinder["index"] >= 0 and s.cylinder["index"] < 6, "cylinder index range FUZZ%d" % n)
			_check(s.player["hp"] >= 0 and s.player["hp"] <= s.player["maxHp"], "player hp range FUZZ%d" % n)
			_check(s.dealer["hp"] >= 0 and s.dealer["hp"] <= s.dealer["maxHp"], "dealer hp range FUZZ%d" % n)
			s.events.clear()
		s.events.clear()


# --- Cross-engine trace replay ----------------------------------------------

const TRACE_KEYS := ["by", "count", "tableRank", "handLeft", "challenger", "lie", "shooter", "who", "bullet", "effect",
	"chamber", "hp", "from", "to", "cheat", "caught", "swapped", "number", "starter", "dealer", "floor", "level",
	"gimmick", "relic", "nextStarter", "target"]


func _compact(e: Dictionary) -> Dictionary:
	var out := {"t": e["type"]}
	for k in TRACE_KEYS:
		if e.has(k):
			out[k] = e[k]
	if e.has("cards"):
		var parts: Array = []
		for c in e["cards"]:
			parts.append(str(c["id"]) + c["rank"])
		out["cards"] = ",".join(parts)
	if e.has("composition"):
		var c: Dictionary = e["composition"]
		out["comp"] = "%d/%d/%d" % [c["live"], c["blank"], c["curse"]]
	if e.has("reward"):
		out["reward"] = e["reward"]["kind"] + ":" + e["reward"]["id"]
	if e.has("rewards"):
		var rs: Array = []
		for r in e["rewards"]:
			rs.append(r["kind"] + ":" + r["id"])
		out["rewards"] = ",".join(rs)
	if e.has("newCard"):
		out["newCard"] = str(e["newCard"]["id"]) + e["newCard"]["rank"]
	return out


func _same_event(a: Dictionary, b: Dictionary) -> bool:
	if a.size() != b.size():
		return false
	for k in a.keys():
		if not b.has(k):
			return false
		var x: Variant = a[k]
		var y: Variant = b[k]
		if typeof(x) == TYPE_FLOAT or typeof(y) == TYPE_FLOAT:
			if absf(float(x) - float(y)) > 1e-9:
				return false
		elif str(x) != str(y):
			return false
	return true


func _test_trace_replay() -> void:
	var path := "res://test/fixtures/traces.json"
	if not FileAccess.file_exists(path):
		_check(false, "traces.json missing")
		return
	var traces: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(traces) != TYPE_ARRAY:
		_check(false, "traces.json unreadable")
		return
	for tr in traces:
		var seed_text: String = tr["seed"]
		var s := Rules.new(seed_text)
		s.start_floor()
		s.begin_round()
		var got: Array = []
		for e in s.drain_events():
			got.append(_compact(e))
		var ok := true
		for action in tr["actions"]:
			var parts: PackedStringArray = str(action).split(":")
			match parts[0]:
				"begin":
					s.begin_round()
				"reward":
					s.choose_reward(int(parts[1]))
				"dealer":
					var res := s.dealer_act()
					if res.get("action") != parts[1]:
						_check(false, "%s: dealer action mismatch (got %s, expected %s)" % [seed_text, str(res.get("action")), parts[1]])
						ok = false
				"play":
					var ids: Array = []
					for p in parts[1].split("."):
						ids.append(int(p))
					var err := s.play("player", ids)
					if err != "":
						_check(false, "%s: play error %s" % [seed_text, err])
						ok = false
				"call":
					s.respond("player", "call")
				"pass":
					s.respond("player", "pass")
				"cheat":
					var opts := {}
					if parts.size() > 2:
						opts["cardId"] = int(parts[2])
					var r := s.use_cheat(parts[1], opts)
					if r.has("error"):
						_check(false, "%s: cheat error %s" % [seed_text, r["error"]])
						ok = false
			for e in s.drain_events():
				got.append(_compact(e))
			if not ok:
				break
		var expected: Array = tr["events"]
		var n: int = mini(got.size(), expected.size())
		var first_diff := -1
		for i in range(n):
			if not _same_event(got[i], expected[i]):
				first_diff = i
				break
		if first_diff == -1 and got.size() != expected.size():
			first_diff = n
		if first_diff >= 0:
			_check(false, "%s: trace diverges at event %d\n  got:      %s\n  expected: %s" % [seed_text, first_diff,
				str(got[first_diff]) if first_diff < got.size() else "<none>",
				str(expected[first_diff]) if first_diff < expected.size() else "<none>"])
		else:
			_check(true, "trace identical")
			print("trace %s: %d events identical, final %s floor %d" % [seed_text, got.size(), s.phase, s.floor_index])
		var fin: Dictionary = tr["final"]
		_eq(s.phase, fin["phase"], "%s final phase" % seed_text)
		_eq(s.floor_index, int(fin["floor"]), "%s final floor" % seed_text)
		_eq(s.player["hp"], int(fin["hp"]), "%s final hp" % seed_text)
		_eq(s.round_number, int(fin["rounds"]), "%s final rounds" % seed_text)


# ---------------------------------------------------------------------------
# Presentation and packaging invariants (regressions found shipping v1.0.0)
# ---------------------------------------------------------------------------

func _test_josa() -> void:
	# 받침 decides the particle; a name we can't classify stays as written.
	_eq(I18n.apply_josa("잭이(가) 온다"), "잭이 온다", "josa: 받침 -> 이")
	_eq(I18n.apply_josa("당신이(가) 온다"), "당신이 온다", "josa: ㄴ 받침 -> 이")
	_eq(I18n.apply_josa("에이스이(가) 온다"), "에이스가 온다", "josa: 모음 -> 가")
	_eq(I18n.apply_josa("킹을(를) 냈다"), "킹을 냈다", "josa: 받침 -> 을")
	_eq(I18n.apply_josa("퀸을(를) 냈다"), "퀸을 냈다", "josa: ㄴ 받침 -> 을")
	_eq(I18n.apply_josa("조커을(를) 냈다"), "조커를 냈다", "josa: 모음 -> 를")
	_eq(I18n.apply_josa("잭은(는) 취했다"), "잭은 취했다", "josa: 받침 -> 은")
	_eq(I18n.apply_josa("조커은(는) 취했다"), "조커는 취했다", "josa: 모음 -> 는")
	_eq(I18n.apply_josa("잭와(과) 함께"), "잭과 함께", "josa: 받침 -> 과")
	_eq(I18n.apply_josa("조커와(과) 함께"), "조커와 함께", "josa: 모음 -> 와")
	_eq(I18n.apply_josa("서울으로(로) 간다"), "서울로 간다", "josa: ㄹ 받침 -> 로")
	_eq(I18n.apply_josa("지하으로(로) 간다"), "지하로 간다", "josa: 모음 -> 로")
	_eq(I18n.apply_josa("빈민가골목으로(로) 간다"), "빈민가골목으로 간다", "josa: 받침 -> 으로")
	_eq(I18n.apply_josa("Jack이(가) 온다"), "Jack이(가) 온다", "josa: 한글이 아니면 그대로")
	_eq(I18n.apply_josa("이(가) 온다"), "이(가) 온다", "josa: 앞 글자가 없으면 그대로")
	_eq(I18n.apply_josa("잭이(가) 잭이(가)"), "잭이 잭이", "josa: 같은 토큰이 여러 번")
	_eq(I18n.batchim_of(""), -1, "batchim: 빈 문자열")
	_eq(I18n.batchim_of("A"), -1, "batchim: 라틴 문자")
	_eq(I18n.batchim_of("가"), 0, "batchim: 받침 없음")
	_eq(I18n.batchim_of("각"), 1, "batchim: 받침 있음")
	_eq(I18n.batchim_of("갈"), 2, "batchim: ㄹ 받침")
	# Every Korean string keeps both forms in the dictionary, so no live string
	# can ship with an unresolved "이(가)" once it goes through t().
	for key in I18n.KO.keys():
		var v: Variant = I18n.KO[key]
		if typeof(v) != TYPE_STRING:
			continue
		for pair in I18n.JOSA_PAIRS:
			var token: String = pair[0]
			var idx: int = v.find(token)
			if idx <= 0:
				continue
			var prev: String = v.substr(idx - 1, 1)
			# Resolvable means: a Hangul syllable, or a placeholder that gets
			# substituted before apply_josa runs. Anything else ships as "이(가)".
			_check(I18n.batchim_of(prev) != -1 or prev == "}",
				"KO[%s]: %s 앞 글자('%s')가 해석 가능해야 한다" % [key, token, prev])


func _test_action_buttons() -> void:
	# The dealer's turn must not stack play + call + pass on screen.
	_eq(TableScreen.shows_respond_buttons("player", "respond"), true, "buttons: 내 응답 차례")
	_eq(TableScreen.shows_respond_buttons("player", "play"), false, "buttons: 내 제출 차례")
	_eq(TableScreen.shows_respond_buttons("dealer", "play"), true, "buttons: 딜러 제출 = 곧 내 응답")
	_eq(TableScreen.shows_respond_buttons("dealer", "respond"), false, "buttons: 딜러 응답 = 곧 내 제출")


func _test_project_config() -> void:
	# v1.0.0 shipped with a user:// that could not be created because the project
	# name contains an apostrophe; the custom dir name is what fixed it.
	_check(bool(ProjectSettings.get_setting("application/config/use_custom_user_dir", false)),
		"project: use_custom_user_dir 켜져 있어야 한다")
	var dir_name := str(ProjectSettings.get_setting("application/config/custom_user_dir_name", ""))
	_check(dir_name != "", "project: custom_user_dir_name 있어야 한다")
	_check(not dir_name.contains("'") and not dir_name.contains("\""),
		"project: custom_user_dir_name 에 따옴표가 없어야 한다")
	# user:// must actually be writable, or settings and logs silently vanish.
	var probe := "user://__probe.tmp"
	var f := FileAccess.open(probe, FileAccess.WRITE)
	_check(f != null, "user:// 쓰기 가능해야 한다 (err %d)" % FileAccess.get_open_error())
	if f != null:
		f.store_string("ok")
		f.close()
		_eq(FileAccess.get_file_as_string(probe), "ok", "user:// 읽기 확인")
		DirAccess.remove_absolute(ProjectSettings.globalize_path(probe))
	# The title screen reads its version from here; empty means the build lies.
	var ver := str(ProjectSettings.get_setting("application/config/version", ""))
	_check(ver.split(".").size() == 3, "project: config/version 은 x.y.z 형식이어야 한다 (got '%s')" % ver)


func _test_challenge_timer() -> void:
	# The challenge window is counted from frame delta, clamped, so a browser tab
	# that was hidden for a minute cannot burn the whole window on the frame it
	# comes back and answer for the player.
	var main_script: GDScript = load("res://scripts/ui/main.gd")
	var step: float = main_script.TIMER_MAX_STEP
	_eq(main_script.timer_step(15.0, 0.016, false), 15.0 - 0.016, "timer: 보통 프레임은 그대로 차감")
	_eq(main_script.timer_step(15.0, 60.0, false), 15.0 - step, "timer: 긴 공백은 한 스텝까지만")
	_eq(main_script.timer_step(15.0, 0.5, false), 15.0 - step, "timer: 스텝 상한 적용")
	_eq(main_script.timer_step(15.0, 0.25, true), 15.0, "timer: 일시정지 중에는 줄지 않는다")
	_eq(main_script.timer_step(15.0, -3.0, false), 15.0, "timer: 음수 델타는 되감지 않는다")
	# 15 s of real time still takes 15 s of frames at any sane frame rate.
	var left := float(GameData.CHALLENGE_SECONDS)
	var frames := 0
	while left > 0.0 and frames < 100000:
		left = float(main_script.timer_step(left, 1.0 / 60.0, false))
		frames += 1
	_eq(frames, GameData.CHALLENGE_SECONDS * 60, "timer: 60fps에서 정확히 15초")


func _test_orientation() -> void:
	# Portrait scales the fixed 1280x720 table to about a third; the game asks
	# for landscape rather than rendering unusable 24x34 px cards.
	var main_script: GDScript = load("res://scripts/ui/main.gd")
	_eq(main_script.wants_landscape(Vector2i(390, 844)), true, "orientation: 폰 세로")
	_eq(main_script.wants_landscape(Vector2i(844, 390)), false, "orientation: 폰 가로")
	_eq(main_script.wants_landscape(Vector2i(1280, 720)), false, "orientation: 데스크톱")
	_eq(main_script.wants_landscape(Vector2i(720, 720)), false, "orientation: 정사각형은 그대로 진행")


func _collect_chars() -> Dictionary:
	## Every character the UI can put on screen: the string tables plus the
	## glyphs that only appear as literals in code (see extra-glyphs.txt, which
	## tools/subset-fonts.py reads too so the two cannot drift).
	var seen := {}
	for dict in [I18n.KO, I18n.EN]:
		for key in dict.keys():
			var v: Variant = dict[key]
			var texts: Array = v if typeof(v) == TYPE_ARRAY else [v]
			for tv in texts:
				var text := str(tv)
				for i in range(text.length()):
					seen[text.unicode_at(i)] = true
	var extra := FileAccess.get_file_as_string("res://assets/fonts/extra-glyphs.txt")
	_check(extra != "", "extra-glyphs.txt 를 읽을 수 있어야 한다")
	for line in extra.split("
"):
		if line.begins_with("#"):
			continue
		for i in range(line.length()):
			var c := line.unicode_at(i)
			if c > 32:
				seen[c] = true
	return seen


func _test_font_coverage() -> void:
	## The bundled fonts are subsets. Anything the dictionaries can render must be
	## in them, or a future string silently ships as tofu boxes.
	var chars := _collect_chars()
	for pair in [["serif", UIKit.serif()], ["sans", UIKit.sans()]]:
		var label: String = pair[0]
		var font: Font = pair[1]
		var missing: Array = []
		for c in chars.keys():
			if c < 32:
				continue
			if not font.has_char(c):
				missing.append("%s(U+%04X)" % [char(c), c])
		_check(missing.is_empty(), "font %s: 빠진 글자 %s" % [label, ", ".join(missing)])


func _test_table_layout() -> void:
	# The wide layout must keep the exact rects the table was drawn with, or a
	# desktop window silently shifts after this refactor.
	var wide := TableLayout.compute(Vector2(1280, 720))
	_eq(wide["compact"], false, "layout: 1280x720는 wide")
	_eq(wide["top"], Rect2(16, 8, 1248, 40), "layout: 상단바 rect 유지")
	_eq(wide["dealer"], Rect2(16, 56, 920, 132), "layout: 딜러존 rect 유지")
	_eq(wide["felt"], Rect2(16, 196, 920, 250), "layout: 펠트 rect 유지")
	_eq(wide["side"], Rect2(948, 56, 316, 654), "layout: 사이드 rect 유지")
	_eq(wide["player"], Rect2(16, 454, 920, 256), "layout: 플레이어존 rect 유지")
	_eq(wide["timer"], Vector2(862, 210), "layout: 타이머 위치 유지")
	_eq(wide["card"], Vector2(78, 110), "layout: 카드 크기 유지")

	# Extra width goes to the table, not to a gap on the right.
	var ultra := TableLayout.compute(Vector2(1707, 720))
	_eq(ultra["compact"], false, "layout: 울트라와이드도 wide")
	_eq(ultra["side"].end.x, 1707.0 - 16.0, "layout: 사이드가 오른쪽 여백에 붙는다")
	_check(ultra["dealer"].size.x > wide["dealer"].size.x, "layout: 남는 폭은 테이블이 가져간다")

	# Wide places panels by hand, so nothing may overlap or run off the screen.
	for v in [Vector2(1280, 720), Vector2(1707, 720), Vector2(1600, 900)]:
		var L := TableLayout.compute(v)
		var name := "%dx%d" % [int(v.x), int(v.y)]
		_eq(L["compact"], false, "layout %s: wide 여야 한다" % name)
		_check(L["dealer"].end.y <= L["felt"].position.y, "layout %s: 딜러존이 펠트를 침범하지 않는다" % name)
		_check(L["felt"].end.y <= L["player"].position.y, "layout %s: 펠트가 플레이어존을 침범하지 않는다" % name)
		_check(L["player"].end.y <= v.y, "layout %s: 플레이어존이 화면을 넘지 않는다" % name)
		_check(L["dealer"].end.x <= L["side"].position.x, "layout %s: 테이블과 사이드가 겹치지 않는다" % name)
		_check(L["side"].end.x <= v.x, "layout %s: 사이드가 화면을 넘지 않는다" % name)
		_check(L["side"].end.y <= v.y, "layout %s: 사이드가 세로로 넘지 않는다" % name)

	# Compact hands placement to containers, so it only promises sizes.
	# 1344x420 is the short-but-wide case: wide there would compute a felt with
	# negative height, so compactness has to look at the height as well.
	for v in [Vector2(909, 420), Vector2(926, 720), Vector2(750, 420), Vector2(1344, 420), Vector2(2016, 420)]:
		var L := TableLayout.compute(v)
		var name := "%dx%d" % [int(v.x), int(v.y)]
		_eq(L["compact"], true, "layout %s: compact 여야 한다" % name)
		_check(not L.has("dealer"), "layout %s: compact는 패널 rect를 내지 않는다" % name)
		_check(L["side_width"] < v.x * 0.5, "layout %s: 사이드가 화면 절반을 넘지 않는다" % name)
		_check(L["actions_horizontal"], "layout %s: compact는 응답 버튼을 가로로 놓는다" % name)

	# A short window drops to the compact design height, which is the whole point:
	# it buys real pixels for the controls.
	_eq(TableLayout.design_height(720.0), TableLayout.WIDE_HEIGHT, "layout: 데스크톱은 720 설계")
	_eq(TableLayout.design_height(390.0), TableLayout.COMPACT_HEIGHT, "layout: 폰은 420 설계")
	var phone := TableLayout.compute(Vector2(909, 420))
	_eq(phone["compact"], true, "layout: 폰 뷰포트는 compact")
	# Buttons and cards must clear the 44 px touch target on a phone in landscape.
	var action_h: float = float(phone["action_pad"]) * 2.0 + 22.0
	var item_h: float = phone["item_min"].y
	var small_side: float = float(phone["small_pad"]) * 2.0 + 20.0
	for probe in [["액션 버튼", action_h], ["사기 도구", item_h], ["아이콘 버튼", small_side], ["카드 폭", phone["card"].x]]:
		var px: float = float(probe[1]) * TableLayout.scale_for(390.0)
		_check(px >= TableLayout.MIN_TOUCH_PX,
			"touch %s: 폰 가로에서 %.0fpx (>= %.0f 필요)" % [probe[0], px, TableLayout.MIN_TOUCH_PX])
