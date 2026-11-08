class_name SettingsPage
extends AppPage
## Onglet Paramètres — blocs arrondis style Réglages iOS.
## Chaque ligne : icône sobre, intitulé, puis valeur, interrupteur ou flèche.
## Les réglages s'appliquent immédiatement (aucun bouton « Enregistrer »).

func page_title() -> String:
	return Loc.t("settings_title")

func page_subtitle() -> String:
	return Loc.t("settings_sub")

func build() -> void:
	DataStore.data_changed.connect(refresh)
	DataStore.auth_changed.connect(refresh)
	refresh()

func refresh() -> void:
	clear_content()
	content.add_child(_account_block())
	content.add_child(_appearance_block())
	content.add_child(_notifications_block())
	if not OS.has_feature("mobile"):
		content.add_child(_scroll_block())
	content.add_child(_about_block())
	UI.stagger_in(content, 4)

# --- Blocs ----------------------------------------------------------------
func _account_block() -> Control:
	var signed_in := DataStore.auth.is_signed_in()
	var title := Loc.t("row_account")
	var value := ""
	if signed_in:
		title = DataStore.auth.display_name() if DataStore.auth.display_name() != "" else DataStore.auth.email()
		value = DataStore.auth.email()
	elif DataStore.last_email() != "":
		title = DataStore.last_email()
	var rows: Array = [
		_nav_row(UI.ICON_PERSON, title, value, func() -> void: _open_account()),
	]
	if signed_in:
		rows.append(_nav_row(UI.ICON_GLOBE, Loc.t("row_devices"), "", func() -> void: _open_devices()))
	return _block(Loc.t("sec_account"), rows)

func _appearance_block() -> Control:
	var rows: Array = [
		_switch_row(UI.ICON_SETTINGS, Loc.t("row_reduced_transparency"),
			DataStore.is_reduce_transparency(), "TransparencySwitch", _on_transparency),
		_nav_row(UI.ICON_GLOBE, Loc.t("row_language"),
			Loc.t("french") if DataStore.language() == "fr" else Loc.t("english"),
			func() -> void: _open_language()),
	]
	return _block(Loc.t("sec_appearance"), rows)

func _notifications_block() -> Control:
	var rows: Array = [
		_switch_row(UI.ICON_BELL, Loc.t("row_alerts"),
			DataStore.notifications_enabled(), "NotificationsSwitch", _on_notifications),
	]
	return _block(Loc.t("sec_notifications"), rows)

func _about_block() -> Control:
	var rows: Array = [
		_nav_row(UI.ICON_SHIELD, Loc.t("row_guide"), "", func() -> void: _open_guide()),
		_info_row(UI.ICON_APPS, Loc.t("row_version"), "1.0"),
		_info_row(UI.ICON_DATABASE, Loc.t("row_source"), "NVD (NIST)"),
		_nav_row(UI.ICON_SHIELD, Loc.t("row_legal"), "", func() -> void: _open_legal()),
	]
	return _block(Loc.t("sec_help"), rows)

## Section réservée à l'ordinateur : choix du défilement à la souris.
func _scroll_block() -> Control:
	var rows: Array = [
		_switch_row(UI.ICON_APPS, "Glisser en maintenant le clic",
			bool(DataStore.settings.get("scroll_drag", true)), "ScrollDragSwitch", _on_scroll_drag),
		_switch_row(UI.ICON_APPS, "Molette de la souris",
			bool(DataStore.settings.get("scroll_wheel", true)), "ScrollWheelSwitch", _on_scroll_wheel),
	]
	return _block("Défilement", rows)

func _on_scroll_drag(value: bool) -> void:
	DataStore.settings["scroll_drag"] = value
	DataStore.save_data()

func _on_scroll_wheel(value: bool) -> void:
	DataStore.settings["scroll_wheel"] = value
	DataStore.save_data()

