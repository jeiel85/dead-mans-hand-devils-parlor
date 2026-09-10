extends Control
## Game controller: title → run → floors → rounds. Owns the Rules state and
## drives TableScreen/Modal from engine events (mirrors src/main.js).

signal modal_continue

## Single source of truth is project.godot's application/config/version, so the
## title screen can't drift from the tag the release workflow builds.
var VERSION: String = str(ProjectSettings.get_setting("application/config/version", "0.0.0"))

var game: Rules
var table: TableScreen
var modal: Modal
var flash: ColorRect
var selected: Dictionary = {}
var busy := false
var run_token := 0
## Seconds left in the challenge window, or < 0 when no timer is running.
## Counted down from frame delta rather than the wall clock: a hidden browser
## tab stops producing frames, and reading the wall clock on return burned the
## whole window at once and auto-answered for the player.
## The three reward cards currently on screen; the screenshot runner clicks
## these to check that taking a reward really advances the floor.
var reward_buttons: Array = []
var portrait_notice: Control
var timer_left := -1.0
var timer_paused := false
var _last_tick_sec := -1
var _reveal_ready := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	table = TableScreen.new()
	add_child(table)
	flash = ColorRect.new()
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.color = Color(0, 0, 0, 0)
	add_child(flash)
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_portrait_notice()
	modal = Modal.new()
	add_child(modal)
	table.play_pressed.connect(on_play)
	table.call_pressed.connect(func(): on_respond("call"))
	table.pass_pressed.connect(func(): on_respond("pass"))
	table.cheat_pressed.connect(on_cheat)
	table.card_toggled.connect(toggle_select)
	table.menu_pressed.connect(show_menu)
	table.help_pressed.connect(func(): show_help())
	table.lang_pressed.connect(func(): I18n.set_lang("en" if I18n.lang() == "ko" else "ko"))
	table.sound_pressed.connect(func():
		Save.sound = not Save.sound
		Save.save_settings()
		table.render_static()
		if Save.sound:
			Audio.play("chip"))
	table.timer_pressed.connect(func():
		Save.timer_enabled = not Save.timer_enabled
		Save.save_settings()
		table.render_static()
		if not Save.timer_enabled:
			stop_timer()
		elif game != null and game.phase == Rules.PHASE_ROUND and game.round["turn"] == "player" and game.round["phase"] == "respond":
			start_timer())
	I18n.language_changed.connect(_on_language_changed)
	table.render_static()
	show_title()


func _on_language_changed() -> void:
	if portrait_notice != null:
		portrait_notice.get_meta("title").text = I18n.t("rotate.title")
		portrait_notice.get_meta("body").text = I18n.t("rotate.body")
	table.render_static()
	if game != null:
		table.render(game)
	match modal.kind:
		"title":
			show_title()
		"help":
			show_help()
		"intro":
			show_floor_intro()
		"reward":
			show_reward()
		"over":
			show_game_over()
		"win":
			show_victory()
		"settings":
			show_settings()
		"menu":
			show_menu()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			if modal.visible:
				if modal.kind in ["help", "settings", "menu"]:
					_close_secondary()
					accept_event()
			elif game != null and game.phase == Rules.PHASE_ROUND:
				show_menu()
				accept_event()
			return
		if modal.visible and modal.kind == "reveal" and _reveal_ready and event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
			modal_continue.emit()
			accept_event()
			return
		if modal.visible or busy or game == null or game.phase != Rules.PHASE_ROUND:
			return
		if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			on_play()
		elif event.keycode == KEY_C:
			on_respond("call")
		elif event.keycode == KEY_P:
			on_respond("pass")


func _process(delta: float) -> void:
	if timer_left < 0.0 or game == null:
		return
	timer_left = timer_step(timer_left, delta, timer_paused)
	var left := timer_left
	var secs := int(ceil(maxf(0.0, left)))
	table.show_timer(maxf(0.0, left), GameData.CHALLENGE_SECONDS)
	if secs != _last_tick_sec:
		_last_tick_sec = secs
		if secs > 0:
			Audio.play("tickUrgent" if secs <= 5 else "tick", -6.0)
	if left <= 0.0:
		stop_timer()
		var la := game.legal_actions()
		if not la["call"] and not la["pass"]:
			return
		var action := "pass" if la["pass"] else "call"
		push_log(I18n.t("log.timeout", {"action": I18n.t("btn.pass") if action == "pass" else I18n.t("btn.call")}), "sys")
		table.set_hint(I18n.t("hint.timeout"))
		on_respond(action)


