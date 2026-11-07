class_name SoftwarePage
extends AppPage
## Mes logiciels — recherche assistée.
## On tape seulement le nom : des suggestions apparaissent pendant la saisie
## (liste locale hors ligne, complétée par le dictionnaire CPE public du NVD).
## Choisir une suggestion remplit automatiquement éditeur, version et
## identifiant. L'ajout manuel reste possible. Doublons refusés.

const DEBOUNCE := 0.35

var _query: String = ""
var _error: String = ""
var _status: String = ""
var _suggestions: Array = []
var _field: LineEdit
var _status_label: Label
var _sugg_box: VBoxContainer
var _list: VBoxContainer
var _debounce: Timer

func page_title() -> String:
	return "Mes logiciels"

func page_subtitle() -> String:
	return "Rechercher un logiciel à suivre"

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
	refresh()

func refresh() -> void:
	clear_content()
	_recompute_status()

	_field = UI.line_edit("Nom du logiciel")
	_field.name = "SoftwareSearchField"
	_field.text = _query
	_field.text_changed.connect(_on_text_changed)
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

## Message court, affiché seulement s'il apporte une information utile.
func _recompute_status() -> void:
	var q := _query.strip_edges()
	if q == "":
		_status = ""
	elif _suggestions.is_empty():
		_status = "Aucun résultat — ajoutez-le manuellement."
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

	var manual := UI.tap_card(56, 14)
	var row := UI.hbox(10)
	var ic := UI.icon(UI.ICON_PLUS, 20, UI.ACCENT)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(ic)
	var mid := UI.vbox(2)
	mid.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mid.add_child(UI.label("Ajouter « %s »" % q, 15, UI.TEXT, true, true))
	row.add_child(mid)
	UI.overlay(manual, row, 14)
	manual.tapped.connect(_add_manual)
	_sugg_box.add_child(manual)
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
		mid.add_child(UI.label(sub, 12, UI.TEXT_2))
	row.add_child(mid)
	# Étiquette uniquement pour les résultats venus du NVD : le catalogue local
	# est le fonctionnement normal, aucune mention superflue.
	if str(item.get("source", "")) == "NVD":
		row.add_child(UI.badge("NVD", UI.ACCENT))
	UI.overlay(card, row, 14)
	card.tapped.connect(_add_from_suggestion.bind(item))
	return card

func _add_manual() -> void:
	_add_from_suggestion({"name": _query.strip_edges()})

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

	_list.add_child(UI.section_title("Logiciels (%d)" % DataStore.software.size()))

	if DataStore.software.is_empty():
		_list.add_child(UI.empty_state("Aucun logiciel",
			"Cherchez un nom puis touchez une suggestion.", UI.ICON_APPS))
		return

	for s in DataStore.software:
		_list.add_child(_software_card(s))

func _software_card(s: Dictionary) -> PanelContainer:
	var p := UI.card(14)
	var row := UI.hbox(12)
	var v := UI.vbox(3)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	v.add_child(UI.label(str(s.get("name", "")), 15, UI.TEXT, true, true))
	var parts: Array = []
	if str(s.get("version", "")) != "":
		parts.append(str(s.get("version", "")))
	if str(s.get("editor", "")) != "":
		parts.append(str(s.get("editor", "")))
	v.add_child(UI.label(" · ".join(parts) if not parts.is_empty() else "—", 12, UI.TEXT_2))
	row.add_child(v)
	# Icône vectorielle nette (rastérisée en 3×), contour fin et état appuyé.
	var del := UI.icon_button(UI.ICON_TRASH, 42, UI.DANGER, Color(0.988, 0.937, 0.937))
	del.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	del.tapped.connect(_on_delete.bind(str(s.get("id", ""))))
	row.add_child(del)
	p.add_child(row)
	return p

func _on_delete(id: String) -> void:
	DataStore.remove_software(id)