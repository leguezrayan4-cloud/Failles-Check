class_name UI
## FaillesCheck — Boîte à outils UI (thème, couleurs, widgets, icônes vectorielles).
## Style inspiré d'iOS : cartes blanches arrondies, ombres douces, police système.

# --- Palette ---------------------------------------------------------------
const BG_TOP := Color(0.933, 0.949, 0.984)
const BG_BOTTOM := Color(0.878, 0.902, 0.957)
const CARD := Color(1, 1, 1)
const CARD_SOFT := Color(0.968, 0.974, 0.986)
const BORDER := Color(0.890, 0.906, 0.937)
const TEXT := Color(0.063, 0.094, 0.157)
const TEXT_2 := Color(0.400, 0.439, 0.522)
const TEXT_3 := Color(0.612, 0.639, 0.686)
const ACCENT := Color(0.176, 0.490, 0.965)
const ACCENT_2 := Color(0.541, 0.298, 0.941)
const DANGER := Color(0.898, 0.282, 0.302)

static var FONT_NAMES := PackedStringArray([
	"SF Pro Text", "SF Pro Display", "Segoe UI", "Helvetica Neue",
	"Roboto", "Noto Sans", "Arial",
])

# --- Icônes (SVG blanc, teintées via modulate) -----------------------------
const ICON_HOME := "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 24 24\"><path fill=\"#fff\" d=\"M12 2.3 1.5 11.1h3.1v9.6h5.2v-5.7h4.4v5.7h5.2v-9.6h3.1z\"/></svg>"
const ICON_SEARCH := "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 24 24\"><circle cx=\"10.4\" cy=\"10.4\" r=\"6.2\" fill=\"none\" stroke=\"#fff\" stroke-width=\"2.6\"/><path d=\"M15.1 15.1 21 21\" fill=\"none\" stroke=\"#fff\" stroke-width=\"2.6\" stroke-linecap=\"round\"/></svg>"
const ICON_FICHE := "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 24 24\"><path fill=\"#fff\" fill-rule=\"evenodd\" d=\"M6 2h7l5 5v15H6V2zM9 11.6h6v1.7H9zM9 15.4h6v1.7H9zM9 7.8h3v1.7H9z\"/></svg>"
const ICON_APPS := "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 24 24\"><g fill=\"#fff\"><rect x=\"3\" y=\"3\" width=\"8\" height=\"8\" rx=\"2.2\"/><rect x=\"13\" y=\"3\" width=\"8\" height=\"8\" rx=\"2.2\"/><rect x=\"3\" y=\"13\" width=\"8\" height=\"8\" rx=\"2.2\"/><rect x=\"13\" y=\"13\" width=\"8\" height=\"8\" rx=\"2.2\"/></g></svg>"
const ICON_SETTINGS := "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 24 24\"><g fill=\"none\" stroke=\"#fff\" stroke-width=\"2\" stroke-linecap=\"round\"><path d=\"M3 7h18M3 12h18M3 17h18\"/></g><g fill=\"#fff\"><circle cx=\"8\" cy=\"7\" r=\"2.7\"/><circle cx=\"16\" cy=\"12\" r=\"2.7\"/><circle cx=\"10.5\" cy=\"17\" r=\"2.7\"/></g></svg>"
const ICON_TRASH := "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 24 24\"><path fill=\"#fff\" d=\"M9 2.4h6v2.1H9zM4.4 6.2h15.2v2.1h-1.5l-1 13.1a1.6 1.6 0 0 1-1.6 1.5H8.5a1.6 1.6 0 0 1-1.6-1.5l-1-13.1H4.4z\"/></svg>"
const ICON_PLUS := "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 24 24\"><g fill=\"none\" stroke=\"#fff\" stroke-width=\"2.8\" stroke-linecap=\"round\"><path d=\"M12 4.5v15M4.5 12h15\"/></g></svg>"
const ICON_SHIELD := "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 24 24\"><path fill=\"#fff\" d=\"M12 2 4 5v6.5c0 4.7 3.2 9.1 8 10.5 4.8-1.4 8-5.8 8-10.5V5z\"/></svg>"
const ICON_BACK := "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 24 24\"><path d=\"M15.5 4 7.5 12l8 8\" fill=\"none\" stroke=\"#fff\" stroke-width=\"2.8\" stroke-linecap=\"round\" stroke-linejoin=\"round\"/></svg>"
const ICON_GLOBE := "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 24 24\"><circle cx=\"12\" cy=\"12\" r=\"9\" fill=\"none\" stroke=\"#fff\" stroke-width=\"2\"/><path d=\"M3 12h18M12 3c3.2 3.2 3.2 14.8 0 18M12 3c-3.2 3.2-3.2 14.8 0 18\" fill=\"none\" stroke=\"#fff\" stroke-width=\"1.6\"/></svg>"

