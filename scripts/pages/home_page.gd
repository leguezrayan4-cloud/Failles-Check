class_name HomePage
extends AppPage
## Onglet Accueil — tableau de bord.

func page_title() -> String:
	return "Accueil"

func page_subtitle() -> String:
	return "Vue d'ensemble"

func build() -> void:
	DataStore.data_changed.connect(refresh)
	refresh()

func refresh() -> void:
	clear_content()
	content.add_child(_hero())

	var has_data := not DataStore.vulnerabilities.is_empty() or not DataStore.software.is_empty()
	if not has_data:
		content.add_child(UI.empty_state(
			"Aucune donnée",
			"Activez une source dans Réglages."))
		UI.stagger_in(content, 6)
		return

	content.add_child(_stats())

	if not DataStore.vulnerabilities.is_empty():
		var head := UI.hbox(8)
		head.add_child(UI.section_title("Failles prioritaires"))
		head.add_child(UI.spacer())
		if DataStore.has_real_data():
			head.add_child(UI.badge("NVD (NIST)", UI.ACCENT))
		content.add_child(head)
		for v in DataStore.vulnerabilities.slice(0, 4):
			content.add_child(UI.vuln_card(v, _open.bind(str(v.get("id", "")))))
	else:
		content.add_child(UI.section_title("Vos logiciels suivis"))
		for s in DataStore.software.slice(0, 5):
			content.add_child(_software_row(s))
	UI.stagger_in(content, 6)

func _hero() -> PanelContainer:
	var p := UI.card(16)
	var row := UI.hbox(14)
	var logo := TextureRect.new()
	logo.texture = preload("res://Logo.png")
	logo.custom_minimum_size = Vector2(58, 58)
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(logo)
	var v := UI.vbox(3)
	v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	v.add_child(UI.label("FaillesCheck", 20, UI.TEXT, true))
	v.add_child(UI.label("Contrôle des vulnérabilités de vos logiciels", 12, UI.TEXT_2, false, true))
	row.add_child(v)
	p.add_child(row)
	return p

func _stats() -> PanelContainer:
	var critiques := 0
	for v in DataStore.vulnerabilities:
		if str(v.get("severity", "")) == "critique":
			critiques += 1
	var p := UI.card(16)
	var row := UI.hbox(10)
	row.add_child(_stat(str(DataStore.vulnerabilities.size()), "Failles", UI.DANGER))
	row.add_child(_stat(str(critiques), "Critiques", Color(0.910, 0.533, 0.039)))
	row.add_child(_stat(str(DataStore.software.size()), "Logiciels", UI.ACCENT))
	p.add_child(row)
	return p

func _stat(value: String, stat_name: String, col: Color) -> VBoxContainer:
	var v := UI.vbox(2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var n := UI.label(value, 26, col, true)
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(n)
	var l := UI.label(stat_name, 12, UI.TEXT_2)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l)
	return v

func _software_row(s: Dictionary) -> PanelContainer:
	var p := UI.card(14)
	var row := UI.hbox(12)
	var ic := UI.icon(UI.ICON_APPS, 22, UI.ACCENT)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(ic)
	var v := UI.vbox(2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	v.add_child(UI.label(str(s.get("name", "")), 15, UI.TEXT, true, true))
	v.add_child(UI.label(str(s.get("version", "")), 12, UI.TEXT_2))
	row.add_child(v)
	p.add_child(row)
	return p

## Ouvre le détail par-dessus l'écran courant (on reste dans le contexte).
func _open(id: String) -> void:
	var main := get_tree().current_scene
	if main != null and main.has_method("open_detail_sheet"):
		main.open_detail_sheet(id)