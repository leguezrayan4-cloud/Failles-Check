class_name DetailPage
extends AppPage
## Onglet Fiche — détail de la faille sélectionnée.

func page_title() -> String:
	return "Fiche"

func page_subtitle() -> String:
	return "Détail d'une vulnérabilité"

func has_back_button() -> bool:
	return true

func build() -> void:
	DataStore.selection_changed.connect(refresh)
	DataStore.data_changed.connect(refresh)
	refresh()

func refresh() -> void:
	clear_content()
	var v := DataStore.selected()
	if v.is_empty():
		content.add_child(UI.empty_state(
			"Aucune fiche sélectionnée",
			"Sélectionnez une faille dans l'onglet Recherche pour afficher sa fiche détaillée.",
			UI.ICON_FICHE))
		return

	var col := UI.sev_color(str(v.get("severity", "")))
	content.add_child(_header_card(v, col))
	content.add_child(_score_card(v, col))
	content.add_child(UI.info_card([
		["Produit", str(v.get("product", "—"))],
		["Version affectée", str(v.get("version", "—"))],
		["Publiée le", str(v.get("date", "—"))],
		["Statut", str(v.get("status", "—"))],
		["Vecteur", str(v.get("vector", "—"))],
		["Source", str(v.get("source", "locale"))],
	]))
	content.add_child(UI.text_section("Résumé", str(v.get("summary", ""))))
	content.add_child(UI.text_section("Description", str(v.get("description", ""))))
	content.add_child(UI.text_section("Recommandation", str(v.get("remediation", ""))))
	var url := str(v.get("url", ""))
	if url != "":
		content.add_child(UI.text_section("Référence officielle", url))

	if bool(v.get("demo", false)):
		var tag := UI.demo_tag()
		tag.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		content.add_child(tag)
	else:
		var src := UI.badge("Source : %s" % str(v.get("source", "NVD")), UI.ACCENT)
		src.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		content.add_child(src)

func _header_card(v: Dictionary, col: Color) -> PanelContainer:
	var p := UI.card(16)
	var vv := UI.vbox(10)
	var top := UI.hbox(8)
	top.add_child(UI.badge(str(v.get("id", "")), UI.TEXT_2))
	top.add_child(UI.spacer())
	top.add_child(UI.badge(UI.sev_label(str(v.get("severity", ""))), col))
	vv.add_child(top)
	vv.add_child(UI.label(str(v.get("title", "")), 19, UI.TEXT, true, true))
	var meta := UI.hbox(8)
	var dot := UI.sev_dot(col, 10)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	meta.add_child(dot)
	meta.add_child(UI.label("%s · %s" % [str(v.get("product", "")), str(v.get("version", ""))], 13, UI.TEXT_2))
	vv.add_child(meta)
	p.add_child(vv)
	return p

func _score_card(v: Dictionary, col: Color) -> PanelContainer:
	var p := UI.card(16)
	var row := UI.hbox(14)
	var left := UI.vbox(2)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	left.add_child(UI.label("Score CVSS v3.1", 13, UI.TEXT_2))
	left.add_child(UI.label("Gravité %s" % UI.sev_label(str(v.get("severity", ""))).to_lower(), 12, UI.TEXT_3))
	row.add_child(left)
	var score := UI.label("%.1f" % float(v.get("score", 0.0)), 34, col, true)
	score.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(score)
	p.add_child(row)
	return p