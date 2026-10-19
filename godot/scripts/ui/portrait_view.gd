class_name PortraitView
extends Control
## Stylised dealer bust drawn with primitives (same themes as the web prototype).
##
## The portrait is the only face in the game, so it carries most of the mood.
## Three cheap layers do the work: a lit background arc behind the head, a
## shadow pass under the features, and a rim light on one side. Without them a
## flat ellipse reads as a smiley, not as someone deciding whether to call you.

var dealer_id := "jack"
var _blink := 0.0

const THEMES := {
	"jack": {"skin": "c9a27c", "coat": "4a3b2a", "hat": "cap", "eye": "f2c14e", "extra": "bottle"},
	"martha": {"skin": "d9b08c", "coat": "5b1f2a", "hat": "wide", "eye": "e86f51", "extra": "none"},
	"dominic": {"skin": "b98b6a", "coat": "1f2a3a", "hat": "bowler", "eye": "7ec8e3", "extra": "glasses"},
	"ida": {"skin": "e0c3a6", "coat": "2b2b2b", "hat": "none", "eye": "ffd166", "extra": "monocle"},
	"bela": {"skin": "e8cbb8", "coat": "f0e6dc", "hat": "nurse", "eye": "c1121f", "extra": "none"},
	"grimm": {"skin": "cbb3a0", "coat": "0f0f12", "hat": "wig", "eye": "e5e5e5", "extra": "none"},
	"devil": {"skin": "7a1e1e", "coat": "120608", "hat": "horns", "eye": "ffb703", "extra": "smile"},
}


func _init() -> void:
	custom_minimum_size = Vector2(100, 110)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	set_process(true)


func _process(delta: float) -> void:
	_blink += delta
	if _blink > 4.6:
		_blink = 0.0
	if _blink < 0.2 or (_blink > 4.3 and _blink < 4.5):
		queue_redraw()


func set_dealer(id: String) -> void:
	dealer_id = id
	queue_redraw()