static var _font_reg: SystemFont
static var _font_bold: SystemFont

# --- Polices ---------------------------------------------------------------
static func font_reg() -> SystemFont:
	if _font_reg == null:
		_font_reg = SystemFont.new()
		_font_reg.font_names = FONT_NAMES
		_font_reg.font_weight = 400
		_font_reg.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	return _font_reg

static func font_bold() -> SystemFont:
	if _font_bold == null:
		_font_bold = SystemFont.new()
		_font_bold.font_names = FONT_NAMES
		_font_bold.font_weight = 700
		_font_bold.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	return _font_bold

static func build_theme() -> Theme:
	var t := Theme.new()
	t.default_font = font_reg()
	t.default_font_size = 15
	return t

# --- Gravité ---------------------------------------------------------------
static func sev_color(key: String) -> Color:
	match key:
		"critique": return Color(0.898, 0.282, 0.302)
		"elevee": return Color(0.910, 0.533, 0.039)
		"moyenne": return Color(0.878, 0.659, 0.0)
		"faible": return Color(0.184, 0.639, 0.420)
	return TEXT_2

static func sev_label(key: String) -> String:
	match key:
		"critique": return "Critique"
		"elevee": return "Élevée"
		"moyenne": return "Moyenne"
		"faible": return "Faible"
	return "Inconnue"

# --- StyleBox --------------------------------------------------------------
static func stylebox(color: Color, radius: int = 14, bw: int = 0, bc: Color = Color(0, 0, 0, 0), margin: int = 12) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(margin)
	if bw > 0:
		sb.set_border_width_all(bw)
		sb.border_color = bc
	return sb

static func card_style(radius: int = 18, margin: int = 16, bg: Color = CARD) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(margin)
	sb.border_color = BORDER
	sb.set_border_width_all(1)
	sb.shadow_color = Color(0.06, 0.09, 0.16, 0.08)
	sb.shadow_size = 8
	sb.shadow_offset = Vector2(0, 3)
	return sb

