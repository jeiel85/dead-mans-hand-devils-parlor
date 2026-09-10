extends Node
## Renders the main screens and saves PNGs (visual check + README assets).
## Run: godot --path godot res://test/screenshot.tscn  (needs a window; not --headless)

const OUT := "res://../build/shots"


func _ready() -> void:
	# The game ships with low-processor mode (redraw only on change); the runner
	# awaits frame_post_draw, so force continuous redraws while capturing.
	OS.low_processor_usage_mode = false
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	await _run()
	get_tree().quit()


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


func _center(c: Control) -> Vector2:
	return c.get_global_rect().get_center()


func _click(pos: Vector2) -> void:
	var mv := InputEventMouseMotion.new()
	mv.position = pos
	mv.global_position = pos
	get_viewport().push_input(mv)
	await get_tree().process_frame
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.position = pos
		ev.global_position = pos
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = pressed
		get_viewport().push_input(ev)
		await get_tree().process_frame
	print("click at ", pos)


func _key(code: Key) -> void:
	for pressed in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = code
		ev.physical_keycode = code
		ev.pressed = pressed
		get_viewport().push_input(ev)
		await get_tree().process_frame
	print("key ", code)


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path(OUT + "/" + name))
	print("shot: " + name)


func _run() -> void:
	var main: Control = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _wait(0.6)
	await _shot("01-title.png")
	main.start_run("DEMO01")
	await _wait(0.5)
	await _shot("02-floor-intro.png")
	main.modal.close()
	main.game.begin_round()
	main.after_engine_step()
	await _wait(0.8)
	await _shot("03-table.png")
	# select two cards and play them, then let the dealer respond
	# Drive the real input path (mouse picking -> CardView._gui_input -> main.toggle_select)
	await _click(_center(main.table._hand_cards[0]))
	await _click(_center(main.table._hand_cards[1]))
	await _wait(0.3)
	assert(main.selected.size() == 2, "card clicks must select 2 cards (got %d)" % main.selected.size())
	await _shot("04-selected.png")
	await _click(_center(main.table._btn_play))
	await _wait(2.2)
	await _shot("05-after-dealer.png")
	# force a reveal: if it's our respond phase, call; otherwise wait
	var guard := 0
	while (main.game.phase == Rules.PHASE_ROUND and main.game.round["turn"] != "player") and guard < 20:
		await _wait(0.5)
		guard += 1
	if main.game.phase == Rules.PHASE_ROUND and main.game.round["phase"] == "respond":
		main.on_respond("call")
		await _wait(1.4)
		# Wait for the reveal to finish animating (continue button armed).
		var waited := 0.0
		while not main._reveal_ready and waited < 6.0:
			await _wait(0.1)
			waited += 0.1
		assert(main._reveal_ready, "reveal must arm its continue button")
		await _shot("06-reveal.png")
		# Dismiss the reveal with the real keyboard path (_unhandled_input).
		await _key(KEY_ENTER)
		await _wait(0.4)
		assert(not main.modal.visible, "Enter must dismiss the reveal modal")
		await _wait(0.8)
	main.show_help()
	await _wait(0.3)
	await _shot("07-help.png")
	main.modal.close()
	# fabricate a reward screen for the shot
	main.game.phase = Rules.PHASE_REWARD
	main.game.rewards = [{"kind": "heal", "id": "heal"}, {"kind": "relic", "id": "hipFlask"}, {"kind": "item", "id": "mirror"}]
	main.show_reward()
	await _wait(0.3)
	await _shot("08-reward.png")

	# Taking a reward must actually move the run to the next floor and show that
	# floor's dealer, not just close the modal.
	var before: int = main.game.current_floor()["level"]
	await _click(_center(main.reward_buttons[0]))
	await _wait(1.2)
	assert(main.game.phase == Rules.PHASE_FLOOR_INTRO,
		"choosing a reward must lead to the next floor intro (phase %s)" % main.game.phase)
	var after: int = main.game.current_floor()["level"]
	assert(after == before + 1, "floor must advance %d -> %d (got %d)" % [before, before + 1, after])
	assert(main.modal.kind == "intro", "the next floor intro must be on screen")
	await _shot("09-next-floor.png")
	main.modal.close()

	# End screens. Both are terminal states a normal run reaches rarely, so they
	# are driven directly rather than played out.
	main.game.phase = Rules.PHASE_GAME_OVER
	main.show_game_over()
	await _wait(0.3)
	assert(main.modal.visible and main.modal.kind == "over", "game over screen must open")
	await _shot("10-game-over.png")
	main.modal.close()

	main.game.phase = Rules.PHASE_VICTORY
	main.show_victory()
	await _wait(0.3)
	assert(main.modal.visible and main.modal.kind == "win", "victory screen must open")
	await _shot("11-victory.png")

	# Back to the title: the run must be torn down, not left half-running.
	main.show_title()
	await _wait(0.5)
	assert(main.modal.kind == "title", "title screen must come back")
	assert(not main.busy, "abandoning a run must clear the busy flag")
	await _shot("12-title-return.png")
	print("screenshots done")
