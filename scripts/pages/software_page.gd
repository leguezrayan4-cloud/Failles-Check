class_name SoftwarePage
extends AppPage
## Mes logiciels — recherche assistée, favoris, détails et statistiques réelles.

const DEBOUNCE := 0.35

var _query: String = ""
var _error: String = ""
var _status: String = ""
var _suggestions: Array = []
var _only_favorites := false
var _field: LineEdit
var _status_label: Label
var _sugg_box: VBoxContainer
var _list: VBoxContainer
var _debounce: Timer

func page_title() -> String:
	return Loc.t("software_title")

func page_subtitle() -> String:
	return Loc.t("software_sub")

func build() -> void:
	DataStore.data_changed.connect(refresh)
	var cat := DataStore.catalog()
	if cat != null and not cat.remote_ready.is_connected(_on_remote_ready):
		cat.remote_ready.connect(_on_remote_ready)
	_debounce = Timer.new()
	_debounce.one_shot = true
	_debounce.wait_time = DEBOUNCE
	add_child(_debounce)
	_debounce.timeout.connect(_request_remote)
	refresh(true)

func refresh(stagger: bool = false) -> void:
	clear_content()
	_recompute_status()

	_field = UI.line_edit("Nom du logiciel")
	_field.name = "SoftwareSearchField"
	_field.text = _query
	_field.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_DEFAULT
	_field.text_changed.connect(_on_text_changed)
	_field.text_submitted.connect(_on_submitted)
	content.add_child(_field)

	if _error != "":
		content.add_child(UI.label(_error, 12, UI.DANGER, false, true))

	_status_label = UI.label(_status, 12, UI.TEXT_2, false, true)
	_status_label.visible = _status != ""
	content.add_child(_status_label)

	_sugg_box = UI.vbox(8)
	content.add_child(_sugg_box)
	_render_suggestions()

	_list = UI.vbox(10)
	content.add_child(_list)
	_render_list()
	if stagger:
		UI.stagger_in(content, 6)

# --- Saisie ----------------------------------------------------------------
func _on_text_changed(t: String) -> void:
	_query = t
	_error = ""
	var q := _query.strip_edges()
	_suggestions = SoftwareCatalog.local_suggestions(q) if q != "" else []
	_recompute_status()
	_refresh_status_label()
	_render_suggestions()
	if _debounce != null:
		_debounce.stop()
		if q.length() >= 2 and DataStore.is_online():
			_debounce.start()

## Validation au clavier (touche Entrée) : ajoute la première suggestion.
func _on_submitted(_text: String) -> void:
	_close_keyboard()
	if not _suggestions.is_empty():
		_add_from_suggestion(_suggestions[0])

func _close_keyboard() -> void:
	var vp := get_viewport()
	if vp != null:
		vp.gui_release_focus()
	if OS.has_feature("mobile"):
		DisplayServer.virtual_keyboard_hide()

func _request_remote() -> void:
	var q := _query.strip_edges()
	if q.length() < 2 or not DataStore.is_online():
		return
	var cat := DataStore.catalog()
	if cat != null:
		cat.request_remote(q)

func _on_remote_ready(query: String, items: Array) -> void:
	if query != _query.strip_edges():
		return
	var merged: Array = []
	var seen := {}
	for item in _suggestions:
		seen[str(item.get("name", "")).to_lower()] = true
		merged.append(item)
	for item in items:
		var key := str(item.get("name", "")).to_lower()
		if key == "" or seen.has(key):
			continue
		seen[key] = true
		merged.append(item)
	_suggestions = merged
	_recompute_status()
	_refresh_status_label()
	_render_suggestions()

func _recompute_status() -> void:
	var q := _query.strip_edges()
	if q == "":
		_status = ""
	elif _suggestions.is_empty():
		_status = "Aucun logiciel correspondant."
	else:
		_status = ""

func _refresh_status_label() -> void:
	if _status_label == null:
		return
	_status_label.text = _status
	_status_label.visible = _status != ""

# --- Suggestions -----------------------------------------------------------
func _render_suggestions() -> void:
	if _sugg_box == null:
		return
	for c in _sugg_box.get_children():
		_sugg_box.remove_child(c)
		c.queue_free()
	var q := _query.strip_edges()
	if q == "":
		return

	if not _suggestions.is_empty():
		for item in _suggestions:
			_sugg_box.add_child(_suggestion_card(item))

	UI.stagger_in(_sugg_box, 6)

