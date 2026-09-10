class_name CylinderView
extends Control
## Six-chamber revolver cylinder. The next chamber sits at 12 o'clock; spent
## chambers show what they fired (colour + glyph, colour-blind safe).

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
	var R := minf(size.x, size.y) / 2.0 - 6.0
	draw_circle(c, R, Color("231d1a"))
	draw_arc(c, R, 0, TAU, 64, Color("6b5a48"), 3.0, true)
	draw_circle(c, R * 0.15, Color("0f0c0b"))
	draw_arc(c, R * 0.15, 0, TAU, 32, Color("6b5a48"), 2.0, true)
	var n := chambers.size()
	if n == 0:
		return
	var ring := R * 0.62
	var rad := R * 0.2
	for i in range(n):
		var ang := float(i) / n * TAU - PI / 2 + _rot
		var p := c + Vector2(cos(ang), sin(ang)) * ring
		var is_spent := i < index
		var is_next := i == index
		var fill := Color("1b1614")
		var glyph := ""
		var glyph_col := Color("bbbbbb")
		if is_spent and i < spent.size():
			match spent[i]:
				"live":
					fill = Color("7a1f1f")
					glyph = "●"
					glyph_col = Color("f5d5d5")
				"curse":
					fill = Color("4a2a6a")
					glyph = "✦"
					glyph_col = Color("e0c8ff")
				_:
					fill = Color("3a3632")
					glyph = "○"
		elif is_next and known_next != null:
			match known_next:
				"live":
					fill = Color("a12626")
					glyph = "●"
				"curse":
					fill = Color("6a3a9a")
					glyph = "✦"
				_:
					fill = Color("5a5650")
					glyph = "○"
			glyph_col = Color.WHITE
		draw_circle(p, rad, fill)
		draw_arc(p, rad, 0, TAU, 32, UIKit.C_BRASS if is_next else Color("5a4a3a"), 2.5 if is_next else 1.5, true)
		if glyph != "":
			draw_string(UIKit.sans(), p + Vector2(-rad, 5), glyph, HORIZONTAL_ALIGNMENT_CENTER, rad * 2, 13, glyph_col)
	# pointer at 12 o'clock
	var tip := c + Vector2(0, -R - 2)
	draw_colored_polygon(PackedVector2Array([tip + Vector2(-6, -8), tip + Vector2(6, -8), tip + Vector2(0, 2)]), UIKit.C_BRASS)
