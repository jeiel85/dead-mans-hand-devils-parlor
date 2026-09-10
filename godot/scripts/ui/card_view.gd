class_name CardView
extends Control
## A playing card drawn procedurally. Click to toggle selection when selectable.

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
	var radius := 6.0 if small else 8.0
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(int(radius))
	if face_down:
		sb.bg_color = Color("5e1717")
		sb.border_color = UIKit.C_PAPER
		sb.set_border_width_all(3 if not small else 2)
		draw_style_box(sb, r)
		# diagonal stripes
		var inner := r.grow(-(7.0 if not small else 5.0))
		var step := 9.0
		var x := inner.position.x - inner.size.y
		while x < inner.end.x:
			var p1 := Vector2(x, inner.end.y)
			var p2 := Vector2(x + inner.size.y, inner.position.y)
			p1.x = clampf(p1.x, inner.position.x, inner.end.x)
			p2.x = clampf(p2.x, inner.position.x, inner.end.x)
			draw_line(p1, p2, Color("4a1212"), 3.0)
			x += step
		draw_rect(inner, Color(UIKit.C_PAPER, 0.55), false, 1.0)
		return
	sb.bg_color = Color("f6ecd6") if rank == "J" else UIKit.C_PAPER
	sb.border_color = UIKit.C_BRASS if selected else Color(0, 0, 0, 0.12)
	sb.set_border_width_all(3 if selected else 1)
	draw_style_box(sb, r)
	if _hover and selectable and not selected:
		draw_rect(r.grow(-1), Color(UIKit.C_BRASS, 0.5), false, 2.0)
	var col: Color
	match rank:
		"K":
			col = Color("1f2f6b")
		"Q":
			col = Color("7a1a2c")
		"J":
			col = Color("6b3fa0")
		_:
			col = UIKit.C_INK
	var f := UIKit.serif()
	var corner_size := 11 if small else 14
	var glyph_size := 26 if small else 40
	var label := "JOKER" if rank == "J" else rank
	draw_string(f, Vector2(6, corner_size + 4), label if rank != "J" else "J", HORIZONTAL_ALIGNMENT_LEFT, -1, corner_size, col)
	draw_set_transform(size, PI, Vector2.ONE)
	draw_string(f, Vector2(6, corner_size + 4), label if rank != "J" else "J", HORIZONTAL_ALIGNMENT_LEFT, -1, corner_size, col)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var center := size / 2.0
	match rank:
		"K":
			_draw_crown(center, (16.0 if small else 24.0), col, true)
		"Q":
			_draw_crown(center, (16.0 if small else 24.0), col, false)
		"J":
			_draw_star(center, (14.0 if small else 22.0), col)
		_:
			draw_string(f, Vector2(0, center.y + glyph_size * 0.36), "A", HORIZONTAL_ALIGNMENT_CENTER, size.x, glyph_size, col)


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