# ---------------------------------------------------------------------------
# Modals: title / help / settings / menu
# ---------------------------------------------------------------------------

func show_title() -> void:
	stop_timer()
	_abandon_run()
	table.visible = false
	var body := modal.open("title")
	modal.set_width(620)
	var art := CylinderView.new()
	art.custom_minimum_size = Vector2(120, 120)
	art.set_state(["live", "blank", "blank", "blank", "blank", "blank"], 0, [], null, false)
	var art_c := CenterContainer.new()
	art_c.add_child(art)
	modal.add(art_c)
	modal.title(I18n.t("app.title"), 40, UIKit.C_BRASS, true)
	modal.text(I18n.t("app.subtitle"), 15, UIKit.C_PAPER_DIM, true)
	modal.text(I18n.t("app.tagline"), 14, UIKit.C_PAPER_DIM, true)
	var seed_row := modal.row(true)
	seed_row.add_child(UIKit.label(I18n.t("seed.label"), 13, UIKit.C_MUTED))
	var seed_edit := UIKit.line_edit(I18n.t("seed.placeholder"))
	seed_edit.max_length = 24
	seed_row.add_child(seed_edit)
	var btns := modal.row(true)
	var start := UIKit.button(I18n.t("btn.newRun"), "primary", 17)
	var rules := UIKit.button(I18n.t("btn.howToPlay"), "normal", 15)
	var settings := UIKit.button(I18n.t("btn.settings"), "normal", 15)
	start.pressed.connect(func():
		var v := seed_edit.text.strip_edges().to_upper()
		start_run(v if v != "" else SeededRng.random_seed()))
	seed_edit.text_submitted.connect(func(_t): start.pressed.emit())
	rules.pressed.connect(func(): show_help())
	settings.pressed.connect(func(): show_settings())
	btns.add_child(start)
	btns.add_child(rules)
	btns.add_child(settings)
	if not OS.has_feature("web"):
		var quit := UIKit.button(I18n.t("btn.quit"), "normal", 15)
		quit.pressed.connect(func(): get_tree().quit())
		btns.add_child(quit)
	var best := I18n.t("seed.best", {"floor": Save.best_floor}) if Save.best_floor > 0 else I18n.t("seed.none")
	var rec := I18n.t("seed.record", {"runs": Save.runs_played, "wins": Save.victories})
	modal.text("%s · %s" % [best, rec], 12, UIKit.C_MUTED, true)
	modal.text(I18n.t("app.version", {"v": VERSION}), 11, UIKit.C_MUTED, true)
	seed_edit.grab_focus()


func show_help() -> void:
	var prev := modal.kind if modal.kind in ["title", "intro", "reward", "over", "win", "menu"] else ""
	var body := modal.open("help")
	modal.set_width(680)
	modal.title(I18n.t("help.title"), 26)
	var i := 1
	for line in I18n.lines("help.body"):
		modal.text("%d. %s" % [i, line], 14, UIKit.C_PAPER_DIM)
		i += 1
	var r := modal.row()
	var close := UIKit.button(I18n.t("btn.close"), "primary", 15)
	close.pressed.connect(func(): _return_from_secondary(prev))
	r.add_child(close)
	modal.set_meta("prev", prev)


func show_settings() -> void:
	var prev: String = modal.get_meta("prev", "") if modal.kind == "settings" else (modal.kind if modal.kind in ["title", "menu", "intro", "reward", "over", "win"] else "")
	var body := modal.open("settings")
	modal.set_meta("prev", prev)
	modal.set_width(520)
	modal.title(I18n.t("btn.settings"), 26)
	var r1 := modal.row()
	r1.add_child(UIKit.label(I18n.t("set.lang"), 15))
	r1.add_child(UIKit.spacer())
	var lang_btn := UIKit.button("한국어" if I18n.lang() == "ko" else "English", "normal", 14)
	lang_btn.pressed.connect(func(): I18n.set_lang("en" if I18n.lang() == "ko" else "ko"))
	r1.add_child(lang_btn)
	var r2 := modal.row()
	r2.add_child(UIKit.label(I18n.t("set.sound"), 15))
	r2.add_child(UIKit.spacer())
	var snd := UIKit.button(I18n.t("set.on") if Save.sound else I18n.t("set.off"), "normal", 14)
	snd.pressed.connect(func():
		Save.sound = not Save.sound
		Save.save_settings()
		table.render_static()
		if Save.sound:
			Audio.play("chip")
		show_settings())
	r2.add_child(snd)
	var r3 := modal.row()
	r3.add_child(UIKit.label(I18n.t("set.timer"), 15))
	r3.add_child(UIKit.spacer())
	var tm := UIKit.button(I18n.t("set.on") if Save.timer_enabled else I18n.t("set.off"), "normal", 14)
	tm.pressed.connect(func():
		Save.timer_enabled = not Save.timer_enabled
		Save.save_settings()
		table.render_static()
		show_settings())
	r3.add_child(tm)
	if Save.write_failed:
		modal.text(I18n.t("set.saveFailed"), 12, UIKit.C_RED)
	var r4 := modal.row()
	var close := UIKit.button(I18n.t("btn.close"), "primary", 15)
	close.pressed.connect(func(): _return_from_secondary(prev))
	r4.add_child(close)


