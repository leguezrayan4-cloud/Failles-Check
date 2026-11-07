class_name SoftwareSheet
extends SheetBase
## FaillesCheck — détails d'un logiciel suivi : informations connues,
## nombre de vulnérabilités réelles, historique réel, favori, suppression.

signal favorite_toggled(id: String)
signal delete_requested(id: String)

var _item: Dictionary = {}

func sheet_title() -> String:
	return "Logiciel"

func show_software(item: Dictionary) -> void:
	_item = item
	clear_body()
	var id := str(item.get("id", ""))
	var app_name := str(item.get("name", "—"))
	var editor := str(item.get("editor", ""))
	var version := str(item.get("version", ""))
	var identifier := str(item.get("identifier", ""))

	# --- Identité ---
	var head := UI.card(16)
	var hv := UI.vbox(6)
	var top := UI.hbox(12)
	var ic := UI.icon(UI.ICON_SOFTWARE, 26, UI.ACCENT)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(ic)
	var names := UI.vbox(2)
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	names.add_child(UI.label(app_name, 18, UI.TEXT, true, true))
	var sub_parts: Array = []
	if editor != "":
		sub_parts.append(editor)
	if version != "":
		sub_parts.append("v" + version)
	if not sub_parts.is_empty():
		names.add_child(UI.label(" · ".join(sub_parts), 13, UI.TEXT_2, false, true))
	top.add_child(names)
	hv.add_child(top)
	if identifier != "":
		hv.add_child(UI.label(identifier, 11, UI.TEXT_3, false, true))
	head.add_child(hv)
	_body.add_child(head)

	# --- Vulnérabilités réelles ---
	var vulns := DataStore.vulns_for_software(app_name)
	var stats := UI.card(16)
	var row := UI.hbox(12)
	var left := UI.vbox(2)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	left.add_child(UI.label("Vulnérabilités", 13, UI.TEXT_2))
	row.add_child(left)
	var count := UI.label(str(vulns.size()), 30, UI.DANGER if vulns.size() > 0 else UI.TEXT_2, true)
	count.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(count)
	stats.add_child(row)
	_body.add_child(stats)

	# --- Historique réel ---
	var hist := DataStore.software_history(app_name)
	var chart_card := UI.card(16)
	var cv := UI.vbox(8)
	cv.add_child(UI.label("Évolution dans le temps", 14, UI.TEXT, true))
	var labels: Array = hist.get("labels", [])
	var values: Array = hist.get("values", [])
	if values.is_empty():
		cv.add_child(UI.label("Historique indisponible pour ce logiciel : la source ne fournit pas de date exploitable.",
			12, UI.TEXT_2, false, true))
	else:
		var chart := SparkChart.new()
		chart.set_data(labels, values, UI.ACCENT)
		cv.add_child(chart)
		cv.add_child(UI.label("%d mois · %d vulnérabilité(s)" % [values.size(), vulns.size()], 11, UI.TEXT_3))
	chart_card.add_child(cv)
	_body.add_child(chart_card)

	# --- Note personnelle ---
	_body.add_child(UI.section_title("Note personnelle"))
	var note := TextEdit.new()
	note.name = "SoftwareNote"
	note.placeholder_text = "Ex. : version utilisée en production, correctif à appliquer…"
	note.custom_minimum_size = Vector2(0, 74)
	note.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	note.text = DataStore.note_for(id)
	note.add_theme_stylebox_override("normal", _note_style())
	note.add_theme_stylebox_override("focus", _note_style())
	note.add_theme_font_size_override("font_size", 13)
	_body.add_child(note)
	var save_note := UI.ghost_button("Enregistrer la note", UI.ACCENT)
	save_note.name = "SoftwareSaveNote"
	save_note.pressed.connect(func() -> void:
		DataStore.set_note(id, note.text))
	_body.add_child(save_note)

	# --- Actions ---
	var actions := UI.hbox(10)
	var fav_on := DataStore.is_favorite(id)
	var fav := UI.ghost_button("Favori" if fav_on else "Ajouter aux favoris", UI.DANGER if fav_on else UI.TEXT_2)
	fav.name = "SoftwareFavorite"
	fav.icon = UI.svg_texture(UI.ICON_HEART if fav_on else UI.ICON_HEART_OUTLINE, 18)
	fav.add_theme_color_override("icon_normal_color", UI.DANGER if fav_on else UI.TEXT_2)
	fav.add_theme_color_override("icon_pressed_color", UI.DANGER)
	fav.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fav.pressed.connect(func() -> void: favorite_toggled.emit(id))
	actions.add_child(fav)
	var del := UI.ghost_button("Supprimer", UI.DANGER)
	del.name = "SoftwareDelete"
	del.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	del.pressed.connect(func() -> void: delete_requested.emit(id))
	actions.add_child(del)
	_body.add_child(actions)

	open()

func _note_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1)
	sb.set_corner_radius_all(12)
	sb.border_color = UI.BORDER
	sb.set_border_width_all(1)
	sb.set_content_margin_all(10)
	return sb
