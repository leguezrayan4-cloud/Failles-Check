extends Control
## FaillesCheck — contrôleur de l'unique scène principale (res://Main.tscn).
## Chargement réel et asynchrone, 4 onglets, panneau de détail animé,
## défilement tactile, toasts.

const NAV_H := 72

var _pages: Array[Control] = []
var _nav_icons: Array[TextureRect] = []
var _nav_labels: Array[Label] = []
var _current: int = -1

var _pages_layer: Control
var _nav_layer: PanelContainer
var _sheet: DetailSheet
var _loader: AppLoader
var _loading_layer: Control
var _loading_bar: ProgressBar
var _loading_status: Label
var _loading_percent: Label
var _loading_error: Label
var _loading_actions: HBoxContainer
var _loading_spinner: Spinner
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
		{"title": "Mes logiciels", "short": "Logiciels", "icon": UI.ICON_APPS, "page": SoftwarePage},
		{"title": "Réglages", "short": "Réglages", "icon": UI.ICON_SETTINGS, "page": SettingsPage},
	]
	_build_background()
	_build_pages()
	_build_nav()
	_build_sheet()
	_build_toast()
	_build_loading()
	DataStore.toast.connect(_show_toast)
	_switch_to(0, true)
	_start_loading()

# --- Fond plein écran ------------------------------------------------------
func _build_background() -> void:
	var bg := TextureRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.texture = _gradient_texture(UI.BG_TOP, UI.BG_BOTTOM)
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	add_child(bg)

func _gradient_texture(top: Color, bottom: Color) -> GradientTexture2D:
	var grad := Gradient.new()
	grad.set_color(0, top)
	grad.set_color(1, bottom)
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill_from = Vector2(0.5, 0.0)
	tex.fill_to = Vector2(0.5, 1.0)
	tex.width = 360
	tex.height = 640
	return tex

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
	sb.bg_color = Color(1, 1, 1, 0.96)
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
	if _sheet != null and _sheet.is_open():
		_sheet.close()
	var dir := 1 if index >= _current else -1
	_switch_to(index, false, dir)

func _update_nav() -> void:
	for i in _nav_icons.size():
		var active := i == _current
		var c := UI.ACCENT if active else UI.TEXT_3
		_nav_icons[i].modulate = c
		_nav_labels[i].add_theme_color_override("font_color", c)

# --- Détail ----------------------------------------------------------------
func _build_sheet() -> void:
	_sheet = DetailSheet.new()
	_sheet.name = "DetailSheet"
	add_child(_sheet)

## Ouverture du détail par-dessus l'écran courant (Accueil ou Recherche).
func open_detail_sheet(id: String) -> void:
	var v := DataStore.get_vulnerability(id)
	if v.is_empty():
		return
	DataStore.select(id)
	_sheet.show_detail(v)

## Conservé pour compatibilité : ferme le panneau de détail.
func go_back() -> void:
	if _sheet != null and _sheet.is_open():
		_sheet.close()

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

# --- Écran de chargement (réel) --------------------------------------------
func _build_loading() -> void:
	_loading_layer = Control.new()
	_loading_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_loading_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_loading_layer)

	var bg := TextureRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.texture = _gradient_texture(Color(0.953, 0.969, 0.996), Color(0.898, 0.925, 0.984))
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	_loading_layer.add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_loading_layer.add_child(center)

	var v := UI.vbox(10)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.custom_minimum_size = Vector2(300, 0)
	center.add_child(v)

	var logo := TextureRect.new()
	logo.texture = preload("res://Logo.png")
	logo.custom_minimum_size = Vector2(120, 120)
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(logo)

	var t := UI.label("FaillesCheck", 30, UI.ACCENT, true)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var sub := UI.label("Contrôle de vulnérabilités", 14, UI.TEXT_2)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)

	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 10)
	v.add_child(gap)

	var status_row := UI.hbox(8)
	status_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_loading_spinner = Spinner.new(18, UI.ACCENT)
	status_row.add_child(_loading_spinner)
	_loading_status = UI.label("Préparation…", 13, UI.TEXT_2, false, true)
	_loading_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_row.add_child(_loading_status)
	v.add_child(status_row)

	_loading_bar = ProgressBar.new()
	_loading_bar.custom_minimum_size = Vector2(0, 6)
	_loading_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_loading_bar.show_percentage = false
	_loading_bar.max_value = 100.0
	_loading_bar.value = 0.0
	_loading_bar.add_theme_stylebox_override("background", UI.stylebox(Color(0.839, 0.871, 0.933), 3, 0, Color(0, 0, 0, 0), 0))
	_loading_bar.add_theme_stylebox_override("fill", UI.stylebox(UI.ACCENT, 3, 0, Color(0, 0, 0, 0), 0))
	v.add_child(_loading_bar)

	_loading_percent = UI.label("0 %", 12, UI.TEXT_3)
	_loading_percent.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_loading_percent)

	_loading_error = UI.label("", 12, UI.DANGER, true, true)
	_loading_error.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_loading_error.visible = false
	v.add_child(_loading_error)

	_loading_actions = UI.hbox(10)
	_loading_actions.visible = false
	var retry := UI.primary_button("Réessayer")
	retry.name = "RetryButton"
	retry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	retry.pressed.connect(_on_retry)
	_loading_actions.add_child(retry)
	var offline := UI.ghost_button("Continuer hors ligne", UI.TEXT_2)
	offline.name = "OfflineButton"
	offline.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	offline.pressed.connect(_on_continue_offline)
	_loading_actions.add_child(offline)
	v.add_child(_loading_actions)

	var note := UI.label("Données publiques : NVD (NIST) · cache local · DÉMO · FICTIF",
		11, UI.TEXT_3, false, true)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(note)

