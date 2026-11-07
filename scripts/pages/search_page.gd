class_name SearchPage
extends AppPage
## Onglet Recherche — catalogue réel, filtres multiples via un seul bouton.

const DEFAULT_FILTERS := {
	"severities": [],
	"software_ids": [],
	"period": "all",
	"min_score": 0.0,
	"sort": "score",
	"saved_only": false,
}

var _query: String = ""
var _filters: Dictionary = DEFAULT_FILTERS.duplicate(true)
var _error: String = ""
var _status: String = ""
var _count_label: Label
var _summary_label: Label
var _results_box: VBoxContainer
var _online_button: Button
var _filter_button: Button

func page_title() -> String:
	return "Recherche"

func page_subtitle() -> String:
	return "Catalogue de failles"

func build() -> void:
	DataStore.data_changed.connect(refresh)
	DataStore.loading_changed.connect(_on_loading)
	DataStore.fetch_finished.connect(_on_fetch)
	refresh()

func refresh() -> void:
	clear_content()

	var field := UI.line_edit("Rechercher une faille…")
	field.name = "SearchField"
	field.text = _query
	field.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_DEFAULT
	field.text_changed.connect(_on_text)
	field.text_submitted.connect(_on_submitted)
	content.add_child(field)

	content.add_child(_build_online_row())
	content.add_child(_build_filter_row())

	if _error != "":
		content.add_child(UI.label(_error, 12, UI.DANGER, false, true))
	if _status != "":
		content.add_child(UI.label(_status, 12, UI.TEXT_2, false, true))

	_count_label = UI.label("", 13, UI.TEXT_2)
	content.add_child(_count_label)

	_results_box = UI.vbox(10)
	content.add_child(_results_box)
	_apply()

func _on_submitted(_text: String) -> void:
	_close_keyboard()
	_apply()

func _close_keyboard() -> void:
	var vp := get_viewport()
	if vp != null:
		vp.gui_release_focus()
	if OS.has_feature("mobile"):
		DisplayServer.virtual_keyboard_hide()

func _build_online_row() -> Control:
	var box := UI.vbox(6)
	_online_button = UI.ghost_icon_button(UI.ICON_GLOBE, "Rechercher en ligne (NVD)", UI.ACCENT)
	_online_button.name = "OnlineButton"
	_online_button.disabled = DataStore.is_loading() or not DataStore.is_online()
	if DataStore.is_loading():
		_online_button.text = "Recherche en ligne…"
	_online_button.pressed.connect(_on_online)
	box.add_child(_online_button)
	if not DataStore.is_online():
		box.add_child(UI.label("Source en ligne désactivée", 12, UI.TEXT_2, false, true))
	return box

func _build_filter_row() -> Control:
	var row := UI.hbox(10)
	_filter_button = UI.ghost_icon_button(UI.ICON_FILTER, "Filtrer", UI.TEXT)
	_filter_button.name = "FilterButton"
	_filter_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_filter_button.pressed.connect(_on_filter_pressed)
	row.add_child(_filter_button)
	_summary_label = UI.label(_filter_summary(), 12, UI.TEXT_2, false, true)
	_summary_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_summary_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_summary_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(_summary_label)
	return row

func _filter_summary() -> String:
	var parts: Array = []
	for k in _filters.get("severities", []):
		parts.append(UI.sev_label(str(k)))
	var sw: Array = _filters.get("software_ids", [])
	if not sw.is_empty():
		parts.append("%d logiciel(s)" % sw.size())
	if bool(_filters.get("saved_only", false)):
		parts.append("enregistrées")
	var period := str(_filters.get("period", "all"))
	if period != "all":
		parts.append(period + " j" if period != "365" else "1 an")
	var min_score := float(_filters.get("min_score", 0.0))
	if min_score > 0.0:
		parts.append("≥ %d" % int(min_score))
	if parts.is_empty():
		return "Aucun filtre"
	return " · ".join(parts)

func _on_filter_pressed() -> void:
	_close_keyboard()
	var main := get_tree().current_scene
	if main != null and main.has_method("open_filter_sheet"):
		main.open_filter_sheet(_filters)

## Appelé par le panneau de filtres : mise à jour de la liste uniquement.
func apply_filters(filters: Dictionary) -> void:
	_filters = filters.duplicate(true)
	if _summary_label != null:
		_summary_label.text = _filter_summary()
	_apply()

