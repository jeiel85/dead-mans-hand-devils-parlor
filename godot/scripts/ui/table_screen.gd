class_name TableScreen
extends Control
## The in-game screen: dealer zone, felt table, revolver side panel, player zone.
## Pure presentation — it renders a Rules state and emits player intents.

signal play_pressed
signal call_pressed
signal pass_pressed
signal cheat_pressed(cheat_id: String)
signal card_toggled(card_id: int)
signal menu_pressed
signal lang_pressed
signal sound_pressed
signal timer_pressed
signal help_pressed

var selected: Dictionary = {}

# top bar
var _hud_floor: Label
var _hud_round: Label
var _hud_seed: Label
var _btn_lang: Button
var _btn_sound: Button
var _btn_timer: Button
var _btn_help: Button
var _btn_menu: Button
# dealer zone
var _portrait: PortraitView
var _dealer_name: Label
var _dealer_title: Label
var _dealer_hearts_box: HBoxContainer
var _dealer_focus: Label
var _speech: PanelContainer
var _speech_label: Label
var _dealer_hand_label: Label
var _dealer_hand: HBoxContainer
var _dealer_notes: Label
# center
var _rank_card_holder: Control
var _rank_name: Label
var _pile: HBoxContainer
var _pile_empty: Label
var _timer: TimerArc
# side
var _cylinder: CylinderView
var _odds_main: Label
var _odds_sub: Label
var _odds_known: Label
var _log: RichTextLabel
var _lbl_cyl: Label
var _lbl_log: Label
var _lbl_pile: Label
var _lbl_rank: Label
var _lbl_relics: Label
# player zone
var _player_hearts_box: HBoxContainer
var _relics: HBoxContainer
var _items: HBoxContainer
var _hand: Control
var _hand_cards: Array = []
var _player_notes: Label
var _btn_play: Button
var _btn_call: Button
var _btn_pass: Button
var _hint: Label
var _selected_label: Label
var _item_buttons: Dictionary = {}
var _log_lines: Array = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()


# ---------------------------------------------------------------------------
# Layout
# ---------------------------------------------------------------------------

