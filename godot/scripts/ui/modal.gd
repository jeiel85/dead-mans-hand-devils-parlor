class_name Modal
extends Control
## Full-screen dim + centred panel. Content is built by the controller through
## the helper methods; `closed` fires when the modal is dismissed.

signal closed

var _dim: ColorRect
var _panel: PanelContainer
var _body: VBoxContainer
var kind := ""


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_dim = ColorRect.new()
	_dim.color = Color(0.02, 0.01, 0.01, 0.84)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_dim)
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel = PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = Color("140d0b")
	st.border_color = UIKit.C_PANEL_EDGE
	st.set_border_width_all(1)
	st.set_corner_radius_all(14)
	st.set_content_margin_all(28)
	st.shadow_color = Color(0, 0, 0, 0.8)
	st.shadow_size = 30
	_panel.add_theme_stylebox_override("panel", st)
	_panel.custom_minimum_size = Vector2(620, 0)
	center.add_child(_panel)
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 10)
	_panel.add_child(_body)
	visible = false


func open(p_kind: String) -> VBoxContainer:
	kind = p_kind
	for c in _body.get_children():
		_body.remove_child(c)
		c.queue_free()
	visible = true
	_panel.modulate = Color(1, 1, 1, 0)
	_panel.scale = Vector2(0.96, 0.96)
	_panel.pivot_offset = _panel.size / 2.0
	var t := create_tween().set_parallel(true)
	t.tween_property(_panel, "modulate", Color.WHITE, 0.18)
	t.tween_property(_panel, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_QUAD)
	return _body


func close() -> void:
	if not visible:
		return
	visible = false
	kind = ""
	closed.emit()


func set_width(w: float) -> void:
	_panel.custom_minimum_size = Vector2(w, 0)


# --- builders ---------------------------------------------------------------

func title(text: String, size: int = 26, color: Color = UIKit.C_BRASS, center := false) -> Label:
	var l := UIKit.label(text, size, color, UIKit.serif())
	if center:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body.add_child(l)
	return l


func text(t: String, size: int = 14, color: Color = UIKit.C_PAPER_DIM, center := false) -> Label:
	var l := UIKit.wrap(UIKit.label(t, size, color))
	if center:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.custom_minimum_size = Vector2(560, 0)
	_body.add_child(l)
	return l


func eyebrow(t: String, center := false) -> Label:
	var l := UIKit.label(t.to_upper(), 11, UIKit.C_MUTED)
	if center:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body.add_child(l)
	return l


func row(center := false) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	if center:
		h.alignment = BoxContainer.ALIGNMENT_CENTER
	_body.add_child(h)
	return h


func add(node: Control) -> Control:
	_body.add_child(node)
	return node