func _suggestion_card(item: Dictionary) -> TapCard:
	var card := UI.tap_card(64, 14)
	var row := UI.hbox(12)
	var ic := UI.icon(UI.ICON_SOFTWARE, 22, UI.ACCENT)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(ic)
	var mid := UI.vbox(2)
	mid.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mid.add_child(UI.label(str(item.get("name", "")), 15, UI.TEXT, true, true))
	var parts: Array = []
	var editor := str(item.get("editor", ""))
	if editor != "":
		parts.append(editor)
	var version := str(item.get("version", ""))
	if version != "":
		parts.append("v" + version)
	var sub := " · ".join(parts)
	if sub != "":
		mid.add_child(UI.label(sub, 12, UI.TEXT_2, false, true))
	row.add_child(mid)
	if str(item.get("source", "")) == "NVD":
		row.add_child(UI.badge("NVD", UI.ACCENT))
	UI.overlay(card, row, 14)
	card.tapped.connect(_add_from_suggestion.bind(item))
	return card

func _add_from_suggestion(item: Dictionary) -> void:
	var err := DataStore.add_software(
		str(item.get("name", "")),
		str(item.get("version", "")),
		str(item.get("editor", "")),
		str(item.get("identifier", "")))
	if err != "":
		_error = err
		refresh()
		return
	_error = ""
	_query = ""
	_suggestions = []
	refresh()

# --- Liste des logiciels suivis --------------------------------------------
func _render_list() -> void:
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()

	var seg := UI.hbox(8)
	var all_chip := UI.chip("Tous", not _only_favorites)
	all_chip.tapped.connect(_set_favorites_only.bind(false))
	seg.add_child(all_chip)
	var fav_chip := UI.chip("Favoris", _only_favorites)
	fav_chip.tapped.connect(_set_favorites_only.bind(true))
	seg.add_child(fav_chip)
	seg.add_child(UI.spacer())
	_list.add_child(seg)

	var items: Array = DataStore.favorites() if _only_favorites else DataStore.software
	_list.add_child(UI.section_title("Logiciels (%d)" % items.size()))

	if items.is_empty():
		_list.add_child(UI.empty_state("Aucun logiciel",
			"Cherchez un nom puis touchez une suggestion." if not _only_favorites else "Aucun favori pour le moment.",
			UI.ICON_APPS))
		return

	for s in items:
		_list.add_child(_software_card(s))
	# Chargement en cours : une carte squelette indique l'activité.
	if DataStore.is_loading():
		_list.add_child(UI.skeleton_software_card())

## Changement de filtre : on ne reconstruit que la liste (aucun rechargement
## de page, aucun clignotement).
func _set_favorites_only(value: bool) -> void:
	_only_favorites = value
	_render_list()

func _software_card(s: Dictionary) -> Control:
	var id := str(s.get("id", ""))
	var app_name := str(s.get("name", ""))
	var vulns := DataStore.vulns_for_software(app_name)

	var card := UI.card(12)
	var row := UI.hbox(10)

	# Zone « détails » : icône + textes (tactile, sans fond).
	var details := UI.flat_tap()
	details.custom_minimum_size = Vector2(0, 52)
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var inner := UI.hbox(12)
	var ic := UI.icon(UI.ICON_SOFTWARE, 24, UI.ACCENT)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	inner.add_child(ic)
	var v := UI.vbox(3)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	v.add_child(UI.label(app_name, 15, UI.TEXT, true, true))
	var parts: Array = []
	if str(s.get("editor", "")) != "":
		parts.append(str(s.get("editor", "")))
	if str(s.get("version", "")) != "":
		parts.append("v" + str(s.get("version", "")))
	v.add_child(UI.label(" · ".join(parts) if not parts.is_empty() else "—", 12, UI.TEXT_2, false, true))
	v.add_child(UI.label("%d vulnérabilité(s)" % vulns.size(), 11, UI.TEXT_3))
	inner.add_child(v)
	UI.overlay(details, inner, 0)
	details.tapped.connect(_open_details.bind(id))
	row.add_child(details)

	var fav_on := DataStore.is_favorite(id)
	var heart := UI.icon_button(UI.ICON_HEART if fav_on else UI.ICON_HEART_OUTLINE, 38,
		UI.DANGER if fav_on else UI.TEXT_3,
		Color(0.988, 0.937, 0.937) if fav_on else UI.CARD_SOFT)
	heart.name = "Fav_%s" % id
	heart.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	heart.tapped.connect(_on_favorite.bind(id))
	row.add_child(heart)

	var del := UI.icon_button(UI.ICON_TRASH, 38, UI.DANGER, Color(0.988, 0.937, 0.937))
	del.name = "Del_%s" % id
	del.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	del.tapped.connect(_on_delete.bind(id))
	row.add_child(del)

	card.add_child(row)
	return card

func _on_favorite(id: String) -> void:
	DataStore.toggle_favorite(id)

func _open_details(id: String) -> void:
	var main := get_tree().current_scene
	if main != null and main.has_method("open_software_sheet"):
		main.open_software_sheet(id)

func _on_delete(id: String) -> void:
	var main := get_tree().current_scene
	if main != null and main.has_method("confirm_delete_software"):
		main.confirm_delete_software(id)