func show_menu() -> void:
	if game == null or game.phase != Rules.PHASE_ROUND:
		return
	stop_timer()
	var body := modal.open("menu")
	modal.set_width(460)
	modal.title(I18n.t("menu.title"), 26)
	var resume := UIKit.button(I18n.t("menu.resume"), "primary", 16)
	resume.pressed.connect(func(): _return_from_secondary(""))
	var help := UIKit.button(I18n.t("btn.howToPlay"), "normal", 15)
	help.pressed.connect(func(): show_help())
	var settings := UIKit.button(I18n.t("btn.settings"), "normal", 15)
	settings.pressed.connect(func(): show_settings())
	var abandon := UIKit.button(I18n.t("menu.abandon"), "danger", 15)
	abandon.pressed.connect(func():
		if game != null:
			Save.record_run_end(game.current_floor()["level"], false)
		game = null
		show_title())
	for b in [resume, help, settings, abandon]:
		modal.add(b)


func _close_secondary() -> void:
	var prev: String = modal.get_meta("prev", "")
	_return_from_secondary(prev)


func _return_from_secondary(prev: String) -> void:
	if modal.has_meta("prev"):
		modal.remove_meta("prev")
	match prev:
		"title":
			show_title()
		"intro":
			show_floor_intro()
		"reward":
			show_reward()
		"over":
			show_game_over()
		"win":
			show_victory()
		"menu":
			show_menu()
		_:
			modal.close()
			if game != null and game.phase == Rules.PHASE_ROUND and game.round["turn"] == "player" and game.round["phase"] == "respond" and Save.timer_enabled:
				start_timer()


# ---------------------------------------------------------------------------
# Run lifecycle
# ---------------------------------------------------------------------------

## Invalidate the running coroutines and release anything blocked on a modal,
## so a coroutine parked on `await modal_continue` resumes, sees the new token
## and returns instead of sitting on the old run forever.
func _abandon_run() -> void:
	run_token += 1
	busy = false
	if _reveal_ready:
		_reveal_ready = false
		modal_continue.emit()


func start_run(seed_text: String) -> void:
	stop_timer()
	_abandon_run()
	game = Rules.new(seed_text)
	table.visible = true
	selected.clear()
	table.selected = selected
	table.clear_log()
	game.start_floor()
	for e in game.drain_events():
		log_event(e)
	table.render(game)
	show_floor_intro()


func show_floor_intro() -> void:
	if game == null:
		return
	var f := game.current_floor()
	var d := game.dealer
	var body := modal.open("intro")
	modal.set_width(620)
	var pc := CenterContainer.new()
	var portrait := PortraitView.new()
	portrait.custom_minimum_size = Vector2(120, 132)
	portrait.set_dealer(d["id"])
	pc.add_child(portrait)
	modal.add(pc)
	modal.eyebrow(I18n.t("intro.title", {"level": f["level"], "name": I18n.t("floor." + f["id"])}), true)
	modal.title(I18n.t("dealer.%s.name" % d["id"]), 28, UIKit.C_BRASS, true)
	modal.text(I18n.t("dealer.%s.title" % d["id"]), 13, UIKit.C_MUTED, true)
	var q := modal.text("“%s”" % I18n.t("dealer.%s.intro" % d["id"]), 17, UIKit.C_PAPER, true)
	q.add_theme_font_override("font", UIKit.serif())
	modal.text(I18n.t("dealer.%s.gimmick" % d["id"]), 14, UIKit.C_BRASS, true)
	var c: Dictionary = f["cylinder"]
	modal.text("%s · %s" % [I18n.t("intro.cylinder", {"live": c["live"], "blank": c["blank"], "curse": c["curse"]}), I18n.t("intro.hp", {"hp": f["hp"]})], 12, UIKit.C_MUTED, true)
	var r := modal.row(true)
	var enter := UIKit.button(I18n.t("btn.enter"), "primary", 17)
	enter.pressed.connect(func():
		modal.close()
		Audio.play("card")
		game.begin_round()
		after_engine_step())
	r.add_child(enter)


