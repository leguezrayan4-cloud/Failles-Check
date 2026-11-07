class_name SettingsPage
extends AppPage
## Onglet Réglages — préférences et interrupteur de démonstration.

func page_title() -> String:
	return "Réglages"

func page_subtitle() -> String:
	return "Préférences de l'application"

func build() -> void:
	DataStore.data_changed.connect(refresh)
	refresh()

func refresh() -> void:
	clear_content()

	content.add_child(_switch_card("Données de démonstration",
		"Affiche un catalogue fictif clairement marqué DÉMO · FICTIF.",
		DataStore.is_demo(), "DemoSwitch", _on_demo))

	content.add_child(_switch_card("Source en ligne (NVD)",
		"Récupère les vulnérabilités réelles depuis le NVD (NIST). Aucune clé n'est requise.",
		DataStore.is_online(), "OnlineSwitch", _on_online))

	var info := DataStore.cache_info()
	var updated := str(info.get("updated", ""))
	if updated == "":
		updated = "jamais"
	content.add_child(UI.info_card([
		["Source active", DataStore.source_label()],
		["Entrées en cache", str(info.get("count", 0))],
		["Dernière mise à jour", updated],
		["Clé API", "non requise (env. NVD_API_KEY)"],
	]))

	var clear := UI.ghost_button("Vider le cache local", UI.TEXT_2)
	clear.pressed.connect(_on_clear_cache)
	content.add_child(clear)

	content.add_child(UI.info_card([
		["Application", "FaillesCheck"],
		["Version", "1.1.0"],
		["Moteur", "Godot 4.7.2"],
		["Stockage", "Local (JSON)"],
		["Réseau", "Optionnel (NVD)"],
	]))

	var reset := UI.ghost_button("Réinitialiser les données", UI.DANGER)
	reset.pressed.connect(_on_reset)
	content.add_child(reset)

func _switch_card(title: String, desc: String, on: bool, node_name: String, handler: Callable) -> PanelContainer:
	var p := UI.card(16)
	var row := UI.hbox(12)
	var v := UI.vbox(3)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	v.add_child(UI.label(title, 15, UI.TEXT, true))
	v.add_child(UI.label(desc, 12, UI.TEXT_2, false, true))
	row.add_child(v)
	var sw := UI.switch_button(on)
	sw.name = node_name
	sw.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sw.toggled.connect(handler)
	row.add_child(sw)
	p.add_child(row)
	return p

func _on_demo(value: bool) -> void:
	DataStore.set_demo(value)

func _on_online(value: bool) -> void:
	DataStore.set_online(value)

func _on_clear_cache() -> void:
	DataStore.clear_cache()

func _on_reset() -> void:
	DataStore.reset_all()
	refresh()