func _build() -> void:
	var bg := ColorRect.new()
	bg.color = UIKit.C_BG
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var glow := RadialGlow.new()
	add_child(glow)
	glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# --- top bar
	var top := HBoxContainer.new()
	top.position = Vector2(16, 8)
	top.size = Vector2(1248, 40)
	top.add_theme_constant_override("separation", 12)
	add_child(top)
	var brand := VBoxContainer.new()
	brand.add_theme_constant_override("separation", 0)
	var brand_main := UIKit.label("DEAD MAN'S HAND", 18, UIKit.C_BRASS, UIKit.serif())
	var brand_sub := UIKit.label("Devil's Parlor", 11, UIKit.C_MUTED)
	brand.add_child(brand_main)
	brand.add_child(brand_sub)
	top.add_child(brand)
	top.add_child(UIKit.spacer())
	var hud := HBoxContainer.new()
	hud.add_theme_constant_override("separation", 10)
	_hud_floor = UIKit.label("", 13, UIKit.C_PAPER_DIM)
	_hud_round = UIKit.label("", 13, UIKit.C_PAPER_DIM)
	_hud_seed = UIKit.label("", 12, UIKit.C_BRASS_DIM)
	hud.add_child(_hud_floor)
	hud.add_child(UIKit.label("·", 13, UIKit.C_BRASS_DIM))
	hud.add_child(_hud_round)
	hud.add_child(UIKit.label("·", 13, UIKit.C_BRASS_DIM))
	hud.add_child(_hud_seed)
	top.add_child(hud)
	top.add_child(UIKit.spacer())
	var ctl := HBoxContainer.new()
	ctl.add_theme_constant_override("separation", 6)
	_btn_lang = UIKit.button("EN", "small", 12)
	_btn_sound = UIKit.button("♪", "small", 12)
	_btn_timer = UIKit.button("⏱", "small", 12)
	_btn_help = UIKit.button("?", "small", 12)
	_btn_menu = UIKit.button("≡", "small", 12)
	_btn_lang.pressed.connect(func(): lang_pressed.emit())
	_btn_sound.pressed.connect(func(): sound_pressed.emit())
	_btn_timer.pressed.connect(func(): timer_pressed.emit())
	_btn_help.pressed.connect(func(): help_pressed.emit())
	_btn_menu.pressed.connect(func(): menu_pressed.emit())
	for b in [_btn_lang, _btn_sound, _btn_timer, _btn_help, _btn_menu]:
		ctl.add_child(b)
	top.add_child(ctl)

	# --- dealer zone
	var dealer_panel := UIKit.panel()
	dealer_panel.position = Vector2(16, 56)
	dealer_panel.size = Vector2(920, 132)
	add_child(dealer_panel)
	var drow := HBoxContainer.new()
	drow.add_theme_constant_override("separation", 14)
	dealer_panel.add_child(drow)
	_portrait = PortraitView.new()
	_portrait.custom_minimum_size = Vector2(96, 106)
	drow.add_child(_portrait)
	var dinfo := VBoxContainer.new()
	dinfo.add_theme_constant_override("separation", 2)
	dinfo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_dealer_name = UIKit.label("", 22, UIKit.C_BRASS, UIKit.serif())
	_dealer_title = UIKit.label("", 12, UIKit.C_MUTED)
	_dealer_hearts_box = HBoxContainer.new()
	_dealer_focus = UIKit.label("", 12, UIKit.C_PAPER_DIM)
	_speech = PanelContainer.new()
	var sp_style := UIKit.panel_style(UIKit.C_PAPER, UIKit.C_PAPER, 10, 0)
	sp_style.set_content_margin_all(6)
	sp_style.content_margin_left = 10
	sp_style.content_margin_right = 10
	_speech.add_theme_stylebox_override("panel", sp_style)
	_speech.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_speech_label = UIKit.label("", 13, UIKit.C_INK)
	_speech.add_child(_speech_label)
	_speech.visible = false
	dinfo.add_child(_dealer_name)
	dinfo.add_child(_dealer_title)
	dinfo.add_child(_dealer_hearts_box)
	dinfo.add_child(_dealer_focus)
	dinfo.add_child(_speech)
	drow.add_child(dinfo)
	var dhand := VBoxContainer.new()
	dhand.alignment = BoxContainer.ALIGNMENT_END
	dhand.add_theme_constant_override("separation", 4)
	_dealer_hand_label = UIKit.caption("")
	_dealer_hand_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_dealer_hand = HBoxContainer.new()
	_dealer_hand.alignment = BoxContainer.ALIGNMENT_END
	_dealer_hand.add_theme_constant_override("separation", 4)
	_dealer_notes = UIKit.label("", 11, Color("d9c6f5"))
	_dealer_notes.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	dhand.add_child(_dealer_hand_label)
	dhand.add_child(_dealer_hand)
	dhand.add_child(_dealer_notes)
	drow.add_child(dhand)

	# --- felt table
	var felt := PanelContainer.new()
	var felt_style := StyleBoxFlat.new()
	felt_style.bg_color = UIKit.C_FELT
	felt_style.border_color = UIKit.C_WOOD
	felt_style.set_border_width_all(6)
	felt_style.set_corner_radius_all(12)
	felt_style.set_content_margin_all(14)
	felt_style.shadow_color = Color(0, 0, 0, 0.5)
	felt_style.shadow_size = 12
	felt.add_theme_stylebox_override("panel", felt_style)
	felt.position = Vector2(16, 196)
	felt.size = Vector2(920, 250)
	add_child(felt)
	var frow := HBoxContainer.new()
	frow.add_theme_constant_override("separation", 22)
	felt.add_child(frow)
	var rank_box := VBoxContainer.new()
	rank_box.alignment = BoxContainer.ALIGNMENT_CENTER
	rank_box.add_theme_constant_override("separation", 6)
	_lbl_rank = UIKit.caption("")
	_lbl_rank.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rank_card_holder = Control.new()
	_rank_card_holder.custom_minimum_size = Vector2(90, 128)
	_rank_name = UIKit.label("", 14, UIKit.C_BRASS, UIKit.serif())
	_rank_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rank_box.add_child(_lbl_rank)
	rank_box.add_child(_rank_card_holder)
	rank_box.add_child(_rank_name)
	frow.add_child(rank_box)
	var pile_box := VBoxContainer.new()
	pile_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pile_box.add_theme_constant_override("separation", 6)
	_lbl_pile = UIKit.caption("")
	_pile = HBoxContainer.new()
	_pile.add_theme_constant_override("separation", 18)
	_pile.alignment = BoxContainer.ALIGNMENT_BEGIN
	_pile_empty = UIKit.label("", 13, Color(UIKit.C_PAPER, 0.5))
	pile_box.add_child(_lbl_pile)
	pile_box.add_child(_pile)
	pile_box.add_child(_pile_empty)
	frow.add_child(pile_box)
	_timer = TimerArc.new()
	_timer.position = Vector2(16 + 920 - 14 - 60, 196 + 14)
	_timer.size = Vector2(56, 56)
	_timer.visible = false
	add_child(_timer)

	# --- side panel
	var side := UIKit.panel()
	side.position = Vector2(948, 56)
	side.size = Vector2(316, 654)
	add_child(side)
	var svbox := VBoxContainer.new()
	svbox.add_theme_constant_override("separation", 6)
	side.add_child(svbox)
	_lbl_cyl = UIKit.caption("")
	svbox.add_child(_lbl_cyl)
	var cyl_center := CenterContainer.new()
	_cylinder = CylinderView.new()
	cyl_center.add_child(_cylinder)
	svbox.add_child(cyl_center)
	_odds_main = UIKit.label("", 16, UIKit.C_PAPER, UIKit.serif())
	_odds_main.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_odds_sub = UIKit.label("", 11, UIKit.C_MUTED)
	_odds_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_odds_known = UIKit.label("", 12, UIKit.C_BRASS)
	_odds_known.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	svbox.add_child(_odds_main)
	svbox.add_child(_odds_sub)
	svbox.add_child(_odds_known)
	_lbl_log = UIKit.caption("")
	svbox.add_child(_lbl_log)
	_log = RichTextLabel.new()
	_log.bbcode_enabled = true
	_log.scroll_following = true
	_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log.add_theme_font_override("normal_font", UIKit.sans())
	_log.add_theme_font_size_override("normal_font_size", 12)
	_log.add_theme_color_override("default_color", UIKit.C_PAPER_DIM)
	_log.mouse_filter = Control.MOUSE_FILTER_PASS
	svbox.add_child(_log)

	# --- player zone
	var pz := UIKit.panel()
	pz.position = Vector2(16, 454)
	pz.size = Vector2(920, 256)
	add_child(pz)
	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 6)
	pz.add_child(pv)
	var status := HBoxContainer.new()
	status.add_theme_constant_override("separation", 14)
	_player_hearts_box = HBoxContainer.new()
	status.add_child(_player_hearts_box)
	status.add_child(UIKit.spacer())
	_lbl_relics = UIKit.caption("")
	_relics = HBoxContainer.new()
	_relics.add_theme_constant_override("separation", 6)
	status.add_child(_lbl_relics)
	status.add_child(_relics)
	pv.add_child(status)
	_items = HBoxContainer.new()
	_items.add_theme_constant_override("separation", 8)
	pv.add_child(_items)
	for id in GameData.CHEAT_IDS:
		var b := ItemButton.new(id)
		b.pressed.connect(func(): cheat_pressed.emit(id))
		_item_buttons[id] = b
		_items.add_child(b)
	var hand_row := HBoxContainer.new()
	hand_row.add_theme_constant_override("separation", 12)
	_hand = Control.new()
	_hand.custom_minimum_size = Vector2(500, 128)
	_hand.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hand_row.add_child(_hand)
	var actions := VBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_END
	actions.add_theme_constant_override("separation", 8)
	actions.custom_minimum_size = Vector2(200, 0)
	_btn_play = UIKit.button("", "primary", 17)
	_btn_call = UIKit.button("", "danger", 17)
	_btn_pass = UIKit.button("", "normal", 17)
	_btn_play.pressed.connect(func(): play_pressed.emit())
	_btn_call.pressed.connect(func(): call_pressed.emit())
	_btn_pass.pressed.connect(func(): pass_pressed.emit())
	actions.add_child(_btn_call)
	actions.add_child(_btn_pass)
	actions.add_child(_btn_play)
	hand_row.add_child(actions)
	pv.add_child(hand_row)
	var hint_row := HBoxContainer.new()
	hint_row.add_theme_constant_override("separation", 10)
	_selected_label = UIKit.label("", 12, UIKit.C_BRASS)
	_hint = UIKit.label("", 13, UIKit.C_PAPER_DIM)
	_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_player_notes = UIKit.label("", 11, UIKit.C_BRASS)
	hint_row.add_child(_selected_label)
	hint_row.add_child(_hint)
	hint_row.add_child(_player_notes)
	pv.add_child(hint_row)