func after_engine_step() -> void:
	var token := run_token
	var evs := game.drain_events()
	await process_events(evs, token)
	if token != run_token or game == null:
		return
	table.selected = selected
	table.render(game)
	schedule_next(token)


func schedule_next(token: int) -> void:
	if token != run_token or game == null:
		return
	match game.phase:
		Rules.PHASE_FLOOR_INTRO:
			show_floor_intro()
		Rules.PHASE_REWARD:
			show_reward()
		Rules.PHASE_GAME_OVER:
			Save.record_run_end(game.current_floor()["level"], false)
			Audio.play("lose")
			show_game_over()
		Rules.PHASE_VICTORY:
			Save.record_run_end(7, true)
			Audio.play("win")
			show_victory()
		Rules.PHASE_ROUND:
			if game.round["turn"] == "dealer":
				table.set_hint(I18n.t("hint.dealerThinking") if game.round["phase"] == "respond" else I18n.t("hint.dealerPlaying"))
				table.set_speech(I18n.t("say.think"), true)
				_dealer_turn(token)
			elif game.round["phase"] == "respond" and Save.timer_enabled:
				start_timer()


func _dealer_turn(token: int) -> void:
	if not await _pause(0.7 + randf() * 0.7, token):
		return
	if modal.visible and modal.kind in ["menu", "settings", "help"]:
		# paused behind a menu: look again once it closes
		if not await _pause(0.5, token):
			return
		_dealer_turn(token)
		return
	var res := game.dealer_act()
	match res.get("action", ""):
		"call":
			table.set_speech(I18n.t("say.call"))
		"pass":
			table.set_speech(I18n.t("say.pass"))
		_:
			table.set_speech("")
	after_engine_step()


# ---------------------------------------------------------------------------
# Player input
# ---------------------------------------------------------------------------

func toggle_select(id: int) -> void:
	if game == null or game.phase != Rules.PHASE_ROUND or busy:
		return
	var la := game.legal_actions()
	if not la["play"] and not la["cheats"].has("bottomDeal"):
		return
	if selected.has(id):
		selected.erase(id)
	else:
		if selected.size() >= 3:
			return
		selected[id] = true
	Audio.play("select")
	table.selected = selected
	for cv in table._hand_cards:
		if cv.card_id == id:
			cv.set_selected(selected.has(id))
	table._selected_label.text = I18n.t("hud.selected", {"n": selected.size()})
	table.render_actions(game)


func on_play() -> void:
	if busy or game == null:
		return
	var la := game.legal_actions()
	if not la["play"] or selected.is_empty():
		return
	var ids := selected.keys()
	selected.clear()
	table.selected = selected
	Audio.play("card")
	if game.play("player", ids) != "":
		return
	after_engine_step()


func on_respond(action: String) -> void:
	if busy or game == null:
		return
	var la := game.legal_actions()
	if (action == "call" and not la["call"]) or (action == "pass" and not la["pass"]):
		return
	stop_timer()
	selected.clear()
	table.selected = selected
	Audio.play("chip")
	if game.respond("player", action) != "":
		return
	after_engine_step()


func on_cheat(id: String) -> void:
	if busy or game == null:
		return
	var la := game.legal_actions()
	if not la["cheats"].has(id):
		return
	var opts := {}
	if id == "bottomDeal":
		if selected.size() != 1:
			table.set_hint(I18n.t("hint.selectCard"), true)
			return
		var card_id: int = selected.keys()[0]
		var card: Variant = null
		for c in game.round["hands"]["player"]:
			if c["id"] == card_id:
				card = c
		if card == null or Rules.is_truthful(card, game.round["tableRank"]):
			table.set_hint(I18n.t("hint.selectLie"), true)
			return
		opts["cardId"] = card_id
		selected.clear()
		table.selected = selected
	var res := game.use_cheat(id, opts)
	if res.has("error"):
		return
	after_engine_step()