# --- Widgets ---------------------------------------------------------------
static func label(text: String, size: int = 15, color: Color = TEXT, bold: bool = false, should_wrap: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_font_override("font", font_bold() if bold else font_reg())
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if should_wrap else TextServer.AUTOWRAP_OFF
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

## Interrupteur style iOS (pilule + curseur animé).
static func switch_button(on: bool) -> Button:
	var b := Button.new()
	b.toggle_mode = true
	b.button_pressed = on
	b.custom_minimum_size = Vector2(52, 32)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	_style_switch(b, on)
	var knob := PanelContainer.new()
	knob.custom_minimum_size = Vector2(26, 26)
	var ks := StyleBoxFlat.new()
	ks.bg_color = Color(1, 1, 1)
	ks.set_corner_radius_all(13)
	ks.shadow_color = Color(0, 0, 0, 0.28)
	ks.shadow_size = 3
	ks.shadow_offset = Vector2(0, 1)
	knob.add_theme_stylebox_override("panel", ks)
	knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	knob.position = Vector2(23, 3) if on else Vector2(3, 3)
	b.add_child(knob)
	b.toggled.connect(func(v: bool) -> void:
		_style_switch(b, v)
		knob.create_tween().tween_property(knob, "position:x", 23.0 if v else 3.0, 0.16).set_trans(Tween.TRANS_SINE))
	return b

static func _style_switch(b: Button, on: bool) -> void:
	var col := ACCENT if on else Color(0.780, 0.800, 0.839)
	b.add_theme_stylebox_override("normal", stylebox(col, 16, 0, Color(0, 0, 0, 0), 0))
	b.add_theme_stylebox_override("hover", stylebox(col.lightened(0.05), 16, 0, Color(0, 0, 0, 0), 0))
	b.add_theme_stylebox_override("pressed", stylebox(col.darkened(0.05), 16, 0, Color(0, 0, 0, 0), 0))

static func icon(svg: String, size: int = 24, color: Color = TEXT_2) -> TextureRect:
	var tex_rect := TextureRect.new()
	tex_rect.texture = svg_texture(svg, size)
	tex_rect.custom_minimum_size = Vector2(size, size)
	tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex_rect.modulate = color
	tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tex_rect

static func svg_texture(svg: String, size: int = 24) -> ImageTexture:
	var img := Image.new()
	var err := img.load_svg_from_string(svg, float(size) / 24.0)
	if err != OK:
		push_error("FaillesCheck: échec chargement SVG (%s)" % err)
		return null
	return ImageTexture.create_from_image(img)

static func card(padding: int = 16) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", card_style(18, padding))
	return p

static func vbox(sep: int = 8) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return v

static func hbox(sep: int = 8) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return h

static func spacer() -> Control:
	var c := Control.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c

static func separator() -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = BORDER
	sb.set_content_margin_all(0)
	sb.content_margin_top = 0
	p.custom_minimum_size = Vector2(0, 1)
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p

static func primary_button(text: String, color: Color = ACCENT) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_override("font", font_bold())
	b.add_theme_font_size_override("font_size", 15)
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	b.add_theme_color_override("font_focus_color", Color.WHITE)
	b.custom_minimum_size = Vector2(0, 46)
	b.add_theme_stylebox_override("normal", stylebox(color, 13, 0, Color(0, 0, 0, 0), 10))
	b.add_theme_stylebox_override("hover", stylebox(color.lightened(0.08), 13, 0, Color(0, 0, 0, 0), 10))
	b.add_theme_stylebox_override("pressed", stylebox(color.darkened(0.12), 13, 0, Color(0, 0, 0, 0), 10))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return b

static func ghost_button(text: String, color: Color = ACCENT) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_override("font", font_bold())
	b.add_theme_font_size_override("font_size", 15)
	b.add_theme_color_override("font_color", color)
	b.add_theme_color_override("font_hover_color", color)
	b.add_theme_color_override("font_pressed_color", color.darkened(0.15))
	b.custom_minimum_size = Vector2(0, 46)
	b.add_theme_stylebox_override("normal", stylebox(CARD, 13, 1, BORDER, 10))
	b.add_theme_stylebox_override("hover", stylebox(CARD_SOFT, 13, 1, BORDER, 10))
	b.add_theme_stylebox_override("pressed", stylebox(BORDER, 13, 1, BORDER, 10))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return b

static func ghost_icon_button(icon_svg: String, text: String, color: Color = ACCENT) -> Button:
	var b := ghost_button(text, color)
	b.icon = svg_texture(icon_svg, 18)
	b.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_color_override("icon_normal_color", color)
	b.add_theme_color_override("icon_hover_color", color)
	b.add_theme_color_override("icon_pressed_color", color.darkened(0.15))
	return b

## Bouton « Retour » compact pour l'en-tête (chevron + libellé).
static func back_button(text: String = "Retour") -> Button:
	var b := Button.new()
	b.text = text
	b.flat = true
	b.icon = svg_texture(ICON_BACK, 18)
	b.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(0, 36)
	b.focus_mode = Control.FOCUS_NONE
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	b.add_theme_font_override("font", font_bold())
	b.add_theme_font_size_override("font_size", 15)
	b.add_theme_color_override("font_color", ACCENT)
	b.add_theme_color_override("font_hover_color", ACCENT)
	b.add_theme_color_override("font_pressed_color", ACCENT.darkened(0.15))
	b.add_theme_color_override("icon_normal_color", ACCENT)
	b.add_theme_color_override("icon_hover_color", ACCENT)
	b.add_theme_color_override("icon_pressed_color", ACCENT.darkened(0.15))
	b.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	b.add_theme_stylebox_override("hover", stylebox(CARD_SOFT, 10, 0, Color(0, 0, 0, 0), 6))
	b.add_theme_stylebox_override("pressed", stylebox(BORDER, 10, 0, Color(0, 0, 0, 0), 6))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return b

static func icon_button(svg: String, size: int = 40, color: Color = DANGER, bg: Color = Color(0.988, 0.937, 0.937)) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(size, size)
	b.add_theme_stylebox_override("normal", stylebox(bg, 11, 0, Color(0, 0, 0, 0), 0))
	b.add_theme_stylebox_override("hover", stylebox(bg.darkened(0.04), 11, 0, Color(0, 0, 0, 0), 0))
	b.add_theme_stylebox_override("pressed", stylebox(bg.darkened(0.08), 11, 0, Color(0, 0, 0, 0), 0))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var ic := icon(svg, 20, color)
	ic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(ic)
	return b

static func line_edit(placeholder: String) -> LineEdit:
	var e := LineEdit.new()
	e.placeholder_text = placeholder
	e.custom_minimum_size = Vector2(0, 44)
	e.add_theme_font_override("font", font_reg())
	e.add_theme_font_size_override("font_size", 15)
	e.add_theme_stylebox_override("normal", stylebox(CARD_SOFT, 12, 1, BORDER, 12))
	e.add_theme_stylebox_override("focus", stylebox(CARD, 12, 2, ACCENT, 12))
	e.add_theme_color_override("font_color", TEXT)
	e.add_theme_color_override("font_placeholder_color", TEXT_3)
	e.add_theme_color_override("caret_color", ACCENT)
	return e

static func chip(text: String, active: bool) -> Button:
	var b := Button.new()
	b.text = text
	b.toggle_mode = true
	b.button_pressed = active
	b.add_theme_font_override("font", font_bold())
	b.add_theme_font_size_override("font_size", 13)
	b.custom_minimum_size = Vector2(0, 34)
	var c := ACCENT if active else TEXT_2
	b.add_theme_color_override("font_color", c)
	b.add_theme_color_override("font_hover_color", c)
	b.add_theme_color_override("font_pressed_color", c)
	b.add_theme_color_override("font_focus_color", c)
	b.add_theme_stylebox_override("normal", stylebox(CARD, 17, 1, BORDER, 14))
	b.add_theme_stylebox_override("hover", stylebox(CARD_SOFT, 17, 1, BORDER, 14))
	b.add_theme_stylebox_override("pressed", stylebox(CARD, 17, 1, BORDER, 14))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return b

static func badge(text: String, color: Color) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(color.r, color.g, color.b, 0.14)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 3
	sb.content_margin_bottom = 3
	p.add_theme_stylebox_override("panel", sb)
	p.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var l := label(text, 12, color, true)
	p.add_child(l)
	return p

## Carte cliquable : Button stylé, contenu posé en overlay (non interactif).
static func clickable_card(height: int = 64, padding: int = 14) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, height)
	b.add_theme_stylebox_override("normal", card_style(18, padding))
	b.add_theme_stylebox_override("hover", card_style(18, padding, Color(0.985, 0.988, 0.996)))
	b.add_theme_stylebox_override("pressed", card_style(18, padding, Color(0.957, 0.964, 0.980)))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return b

