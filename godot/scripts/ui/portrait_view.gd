class_name PortraitView
extends Control
## Stylised dealer silhouette drawn with primitives (same themes as the web prototype).

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
	draw_rect(Rect2(Vector2.ZERO, size), Color("0a0606"))
	# glow
	draw_circle(Vector2(50, 44) * s, 46 * s, Color(eye, 0.12))
	# shoulders
	draw_colored_polygon(PackedVector2Array([Vector2(14, 110) * s, Vector2(22, 84) * s, Vector2(50, 78) * s, Vector2(78, 84) * s, Vector2(86, 110) * s]), coat)
	draw_rect(Rect2(Vector2(42, 70) * s, Vector2(16, 12) * s), skin)
	# head
	var head_c := Vector2(50, 56) * s
	_ellipse(head_c, 22 * s, 26 * s, skin)
	# eyes (blink)
	var ry := 2.2 * s
	if _blink > 4.3 and _blink < 4.5:
		ry = 0.4 * s
	_ellipse(Vector2(41, 58) * s, 3.5 * s, ry, eye)
	_ellipse(Vector2(59, 58) * s, 3.5 * s, ry, eye)
	match th["hat"]:
		"cap":
			draw_colored_polygon(PackedVector2Array([Vector2(22, 38) * s, Vector2(36, 26) * s, Vector2(64, 26) * s, Vector2(78, 38) * s, Vector2(78, 44) * s, Vector2(22, 44) * s]), Color("2e2a24"))
		"wide":
			_ellipse(Vector2(50, 40) * s, 40 * s, 8 * s, Color("2a1216"))
			draw_colored_polygon(PackedVector2Array([Vector2(28, 40) * s, Vector2(36, 20) * s, Vector2(64, 20) * s, Vector2(72, 40) * s]), Color("3b1a20"))
		"bowler":
			_ellipse(Vector2(50, 42) * s, 34 * s, 6 * s, Color("111111"))
			draw_colored_polygon(PackedVector2Array([Vector2(28, 42) * s, Vector2(34, 18) * s, Vector2(66, 18) * s, Vector2(72, 42) * s]), Color("181818"))
		"nurse":
			draw_rect(Rect2(Vector2(34, 26) * s, Vector2(32, 12) * s), Color.WHITE)
			draw_rect(Rect2(Vector2(47, 28) * s, Vector2(6, 8) * s), Color("c1121f"))
			draw_rect(Rect2(Vector2(44, 31) * s, Vector2(12, 2) * s), Color("c1121f"))
		"wig":
			draw_colored_polygon(PackedVector2Array([Vector2(22, 44) * s, Vector2(30, 20) * s, Vector2(50, 14) * s, Vector2(70, 20) * s, Vector2(78, 44) * s, Vector2(72, 50) * s, Vector2(50, 40) * s, Vector2(28, 50) * s]), Color("dcdcdc"))
		"horns":
			draw_colored_polygon(PackedVector2Array([Vector2(30, 40) * s, Vector2(22, 22) * s, Vector2(34, 10) * s, Vector2(34, 26) * s, Vector2(40, 36) * s]), Color("3a0a0a"))
			draw_colored_polygon(PackedVector2Array([Vector2(70, 40) * s, Vector2(78, 22) * s, Vector2(66, 10) * s, Vector2(66, 26) * s, Vector2(60, 36) * s]), Color("3a0a0a"))
	match th["extra"]:
		"bottle":
			draw_rect(Rect2(Vector2(78, 70) * s, Vector2(8, 22) * s), Color("4c7a3a"))
		"glasses":
			draw_arc(Vector2(40, 58) * s, 7 * s, 0, TAU, 24, Color("cccccc"), 2.0, true)
			draw_arc(Vector2(60, 58) * s, 7 * s, 0, TAU, 24, Color("cccccc"), 2.0, true)
			draw_line(Vector2(47, 58) * s, Vector2(53, 58) * s, Color("cccccc"), 2.0)
		"monocle":
			draw_arc(Vector2(61, 58) * s, 8 * s, 0, TAU, 24, Color("e5c07b"), 2.0, true)
			draw_line(Vector2(66, 64) * s, Vector2(72, 80) * s, Color("e5c07b"), 1.5)
		"smile":
			draw_arc(Vector2(50, 70) * s, 12 * s, 0.15 * PI, 0.85 * PI, 16, Color("ffb703"), 2.5, true)


func _ellipse(c: Vector2, rx: float, ry: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in range(28):
		var a := float(i) / 28.0 * TAU
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	draw_colored_polygon(pts, col)