# ---------------------------------------------------------------------------
# Challenge timer
# ---------------------------------------------------------------------------

## Largest slice of a single frame the timer will accept. Normal frames are far
## below it; a frame that took longer means the game was not on screen (hidden
## tab, dragged window, suspended laptop) and must not eat the player's window.
const TIMER_MAX_STEP := 0.25


static func timer_step(left: float, delta: float, paused: bool) -> float:
	if paused:
		return left
	return left - minf(maxf(delta, 0.0), TIMER_MAX_STEP)


func start_timer() -> void:
	if timer_left >= 0.0:
		return
	timer_left = float(GameData.CHALLENGE_SECONDS)
	timer_paused = false
	_last_tick_sec = GameData.CHALLENGE_SECONDS


func stop_timer() -> void:
	timer_left = -1.0
	timer_paused = false
	table.hide_timer()


func _notification(what: int) -> void:
	# Losing focus pauses the countdown; the player is not looking at the table.
	match what:
		NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_WINDOW_FOCUS_OUT:
			timer_paused = true
		NOTIFICATION_APPLICATION_FOCUS_IN, NOTIFICATION_WM_WINDOW_FOCUS_IN:
			timer_paused = false


# ---------------------------------------------------------------------------
# Events → log / sfx / modals
# ---------------------------------------------------------------------------

## The table is a fixed 1280x720 layout, letterboxed by stretch aspect "keep".
## In portrait that scales everything to roughly a third (a card lands near
## 24x34 px on a phone), which is not playable, so ask for landscape instead of
## pretending it works.
static func wants_landscape(window_size: Vector2i) -> bool:
	return window_size.y > window_size.x


func _build_portrait_notice() -> void:
	portrait_notice = Control.new()
	portrait_notice.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(portrait_notice)
	portrait_notice.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = UIKit.C_BG
	portrait_notice.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	portrait_notice.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	var title := UIKit.label(I18n.t("rotate.title"), 30, UIKit.C_BRASS, UIKit.serif())
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var body := UIKit.wrap(UIKit.label(I18n.t("rotate.body"), 15, UIKit.C_PAPER_DIM))
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.custom_minimum_size = Vector2(420, 0)
	box.add_child(title)
	box.add_child(body)
	center.add_child(box)
	portrait_notice.visible = false
	portrait_notice.set_meta("title", title)
	portrait_notice.set_meta("body", body)
	get_window().size_changed.connect(_update_orientation)
	_update_orientation()


func _update_orientation() -> void:
	if portrait_notice == null:
		return
	portrait_notice.visible = wants_landscape(get_window().size)


## Wait `sec`, then report whether this run is still current. Every animation
## pause goes through here so an abandoned run (new game, back to title) stops
## at the next beat instead of finishing its effects over the new one.
func _pause(sec: float, token: int) -> bool:
	await get_tree().create_timer(sec).timeout
	return token == run_token and game != null


func process_events(evs: Array, token: int) -> void:
	busy = true
	var i := 0
	while i < evs.size():
		var ev: Dictionary = evs[i]
		log_event(ev)
		match ev["type"]:
			"reveal":
				var fires: Array = []
				var extra: Array = []
				var j := i + 1
				while j < evs.size() and evs[j]["type"] in ["fire", "hp", "reload", "gimmick", "relicProc", "pactBackfire"]:
					var e2: Dictionary = evs[j]
					log_event(e2)
					match e2["type"]:
						"fire":
							fires.append(e2)
						"reload":
							extra.append([I18n.t("reveal.reload"), UIKit.C_MUTED])
						"pactBackfire":
							extra.append([I18n.t("reveal.pactBackfire", {"who": I18n.who(e2["by"], game.dealer["id"])}), UIKit.C_RED])
						"gimmick":
							extra.append([I18n.t("log.gimmick." + e2["gimmick"]), UIKit.C_MUTED])
						"relicProc":
							extra.append([I18n.t("log.relicProc." + e2["relic"]), UIKit.C_MUTED])
					j += 1
				i = j - 1
				await show_reveal(ev, fires, extra, token)
				if token != run_token:
					busy = false
					return
				if ev["by"] == "player":
					table.set_speech(I18n.t("say.caughtYou") if ev["lie"] else "")
			"cheat":
				if ev["caught"]:
					Audio.play("caught")
					table.set_speech(I18n.t("say.cheatCaught"))
					table.render(game)
					if not await _pause(0.6, token):
						busy = false
						return
				else:
					Audio.play("chip")
			"fire":
				table.render(game)
				Audio.play("hammer")
				if not await _pause(0.4, token):
					busy = false
					return
				_fire_fx(ev)
				if not await _pause(0.5, token):
					busy = false
					return
			"reload":
				Audio.play("reload")
				table.render(game)
				if not await _pause(0.5, token):
					busy = false
					return
			"play":
				if ev["by"] == "dealer":
					Audio.play("card")
			"pactStrike":
				Audio.play("hurt")
				table.render(game)
				if not await _pause(0.5, token):
					busy = false
					return
			"hp":
				if ev["to"] > ev["from"]:
					Audio.play("heal")
			"roundStart":
				selected.clear()
				table.selected = selected
				table.render(game)
				Audio.play("card")
				if not await _pause(0.25, token):
					busy = false
					return
		if token != run_token:
			busy = false
			return
		i += 1
	busy = false


