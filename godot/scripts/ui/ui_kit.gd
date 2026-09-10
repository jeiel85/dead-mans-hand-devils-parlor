class_name UIKit
extends RefCounted
## Fonts, palette and small factories for code-built UI (no .tscn authoring).

const C_BG := Color("0d0808")
const C_FELT := Color("1d3a2a")
const C_FELT_EDGE := Color("0f2419")
const C_WOOD := Color("3a2418")
const C_WOOD_HI := Color("6b4a30")
const C_PAPER := Color("efe3c8")
const C_PAPER_DIM := Color("c8b89a")
const C_INK := Color("1a1410")
const C_BRASS := Color("e5c07b")
const C_BRASS_DIM := Color("9c7f4a")
const C_BLOOD := Color("a12626")
const C_BLOOD_DIM := Color("5e1717")
const C_CURSE := Color("7b4bb0")
const C_MUTED := Color("8f8577")
const C_PANEL := Color(0.07, 0.047, 0.04, 0.9)
const C_PANEL_EDGE := Color(0.9, 0.75, 0.48, 0.18)
const C_GREEN := Color("b8e0a0")
const C_RED := Color("ff8a80")

static var _sans: Font
static var _sans_bold: Font
static var _serif: Font


static func sans() -> Font:
	if _sans == null:
		_sans = load("res://assets/fonts/NotoSansKR.ttf")
		if _sans == null:
			_sans = ThemeDB.fallback_font
	return _sans


static func sans_bold() -> Font:
	if _sans_bold == null:
		var fv := FontVariation.new()
		fv.base_font = sans()
		fv.variation_embolden = 0.7
		_sans_bold = fv
	return _sans_bold


static func serif() -> Font:
	if _serif == null:
		_serif = load("res://assets/fonts/NanumMyeongjo-Bold.ttf")
		if _serif == null:
			_serif = sans_bold()
	return _serif


static func label(text: String, size: int = 15, color: Color = C_PAPER, font: Font = null) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font if font != null else sans())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func caption(text: String) -> Label:
	var l := label(text.to_upper(), 11, C_MUTED)
	return l


static func wrap(l: Label) -> Label:
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


static func panel_style(bg: Color = C_PANEL, edge: Color = C_PANEL_EDGE, radius: int = 10, border: int = 1) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = edge
	sb.set_border_width_all(border)
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(12)
	return sb


static func panel(bg: Color = C_PANEL, edge: Color = C_PANEL_EDGE, radius: int = 10) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", panel_style(bg, edge, radius))
	return p


static func button(text: String, kind: String = "normal", size: int = 15) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_override("font", serif() if kind != "small" else sans())
	b.add_theme_font_size_override("font_size", size)
	b.focus_mode = Control.FOCUS_NONE
	var normal := StyleBoxFlat.new()
	normal.set_corner_radius_all(8)
	normal.set_border_width_all(1)
	normal.set_content_margin_all(10)
	normal.content_margin_left = 18
	normal.content_margin_right = 18
	var hover := normal.duplicate()
	var disabled := normal.duplicate()
	match kind:
		"primary":
			normal.bg_color = Color("241811")
			normal.border_color = C_BRASS
			b.add_theme_color_override("font_color", C_BRASS)
		"danger":
			normal.bg_color = Color("4a1212")
			normal.border_color = C_BLOOD
			b.add_theme_color_override("font_color", Color("ffd7d7"))
		"small":
			normal.bg_color = Color(0, 0, 0, 0)
			normal.border_color = C_PANEL_EDGE
			normal.set_content_margin_all(5)
			normal.content_margin_left = 9
			normal.content_margin_right = 9
			b.add_theme_color_override("font_color", C_PAPER_DIM)
		_:
			normal.bg_color = Color("170f0b")
			normal.border_color = C_BRASS_DIM
			b.add_theme_color_override("font_color", C_PAPER)
	hover = normal.duplicate()
	hover.bg_color = normal.bg_color.lightened(0.12)
	hover.border_color = C_BRASS
	disabled = normal.duplicate()
	disabled.bg_color = normal.bg_color.darkened(0.3)
	disabled.border_color = Color(normal.border_color, 0.35)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", hover)
	b.add_theme_stylebox_override("disabled", disabled)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_color_override("font_hover_color", C_BRASS)
	b.add_theme_color_override("font_disabled_color", Color(C_PAPER, 0.35))
	b.add_theme_color_override("font_pressed_color", C_BRASS)
	return b


static func line_edit(placeholder: String, width: float = 200.0) -> LineEdit:
	var e := LineEdit.new()
	e.placeholder_text = placeholder
	e.custom_minimum_size = Vector2(width, 0)
	e.add_theme_font_override("font", sans())
	e.add_theme_font_size_override("font_size", 14)
	e.add_theme_color_override("font_color", C_BRASS)
	e.add_theme_color_override("font_placeholder_color", C_MUTED)
	e.add_theme_color_override("caret_color", C_BRASS)
	var st := StyleBoxFlat.new()
	st.bg_color = Color("0a0606")
	st.border_color = C_PANEL_EDGE
	st.set_border_width_all(1)
	st.set_corner_radius_all(6)
	st.set_content_margin_all(6)
	st.content_margin_left = 10
	st.content_margin_right = 10
	var focus := st.duplicate()
	focus.border_color = C_BRASS
	e.add_theme_stylebox_override("normal", st)
	e.add_theme_stylebox_override("focus", focus)
	return e


static func hearts(hp: int, max_hp: int) -> HBoxContainer:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	for i in range(max_hp):
		var h := HeartIcon.new()
		h.full = i < hp
		box.add_child(h)
	var n := label("%d/%d" % [hp, max_hp], 12, C_PAPER_DIM)
	box.add_child(n)
	return box


static func spacer(min_size: Vector2 = Vector2.ZERO, expand := true) -> Control:
	var c := Control.new()
	c.custom_minimum_size = min_size
	if expand:
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


class HeartIcon extends Control:
	var full := true

	func _init() -> void:
		custom_minimum_size = Vector2(16, 16)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c: Color = UIKit.C_BLOOD if full else Color("2b1c1c")
		var s := 16.0
		draw_circle(Vector2(s * 0.3, s * 0.35), s * 0.28, c)
		draw_circle(Vector2(s * 0.7, s * 0.35), s * 0.28, c)
		var tri := PackedVector2Array([Vector2(s * 0.04, s * 0.45), Vector2(s * 0.96, s * 0.45), Vector2(s * 0.5, s * 0.98)])
		draw_colored_polygon(tri, c)
