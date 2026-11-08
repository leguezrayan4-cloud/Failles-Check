class_name DetailSheet
extends SheetBase
## FaillesCheck — fiche détaillée d'une vulnérabilité, présentée dans le
## panneau superposé commun (croix de fermeture à droite, glissement vers le
## bas pour fermer, contenu défilant).

signal share_requested(v: Dictionary)
signal translation_requested(v: Dictionary)

func sheet_title() -> String:
	return Loc.t("detail")

func show_detail(v: Dictionary) -> void:
	if v.is_empty():
		return
	DataStore.push_recent(str(v.get("id", "")))
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
	var title_label := UI.label(str(v.get("title", "")), 19, UI.TEXT, true, true)
	hv.add_child(title_label)
	Loc.translate(str(v.get("title", "")), func(translated: String) -> void:
		if translated != "" and is_instance_valid(title_label):
			title_label.text = translated)
	head.add_child(hv)
	_body.add_child(head)

	# Score CVSS.
	var score_card := UI.card(16)
	var row := UI.hbox(14)
	var left := UI.vbox(2)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	left.add_child(UI.label(Loc.t("score"), 13, UI.TEXT_2))
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
		[Loc.t("software"), product],
		[Loc.t("affected_version"), str(v.get("version", "—"))],
		[Loc.t("status"), str(v.get("status", "—"))],
		[Loc.t("date"), str(v.get("date", "—"))],
	]
	# Comparaison avec la version que vous suivez (si le logiciel est dans votre liste).
	var mine := _my_version(product)
	if mine != "":
		pairs.append([Loc.t("your_version"), mine])
	_body.add_child(UI.info_card(pairs))
	if mine != "" and mine == str(v.get("version", "")):
		var warn := UI.badge("Version concernée", UI.DANGER)
		warn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		_body.add_child(warn)

	# Actions : enregistrer la faille + partager.
	var actions := UI.hbox(10)
	var id := str(v.get("id", ""))
	var saved := DataStore.is_saved(id)
	var bm := UI.ghost_button(Loc.t("saved") if saved else Loc.t("save"), UI.ACCENT if saved else UI.TEXT_2)
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
	var tr_btn := UI.ghost_button(Loc.t("ask_translation"), UI.ACCENT)
	tr_btn.name = "SheetTranslateButton"
	tr_btn.icon = UI.svg_texture(UI.ICON_AI, 18)
	tr_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tr_btn.pressed.connect(func() -> void:
		DataStore.mark_read(id)
		translation_requested.emit(v))
	_body.add_child(tr_btn)

	var treated := UI.ghost_button("Traitée" if DataStore.is_read(id) else "Marquer comme traitée",
		UI.ACCENT if DataStore.is_read(id) else UI.TEXT_2)
	treated.name = "SheetTreatedButton"
	treated.pressed.connect(func() -> void:
		DataStore.mark_read(id)
		Haptics.confirm()
		clear_body()
		_fill(v))
	_body.add_child(treated)

	# Commentaire personnel sur cette faille (distinct de la note du logiciel).
	var comment := UI.line_edit("Ajouter un commentaire…")
	comment.name = "SheetComment"
	comment.text = DataStore.comment_for(id)
	_body.add_child(comment)
	var save_comment := UI.ghost_button("Enregistrer le commentaire", UI.TEXT_2)
	save_comment.name = "SheetSaveComment"
	save_comment.pressed.connect(func() -> void:
		DataStore.set_comment(id, comment.text)
		comment.release_focus()
		Haptics.tap())
	_body.add_child(save_comment)

	var share := UI.ghost_button(Loc.t("share"), UI.TEXT_2)
	share.name = "SheetShareButton"
	share.icon = UI.svg_texture(UI.ICON_SHARE, 18)
	share.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	share.pressed.connect(func() -> void: share_requested.emit(v))
	actions.add_child(share)
	_body.add_child(actions)

	var desc_section := UI.text_section(Loc.t("description"), str(v.get("description", "—")))
	_body.add_child(desc_section)
	var desc_label := _last_label(desc_section)
	Loc.translate(str(v.get("description", "")), func(translated: String) -> void:
		if translated != "" and is_instance_valid(desc_label):
			desc_label.text = translated)
	_body.add_child(UI.text_section(Loc.t("recommendations"), str(v.get("remediation", "—"))))

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


## Dernier libellé d'une section (le texte de la description).
func _last_label(node: Node) -> Label:
	var found: Label = null
	for c in node.get_children():
		if c is Label:
			found = c as Label
		var sub := _last_label(c)
		if sub != null:
			found = sub
	return found