# ---------------------------------------------------------------------------
# Rendering
# ---------------------------------------------------------------------------

func render_static() -> void:
	_btn_lang.text = "EN" if I18n.lang() == "ko" else "한국어"
	_btn_sound.text = "♪" if Save.sound else "♪̸"
	_btn_sound.modulate = Color.WHITE if Save.sound else Color(1, 1, 1, 0.5)
	_btn_timer.text = "⏱"
	_btn_timer.modulate = Color.WHITE if Save.timer_enabled else Color(1, 1, 1, 0.5)
	_btn_play.text = I18n.t("btn.play")
	_btn_call.text = I18n.t("btn.call")
	_btn_pass.text = I18n.t("btn.pass")
	_lbl_pile.text = I18n.t("hud.pile").to_upper()
	_lbl_cyl.text = I18n.t("hud.cylinder").to_upper()
	_lbl_relics.text = I18n.t("hud.relics").to_upper()
	_lbl_log.text = I18n.t("hud.log").to_upper()
	_lbl_rank.text = I18n.t("hud.tableRank").to_upper()


func render(game: Rules) -> void:
	if game == null or game.dealer.is_empty():
		return
	var f := game.current_floor()
	_hud_floor.text = I18n.t("hud.floor", {"level": f["level"], "name": I18n.t("floor." + f["id"])})
	_hud_round.text = I18n.t("hud.round", {"n": game.round["number"]}) if not game.round.is_empty() else ""
	_hud_seed.text = "%s %s" % [I18n.t("seed.label"), game.seed_text]
	_render_dealer(game)
	_render_center(game)
	_render_side(game)
	_render_player(game)
	render_hand(game)
	render_actions(game)