# --- Fabrique de lignes ---------------------------------------------------
func _block(title: String, rows: Array) -> Control:
	var v := UI.vbox(8)
	if title != "":
		v.add_child(UI.section_title(title))
	var card := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 1)
	sb.set_corner_radius_all(16)
	sb.set_content_margin_all(0)
	sb.border_color = UI.BORDER
	sb.set_border_width_all(1)
	card.add_theme_stylebox_override("panel", sb)
	var inner := UI.vbox(0)
	inner.add_theme_constant_override("separation", 0)
	var i := 0
	for r in rows:
		if i > 0:
			var line := ColorRect.new()
			line.color = Color(UI.BORDER.r, UI.BORDER.g, UI.BORDER.b, 0.7)
			line.custom_minimum_size = Vector2(0, 1)
			inner.add_child(line)
		inner.add_child(r)
		i += 1
	card.add_child(inner)
	v.add_child(card)
	return v

func _icon_box(svg: String) -> Control:
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(30, 30)
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var sb := StyleBoxFlat.new()
	sb.bg_color = UI.ACCENT
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(0)
	p.add_theme_stylebox_override("panel", sb)
	var ic := UI.icon(svg, 17, Color.WHITE)
	ic.position = Vector2(6, 6)
	p.add_child(ic)
	return p

func _row_shell(svg: String, title: String, right: Control) -> Control:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 14)
	m.add_theme_constant_override("margin_right", 14)
	m.add_theme_constant_override("margin_top", 11)
	m.add_theme_constant_override("margin_bottom", 11)
	var row := UI.hbox(12)
	m.add_child(row)
	row.add_child(_icon_box(svg))
	var t := UI.label(title, 15, UI.TEXT, false, true)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(t)
	if right != null:
		right.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(right)
	return m

func _nav_row(svg: String, title: String, value: String, on_press: Callable, danger: bool = false) -> Control:
	var right := UI.hbox(6)
	right.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if value != "":
		var v := UI.label(value, 13, UI.DANGER if danger else UI.TEXT_3, false, true)
		v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		right.add_child(v)
	var chev := UI.icon(UI.ICON_CHEVRON, 13, UI.TEXT_3)
	chev.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	right.add_child(chev)
	var shell := _row_shell(svg, title, right)
	if danger:
		var t := shell.get_child(0).get_child(1)
		if t is Label:
			(t as Label).add_theme_color_override("font_color", UI.DANGER)
	var card := TapCard.new()
	# Ligne transparente : seul le bloc blanc porte le fond.
	card.set_styles(StyleBoxEmpty.new(), _row_hover(), _row_pressed())
	card.add_child(shell)
	card.tapped.connect(func() -> void:
		Haptics.tap()
		on_press.call())
	return card

func _row_hover() -> StyleBox:
	return UI.stylebox(Color(UI.ACCENT.r, UI.ACCENT.g, UI.ACCENT.b, 0.05), 0, 0, Color(0, 0, 0, 0), 0)

func _row_pressed() -> StyleBox:
	return UI.stylebox(Color(UI.ACCENT.r, UI.ACCENT.g, UI.ACCENT.b, 0.10), 0, 0, Color(0, 0, 0, 0), 0)

func _info_row(svg: String, title: String, value: String) -> Control:
	var v := UI.label(value, 13, UI.TEXT_3, false, true)
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	return _row_shell(svg, title, v)

func _switch_row(svg: String, title: String, on: bool, node_name: String, handler: Callable) -> Control:
	var sw := UI.switch_button(on)
	sw.name = node_name
	sw.toggled.connect(func(value: bool) -> void:
		Haptics.tap()
		handler.call(value))
	return _row_shell(svg, title, sw)

# --- Actions --------------------------------------------------------------
func _cache_text() -> String:
	var info := DataStore.cache_info()
	return "%d" % int(info.get("count", 0))

func _main() -> Node:
	return get_tree().current_scene