func _draw() -> void:
	var th: Dictionary = THEMES.get(dealer_id, THEMES["jack"])
	var s := size.x / 100.0
	var skin := Color(th["skin"])
	var coat := Color(th["coat"])
	var eye := Color(th["eye"])
	var shade := skin.darkened(0.32)

	draw_rect(Rect2(Vector2.ZERO, size), Color("0a0606"))
	# Light behind the head: the dealer sits in a pool of it.
	for i in range(9):
		var t := float(i) / 9.0
		draw_circle(Vector2(50, 42) * s, (50.0 - 3.0 * i) * s, Color(eye, 0.028))
	draw_arc(Vector2(50, 46) * s, 42 * s, PI * 1.06, PI * 1.94, 32, Color(1, 0.95, 0.85, 0.05), 1.0, true)

	# Shoulders, then the shirt and lapels that break up the silhouette.
	draw_colored_polygon(PackedVector2Array([Vector2(8, 110) * s, Vector2(19, 82) * s,
		Vector2(50, 74) * s, Vector2(81, 82) * s, Vector2(92, 110) * s]), coat)
	draw_colored_polygon(PackedVector2Array([Vector2(41, 76) * s, Vector2(59, 76) * s,
		Vector2(55, 92) * s, Vector2(45, 92) * s]), Color("d8cbb8"))
	draw_colored_polygon(PackedVector2Array([Vector2(41, 76) * s, Vector2(30, 82) * s,
		Vector2(38, 110) * s, Vector2(45, 92) * s]), coat.lightened(0.10))
	draw_colored_polygon(PackedVector2Array([Vector2(59, 76) * s, Vector2(70, 82) * s,
		Vector2(62, 110) * s, Vector2(55, 92) * s]), coat.darkened(0.12))
	draw_rect(Rect2(Vector2(42, 68) * s, Vector2(16, 12) * s), shade)
	draw_rect(Rect2(Vector2(43, 68) * s, Vector2(14, 9) * s), skin)

	# Head: shadow pass first, then the lit pass slightly up-left of it.
	var head_c := Vector2(50, 54) * s
	_ellipse(head_c + Vector2(2.5, 2.0) * s, 21.5 * s, 25.0 * s, shade)
	_ellipse(head_c, 21.0 * s, 24.5 * s, skin)
	# Rim light down the right cheek and jaw.
	draw_arc(head_c + Vector2(1.0, 1.0) * s, 20.0 * s, -PI * 0.42, PI * 0.30, 24,
		Color(1.0, 0.93, 0.80, 0.22), 2.0 * maxf(1.0, s), true)
	# Jaw shadow under the cheekbones.
	_ellipse(Vector2(50, 64) * s, 15.0 * s, 7.0 * s, Color(shade, 0.35))

	# Eyes: sockets, then a lit iris. At 96 px a sclera-and-pupil eye turns into
	# a pair of spectacles, so the eye is a glow inside a shadow instead.
	var open := 1.0
	if _blink > 4.3 and _blink < 4.5:
		open = 0.12
	for ex in [41.5, 58.5]:
		var ec := Vector2(ex, 56) * s
		_ellipse(ec, 5.4 * s, 3.4 * s * open, Color(shade, 0.55))
		if open > 0.5:
			draw_circle(ec, 3.4 * s, Color(eye, 0.16))
			_ellipse(ec, 2.2 * s, 2.4 * s, eye)
			_ellipse(ec, 1.0 * s, 1.2 * s, Color("120a08"))
			draw_circle(ec + Vector2(-0.7, -0.8) * s, 0.55 * s, Color(1, 1, 1, 0.75))
	# Nose and mouth.
	draw_line(Vector2(50, 59) * s, Vector2(49, 63) * s, Color(shade, 0.55), 1.2 * maxf(1.0, s))
	draw_line(Vector2(46.5, 67) * s, Vector2(53.5, 67) * s, Color(shade, 0.7), 1.4 * maxf(1.0, s))

	match th["hat"]:
		"cap":
			draw_colored_polygon(PackedVector2Array([Vector2(21, 38) * s, Vector2(36, 25) * s,
				Vector2(64, 25) * s, Vector2(79, 38) * s, Vector2(79, 44) * s, Vector2(21, 44) * s]), Color("2e2a24"))
			draw_line(Vector2(21, 44) * s, Vector2(79, 44) * s, Color(0, 0, 0, 0.35), 1.5 * maxf(1.0, s))
		"wide":
			_ellipse(Vector2(50, 39) * s, 41 * s, 7.5 * s, Color("2a1216"))
			draw_colored_polygon(PackedVector2Array([Vector2(29, 39) * s, Vector2(36, 19) * s,
				Vector2(64, 19) * s, Vector2(71, 39) * s]), Color("3b1a20"))
			draw_line(Vector2(29, 39) * s, Vector2(71, 39) * s, Color("1a0a0e"), 2.0 * maxf(1.0, s))
		"bowler":
			_ellipse(Vector2(50, 41) * s, 35 * s, 6 * s, Color("0d0d0d"))
			draw_colored_polygon(PackedVector2Array([Vector2(29, 41) * s, Vector2(34, 17) * s,
				Vector2(66, 17) * s, Vector2(71, 41) * s]), Color("181818"))
			draw_line(Vector2(30, 33) * s, Vector2(70, 33) * s, Color(1, 1, 1, 0.08), 3.0 * maxf(1.0, s))
		"nurse":
			draw_rect(Rect2(Vector2(34, 25) * s, Vector2(32, 12) * s), Color("f4efe6"))
			draw_rect(Rect2(Vector2(47, 27) * s, Vector2(6, 8) * s), Color("c1121f"))
			draw_rect(Rect2(Vector2(44, 30) * s, Vector2(12, 2) * s), Color("c1121f"))
		"wig":
			draw_colored_polygon(PackedVector2Array([Vector2(22, 44) * s, Vector2(30, 20) * s,
				Vector2(50, 13) * s, Vector2(70, 20) * s, Vector2(78, 44) * s, Vector2(72, 50) * s,
				Vector2(50, 40) * s, Vector2(28, 50) * s]), Color("dcdcdc"))
			draw_line(Vector2(28, 44) * s, Vector2(72, 44) * s, Color(0, 0, 0, 0.15), 1.0 * maxf(1.0, s))
		"horns":
			draw_colored_polygon(PackedVector2Array([Vector2(30, 40) * s, Vector2(22, 22) * s,
				Vector2(34, 10) * s, Vector2(34, 26) * s, Vector2(40, 36) * s]), Color("3a0a0a"))
			draw_colored_polygon(PackedVector2Array([Vector2(70, 40) * s, Vector2(78, 22) * s,
				Vector2(66, 10) * s, Vector2(66, 26) * s, Vector2(60, 36) * s]), Color("3a0a0a"))
	match th["extra"]:
		"bottle":
			draw_rect(Rect2(Vector2(78, 70) * s, Vector2(8, 22) * s), Color("4c7a3a"))
			draw_rect(Rect2(Vector2(80, 66) * s, Vector2(4, 5) * s), Color("4c7a3a").darkened(0.3))
			draw_line(Vector2(78, 78) * s, Vector2(86, 78) * s, Color(1, 1, 1, 0.18), 1.0 * maxf(1.0, s))
		"glasses":
			draw_arc(Vector2(41, 56) * s, 7 * s, 0, TAU, 24, Color("cccccc"), 1.6 * maxf(1.0, s), true)
			draw_arc(Vector2(59, 56) * s, 7 * s, 0, TAU, 24, Color("cccccc"), 1.6 * maxf(1.0, s), true)
			draw_line(Vector2(48, 56) * s, Vector2(52, 56) * s, Color("cccccc"), 1.4 * maxf(1.0, s))
		"monocle":
			draw_arc(Vector2(60, 56) * s, 8 * s, 0, TAU, 24, Color("e5c07b"), 1.8 * maxf(1.0, s), true)
			draw_line(Vector2(66, 62) * s, Vector2(72, 80) * s, Color("e5c07b"), 1.2 * maxf(1.0, s))
		"smile":
			draw_arc(Vector2(50, 66) * s, 11 * s, 0.12 * PI, 0.88 * PI, 20, Color("ffb703"), 2.0 * maxf(1.0, s), true)


func _ellipse(c: Vector2, rx: float, ry: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in range(28):
		var a := float(i) / 28.0 * TAU
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	draw_colored_polygon(pts, col)
