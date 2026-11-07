class_name DetailSheet
extends Control
## FaillesCheck — panneau de détail présenté par-dessus l'écran courant.
## Ouverture / fermeture animées, bouton Retour en haut à gauche,
## contenu défilant au doigt (aucune barre de défilement).

signal closed

const SHEET_RATIO := 0.90

var _backdrop: ColorRect
var _panel: PanelContainer
var _body: VBoxContainer
var _is_open := false
var _tween: Tween

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false

	_backdrop = ColorRect.new()
	_backdrop.name = "SheetBackdrop"
	# Voile semi-transparent : la page précédente reste visible mais désactivée
	# (opacité renforcée si l'accessibilité « transparence réduite » est active).
	_backdrop.color = Color(0.03, 0.05, 0.10, 0.55 if UI.transparency_reduced else 0.42)
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_backdrop.z_index = 0
	_backdrop.gui_input.connect(_on_backdrop_input)
	add_child(_backdrop)

	_panel = PanelContainer.new()
	_panel.name = "SheetPanel"
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.z_index = 1
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.976, 0.980, 0.988)
	sb.corner_radius_top_left = 24
	sb.corner_radius_top_right = 24
	sb.set_content_margin_all(0)
	sb.shadow_color = Color(0, 0, 0, 0.28)
	sb.shadow_size = 18
	_panel.add_theme_stylebox_override("panel", sb)
	add_child(_panel)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 0)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(root)

	var handle_margin := MarginContainer.new()
	handle_margin.add_theme_constant_override("margin_top", 9)
	handle_margin.add_theme_constant_override("margin_bottom", 5)
	handle_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(handle_margin)
	var handle := PanelContainer.new()
	handle.custom_minimum_size = Vector2(42, 5)
	handle.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var hsb := StyleBoxFlat.new()
	hsb.bg_color = Color(0.78, 0.80, 0.84)
	hsb.set_corner_radius_all(3)
	hsb.set_content_margin_all(0)
	handle.add_theme_stylebox_override("panel", hsb)
	handle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	handle_margin.add_child(handle)

	var bar_margin := MarginContainer.new()
	bar_margin.add_theme_constant_override("margin_left", 14)
	bar_margin.add_theme_constant_override("margin_right", 14)
	bar_margin.add_theme_constant_override("margin_bottom", 4)
	bar_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bar_margin)
	var bar_row := UI.hbox(8)
	bar_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_margin.add_child(bar_row)
	var back := UI.back_button()
	back.name = "SheetBackButton"
	back.pressed.connect(_on_back_pressed)
	bar_row.add_child(back)
	bar_row.add_child(UI.spacer())

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	scroll.scroll_deadzone = 8
	root.add_child(scroll)

	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 30)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scroll.add_child(margin)

	_body = UI.vbox(12)
	margin.add_child(_body)

	resized.connect(_layout)

func is_open() -> bool:
	return _is_open

func _layout() -> void:
	var h := size.y * SHEET_RATIO
	_panel.size = Vector2(size.x, h)
	_panel.position = Vector2(0, size.y - h) if _is_open else Vector2(0, size.y)

func show_detail(v: Dictionary) -> void:
	if v.is_empty():
		return
	_fill(v)
	visible = true
	_is_open = true
	_layout()
	_panel.position = Vector2(0, size.y)
	_backdrop.modulate.a = 0.0
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(_backdrop, "modulate:a", 1.0, 0.26)
	_tween.tween_property(_panel, "position:y", size.y - _panel.size.y, 0.34).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	UI.stagger_in(_body, 6)

func close() -> void:
	if not _is_open:
		return
	_is_open = false
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(_backdrop, "modulate:a", 0.0, 0.24)
	_tween.tween_property(_panel, "position:y", size.y, 0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_tween.chain().tween_callback(func() -> void:
		visible = false
		closed.emit())

func _on_back_pressed() -> void:
	close()

func _on_backdrop_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		close()
	elif event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		close()

func _fill(v: Dictionary) -> void:
	for c in _body.get_children():
		_body.remove_child(c)
		c.queue_free()

	var sev := str(v.get("severity", ""))
	var col := UI.sev_color(sev)

	# En-tête
	var head := UI.card(16)
	var hv := UI.vbox(10)
	var top := UI.hbox(8)
	top.add_child(UI.badge(str(v.get("id", "—")), UI.TEXT_2))
	top.add_child(UI.spacer())
	top.add_child(UI.badge(UI.sev_label(sev), col))
	hv.add_child(top)
	hv.add_child(UI.label(str(v.get("title", "")), 19, UI.TEXT, true, true))
	# Le logiciel et sa version figurent dans la carte « Détails » ci-dessous :
	# pas de doublon dans l'en-tête.
	head.add_child(hv)
	_body.add_child(head)

	# Score
	var score_card := UI.card(16)
	var row := UI.hbox(14)
	var left := UI.vbox(2)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	left.add_child(UI.label("Score CVSS", 13, UI.TEXT_2))
	left.add_child(UI.label("Gravité %s" % UI.sev_label(sev).to_lower(), 12, UI.TEXT_3))
	row.add_child(left)
	var score := UI.label("%.1f" % float(v.get("score", 0.0)), 34, col, true)
	score.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(score)
	score_card.add_child(row)
	_body.add_child(score_card)

	# Détails utiles (l'identifiant, la gravité et le score sont déjà affichés
	# ci-dessus : pas de doublon).
	_body.add_child(UI.info_card([
		["Logiciel", str(v.get("product", "—"))],
		["Version affectée", str(v.get("version", "—"))],
		["Statut", str(v.get("status", "—"))],
		["Date", str(v.get("date", "—"))],
	]))

	_body.add_child(UI.text_section("Description", str(v.get("description", "—"))))
	_body.add_child(UI.text_section("Recommandations", str(v.get("remediation", "—"))))

	var url := str(v.get("url", ""))
	if url != "":
		_body.add_child(UI.text_section("Référence officielle", url))

	if bool(v.get("demo", false)):
		var tag := UI.demo_tag()
		tag.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		_body.add_child(tag)
	else:
		var src := UI.badge("Source : %s" % str(v.get("source", "NVD")), UI.ACCENT)
		src.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		_body.add_child(src)
