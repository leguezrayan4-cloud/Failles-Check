class_name DetailSheet
extends SheetBase
## FaillesCheck — fiche détaillée d'une vulnérabilité, présentée dans le
## panneau superposé commun (croix de fermeture à droite, glissement vers le
## bas pour fermer, contenu défilant).

func sheet_title() -> String:
	return "Détail"

func show_detail(v: Dictionary) -> void:
	if v.is_empty():
		return
	clear_body()
	_fill(v)
	if not is_open():
		open()

func _fill(v: Dictionary) -> void:
	var sev := str(v.get("severity", ""))
	var col := UI.sev_color(sev)

	# En-tête : identifiant + gravité + titre.
	var head := UI.card(16)
	var hv := UI.vbox(10)
	var top := UI.hbox(8)
	top.add_child(UI.badge(str(v.get("id", "—")), UI.TEXT_2))
	top.add_child(UI.spacer())
	top.add_child(UI.badge(UI.sev_label(sev), col))
	hv.add_child(top)
	hv.add_child(UI.label(str(v.get("title", "")), 19, UI.TEXT, true, true))
	head.add_child(hv)
	_body.add_child(head)

	# Score CVSS.
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

	# Détails utiles (identifiant, gravité et score sont déjà affichés).
	var product := str(v.get("product", "—"))
	var pairs: Array = [
		["Logiciel", product],
		["Version affectée", str(v.get("version", "—"))],
		["Statut", str(v.get("status", "—"))],
		["Date", str(v.get("date", "—"))],
	]
	# Comparaison avec la version que vous suivez (si le logiciel est dans votre liste).
	var mine := _my_version(product)
	if mine != "":
		pairs.append(["Votre version", mine])
	_body.add_child(UI.info_card(pairs))
	if mine != "" and mine == str(v.get("version", "")):
		var warn := UI.badge("Version concernée", UI.DANGER)
		warn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		_body.add_child(warn)

	# Actions : enregistrer la faille + partager.
	var actions := UI.hbox(10)
	var id := str(v.get("id", ""))
	var saved := DataStore.is_saved(id)
	var bm := UI.ghost_button("Enregistrée" if saved else "Enregistrer", UI.ACCENT if saved else UI.TEXT_2)
	bm.name = "SheetSaveButton"
	bm.icon = UI.svg_texture(UI.ICON_BOOKMARK if saved else UI.ICON_BOOKMARK_OUTLINE, 18)
	bm.add_theme_color_override("icon_normal_color", UI.ACCENT if saved else UI.TEXT_2)
	bm.add_theme_color_override("icon_pressed_color", UI.ACCENT)
	bm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bm.pressed.connect(func() -> void:
		DataStore.toggle_saved(id)
		clear_body()
		_fill(v))
	actions.add_child(bm)
	var share := UI.ghost_button("Partager", UI.TEXT_2)
	share.name = "SheetShareButton"
	share.icon = UI.svg_texture(UI.ICON_SHARE, 18)
	share.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	share.pressed.connect(func() -> void: _share(v))
	actions.add_child(share)
	_body.add_child(actions)

	_body.add_child(UI.text_section("Description", str(v.get("description", "—"))))
	_body.add_child(UI.text_section("Recommandations", str(v.get("remediation", "—"))))

	var url := str(v.get("url", ""))
	if url != "":
		_body.add_child(UI.text_section("Référence officielle", url))

	var src := UI.badge("Source : %s" % str(v.get("source", "NVD")), UI.ACCENT)
	src.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_body.add_child(src)

## Version suivie pour ce logiciel (vide si le logiciel n'est pas dans la liste).
func _my_version(app_name: String) -> String:
	var target := app_name.strip_edges().to_lower()
	if target == "":
		return ""
	for sw in DataStore.software:
		if typeof(sw) != TYPE_DICTIONARY:
			continue
		var n := str(sw.get("name", "")).strip_edges().to_lower()
		if n == "":
			continue
		if target == n or target.contains(n) or n.contains(target):
			return str(sw.get("version", ""))
	return ""

## Partage : la fiche complète est copiée (presse-papiers du téléphone).
func _share(v: Dictionary) -> void:
	var lines: Array = [
		"FaillesCheck — %s" % str(v.get("id", "")),
		str(v.get("title", "")),
		"Gravité : %s (%.1f)" % [UI.sev_label(str(v.get("severity", ""))), float(v.get("score", 0.0))],
		"Logiciel : %s %s" % [str(v.get("product", "—")), str(v.get("version", ""))],
	]
	var url := str(v.get("url", ""))
	if url != "":
		lines.append(url)
	DisplayServer.clipboard_set("
".join(lines))
	DataStore.toast.emit("Fiche copiée")
