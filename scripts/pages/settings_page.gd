class_name SettingsPage
extends AppPage
## Onglet Réglages — préférences, sources de données et synchronisation.

var _status: String = ""

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
		"Catalogue fictif (DÉMO · FICTIF).",
		DataStore.is_demo(), "DemoSwitch", _on_demo))

	content.add_child(_switch_card("Source en ligne (NVD)",
		"Vulnérabilités réelles du NVD (NIST).",
		DataStore.is_online(), "OnlineSwitch", _on_online))

	content.add_child(_switch_card("Transparence réduite",
		"Fonds opaques et contraste renforcé.",
		DataStore.is_reduce_transparency(), "TransparencySwitch", _on_transparency))

	var info := DataStore.cache_info()
	var updated := str(info.get("updated", ""))
	if updated == "":
		updated = "jamais"
	content.add_child(UI.info_card([
		["Source active", DataStore.source_label()],
		["Entrées en cache", str(info.get("count", 0))],
		["Dernière mise à jour", updated],
	]))

	if _status != "":
		content.add_child(UI.label(_status, 12, UI.TEXT_2, false, true))

	var clear := UI.ghost_button("Vider le cache local", UI.TEXT_2)
	clear.pressed.connect(_on_clear_cache)
	content.add_child(clear)

	# --- Synchronisation distante (Supabase) ---
	content.add_child(UI.section_title("Synchronisation distante"))
	var configured := DataStore.sync_configured()
	content.add_child(UI.info_card([
		["Service", "Supabase"],
		["État", "configurée" if configured else "non configurée"],
		["Dernière synchro", DataStore.last_sync_at if DataStore.last_sync_at != "" else "—"],
	]))
	if configured:
		var sync := UI.primary_button("Synchroniser")
		sync.name = "SyncButton"
		sync.pressed.connect(_on_sync)
		content.add_child(sync)
	else:
		content.add_child(UI.label("Configuration requise : docs/supabase_setup.md", 12, UI.TEXT_2, false, true))

	content.add_child(UI.info_card([
		["Version", "2.0.0"],
		["Stockage", "Local (JSON)"],
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

func _on_transparency(value: bool) -> void:
	DataStore.set_reduce_transparency(value)

func _on_clear_cache() -> void:
	DataStore.clear_cache()

func _on_sync() -> void:
	_status = "Synchronisation en cours…"
	refresh()
	var res: Dictionary = await DataStore.sync_now()
	if bool(res.get("ok", false)):
		_status = "Synchronisé : %d envoyé(s), %d récupéré(s)." % [int(res.get("pushed", 0)), int(res.get("merged", 0))]
	else:
		_status = str(res.get("error", "Échec de la synchronisation."))
	refresh()

func _on_reset() -> void:
	DataStore.reset_all()
	refresh()