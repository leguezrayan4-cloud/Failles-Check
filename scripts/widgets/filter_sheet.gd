class_name FilterSheet
extends SheetBase
## FaillesCheck — panneau de filtres multiples.
## Gravité, logiciels favoris, période, score minimum et tri.

signal applied(filters: Dictionary)

const SEVERITIES := [
	["critique", "Critique"],
	["elevee", "Élevée"],
	["moyenne", "Moyenne"],
	["faible", "Faible"],
]
const PERIODS := [
	["all", "Tout"],
	["365", "1 an"],
	["30", "30 jours"],
	["7", "7 jours"],
]
const SCORES := [
	["0", "Tout"],
	["4", "≥ 4"],
	["7", "≥ 7"],
	["9", "≥ 9"],
]
const SORTS := [
	["score", "Score"],
	["date", "Date"],
	["severity", "Gravité"],
]

var _filters: Dictionary = {}
var _sev_chips := {}
var _sw_chips := {}
var _period_chips := {}
var _score_chips := {}
var _sort_chips := {}
var _saved_chips := {}

func sheet_title() -> String:
	return "Filtrer"

func open_with(filters: Dictionary) -> void:
	_filters = filters.duplicate(true)
	if not _filters.has("severities"):
		_filters["severities"] = []
	if not _filters.has("software_ids"):
		_filters["software_ids"] = []
	if not _filters.has("period"):
		_filters["period"] = "all"
	if not _filters.has("min_score"):
		_filters["min_score"] = 0.0
	if not _filters.has("sort"):
		_filters["sort"] = "score"
	if not _filters.has("saved_only"):
		_filters["saved_only"] = false
	clear_body()
	_sev_chips.clear()
	_sw_chips.clear()
	_period_chips.clear()
	_score_chips.clear()
	_sort_chips.clear()
	_saved_chips.clear()

	# --- Gravité (multi) ---
	_body.add_child(UI.section_title("Gravité"))
	var flow := _flow()
	for d in SEVERITIES:
		var key := str(d[0])
		var chip := UI.chip(str(d[1]), (_filters["severities"] as Array).has(key))
		chip.tapped.connect(_toggle_sev.bind(key))
		_sev_chips[key] = chip
		flow.add_child(chip)
	_body.add_child(flow)

	# --- Logiciels favoris (multi) ---
	_body.add_child(UI.section_title("Logiciels favoris"))
	var favs := DataStore.favorites()
	if favs.is_empty():
		_body.add_child(UI.label("Aucun favori pour le moment.", 12, UI.TEXT_2, false, true))
	else:
		var flow2 := _flow()
		for s in favs:
			var id := str(s.get("id", ""))
			var chip := UI.chip(str(s.get("name", "")), (_filters["software_ids"] as Array).has(id))
			chip.tapped.connect(_toggle_sw.bind(id))
			_sw_chips[id] = chip
			flow2.add_child(chip)
		_body.add_child(flow2)

	# --- Failles enregistrées (unique) ---
	_body.add_child(UI.section_title("Failles enregistrées"))
	var flow_saved := _flow()
	for d in [["false", "Toutes"], ["true", "Enregistrées"]]:
		var key := str(d[0])
		var chip := UI.chip(str(d[1]), bool(_filters["saved_only"]) == (key == "true"))
		chip.tapped.connect(_set_saved_only.bind(key == "true"))
		_saved_chips[key] = chip
		flow_saved.add_child(chip)
	_body.add_child(flow_saved)

	# --- Période (unique) ---
	_body.add_child(UI.section_title("Période"))
	var flow3 := _flow()
	for d in PERIODS:
		var key := str(d[0])
		var chip := UI.chip(str(d[1]), str(_filters["period"]) == key)
		chip.tapped.connect(_set_period.bind(key))
		_period_chips[key] = chip
		flow3.add_child(chip)
	_body.add_child(flow3)

	# --- Score minimum (unique) ---
	_body.add_child(UI.section_title("Score minimum"))
	var flow4 := _flow()
	for d in SCORES:
		var key := str(d[0])
		var chip := UI.chip(str(d[1]), is_equal_approx(float(_filters["min_score"]), float(key)))
		chip.tapped.connect(_set_score.bind(float(key)))
		_score_chips[key] = chip
		flow4.add_child(chip)
	_body.add_child(flow4)

	# --- Tri (unique) ---
	_body.add_child(UI.section_title("Trier par"))
	var flow5 := _flow()
	for d in SORTS:
		var key := str(d[0])
		var chip := UI.chip(str(d[1]), str(_filters["sort"]) == key)
		chip.tapped.connect(_set_sort.bind(key))
		_sort_chips[key] = chip
		flow5.add_child(chip)
	_body.add_child(flow5)

	# --- Filtres enregistrés ---
	_body.add_child(UI.section_title("Filtres enregistrés"))
	if DataStore.filter_presets.is_empty():
		_body.add_child(UI.label("Aucun filtre enregistré pour le moment.", 12, UI.TEXT_2, false, true))
	else:
		var flow6 := _flow()
		for p in DataStore.filter_presets:
			if typeof(p) != TYPE_DICTIONARY:
				continue
			var pname := str(p.get("name", ""))
			var pchip := UI.chip(pname, false)
			pchip.name = "Preset_" + pname
			pchip.tapped.connect(_apply_preset.bind(pname))
			flow6.add_child(pchip)
			var del_preset := UI.close_button(24)
			del_preset.name = "PresetDelete_" + pname
			del_preset.pressed.connect(func() -> void:
				DataStore.delete_filter_preset(pname)
				rebuild())
			flow6.add_child(del_preset)
		_body.add_child(flow6)
	var save_row := UI.hbox(8)
	var preset_name := UI.line_edit("Nom du filtre")
	preset_name.name = "PresetName"
	preset_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	save_row.add_child(preset_name)
	var save_preset := UI.ghost_button("Enregistrer", UI.ACCENT)
	save_preset.name = "PresetSave"
	save_preset.pressed.connect(func() -> void:
		var f := _body.find_child("PresetName", true, false)
		if f is LineEdit:
			DataStore.save_filter_preset((f as LineEdit).text, _filters)
			rebuild())
	save_row.add_child(save_preset)
	_body.add_child(save_row)

	var row := UI.hbox(10)
	var reset := UI.ghost_button("Réinitialiser", UI.TEXT_2)
	reset.name = "FilterReset"
	reset.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reset.pressed.connect(_reset)
	row.add_child(reset)
	var apply := UI.primary_button("Appliquer")
	apply.name = "FilterApply"
	apply.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	apply.pressed.connect(_apply)
	row.add_child(apply)
	_body.add_child(row)

	if not is_open():
		open()