static func overlay(btn: Button, node: Control, margin: int = 0) -> void:
	node.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	node.offset_left = margin
	node.offset_top = margin
	node.offset_right = -margin
	node.offset_bottom = -margin
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(node)
	# Tout le contenu décoratif reste transparent : seul le bouton capte le clic.
	_ignore_mouse_recursive(node)

static func _ignore_mouse_recursive(node: Node) -> void:
	for child in node.get_children():
		if child is Control:
			(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		_ignore_mouse_recursive(child)

static func info_card(pairs: Array) -> PanelContainer:
	var p := card(16)
	var v := vbox(12)
	for i in pairs.size():
		if i > 0:
			v.add_child(separator())
		var row := hbox(10)
		row.add_child(label(str(pairs[i][0]), 13, TEXT_2))
		row.add_child(spacer())
		row.add_child(label(str(pairs[i][1]), 13, TEXT, true))
		v.add_child(row)
	p.add_child(v)
	return p

static func text_section(title: String, body: String) -> PanelContainer:
	var p := card(16)
	var v := vbox(8)
	v.add_child(label(title, 14, TEXT, true))
	v.add_child(label(body, 13, TEXT_2, false, true))
	p.add_child(v)
	return p

static func section_title(text: String) -> Label:
	var l := label(text, 17, TEXT, true)
	return l

static func demo_tag() -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(ACCENT_2.r, ACCENT_2.g, ACCENT_2.b, 0.12)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 3
	sb.content_margin_bottom = 3
	p.add_theme_stylebox_override("panel", sb)
	p.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	p.add_child(label("DÉMO · FICTIF", 11, ACCENT_2, true))
	return p

static func empty_state(title: String, message: String, svg: String = ICON_SHIELD) -> PanelContainer:
	var p := card(26)
	var v := vbox(12)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	var ic := icon(svg, 44, TEXT_3)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(ic)
	var t := label(title, 18, TEXT, true, true)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var m := label(message, 13, TEXT_2, false, true)
	m.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(m)
	p.add_child(v)
	return p

static func vuln_card(v: Dictionary, on_press: Callable) -> Button:
	var sev := str(v.get("severity", ""))
	var col := sev_color(sev)
	var b := clickable_card(80, 14)
	var row := hbox(12)
	var bar := PanelContainer.new()
	bar.custom_minimum_size = Vector2(5, 46)
	var bs := StyleBoxFlat.new()
	bs.bg_color = col
	bs.set_corner_radius_all(3)
	bs.set_content_margin_all(0)
	bar.add_theme_stylebox_override("panel", bs)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(bar)

	var mid := vbox(3)
	mid.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mid.add_child(label(str(v.get("title", "")), 14, TEXT, true, true))
	mid.add_child(label("%s · %s" % [str(v.get("product", "")), str(v.get("version", ""))], 12, TEXT_2))
	row.add_child(mid)

	var right := vbox(2)
	right.size_flags_horizontal = Control.SIZE_SHRINK_END
	right.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var score := label("%.1f" % float(v.get("score", 0.0)), 16, col, true)
	score.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(score)
	var sl := label(sev_label(sev), 11, TEXT_3)
	sl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(sl)
	row.add_child(right)

	overlay(b, row, 14)
	b.pressed.connect(on_press)
	return b

static func sev_dot(color: Color, size: int = 10) -> PanelContainer:
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(size, size)
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(size)
	sb.set_content_margin_all(0)
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p