func _open_account() -> void:
	if _main() != null and _main().has_method("open_account_sheet"):
		_main().open_account_sheet()

func _open_devices() -> void:
	_push_sub(Loc.t("row_devices"), func(body: VBoxContainer) -> void:
		var card := UI.card(16)
		var v := UI.vbox(6)
		v.add_child(UI.label(OS.get_model_name(), 15, UI.TEXT, true, true))
		v.add_child(UI.label(DataStore.auth.email(), 12, UI.TEXT_2, false, true))
		card.add_child(v)
		body.add_child(card)
		body.add_child(UI.label("Les autres appareils apparaîtront ici dès qu'ils se connecteront au même compte. La déconnexion à distance sera disponible après déploiement de la fonction de gestion des sessions.",
			12, UI.TEXT_2, false, true)))

func _open_language() -> void:
	var sub := SubPage.new()
	sub.name = "LangSubPage"
	sub.z_index = Z_SUB
	add_child(sub)
	sub.open_with(Loc.t("row_language"), func(body: VBoxContainer) -> void: _fill_language(body, sub))

func _fill_language(body: VBoxContainer, sub: SubPage) -> void:
	for d in [["fr", Loc.t("french")], ["en", Loc.t("english")]]:
		var key := str(d[0])
		var label_txt := str(d[1])
		var row := TapCard.new()
		var card := UI.card(14)
		var h := UI.hbox(10)
		var l := UI.label(label_txt, 15, UI.TEXT, true, true)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(l)
		if DataStore.language() == key:
			var check := UI.label("✓", 16, UI.ACCENT, true)
			check.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			h.add_child(check)
		card.add_child(h)
		row.add_child(card)
		row.tapped.connect(func() -> void:
			DataStore.set_language(key)
			Haptics.tap()
			refresh()
			sub.open_with(Loc.t("row_language"), func(b: VBoxContainer) -> void: _fill_language(b, sub)))
		body.add_child(row)
	body.add_child(UI.label(Loc.t("language_desc"), 12, UI.TEXT_3, false, true))

func _open_legal() -> void:
	_push_sub(Loc.t("row_legal"), func(body: VBoxContainer) -> void:
		body.add_child(UI.text_section("NVD (NIST)", "Les données de vulnérabilités proviennent de la base nationale américaine NVD (nvd.nist.gov), publiée par le NIST. FaillesCheck n'invente aucune faille : seules les données de cette source et celles saisies par vous sont affichées."))
		body.add_child(UI.text_section(Loc.t("row_source"), "Les traductions et réponses de la section IA sont fournies par un assistant et ne remplacent pas l'avis d'un professionnel de sécurité.")))

func _push_sub(title: String, builder: Callable) -> void:
	var sub := SubPage.new()
	sub.name = "SettingsSubPage"
	sub.z_index = Z_SUB
	add_child(sub)
	sub.open_with(title, builder)

func _open_guide() -> void:
	if _main() != null and _main().has_method("show_guide"):
		_main().show_guide()

func _on_clear_local() -> void:
	if _main() == null or not _main().has_method("confirm_clear_local"):
		return
	_main().confirm_clear_local()

func _on_transparency(value: bool) -> void:
	DataStore.set_reduce_transparency(value)

func _on_notifications(value: bool) -> void:
	DataStore.set_notifications(value)

func _on_sync() -> void:
	DataStore.start_busy("Synchronisation…")
	var res: Dictionary = await DataStore.sync_now()
	DataStore.end_busy()
	DataStore.toast.emit("Synchronisé" if bool(res.get("ok", false)) else str(res.get("error", "Synchronisation impossible.")))
	refresh()

func _on_clear_cache() -> void:
	DataStore.clear_cache()
	refresh()

func _on_export() -> void:
	if _main() != null and _main().has_method("open_export_sheet"):
		_main().open_export_sheet()

const Z_SUB := 40