func _fire_fx(ev: Dictionary) -> void:
	var col: Color
	if ev["effect"] == "misfire":
		Audio.play("misfire")
		col = UIKit.C_BRASS
	elif ev["bullet"] == "live":
		Audio.play("bang")
		col = Color("c1121f")
	elif ev["bullet"] == "curse":
		Audio.play("curse")
		col = Color("5b2a8a")
	else:
		Audio.play("click")
		col = Color("f2e9d8")
	flash.color = Color(col, 0.75)
	var t := create_tween()
	t.tween_property(flash, "color:a", 0.0, 0.5)


func show_reveal(ev: Dictionary, fires: Array, extra: Array, token: int) -> void:
	var body := modal.open("reveal")
	modal.set_width(600)
	modal.eyebrow(I18n.t("reveal.claim", {"who": I18n.who(ev["by"], game.dealer["id"]), "rank": I18n.rank(ev["tableRank"]), "n": ev["cards"].size()}), true)
	var cards := modal.row(true)
	for c in ev["cards"]:
		cards.add_child(CardView.new(c["rank"], -1, true, false))
	modal.title(I18n.t("reveal.title.lie") if ev["lie"] else I18n.t("reveal.title.truth"), 26, UIKit.C_RED if ev["lie"] else UIKit.C_GREEN, true)
	var s := "" if ev["shooter"] == "player" else "s"
	modal.text(I18n.t("reveal.shooter", {"who": I18n.who(ev["shooter"], game.dealer["id"]), "s": s}), 14, UIKit.C_PAPER_DIM, true)
	var results := VBoxContainer.new()
	results.alignment = BoxContainer.ALIGNMENT_CENTER
	results.add_theme_constant_override("separation", 4)
	modal.add(results)
	var r := modal.row(true)
	var cont := UIKit.button(I18n.t("btn.continue"), "primary", 16)
	cont.visible = false
	cont.pressed.connect(func(): modal_continue.emit())
	r.add_child(cont)
	if not await _pause(0.9, token):
		return
	for f in fires:
		Audio.play("hammer")
		if not await _pause(0.45, token):
			return
		_fire_fx(f)
		var key: String = "reveal.result.misfire" if f["effect"] == "misfire" else "reveal.result." + str(f["bullet"])
		var col := UIKit.C_RED if f["effect"] == "live" else (Color("c9a9f0") if f["bullet"] == "curse" else (UIKit.C_BRASS if f["effect"] == "misfire" else UIKit.C_PAPER))
		var l := UIKit.label(I18n.t(key, {"who": I18n.who(f["who"], game.dealer["id"])}), 18, col, UIKit.serif())
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		results.add_child(l)
		if not await _pause(0.3, token):
			return
	for x in extra:
		var l2 := UIKit.label(x[0], 14, x[1])
		l2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		results.add_child(l2)
	cont.visible = true
	_reveal_ready = true
	await modal_continue
	_reveal_ready = false
	if token != run_token:
		return
	modal.close()


