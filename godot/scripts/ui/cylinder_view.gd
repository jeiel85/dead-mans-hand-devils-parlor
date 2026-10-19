class_name CylinderView
extends Control
## Six-chamber revolver cylinder. The next chamber sits at 12 o'clock; spent
## chambers show what they fired (colour + glyph, colour-blind safe).
##
## This is the object the whole game is about, so it gets metal treatment: a
## bevelled rim lit from above, chambers bored into the face rather than
## painted on, and a glow under the chamber that is about to fire.

var chambers: Array = []
var index := 0
var spent: Array = []
var known_next: Variant = null
var _rot := 0.0
var _target_rot := 0.0


func _init() -> void:
	custom_minimum_size = Vector2(150, 150)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_state(p_chambers: Array, p_index: int, p_spent: Array, p_known: Variant, animate := true) -> void:
	chambers = p_chambers
	spent = p_spent
	known_next = p_known
	var n := maxi(1, chambers.size())
	var new_target := -float(p_index) / n * TAU
	if p_index < index:
		# reload: spin a full extra turn for the feel of it
		_rot += TAU
	index = p_index
	_target_rot = new_target
	if animate:
		var t := create_tween()
		t.tween_method(_set_rot, _rot, _target_rot, 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	else:
		_set_rot(_target_rot)


func _set_rot(v: float) -> void:
	_rot = v
	queue_redraw()


func _draw() -> void:
	var c := size / 2.0
	var R := minf(size.x, size.y) / 2.0 - 7.0
	var k := R / 68.0  # stroke widths follow the control's size

	# The cylinder sits on the panel: cast shadow, then the body.
	draw_circle(c + Vector2(0, 3) * k, R + 1.5, Color(0, 0, 0, 0.45))
	draw_circle(c, R, Color("1a1512"))
	draw_circle(c, R * 0.955, Color("2b231e"))
	draw_circle(c, R * 0.90, Color("221b17"))

	# Bevel: light along the top-left rim, shadow along the bottom-right.
	draw_arc(c, R - 1.5 * k, PI * 1.02, PI * 1.98, 64, Color(1.0, 0.94, 0.82, 0.13), 2.0 * k, true)
	draw_arc(c, R - 1.5 * k, PI * 0.04, PI * 0.96, 64, Color(0, 0, 0, 0.5), 2.0 * k, true)
	draw_arc(c, R, 0, TAU, 96, Color("6b5a48"), 2.4 * k, true)
	draw_arc(c, R - 2.2 * k, 0, TAU, 96, Color("8d7757"), 1.0 * k, true)

	# Centre pin.
	draw_circle(c, R * 0.17, Color("0d0a09"))
	draw_arc(c, R * 0.17, 0, TAU, 40, Color("6b5a48"), 1.8 * k, true)
	draw_circle(c, R * 0.055, Color("4a3d31"))
	# Tool marks: a few faint concentric rings on the face.
	draw_arc(c, R * 0.42, 0, TAU, 72, Color(1, 1, 1, 0.025), 1.0 * k, true)
	draw_arc(c, R * 0.72, 0, TAU, 72, Color(0, 0, 0, 0.10), 1.0 * k, true)

	var n := chambers.size()
	if n == 0:
		_draw_pointer(c, R, k)
		return
	var ring := R * 0.60
	var rad := R * 0.185
	for i in range(n):
		var ang := float(i) / n * TAU - PI / 2 + _rot
		var p := c + Vector2(cos(ang), sin(ang)) * ring
		var is_spent := i < index
		var is_next := i == index
		var fill := Color("0e0b0a")
		var glyph := ""
		var glyph_col := Color("bbbbbb")

		if is_spent and i < spent.size():
			match spent[i]:
				"live":
					fill = Color("6d1a1a")
					glyph = "●"
					glyph_col = Color("f5d5d5")
				"curse":
					fill = Color("3f2459")
					glyph = "◆"
					glyph_col = Color("e0c8ff")
				_:
					fill = Color("2e2a26")
					glyph = "○"
		elif is_next and known_next != null:
			match known_next:
				"live":
					fill = Color("a12626")
					glyph = "●"
				"curse":
					fill = Color("6a3a9a")
					glyph = "◆"
				_:
					fill = Color("4e4a44")
					glyph = "○"
			glyph_col = Color.WHITE

		# Glow under the chamber that is about to fire.
		if is_next:
			for g in range(5):
				draw_circle(p, rad * (1.7 - 0.16 * g), Color(UIKit.C_BRASS, 0.05))

		# Bore: rim shadow, hole, then a highlight on the near edge.
		draw_circle(p, rad * 1.10, Color(0, 0, 0, 0.55))
		draw_circle(p, rad, fill)
		draw_arc(p, rad, PI * 0.05, PI * 0.95, 24, Color(0, 0, 0, 0.45), 2.0 * k, true)
		draw_arc(p, rad, PI * 1.05, PI * 1.95, 24, Color(1, 1, 1, 0.10), 1.4 * k, true)
		draw_arc(p, rad, 0, TAU, 40,
			UIKit.C_BRASS if is_next else Color("5a4a3a"), (2.4 if is_next else 1.4) * k, true)
		if glyph != "":
			draw_string(UIKit.sans(), p + Vector2(-rad, 4.5 * k), glyph,
				HORIZONTAL_ALIGNMENT_CENTER, rad * 2, 12 * k, glyph_col)
	_draw_pointer(c, R, k)


## The brass index mark at 12 o'clock, sitting on the rim.
func _draw_pointer(c: Vector2, R: float, k: float) -> void:
	var tip := c + Vector2(0, -R - 3.0 * k)
	draw_colored_polygon(PackedVector2Array([
		tip + Vector2(-6, -9) * k, tip + Vector2(6, -9) * k, tip + Vector2(0, 3) * k,
	]), UIKit.C_BRASS)
	draw_line(tip + Vector2(-6, -9) * k, tip + Vector2(0, 3) * k, Color(0, 0, 0, 0.35), 1.0 * k)