func _clear(node: Node) -> void:
	for c in node.get_children():
		node.remove_child(c)
		c.queue_free()


func _render_dealer(game: Rules) -> void:
	var d := game.dealer
	_portrait.set_dealer(d["id"])
	_dealer_name.text = I18n.t("dealer.%s.name" % d["id"])
	_dealer_title.text = I18n.t("dealer.%s.title" % d["id"])
	_clear(_dealer_hearts_box)
	_dealer_hearts_box.add_child(UIKit.hearts(d["hp"], d["maxHp"]))
	_dealer_focus.text = I18n.t("hud.focus", {"focus": d["focus"]})
	var r := game.round
	var hand: Array = r["hands"]["dealer"] if not r.is_empty() else []
	var revealed: bool = (not r.is_empty()) and r["revealed"]["dealer"]
	_dealer_hand_label.text = I18n.t("hud.dealerHand", {"n": hand.size()}).to_upper()
	_clear(_dealer_hand)
	for c in hand:
		var cv := CardView.new(c["rank"], -1, true, not revealed)
		_dealer_hand.add_child(cv)
	var notes: Array = []
	if revealed:
		notes.append(I18n.t("hud.revealedDealer"))
	if not r.is_empty() and r["peekedDealerCard"] != null and not revealed:
		var still := false
		for c in hand:
			if c["id"] == r["peekedDealerCard"]["id"]:
				still = true
		if still:
			notes.append(I18n.t("hud.peeked", {"rank": I18n.rank(r["peekedDealerCard"]["rank"])}))
	_dealer_notes.text = "  ".join(notes)


