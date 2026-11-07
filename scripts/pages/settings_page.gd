class_name SettingsPage
extends AppPage
## Onglet Paramètres — compte, apparence, notifications, cache.

func page_title() -> String:
	return Loc.t("settings_title")

func page_subtitle() -> String:
	return Loc.t("settings_sub")

func build() -> void:
	DataStore.data_changed.connect(refresh)
	DataStore.auth_changed.connect(refresh)
	refresh()

func refresh() -> void:
	clear_content()

	# --- Compte ---
	content.add_child(UI.section_title("Compte"))
	var signed_in := DataStore.auth.is_signed_in()
	var account := UI.card(16)
	var av := UI.vbox(6)
	if signed_in:
		var shown := DataStore.auth.display_name()
		av.add_child(UI.label(shown if shown != "" else "Compte", 16, UI.TEXT, true, true))
		av.add_child(UI.label(DataStore.auth.email(), 12, UI.TEXT_2, false, true))
	else:
		av.add_child(UI.label("Non connecté", 16, UI.TEXT, true))
		av.add_child(UI.label("Connectez-vous pour retrouver vos logiciels.", 12, UI.TEXT_2, false, true))
	account.add_child(av)
	content.add_child(account)

	var manage := UI.primary_button("Gérer le compte" if signed_in else "Se connecter")
	manage.name = "AccountButton"
	manage.pressed.connect(_on_account)
	content.add_child(manage)

	if signed_in:
		var sync := UI.ghost_button("Synchroniser", UI.ACCENT)
		sync.name = "SyncButton"
		sync.pressed.connect(_on_sync)
		content.add_child(sync)

	# --- Apparence ---
	content.add_child(UI.section_title("Apparence"))
	content.add_child(_switch_card("Transparence réduite",
		"Fonds opaques et contraste renforcé.",
		DataStore.is_reduce_transparency(), "TransparencySwitch", _on_transparency))

	# --- Langue ---
	content.add_child(UI.section_title("Langue"))
	var lang_row := UI.hbox(8)
	var fr := UI.chip("Français", DataStore.language() == "fr")
	fr.name = "LangFr"
	fr.tapped.connect(func() -> void: _set_lang("fr"))
	lang_row.add_child(fr)
	var en := UI.chip("English", DataStore.language() == "en")
	en.name = "LangEn"
	en.tapped.connect(func() -> void: _set_lang("en"))
	lang_row.add_child(en)
	content.add_child(lang_row)
	content.add_child(UI.label(Loc.t("language_desc"), 12, UI.TEXT_3, false, true))

	# --- Notifications ---
	content.add_child(UI.section_title("Notifications"))
	var notif_desc := "Alertes de failles critiques sur votre téléphone."
	if not NotificationService.available():
		notif_desc += " Disponibles sur l'application mobile."
	content.add_child(_switch_card("Alertes de vulnérabilités",
		notif_desc,
		DataStore.notifications_enabled(), "NotificationsSwitch", _on_notifications))

	content.add_child(_switch_card("Notification de test (toutes les minutes)",
		"Vérifie que les notifications arrivent bien sur votre téléphone.",
		bool(DataStore.settings.get("test_notifications", true)), "TestNotifSwitch", _on_test_notifications))

	# --- Cache (le bouton vide réellement les données mises en cache) ---
	var clear := UI.ghost_button("Vider le cache", UI.TEXT_2)
	clear.name = "ClearCacheButton"
	clear.pressed.connect(_on_clear_cache)
	content.add_child(clear)

	# --- Déconnexion ---
	if signed_in:
		var out := UI.ghost_button("Se déconnecter", UI.DANGER)
		out.name = "SignOutButton"
		out.pressed.connect(_on_sign_out)
		content.add_child(out)

func _switch_card(title: String, desc: String, on: bool, node_name: String, handler: Callable) -> PanelContainer:
	var p := UI.card(16)
	var row := UI.hbox(12)
	var v := UI.vbox(3)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var title_label := UI.label(title, 15, UI.TEXT, true, true)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(title_label)
	var desc_label := UI.label(desc, 12, UI.TEXT_2, false, true)
	desc_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(desc_label)
	row.add_child(v)
	var sw := UI.switch_button(on)
	sw.name = node_name
	sw.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sw.toggled.connect(handler)
	row.add_child(sw)
	p.add_child(row)
	return p

func _on_account() -> void:
	var main := get_tree().current_scene
	if main != null and main.has_method("open_account_sheet"):
		main.open_account_sheet()

func _on_sync() -> void:
	DataStore.start_busy("Synchronisation…")
	var res: Dictionary = await DataStore.sync_now()
	DataStore.end_busy()
	if bool(res.get("ok", false)):
		DataStore.toast.emit("Synchronisé")
	else:
		DataStore.toast.emit(str(res.get("error", "Synchronisation impossible.")))

func _on_transparency(value: bool) -> void:
	DataStore.set_reduce_transparency(value)

func _set_lang(code: String) -> void:
	DataStore.set_language(code)
	refresh()

func _on_test_notifications(value: bool) -> void:
	DataStore.settings["test_notifications"] = value
	DataStore.save_data()
	DataStore.toast.emit("Notification de test activée" if value else "Notification de test désactivée")

func _on_notifications(value: bool) -> void:
	DataStore.set_notifications(value)

func _on_clear_cache() -> void:
	DataStore.clear_cache()

func _on_sign_out() -> void:
	await DataStore.auth.sign_out()
