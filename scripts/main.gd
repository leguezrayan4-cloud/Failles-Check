extends Control
## FaillesCheck — contrôleur de l'unique scène principale.
## Écran de chargement, fond plein écran, barre d'onglets (5) et transitions.

const NAV_H := 72

var _pages: Array[Control] = []
var _nav_icons: Array[TextureRect] = []
var _nav_labels: Array[Label] = []
var _current: int = -1
var _return_tab: int = 0

var _pages_layer: Control
var _nav_layer: PanelContainer
var _splash: Control
var _splash_bar: ProgressBar
var _toast_panel: PanelContainer
var _toast: Label
var _toast_tween: Tween
var _defs: Array = []

func _ready() -> void:
	theme = UI.build_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_defs = [
		{"title": "Accueil", "short": "Accueil", "icon": UI.ICON_HOME, "page": HomePage},
		{"title": "Recherche", "short": "Recherche", "icon": UI.ICON_SEARCH, "page": SearchPage},
		{"title": "Fiche", "short": "Fiche", "icon": UI.ICON_FICHE, "page": DetailPage},
		{"title": "Mes logiciels", "short": "Logiciels", "icon": UI.ICON_APPS, "page": SoftwarePage},
		{"title": "Réglages", "short": "Réglages", "icon": UI.ICON_SETTINGS, "page": SettingsPage},
	]
	_build_background()
	_build_pages()
	_build_nav()
	_build_splash()
	_build_toast()
	DataStore.toast.connect(_show_toast)
	_switch_to(0, true)
	_run_splash()

# --- Fond plein écran ------------------------------------------------------
func _build_background() -> void:
	var bg := TextureRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var grad := Gradient.new()
	grad.set_color(0, UI.BG_TOP)
	grad.set_color(1, UI.BG_BOTTOM)
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill_from = Vector2(0.5, 0.0)
	tex.fill_to = Vector2(0.5, 1.0)
	tex.width = 360
	tex.height = 640
	bg.texture = tex
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	add_child(bg)

# --- Pages -----------------------------------------------------------------
func _build_pages() -> void:
	_pages_layer = Control.new()
	_pages_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pages_layer.offset_bottom = -NAV_H
	_pages_layer.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_pages_layer)
	for d in _defs:
		var page: Control = d["page"].new()
		page.visible = false
		_pages_layer.add_child(page)
		_pages.append(page)

# --- Barre d'onglets -------------------------------------------------------
func _build_nav() -> void:
	_nav_layer = PanelContainer.new()
	_nav_layer.anchor_left = 0.0
	_nav_layer.anchor_right = 1.0
	_nav_layer.anchor_top = 1.0
	_nav_layer.anchor_bottom = 1.0
	_nav_layer.offset_top = -NAV_H
	_nav_layer.offset_bottom = 0.0
	_nav_layer.offset_left = 0.0
	_nav_layer.offset_right = 0.0
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.95)
	sb.border_color = UI.BORDER
	sb.border_width_top = 1
	sb.content_margin_left = 6
	sb.content_margin_right = 6
	sb.content_margin_top = 8
	sb.content_margin_bottom = 12
	_nav_layer.add_theme_stylebox_override("panel", sb)
	add_child(_nav_layer)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	_nav_layer.add_child(row)
	for i in _defs.size():
		row.add_child(_make_nav_item(str(_defs[i]["short"]), str(_defs[i]["icon"]), i))

func _make_nav_item(title: String, icon_svg: String, index: int) -> Button:
	var b := Button.new()
	b.name = "Nav_%d" % index
	b.flat = true
	b.custom_minimum_size = Vector2(0, 50)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	b.add_theme_stylebox_override("hover", UI.stylebox(Color(UI.ACCENT.r, UI.ACCENT.g, UI.ACCENT.b, 0.06), 12, 0, Color(0, 0, 0, 0), 0))
	b.add_theme_stylebox_override("pressed", UI.stylebox(Color(UI.ACCENT.r, UI.ACCENT.g, UI.ACCENT.b, 0.13), 12, 0, Color(0, 0, 0, 0), 0))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var vb := VBoxContainer.new()
	vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 3)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ic := UI.icon(icon_svg, 23, UI.TEXT_3)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vb.add_child(ic)
	var lb := UI.label(title, 10, UI.TEXT_3)
	lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_child(lb)
	b.add_child(vb)
	b.pressed.connect(_on_nav_pressed.bind(index))
	_nav_icons.append(ic)
	_nav_labels.append(lb)
	return b

func _on_nav_pressed(index: int) -> void:
	var dir := 1 if index >= _current else -1
	_switch_to(index, false, dir)

func _update_nav() -> void:
	for i in _nav_icons.size():
		var active := i == _current
		var c := UI.ACCENT if active else UI.TEXT_3
		_nav_icons[i].modulate = c
		_nav_labels[i].add_theme_color_override("font_color", c)

## Appelé par les pages pour ouvrir la fiche d'une faille.
func open_detail() -> void:
	if _current != 2 and _current >= 0:
		_return_tab = _current
	_switch_to(2, false, 1)

## Retour à l'écran précédent (bouton Retour de la fiche), avec transition animée.
func go_back() -> void:
	var target := _return_tab
	if target == _current or target < 0 or target >= _pages.size():
		target = 0
	_switch_to(target, false, -1)