func _render_center(game: Rules) -> void:
	var r := game.round
	_clear(_rank_card_holder)
	if not r.is_empty():
		var cv := CardView.new(r["tableRank"], -1, false, false)
		cv.custom_minimum_size = Vector2(90, 128)
		cv.size = Vector2(90, 128)
		_rank_card_holder.add_child(cv)
		_rank_name.text = I18n.rank(r["tableRank"])
	_clear(_pile)
	var pile: Array = r["pile"] if not r.is_empty() else []
	_pile_empty.visible = pile.is_empty()
	_pile_empty.text = I18n.t("hud.pileEmpty")
	for i in range(pile.size()):
		var p: Dictionary = pile[i]
		var entry := VBoxContainer.new()
		entry.add_theme_constant_override("separation", 4)
		entry.alignment = BoxContainer.ALIGNMENT_END
		var stack := Control.new()
		stack.custom_minimum_size = Vector2(50 + 6 * (p["cards"].size() - 1) + 6, 78)
		for k in range(p["cards"].size()):
			var cv := CardView.new("A", -1, true, true)
			cv.position = Vector2(k * 6, 6 - k * 3)
			cv.rotation = deg_to_rad(k * 4 - 4)
			stack.add_child(cv)
		entry.add_child(stack)
		var lbl := UIKit.label(I18n.t("hud.pileEntry", {"who": I18n.who(p["by"], game.dealer["id"]), "rank": I18n.rank(r["tableRank"]), "n": p["claim"]}), 11,
			UIKit.C_BRASS if p["by"] == "player" else UIKit.C_PAPER_DIM)
		entry.add_child(lbl)
		entry.modulate = Color(1, 1, 1, 1.0 if i == pile.size() - 1 else 0.6)
		_pile.add_child(entry)


func _render_side(game: Rules) -> void:
	var cyl := game.cylinder
	_cylinder.set_state(cyl["chambers"], cyl["index"], cyl["spent"], cyl["knownNext"])
	var o := game.next_chamber_odds()
	var p := int(round(o["pLive"] * 100))
	_odds_main.text = I18n.t("hud.odds", {"p": p})
	_odds_main.add_theme_color_override("font_color", UIKit.C_RED if p >= 50 else UIKit.C_PAPER)
	_odds_sub.text = I18n.t("hud.remaining", {"n": o["remaining"], "live": o["live"], "blank": o["blank"], "curse": o["curse"]})
	_odds_known.text = I18n.t("hud.known", {"bullet": I18n.t("bullet." + str(cyl["knownNext"]))}) if cyl["knownNext"] != null else ""


