class_name FeltView
extends Control
## The green baize the cards are played on.
##
## A flat colour reads as a rectangle, not a table. This draws the layers that
## make it read as a surface: woven threads, a lamp falling from above, the
## darkening toward the rail, a brass inlay, and a watermark in the middle so
## the large empty area between the dealer and the pile is not just dead space.
##
## Everything is drawn from `size`, so it survives both layouts unchanged.

const C_FELT := Color("1d3a2a")
const C_FELT_DEEP := Color("122a1e")
const C_BRASS := Color("e5c07b")

var _vignette: GradientTexture2D
var _lamp: GradientTexture2D


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette = _radial(Color(0, 0, 0, 0.0), Color(0, 0, 0, 0.55))
	_lamp = _radial(Color(1.0, 0.86, 0.6, 0.10), Color(1.0, 0.86, 0.6, 0.0))


## A radial fade from `inner` at the middle to `outer` at the rim.
func _radial(inner: Color, outer: Color) -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, inner)
	g.set_color(1, outer)
	var t := GradientTexture2D.new()
	t.gradient = g
	t.width = 256
	t.height = 256
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 1.0)
	return t


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	if r.size.x < 8.0 or r.size.y < 8.0:
		return

	# Base, then a slightly deeper band along the bottom so the table has a
	# direction the light comes from.
	draw_rect(r, C_FELT)
	var bands := 10
	for i in range(bands):
		var t := float(i) / float(bands)
		var y := r.size.y * (0.55 + 0.45 * t)
		draw_rect(Rect2(0, y, r.size.x, r.size.y * 0.45 / bands + 1.0),
			Color(C_FELT_DEEP, 0.10 * t))

	# Woven threads. Two passes, offset, so it does not read as scan lines.
	var step := 4.0
	var y := 0.0
	while y < r.size.y:
		draw_line(Vector2(0, y), Vector2(r.size.x, y), Color(0, 0, 0, 0.05), 1.0)
		y += step
	y = 2.0
	while y < r.size.y:
		draw_line(Vector2(0, y), Vector2(r.size.x, y), Color(1, 1, 1, 0.018), 1.0)
		y += step
	var x := 0.0
	while x < r.size.x:
		draw_line(Vector2(x, 0), Vector2(x, r.size.y), Color(0, 0, 0, 0.018), 1.0)
		x += step

	# Lamp from above the table, then the fall-off toward the rail.
	draw_texture_rect(_lamp, Rect2(Vector2(0, -r.size.y * 0.55), Vector2(r.size.x, r.size.y * 1.7)), false)
	draw_texture_rect(_vignette, r, false)

	# Brass inlay, a finger's width inside the rail.
	var inlay := r.grow(-9.0)
	if inlay.size.x > 4.0 and inlay.size.y > 4.0:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0, 0, 0, 0)
		sb.border_color = Color(C_BRASS, 0.22)
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(7)
		draw_style_box(sb, inlay)

	_draw_watermark(r)


## A revolver cylinder pressed into the baize, barely visible. It fills the
## middle of the table without competing with the cards on top of it.
func _draw_watermark(r: Rect2) -> void:
	var c := r.get_center()
	var R := minf(r.size.x, r.size.y) * 0.30
	if R < 26.0:
		return
	var ink := Color(C_BRASS, 0.055)
	draw_arc(c, R, 0, TAU, 96, ink, 2.0, true)
	draw_arc(c, R * 0.78, 0, TAU, 96, Color(C_BRASS, 0.03), 1.0, true)
	var ring := R * 0.52
	var rad := R * 0.13
	for i in range(6):
		var a := float(i) / 6.0 * TAU - PI / 2
		draw_circle(c + Vector2(cos(a), sin(a)) * ring, rad, Color(C_BRASS, 0.035))
		draw_arc(c + Vector2(cos(a), sin(a)) * ring, rad, 0, TAU, 32, Color(C_BRASS, 0.05), 1.0, true)
	draw_circle(c, R * 0.13, Color(C_BRASS, 0.05))