func rebuild() -> void:
	clear_body()
	build_body()

func _apply_preset(preset_label: String) -> void:
	for p in DataStore.filter_presets:
		if typeof(p) == TYPE_DICTIONARY and str(p.get("name", "")) == preset_label:
			var f: Variant = p.get("filters", null)
			if typeof(f) == TYPE_DICTIONARY:
				var merged: Dictionary = {
					"severities": [], "software_ids": [], "period": "all",
					"min_score": 0.0, "sort": "score", "saved_only": false,
				}
				merged.merge((f as Dictionary).duplicate(true), true)
				_filters = merged
				rebuild()
			return

func _flow() -> HFlowContainer:
	var f := HFlowContainer.new()
	f.add_theme_constant_override("h_separation", 8)
	f.add_theme_constant_override("v_separation", 8)
	f.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return f

func _toggle_sev(key: String) -> void:
	var arr: Array = _filters["severities"]
	if arr.has(key):
		arr.erase(key)
	else:
		arr.append(key)
	_filters["severities"] = arr
	if _sev_chips.has(key):
		UI.style_chip(_sev_chips[key], arr.has(key))

func _toggle_sw(id: String) -> void:
	var arr: Array = _filters["software_ids"]
	if arr.has(id):
		arr.erase(id)
	else:
		arr.append(id)
	_filters["software_ids"] = arr
	if _sw_chips.has(id):
		UI.style_chip(_sw_chips[id], arr.has(id))

func _set_saved_only(value: bool) -> void:
	_filters["saved_only"] = value
	for k in _saved_chips:
		UI.style_chip(_saved_chips[k], bool(_filters["saved_only"]) == (str(k) == "true"))

func _set_period(key: String) -> void:
	_filters["period"] = key
	for k in _period_chips:
		UI.style_chip(_period_chips[k], str(k) == key)

func _set_score(value: float) -> void:
	_filters["min_score"] = value
	for k in _score_chips:
		UI.style_chip(_score_chips[k], is_equal_approx(float(k), value))

func _set_sort(key: String) -> void:
	_filters["sort"] = key
	for k in _sort_chips:
		UI.style_chip(_sort_chips[k], str(k) == key)

func _reset() -> void:
	_filters = {"severities": [], "software_ids": [], "period": "all", "min_score": 0.0, "sort": "score", "saved_only": false}
	for k in _sev_chips:
		UI.style_chip(_sev_chips[k], false)
	for k in _sw_chips:
		UI.style_chip(_sw_chips[k], false)
	for k in _period_chips:
		UI.style_chip(_period_chips[k], str(k) == "all")
	for k in _score_chips:
		UI.style_chip(_score_chips[k], str(k) == "0")
	for k in _sort_chips:
		UI.style_chip(_sort_chips[k], str(k) == "score")
	for k in _saved_chips:
		UI.style_chip(_saved_chips[k], str(k) == "false")

func _apply() -> void:
	var out := _filters.duplicate(true)
	close()
	applied.emit(out)
