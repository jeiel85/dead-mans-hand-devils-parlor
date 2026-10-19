class_name CardView
extends Control
## A playing card drawn procedurally. Click to toggle selection when selectable.
##
## There are no image assets in this project, so the card has to earn its keep
## from geometry alone: a cast shadow so it sits on the felt, a paper edge, an
## inner hairline like a real deck's border, and a corner index you can read at
## a glance. The back gets the same treatment in red and brass.

signal toggled(card_id: int)

var card_id: int = -1
var rank: String = "A"
var face_down := false
var selected := false
var selectable := false
var small := false
var _hover := false
var _base_y := 0.0

const W := 78.0
const H := 110.0
const SW := 50.0
const SH := 70.0

const C_PAPER := Color("efe3c8")
const C_INK := Color("1a1410")
const C_BRASS := Color("e5c07b")


func _init(p_rank: String = "A", p_id: int = -1, p_small := false, p_face_down := false,
		p_size: Vector2 = Vector2.ZERO) -> void:
	rank = p_rank
	card_id = p_id
	small = p_small
	face_down = p_face_down
	# The compact layout draws smaller cards; W/H stay the wide-layout defaults.
	if p_size != Vector2.ZERO:
		custom_minimum_size = p_size
	else:
		custom_minimum_size = Vector2(SW, SH) if small else Vector2(W, H)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_entered.connect(func(): _hover = true; queue_redraw())
	mouse_exited.connect(func(): _hover = false; queue_redraw())


func _gui_input(event: InputEvent) -> void:
	if not selectable:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		toggled.emit(card_id)
		accept_event()


func set_selected(v: bool) -> void:
	if selected == v:
		return
	selected = v
	var t := create_tween()
	t.tween_property(self, "position:y", _base_y - (14.0 if v else 0.0), 0.12).set_trans(Tween.TRANS_QUAD)
	queue_redraw()


func remember_base() -> void:
	_base_y = position.y


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var radius := 5.0 if small else 7.0
	_draw_shadow(r, radius)
	if face_down:
		_draw_back(r, radius)
	else:
		_draw_face(r, radius)


## A soft drop shadow, offset down-right. Drawn outside the card rect on
## purpose: a card lying on cloth has to cast something.
func _draw_shadow(r: Rect2, radius: float) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.38 if not small else 0.28)
	sb.set_corner_radius_all(int(radius) + 1)
	draw_style_box(sb, Rect2(r.position + Vector2(1.5, 2.5), r.size))


func _draw_face(r: Rect2, radius: float) -> void:
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(int(radius))
	sb.bg_color = C_PAPER if rank != "J" else Color("f0e2c6")
	sb.border_color = C_BRASS if selected else Color(0, 0, 0, 0.16)
	sb.set_border_width_all(3 if selected else 1)
	draw_style_box(sb, r)

	# Paper: a lighter band at the top so the card has a grain direction.
	var hi := r.grow(-1.0)
	hi.size.y *= 0.34
	draw_rect(hi, Color(1, 1, 1, 0.22))

	# Inner hairline, the border printed on a real deck.
	var inner := r.grow(-(3.0 if small else 4.0))
	if inner.size.x > 6.0 and inner.size.y > 6.0:
		var line := StyleBoxFlat.new()
		line.bg_color = Color(0, 0, 0, 0)
		line.border_color = Color(C_INK, 0.13)
		line.set_border_width_all(1)
		line.set_corner_radius_all(int(maxf(2.0, radius - 2.0)))
		draw_style_box(line, inner)

	if _hover and selectable and not selected:
		var hv := StyleBoxFlat.new()
		hv.bg_color = Color(0, 0, 0, 0)
		hv.border_color = Color(C_BRASS, 0.65)
		hv.set_border_width_all(2)
		hv.set_corner_radius_all(int(radius))
		draw_style_box(hv, r.grow(-1.0))

	var col: Color
	match rank:
		"K":
			col = Color("1f2f6b")
		"Q":
			col = Color("7a1a2c")
		"J":
			col = Color("6b3fa0")
		_:
			col = C_INK
	var f := UIKit.serif()
	var corner_size := 10 if small else 13
	var glyph_size := 24 if small else 36
	var label := "J" if rank == "J" else rank
	var pad := 5.0 if small else 7.0

	# Corner index: rank over a small pip, mirrored at the opposite corner.
	_corner_index(Vector2(pad, corner_size + 2.0), label, col, corner_size, false)
	_corner_index(Vector2(size.x - pad, size.y - 3.0), label, col, corner_size, true)

	var center := size / 2.0 + Vector2(0, 1.0)
	match rank:
		"K":
			_draw_crown(center, (14.0 if small else 21.0), col, true)
		"Q":
			_draw_crown(center, (14.0 if small else 21.0), col, false)
		"J":
			_draw_star(center, (12.0 if small else 19.0), col)
		_:
			draw_string(f, Vector2(0, center.y + glyph_size * 0.36), "A",
				HORIZONTAL_ALIGNMENT_CENTER, size.x, glyph_size, col)