func _render_player(game: Rules) -> void:
	_clear(_player_hearts_box)
	_player_hearts_box.add_child(UIKit.hearts(game.player["hp"], game.player["maxHp"]))
	_clear(_relics)
	if game.player["relics"].is_empty():
		_relics.add_child(UIKit.label(I18n.t("hud.noRelics"), 12, UIKit.C_MUTED))
	for id in game.player["relics"]:
		var chip := PanelContainer.new()
		var st := UIKit.panel_style(Color(0.9, 0.75, 0.48, 0.06), UIKit.C_BRASS_DIM, 999, 1)
		st.set_content_margin_all(3)
		st.content_margin_left = 9
		st.content_margin_right = 9
		chip.add_theme_stylebox_override("panel", st)
		chip.tooltip_text = I18n.t("relic.%s.desc" % id)
		chip.mouse_filter = Control.MOUSE_FILTER_PASS
		chip.add_child(UIKit.label(I18n.t("relic.%s.name" % id), 12, UIKit.C_PAPER))
		_relics.add_child(chip)
	var la := game.legal_actions()
	for id in GameData.CHEAT_IDS:
		var b: ItemButton = _item_buttons[id]
		var n: int = game.player["items"][id]
		var pct := int(round(game.cheat_detect_chance(id) * 100))
		b.update_view(I18n.t("item.%s.name" % id), n, pct, la["cheats"].has(id), I18n.t("item.%s.desc" % id))
	var notes: Array = []
	var r := game.round
	if not r.is_empty() and r["revealed"]["player"]:
		notes.append(I18n.t("hud.revealedYou"))
	if not r.is_empty() and r["pact"] != null and r["pact"]["by"] == "player":
		notes.append(I18n.t("hud.pactArmed"))
	_player_notes.text = "  ".join(notes)


func render_hand(game: Rules) -> void:
	_clear(_hand)
	_hand_cards.clear()
	var r := game.round
	if r.is_empty():
		return
	var hand: Array = r["hands"]["player"]
	var la := game.legal_actions()
	var can_select: bool = la["play"] or la["cheats"].has("bottomDeal")
	var x := 0.0
	for c in hand:
		var cv := CardView.new(c["rank"], c["id"], false, false)
		cv.selectable = can_select
		cv.position = Vector2(x, 16)
		cv.remember_base()
		cv.selected = selected.has(c["id"])
		if cv.selected:
			cv.position.y -= 14
		cv.toggled.connect(func(id): card_toggled.emit(id))
		_hand.add_child(cv)
		_hand_cards.append(cv)
		x += CardView.W + 10
	_selected_label.text = I18n.t("hud.selected", {"n": selected.size()}) if hand.size() > 0 else ""


func render_actions(game: Rules) -> void:
	var la := game.legal_actions()
	var r := game.round
	# Show the button set the player will actually use next, so the dealer's
	# turn keeps the same (disabled) buttons instead of stacking all three.
	var respond_side := false
	if not r.is_empty() and game.phase == Rules.PHASE_ROUND:
		var mine: bool = r["turn"] == "player"
		respond_side = (r["phase"] == "respond") == mine
	_btn_play.visible = not respond_side
	_btn_call.visible = respond_side
	_btn_pass.visible = respond_side
	_btn_play.disabled = not la["play"] or selected.is_empty()
	_btn_call.disabled = not la["call"]
	_btn_pass.disabled = not la["pass"]
	if r.is_empty() or game.phase != Rules.PHASE_ROUND:
		set_hint("")
		return
	if r["turn"] != "player":
		return
	if la["play"]:
		set_hint(I18n.t("hint.yourPlay", {"rank": I18n.rank(r["tableRank"])}))
	elif la["call"] and not la["pass"]:
		set_hint(I18n.t("hint.mustCall"))
	else:
		set_hint(I18n.t("hint.yourRespond", {"rank": I18n.rank(r["tableRank"]), "n": r["lastPlay"]["claim"]}))


func set_hint(text: String, transient := false) -> void:
	_hint.text = text
	_hint.add_theme_color_override("font_color", UIKit.C_BRASS if transient else UIKit.C_PAPER_DIM)


func set_speech(text: String, thinking := false) -> void:
	_speech.visible = text != ""
	_speech_label.text = text
	_speech.modulate = Color(1, 1, 1, 0.75 if thinking else 1.0)


func push_log(text: String, cls: String = "sys") -> void:
	var col := "#c8b89a"
	match cls:
		"player":
			col = "#e5c07b"
		"dealer":
			col = "#d7c4b0"
		"danger":
			col = "#ff8a80"
		"sys":
			col = "#8f8577"
	_log_lines.append("[color=%s]%s[/color]" % [col, text.replace("[", "［").replace("]", "］")])
	if _log_lines.size() > 80:
		_log_lines.pop_front()
	_log.text = "\n".join(_log_lines)