# --- Transitions -----------------------------------------------------------
## dir = 1 : avant (entre par la droite) ; dir = -1 : retour (entre par la gauche).
func _switch_to(index: int, instant: bool = false, dir: int = 1) -> void:
	if index == _current or index < 0 or index >= _pages.size():
		return
	var prev := _current
	_current = index
	var page := _pages[index]
	page.visible = true
	page.z_index = 1

	if prev >= 0:
		var old := _pages[prev]
		old.z_index = 0
		if instant:
			_hide_page(old)
		else:
			var t := create_tween().set_parallel(true)
			t.tween_property(old, "modulate:a", 0.0, 0.16)
			t.tween_property(old, "position:x", -26.0 * dir, 0.16)
			t.chain().tween_callback(_hide_page.bind(old))

	page.modulate = Color(1, 1, 1, 1)
	page.position.x = 0.0
	if instant:
		page.modulate.a = 1.0
	else:
		page.modulate.a = 0.0
		page.position.x = 26.0 * dir
		var t2 := create_tween().set_parallel(true)
		t2.tween_property(page, "modulate:a", 1.0, 0.22)
		t2.tween_property(page, "position:x", 0.0, 0.22)

	_update_nav()

func _hide_page(page: Control) -> void:
	page.visible = false
	page.position.x = 0.0
	page.modulate = Color(1, 1, 1, 1)
	page.z_index = 0

# --- Écran de chargement ---------------------------------------------------
func _build_splash() -> void:
	_splash = Control.new()
	_splash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_splash.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_splash)

	var bg := TextureRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var grad := Gradient.new()
	grad.set_color(0, Color(0.953, 0.969, 0.996))
	grad.set_color(1, Color(0.898, 0.925, 0.984))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill_from = Vector2(0.5, 0.0)
	tex.fill_to = Vector2(0.5, 1.0)
	tex.width = 360
	tex.height = 640
	bg.texture = tex
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	_splash.add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_splash.add_child(center)

	var v := UI.vbox(12)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(v)

	var logo := TextureRect.new()
	logo.texture = preload("res://Logo.png")
	logo.custom_minimum_size = Vector2(132, 132)
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(logo)

	var t := UI.label("FaillesCheck", 30, UI.ACCENT, true)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.custom_minimum_size = Vector2(240, 0)
	v.add_child(t)

	var sub := UI.label("Contrôle de vulnérabilités", 14, UI.TEXT_2)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.custom_minimum_size = Vector2(240, 0)
	v.add_child(sub)

	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 8)
	v.add_child(gap)

	_splash_bar = ProgressBar.new()
	_splash_bar.custom_minimum_size = Vector2(180, 6)
	_splash_bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_splash_bar.show_percentage = false
	_splash_bar.max_value = 100.0
	_splash_bar.value = 0.0
	_splash_bar.add_theme_stylebox_override("background", UI.stylebox(Color(0.839, 0.871, 0.933), 3, 0, Color(0, 0, 0, 0), 0))
	_splash_bar.add_theme_stylebox_override("fill", UI.stylebox(UI.ACCENT, 3, 0, Color(0, 0, 0, 0), 0))
	v.add_child(_splash_bar)

	var load_label := UI.label("Chargement…", 12, UI.TEXT_3)
	load_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	load_label.custom_minimum_size = Vector2(240, 0)
	v.add_child(load_label)

func _run_splash() -> void:
	_pages_layer.modulate.a = 0.0
	_nav_layer.modulate.a = 0.0
	var t := create_tween()
	t.tween_property(_splash_bar, "value", 100.0, 1.3).set_trans(Tween.TRANS_SINE)
	t.tween_interval(0.15)
	t.tween_callback(_end_splash)

func _end_splash() -> void:
	var t := create_tween().set_parallel(true)
	t.tween_property(_splash, "modulate:a", 0.0, 0.4)
	t.tween_property(_pages_layer, "modulate:a", 1.0, 0.45)
	t.tween_property(_nav_layer, "modulate:a", 1.0, 0.45)
	t.chain().tween_callback(func():
		_splash.visible = false
		_splash.queue_free()
		_pages_layer.modulate = Color(1, 1, 1, 1))

# --- Toast -----------------------------------------------------------------
func _build_toast() -> void:
	_toast_panel = PanelContainer.new()
	_toast_panel.anchor_left = 0.5
	_toast_panel.anchor_right = 0.5
	_toast_panel.anchor_top = 1.0
	_toast_panel.anchor_bottom = 1.0
	_toast_panel.offset_bottom = -(NAV_H + 14)
	_toast_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toast_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.063, 0.094, 0.157, 0.93)
	sb.set_corner_radius_all(20)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 9
	sb.content_margin_bottom = 9
	_toast_panel.add_theme_stylebox_override("panel", sb)
	_toast = UI.label("", 13, Color.WHITE, true)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_panel.add_child(_toast)
	_toast_panel.modulate.a = 0.0
	add_child(_toast_panel)

func _show_toast(message: String) -> void:
	_toast.text = message
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_property(_toast_panel, "modulate:a", 1.0, 0.18)
	_toast_tween.tween_interval(1.4)
	_toast_tween.tween_property(_toast_panel, "modulate:a", 0.0, 0.3)