## Rank letter and, under it, the rank's mark in miniature. `flip` draws it
## rotated 180 degrees for the bottom-right corner.
func _corner_index(at: Vector2, label: String, col: Color, font_size: int, flip: bool) -> void:
	var f := UIKit.serif()
	if not flip:
		draw_string(f, at, label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, col)
		_pip(at + Vector2(font_size * 0.22, font_size * 0.62), (3.2 if small else 4.2), col)
	else:
		draw_set_transform(size, PI, Vector2.ONE)
		var mirrored := Vector2(size.x - at.x, size.y - at.y)
		draw_string(f, mirrored, label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, col)
		_pip(mirrored + Vector2(font_size * 0.22, font_size * 0.62), (3.2 if small else 4.2), col)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _pip(c: Vector2, s: float, col: Color) -> void:
	match rank:
		"K", "Q":
			_draw_crown(c, s, col, rank == "K")
		"J":
			_draw_star(c, s * 1.1, col)
		_:
			var pts := PackedVector2Array([c + Vector2(0, -s), c + Vector2(s, 0), c + Vector2(0, s), c + Vector2(-s, 0)])
			draw_colored_polygon(pts, col)


func _draw_back(r: Rect2, radius: float) -> void:
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(int(radius))
	sb.bg_color = Color("5e1717")
	sb.border_color = Color(C_BRASS, 0.55)
	sb.set_border_width_all(2 if small else 3)
	draw_style_box(sb, r)

	var inner := r.grow(-(5.0 if small else 6.0))
	if inner.size.x <= 4.0 or inner.size.y <= 4.0:
		return

	# Woven diamond hatch instead of flat stripes: reads as fabric at a glance.
	# Each 45-degree line is clipped to the inner rect by solving for the
	# parameter range, so nothing spills past the card edge.
	var step := 8.0
	var left := inner.position.x
	var right := inner.end.x
	var top := inner.position.y
	var bottom := inner.end.y
	var h := inner.size.y
	var w := inner.size.x
	var x := left - h
	while x < right:
		var t0 := maxf(0.0, left - x)
		var t1 := minf(h, right - x)
		if t1 > t0:
			draw_line(Vector2(x + t0, bottom - t0), Vector2(x + t1, bottom - t1), Color("4a1212"), 2.0)
		x += step
	var y := top - w
	while y < bottom:
		var u0 := maxf(0.0, top - y)
		var u1 := minf(w, bottom - y)
		if u1 > u0:
			draw_line(Vector2(left + u0, y + u0), Vector2(left + u1, y + u1), Color("4a1212"), 2.0)
		y += step

	# Brass frame, then the same cylinder mark the table carries.
	var frame := StyleBoxFlat.new()
	frame.bg_color = Color(0, 0, 0, 0)
	frame.border_color = Color(C_BRASS, 0.30)
	frame.set_border_width_all(1)
	frame.set_corner_radius_all(int(maxf(2.0, radius - 3.0)))
	draw_style_box(frame, inner)

	var c := r.get_center()
	var R := minf(inner.size.x, inner.size.y) * 0.24
	if R < 6.0:
		return
	draw_arc(c, R, 0, TAU, 48, Color(C_BRASS, 0.30), 1.0, true)
	for i in range(6):
		var a := float(i) / 6.0 * TAU - PI / 2
		draw_circle(c + Vector2(cos(a), sin(a)) * R * 0.52, maxf(1.2, R * 0.13), Color(C_BRASS, 0.24))
	draw_circle(c, maxf(1.2, R * 0.14), Color(C_BRASS, 0.30))


func _draw_crown(c: Vector2, s: float, col: Color, king: bool) -> void:
	var pts := PackedVector2Array()
	if king:
		pts = PackedVector2Array([
			c + Vector2(-s, s * 0.5), c + Vector2(-s, -s * 0.4), c + Vector2(-s * 0.5, 0), c + Vector2(0, -s * 0.8),
			c + Vector2(s * 0.5, 0), c + Vector2(s, -s * 0.4), c + Vector2(s, s * 0.5),
		])
	else:
		pts = PackedVector2Array([
			c + Vector2(-s, s * 0.5), c + Vector2(-s * 0.9, -s * 0.3), c + Vector2(-s * 0.35, -s * 0.05),
			c + Vector2(0, -s * 0.9), c + Vector2(s * 0.35, -s * 0.05), c + Vector2(s * 0.9, -s * 0.3), c + Vector2(s, s * 0.5),
		])
	draw_colored_polygon(pts, col)
	draw_rect(Rect2(c + Vector2(-s, s * 0.55), Vector2(s * 2, s * 0.28)), col)
	if not king:
		draw_circle(c + Vector2(0, -s * 0.95), s * 0.14, col)


func _draw_star(c: Vector2, s: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in range(10):
		var a := -PI / 2 + i * PI / 5
		var rr := s if i % 2 == 0 else s * 0.45
		pts.append(c + Vector2(cos(a), sin(a)) * rr)
	draw_colored_polygon(pts, col)