func clear_log() -> void:
	_log_lines.clear()
	_log.text = ""


func show_timer(seconds_left: float, total: float) -> void:
	_timer.visible = true
	_timer.set_progress(seconds_left, total)


func hide_timer() -> void:
	_timer.visible = false


# ---------------------------------------------------------------------------
# Helper controls
# ---------------------------------------------------------------------------

class ItemButton extends Button:
	var cheat_id: String
	var _name_label: Label
	var _meta_label: Label

	func _init(id: String) -> void:
		cheat_id = id
		focus_mode = Control.FOCUS_NONE
		custom_minimum_size = Vector2(210, 44)
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var st := StyleBoxFlat.new()
		st.bg_color = Color(0, 0, 0, 0.35)
		st.border_color = UIKit.C_PANEL_EDGE
		st.set_border_width_all(1)
		st.set_corner_radius_all(8)
		st.set_content_margin_all(6)
		add_theme_stylebox_override("normal", st)
		var hv := st.duplicate()
		hv.border_color = UIKit.C_BRASS
		add_theme_stylebox_override("hover", hv)
		add_theme_stylebox_override("pressed", hv)
		var dis := st.duplicate()
		dis.bg_color = Color(0, 0, 0, 0.2)
		add_theme_stylebox_override("disabled", dis)
		add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		var v := VBoxContainer.new()
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_theme_constant_override("separation", 0)
		_name_label = UIKit.label("", 13, UIKit.C_PAPER, UIKit.sans_bold())
		_meta_label = UIKit.label("", 11, UIKit.C_MUTED)
		v.add_child(_name_label)
		v.add_child(_meta_label)
		add_child(v)
		v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		v.offset_left = 34
		v.offset_top = 3
		var icon := ColorRect.new()
		icon.size = Vector2(20, 20)
		icon.position = Vector2(8, 12)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.color = {"mirror": Color("8fa8b3"), "bottomDeal": Color("b0413e"), "leadWeight": Color("6e6e6e"), "pact": Color("7a1f1f")}[id]
		add_child(icon)

	func update_view(name_text: String, charges: int, detect_pct: int, usable: bool, desc: String) -> void:
		_name_label.text = name_text
		var det := I18n.t("item.detect", {"p": detect_pct}) if detect_pct > 0 else I18n.t("item.detectNone")
		_meta_label.text = "×%d · %s" % [charges, det]
		disabled = not usable
		modulate = Color(1, 1, 1, 0.45 if charges == 0 else (1.0 if usable else 0.6))
		tooltip_text = desc


class TimerArc extends Control:
	var _p := 1.0
	var _text := "15"
	var _urgent := false

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_progress(left: float, total: float) -> void:
		_p = clampf(left / total, 0.0, 1.0)
		_text = str(int(ceil(left)))
		_urgent = left <= 5.0
		queue_redraw()

	func _draw() -> void:
		var c := size / 2.0
		var r := minf(size.x, size.y) / 2.0 - 3.0
		draw_arc(c, r, 0, TAU, 48, Color(0, 0, 0, 0.35), 5.0, true)
		if _p > 0.0:
			draw_arc(c, r, -PI / 2, -PI / 2 + TAU * _p, 48, UIKit.C_BLOOD if _urgent else UIKit.C_BRASS, 5.0, true)
		draw_string(UIKit.serif(), Vector2(0, c.y + 7), _text, HORIZONTAL_ALIGNMENT_CENTER, size.x, 20, Color("ff6b6b") if _urgent else UIKit.C_PAPER)


class RadialGlow extends Control:
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := Vector2(size.x * 0.5, size.y * 0.2)
		for i in range(12):
			var t := float(i) / 12.0
			draw_circle(c, 700.0 * (1.0 - t) + 40.0, Color(0.16, 0.08, 0.08, 0.06))