func show_reward() -> void:
	if game == null or game.phase != Rules.PHASE_REWARD:
		return
	reward_buttons.clear()
	var body := modal.open("reward")
	modal.set_width(700)
	modal.title(I18n.t("reward.title"), 26)
	modal.text(I18n.t("reward.sub", {"name": I18n.t("dealer.%s.name" % game.dealer["id"])}), 13, UIKit.C_MUTED)
	var row := modal.row()
	for i in range(game.rewards.size()):
		var rw: Dictionary = game.rewards[i]
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(200, 150)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var st := UIKit.panel_style(Color("170f0b"), UIKit.C_BRASS_DIM, 10, 1)
		b.add_theme_stylebox_override("normal", st)
		var hv := UIKit.panel_style(Color("241811"), UIKit.C_BRASS, 10, 1)
		b.add_theme_stylebox_override("hover", hv)
		b.add_theme_stylebox_override("pressed", hv)
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		var v := VBoxContainer.new()
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_theme_constant_override("separation", 4)
		var kind_text := "" if rw["kind"] == "heal" else (I18n.t("reward.item") if rw["kind"] == "item" else I18n.t("reward.relic"))
		var name_text: String = I18n.t("reward.heal.name") if rw["kind"] == "heal" else (I18n.t("item.%s.name" % rw["id"]) if rw["kind"] == "item" else I18n.t("relic.%s.name" % rw["id"]))
		var desc_text: String = I18n.t("reward.heal.desc") if rw["kind"] == "heal" else (I18n.t("item.%s.desc" % rw["id"]) if rw["kind"] == "item" else I18n.t("relic.%s.desc" % rw["id"]))
		v.add_child(UIKit.label(kind_text.to_upper(), 10, UIKit.C_MUTED))
		v.add_child(UIKit.label(name_text, 17, UIKit.C_BRASS, UIKit.serif()))
		v.add_child(UIKit.wrap(UIKit.label(desc_text, 12, UIKit.C_PAPER_DIM)))
		b.add_child(v)
		v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		v.offset_left = 14
		v.offset_top = 12
		v.offset_right = -14
		b.pressed.connect(func():
			Audio.play("chip")
			modal.close()
			game.choose_reward(i)
			after_engine_step())
		row.add_child(b)
		reward_buttons.append(b)
	var hp := CenterContainer.new()
	hp.add_child(UIKit.hearts(game.player["hp"], game.player["maxHp"]))
	modal.add(hp)


func _stats_block() -> void:
	var s := game.stats
	modal.text(I18n.t("stat.rounds", {"n": game.round_number}), 13, UIKit.C_PAPER_DIM, true)
	modal.text(I18n.t("stat.bluffs", {"b": s["playerBluffs"], "p": s["playerPlays"]}), 13, UIKit.C_PAPER_DIM, true)
	modal.text(I18n.t("stat.calls", {"r": s["playerCallsRight"], "w": s["playerCallsWrong"]}), 13, UIKit.C_PAPER_DIM, true)
	modal.text(I18n.t("stat.cheats", {"u": s["cheatsUsed"], "c": s["cheatsCaught"]}), 13, UIKit.C_PAPER_DIM, true)
	modal.text(I18n.t("stat.shots", {"s": s["shotsTaken"], "l": s["liveTaken"]}), 13, UIKit.C_PAPER_DIM, true)
	modal.text(I18n.t("stat.seed", {"seed": game.seed_text}), 12, UIKit.C_BRASS_DIM, true)


func _end_buttons() -> void:
	var r := modal.row(true)
	var retry := UIKit.button(I18n.t("btn.retry"), "primary", 16)
	retry.pressed.connect(func(): start_run(SeededRng.random_seed()))
	var title_btn := UIKit.button(I18n.t("btn.title"), "normal", 15)
	title_btn.pressed.connect(func(): show_title())
	r.add_child(retry)
	r.add_child(title_btn)


func show_game_over() -> void:
	if game == null:
		return
	var f := game.current_floor()
	var body := modal.open("over")
	modal.set_width(560)
	modal.title(I18n.t("over.title"), 30, UIKit.C_RED, true)
	modal.text(I18n.t("over.sub", {"level": f["level"], "name": I18n.t("floor." + f["id"])}), 14, UIKit.C_MUTED, true)
	_stats_block()
	_end_buttons()


func show_victory() -> void:
	if game == null:
		return
	var body := modal.open("win")
	modal.set_width(560)
	modal.title(I18n.t("win.title"), 30, UIKit.C_GREEN, true)
	modal.text(I18n.t("win.sub"), 14, UIKit.C_MUTED, true)
	_stats_block()
	_end_buttons()


# ---------------------------------------------------------------------------
# Log
# ---------------------------------------------------------------------------

func push_log(text: String, cls: String = "sys") -> void:
	table.push_log(text, cls)