func _on_online() -> void:
	_error = ""
	_status = "Interrogation du NVD…"
	DataStore.search_online(_query)
	refresh()

func _on_loading(_is_loading: bool) -> void:
	_apply()

func _on_fetch(ok: bool, message: String, _source: String) -> void:
	if ok:
		_status = message
		_error = ""
	else:
		_error = message
		_status = ""
	refresh()

func _on_text(t: String) -> void:
	_query = t
	_apply()

func _apply() -> void:
	if _results_box == null:
		return
	for c in _results_box.get_children():
		_results_box.remove_child(c)
		c.queue_free()

	# Chargement réel en cours : structure affichée (squelettes), puis données.
	if DataStore.is_loading():
		if _count_label != null:
			_count_label.text = "Chargement…"
		_results_box.add_child(UI.skeleton_list(4))
		return

	if DataStore.vulnerabilities.is_empty():
		if _count_label != null:
			_count_label.text = ""
		_results_box.add_child(UI.empty_state(
			"Aucune donnée disponible",
			"Lancez une recherche en ligne pour récupérer les données réelles.", UI.ICON_SEARCH))
		return

	var list := _filtered()
	_count_label.text = "%d faille%s" % [list.size(), "" if list.size() == 1 else "s"]

	if list.is_empty():
		_results_box.add_child(UI.empty_state("Aucun résultat",
			"Modifiez le filtre ou le terme recherché.", UI.ICON_SEARCH))
		return

	if DataStore.has_real_data():
		_results_box.add_child(UI.badge("Source : NVD (NIST)", UI.ACCENT))

	for v in list:
		_results_box.add_child(UI.vuln_card(v, _open.bind(str(v.get("id", "")))))
	UI.stagger_in(_results_box, 6)

func _filtered() -> Array:
	var q := _query.strip_edges().to_lower()
	var severities: Array = _filters.get("severities", [])
	var software_ids: Array = _filters.get("software_ids", [])
	var period := str(_filters.get("period", "all"))
	var min_score := float(_filters.get("min_score", 0.0))
	var sort_key := str(_filters.get("sort", "score"))
	var saved_only := bool(_filters.get("saved_only", false))

	var names: Array = []
	for id in software_ids:
		for s in DataStore.software:
			if str(s.get("id", "")) == str(id):
				names.append(str(s.get("name", "")).to_lower())

	var cutoff := 0
	if period != "all":
		cutoff = int(Time.get_unix_time_from_system()) - int(period) * 86400

	var out: Array = []
	for v in DataStore.vulnerabilities:
		if not severities.is_empty() and not severities.has(str(v.get("severity", ""))):
			continue
		if min_score > 0.0 and float(v.get("score", 0.0)) < min_score:
			continue
		if cutoff > 0:
			var d := str(v.get("date", ""))
			if d.length() < 10:
				continue
			if int(Time.get_unix_time_from_datetime_string(d)) < cutoff:
				continue
		if not names.is_empty():
			var prod := str(v.get("product", "")).to_lower()
			var matched := false
			for n in names:
				if n != "" and (prod == n or prod.contains(n) or n.contains(prod)):
					matched = true
					break
			if not matched:
				continue
		if saved_only and not DataStore.is_saved(str(v.get("id", ""))):
			continue
		if q != "":
			var hay := "%s %s %s %s" % [str(v.get("title", "")), str(v.get("product", "")), str(v.get("id", "")), str(v.get("summary", ""))]
			if not hay.to_lower().contains(q):
				continue
		out.append(v)

	match sort_key:
		"date":
			out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
				return str(a.get("date", "")) > str(b.get("date", "")))
		"severity":
			out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
				return _sev_rank(str(a.get("severity", ""))) > _sev_rank(str(b.get("severity", ""))))
		_:
			out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
				return float(a.get("score", 0.0)) > float(b.get("score", 0.0)))
	return out

func _sev_rank(key: String) -> int:
	match key:
		"critique": return 4
		"elevee": return 3
		"moyenne": return 2
		"faible": return 1
	return 0

## Ouvre le détail par-dessus l'écran courant (on reste dans le contexte).
func _open(id: String) -> void:
	var main := get_tree().current_scene
	if main != null and main.has_method("open_detail_sheet"):
		main.open_detail_sheet(id)
