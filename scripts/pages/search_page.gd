class_name SearchPage
extends AppPage
## Onglet Recherche — catalogue filtrable par gravité et par texte.

var _query: String = ""
var _filter: String = "all"
var _error: String = ""
var _status: String = ""
var _count_label: Label
var _results_box: VBoxContainer
var _online_button: Button

func page_title() -> String:
	return "Recherche"

func page_subtitle() -> String:
	return "Explorer le catalogue de failles"

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
	field.text_changed.connect(_on_text)
	content.add_child(field)

	content.add_child(_build_online_row())

	if _error != "":
		content.add_child(UI.label(_error, 12, UI.DANGER, false, true))
	# Le message de récupération distante n'a plus de sens en mode démonstration.
	if _status != "" and not DataStore.is_demo():
		content.add_child(UI.label(_status, 12, UI.TEXT_2, false, true))

	var chips := HFlowContainer.new()
	chips.add_theme_constant_override("h_separation", 8)
	chips.add_theme_constant_override("v_separation", 8)
	chips.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var defs := [["all", "Tous"], ["critique", "Critique"], ["elevee", "Élevée"], ["moyenne", "Moyenne"], ["faible", "Faible"]]
	for d in defs:
		var c := UI.chip(str(d[1]), _filter == str(d[0]))
		c.tapped.connect(_set_filter.bind(str(d[0])))
		chips.add_child(c)
	content.add_child(chips)

	_count_label = UI.label("", 13, UI.TEXT_2)
	content.add_child(_count_label)

	_results_box = UI.vbox(10)
	content.add_child(_results_box)
	_apply()

## Bloc de recherche en ligne : bouton + aide contextuelle.
func _build_online_row() -> Control:
	if DataStore.is_demo():
		return UI.label("Mode démonstration (DÉMO · FICTIF)", 12, UI.TEXT_2, false, true)

	var box := UI.vbox(6)
	_online_button = UI.ghost_icon_button(UI.ICON_GLOBE, "Rechercher en ligne (NVD)", UI.ACCENT)
	_online_button.name = "OnlineButton"
	# Bouton désactivé (état grisé) si la source en ligne est coupée ou occupée.
	_online_button.disabled = DataStore.is_loading() or not DataStore.is_online()
	if DataStore.is_loading():
		_online_button.text = "Recherche en ligne…"
	_online_button.pressed.connect(_on_online)
	box.add_child(_online_button)
	if not DataStore.is_online():
		box.add_child(UI.label("Source en ligne désactivée", 12, UI.TEXT_2, false, true))
	return box

func _on_online() -> void:
	_error = ""
	_status = "Interrogation du NVD…"
	DataStore.search_online(_query)
	refresh()

func _on_loading(_is_loading: bool) -> void:
	refresh()

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

func _set_filter(k: String) -> void:
	_filter = k
	refresh()

func _apply() -> void:
	if _results_box == null:
		return
	for c in _results_box.get_children():
		_results_box.remove_child(c)
		c.queue_free()

	if DataStore.vulnerabilities.is_empty():
		if _count_label != null:
			_count_label.text = ""
		_results_box.add_child(UI.empty_state(
			"Aucune donnée",
			"Activez une source dans Réglages.", UI.ICON_SEARCH))
		return

	var list := _filtered()
	_count_label.text = "%d faille%s trouvée%s" % [list.size(), "" if list.size() == 1 else "s", "" if list.size() == 1 else "s"]

	if list.is_empty():
		_results_box.add_child(UI.empty_state("Aucun résultat",
			"Modifiez le filtre ou le terme recherché.", UI.ICON_SEARCH))
		return

	if DataStore.is_demo():
		_results_box.add_child(UI.demo_tag())
	elif DataStore.has_real_data():
		_results_box.add_child(UI.badge("Source : NVD (NIST)", UI.ACCENT))

	for v in list:
		_results_box.add_child(UI.vuln_card(v, _open.bind(str(v.get("id", "")))))
	UI.stagger_in(_results_box, 6)

func _filtered() -> Array:
	var q := _query.strip_edges().to_lower()
	var out: Array = []
	for v in DataStore.vulnerabilities:
		if _filter != "all" and str(v.get("severity", "")) != _filter:
			continue
		if q != "":
			var hay := "%s %s %s %s" % [str(v.get("title", "")), str(v.get("product", "")), str(v.get("id", "")), str(v.get("summary", ""))]
			if not hay.to_lower().contains(q):
				continue
		out.append(v)
	return out

## Ouvre le détail par-dessus l'écran courant (on reste dans le contexte).
func _open(id: String) -> void:
	var main := get_tree().current_scene
	if main != null and main.has_method("open_detail_sheet"):
		main.open_detail_sheet(id)