func _start_loading() -> void:
	_pages_layer.modulate.a = 0.0
	_nav_layer.modulate.a = 0.0
	if _loader == null:
		_loader = AppLoader.new()
		_loader.name = "AppLoader"
		add_child(_loader)
		_loader.progress_changed.connect(_on_progress)
		_loader.failed.connect(_on_load_failed)
		_loader.completed.connect(_on_load_completed)
	_loading_error.visible = false
	_loading_actions.visible = false
	_loading_spinner.visible = true
	_loading_bar.value = 0.0
	_loading_percent.text = "0 %"
	_loader.run()

func _on_progress(ratio: float, label: String) -> void:
	_loading_bar.value = ratio * 100.0
	_loading_percent.text = "%d %%" % int(round(ratio * 100.0))
	_loading_status.text = label

func _on_load_failed(message: String) -> void:
	_loading_spinner.visible = false
	_loading_status.text = "Chargement incomplet"
	_loading_error.text = message
	_loading_error.add_theme_color_override("font_color", UI.DANGER)
	_loading_error.visible = true
	_loading_actions.visible = true

func _on_load_completed(with_warnings: bool, summary: String) -> void:
	if with_warnings:
		_loading_status.text = "Chargé (mode dégradé)"
		_loading_error.text = summary
		_loading_error.add_theme_color_override("font_color", UI.TEXT_2)
		_loading_error.visible = true
	else:
		_loading_status.text = "Terminé"
	_loading_spinner.visible = false
	await get_tree().create_timer(0.45).timeout
	_hide_loading()

func _hide_loading() -> void:
	# L'interface est déjà prête : on ne capture plus aucun appui pendant le fondu.
	_loading_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var t := create_tween().set_parallel(true)
	t.tween_property(_loading_layer, "modulate:a", 0.0, 0.4)
	t.tween_property(_pages_layer, "modulate:a", 1.0, 0.45)
	t.tween_property(_nav_layer, "modulate:a", 1.0, 0.45)
	t.chain().tween_callback(func() -> void:
		_loading_layer.visible = false
		_loading_layer.queue_free()
		_pages_layer.modulate = Color(1, 1, 1, 1))

func _on_retry() -> void:
	_set_loading_actions_visible(false)
	_loading_error.visible = false
	_loading_spinner.visible = true
	_loading_status.text = "Nouvelle tentative…"
	_loading_bar.value = 0.0
	_loading_percent.text = "0 %"
	_loader.run()

func _on_continue_offline() -> void:
	_set_loading_actions_visible(false)
	_loader.continue_offline()

func _set_loading_actions_visible(v: bool) -> void:
	_loading_actions.visible = v

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
	sb.bg_color = Color(0.063, 0.094, 0.157, 0.94)
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
	if _toast == null:
		return
	_toast.text = message
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_property(_toast_panel, "modulate:a", 1.0, 0.18)
	_toast_tween.tween_interval(1.6)
	_toast_tween.tween_property(_toast_panel, "modulate:a", 0.0, 0.3)