func log_event(ev: Dictionary) -> void:
	var d_id: String = game.dealer["id"] if game != null and not game.dealer.is_empty() else "jack"
	var W := func(w: String) -> String: return I18n.who(w, d_id)
	var R := func(r: String) -> String: return I18n.rank(r)
	match ev["type"]:
		"floorStart":
			push_log(I18n.t("log.floorStart", {"level": ev["level"], "name": I18n.t("floor." + ev["floor"]), "dealer": I18n.t("dealer.%s.name" % ev["dealer"])}), "sys")
		"roundStart":
			push_log(I18n.t("log.roundStart", {"n": ev["number"], "rank": R.call(ev["tableRank"]), "who": W.call(ev["starter"])}), "sys")
		"play":
			push_log(I18n.t("log.play", {"who": W.call(ev["by"]), "rank": R.call(ev["tableRank"]), "n": ev["count"], "left": ev["handLeft"]}), ev["by"])
		"pass":
			push_log(I18n.t("log.pass", {"who": W.call(ev["by"])}), ev["by"])
		"reveal":
			var names: Array = []
			for c in ev["cards"]:
				names.append(R.call(c["rank"]))
			push_log(I18n.t("log.call", {"who": W.call(ev["challenger"])}), ev["challenger"])
			var s := "" if ev["shooter"] == "player" else "s"
			push_log(I18n.t("log.reveal.lie" if ev["lie"] else "log.reveal.truth", {"cards": ", ".join(names), "who": W.call(ev["shooter"]), "s": s}), "sys")
		"fire":
			var key: String = "log.fire.misfire" if ev["effect"] == "misfire" else "log.fire." + str(ev["bullet"])
			push_log(I18n.t(key, {"who": W.call(ev["who"]), "n": ev["chamber"], "hp": ev["hp"]}), "danger" if (ev["bullet"] == "live" and ev["effect"] != "misfire") else "sys")
		"reload":
			push_log(I18n.t("log.reload", ev["composition"]), "sys")
		"cheat":
			var item := I18n.t("item.%s.name" % ev["cheat"])
			var p := int(round(ev["detectChance"] * 100))
			if ev["caught"]:
				push_log(I18n.t("log.cheat.caught", {"item": item, "p": p}), "danger")
			else:
				push_log(I18n.t("log.cheat.ok", {"item": item, "p": p}), "player")
				match ev["cheat"]:
					"mirror":
						push_log(I18n.t("log.cheat.mirror", {"bullet": I18n.t("bullet." + ev["bullet"])}), "player")
					"leadWeight":
						push_log(I18n.t("log.cheat.lead" if ev["swapped"] else "log.cheat.leadNoop"), "player")
					"bottomDeal":
						push_log(I18n.t("log.cheat.bottom", {"rank": R.call(ev["newCard"]["rank"])}) if ev["swapped"] else I18n.t("log.cheat.bottomFail"), "player")
					"pact":
						push_log(I18n.t("log.cheat.pact"), "player")
		"pactStrike":
			push_log(I18n.t("log.pactStrike"), "danger")
		"pactFizzle":
			push_log(I18n.t("log.pactFizzle"), "sys")
		"pactBackfire":
			push_log(I18n.t("log.pactBackfire"), "danger")
		"gimmick":
			push_log(I18n.t("log.gimmick." + ev["gimmick"]), "dealer")
		"relicProc":
			push_log(I18n.t("log.relicProc." + ev["relic"]), "player")
		"hp":
			push_log(I18n.t("log.hp", {"who": W.call(ev["who"]), "from": ev["from"], "to": ev["to"]}), "danger" if ev["to"] < ev["from"] else "sys")
		"dealerDefeated":
			push_log(I18n.t("log.dealerDefeated", {"dealer": I18n.t("dealer.%s.name" % ev["dealer"])}), "sys")
		"rewardTaken":
			var rw: Dictionary = ev["reward"]
			var name_text: String = I18n.t("reward.heal.name") if rw["kind"] == "heal" else (I18n.t("item.%s.name" % rw["id"]) if rw["kind"] == "item" else I18n.t("relic.%s.name" % rw["id"]))
			push_log(I18n.t("log.rewardTaken", {"name": name_text}), "sys")
		"gameOver":
			push_log(I18n.t("log.gameOver"), "danger")
		"victory":
			push_log(I18n.t("log.victory"), "sys")
