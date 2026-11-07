class_name FilterSheet
extends SheetBase
## FaillesCheck — panneau de filtres multiples (gravités + logiciels favoris).

signal applied(severities: Array, software_ids: Array)

const SEVERITIES := [
	["critique", "Critique"],
	["elevee", "Élevée"],
	["moyenne", "Moyenne"],
	["faible", "Faible"],
]

var _sev: Array = []
var _sw: Array = []
var _sev_chips := {}
var _sw_chips := {}

func sheet_title() -> String:
	return "Filtrer"

func open_with(severities: Array, software_ids: Array) -> void:
	_sev = severities.duplicate()
	_sw = software_ids.duplicate()
	clear_body()
	_sev_chips.clear()
	_sw_chips.clear()

	_body.add_child(UI.section_title("Gravité"))
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 8)
	flow.add_theme_constant_override("v_separation", 8)
	flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for d in SEVERITIES:
		var key := str(d[0])
		var chip := UI.chip(str(d[1]), _sev.has(key))
		chip.tapped.connect(_toggle_sev.bind(key))
		_sev_chips[key] = chip
		flow.add_child(chip)
	_body.add_child(flow)

	_body.add_child(UI.section_title("Logiciels favoris"))
	var favs := DataStore.favorites()
	if favs.is_empty():
		_body.add_child(UI.label("Aucun favori pour le moment.", 12, UI.TEXT_2, false, true))
	else:
		var flow2 := HFlowContainer.new()
		flow2.add_theme_constant_override("h_separation", 8)
		flow2.add_theme_constant_override("v_separation", 8)
		flow2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		for s in favs:
			var id := str(s.get("id", ""))
			var chip := UI.chip(str(s.get("name", "")), _sw.has(id))
			chip.tapped.connect(_toggle_sw.bind(id))
			_sw_chips[id] = chip
			flow2.add_child(chip)
		_body.add_child(flow2)

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

	open()

func _toggle_sev(key: String) -> void:
	if _sev.has(key):
		_sev.erase(key)
	else:
		_sev.append(key)
	if _sev_chips.has(key):
		UI.style_chip(_sev_chips[key], _sev.has(key))

func _toggle_sw(id: String) -> void:
	if _sw.has(id):
		_sw.erase(id)
	else:
		_sw.append(id)
	if _sw_chips.has(id):
		UI.style_chip(_sw_chips[id], _sw.has(id))

func _reset() -> void:
	_sev.clear()
	_sw.clear()
	for k in _sev_chips:
		UI.style_chip(_sev_chips[k], false)
	for k in _sw_chips:
		UI.style_chip(_sw_chips[k], false)

func _apply() -> void:
	var sev := _sev.duplicate()
	var sw := _sw.duplicate()
	close()
	applied.emit(sev, sw)
