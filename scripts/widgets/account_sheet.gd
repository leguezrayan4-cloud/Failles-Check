class_name AccountSheet
extends SheetBase
## FaillesCheck — gestion du compte (Supabase Auth), affiché en plein écran.
## Aucun mot de passe n'est conservé : la session reste en mémoire.

## Plein écran : le panneau couvre toute la surface (pas de feuille basse).
func _ready() -> void:
	super()
	if _backdrop != null:
		_backdrop.visible = false
		_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := _panel.get_theme_stylebox("panel")
	if sb is StyleBoxFlat:
		var f := sb as StyleBoxFlat
		f.corner_radius_top_left = 0
		f.corner_radius_top_right = 0
		f.shadow_size = 0
	var grab := _panel.find_child("SheetGrabber", true, false)
	if grab is MarginContainer:
		var gm := grab as MarginContainer
		gm.add_theme_constant_override("margin_top", 26)
		gm.add_theme_constant_override("margin_bottom", 10)
		for c in gm.get_children():
			if c is Control:
				(c as Control).visible = false

func _open_panel_y() -> float:
	return 0.0

func _layout() -> void:
	_panel.size = size
	_panel.position = Vector2.ZERO if _is_open else Vector2(0, size.y)

## Pas de fermeture par glissement : c'est un écran plein, on utilise la croix.
func _begin_pull(_pos: Vector2) -> void:
	pass

var _mode := "signin"
var _error := ""
var _info := ""
var _busy := false
var _confirm_delete := false

func sheet_title() -> String:
	return "Compte"

func open_account() -> void:
	_mode = "manage" if DataStore.auth.is_signed_in() else "signin"
	_error = ""
	_info = ""
	_confirm_delete = false
	_render()
	open()

func _render() -> void:
	clear_body()
	if not DataStore.auth.is_configured():
		var card := UI.card(16)
		var v := UI.vbox(8)
		v.add_child(UI.label("Configuration requise", 16, UI.TEXT, true))
		v.add_child(UI.label("Les comptes utilisent Supabase Auth. Renseignez l'URL du projet et la clé publique « anon » dans user://faillescheck_remote.json (procédure : docs/supabase_setup.md).",
			12, UI.TEXT_2, false, true))
		card.add_child(v)
		_body.add_child(card)
		return
	if DataStore.auth.is_signed_in():
		_render_manage()
	else:
		_render_form()

func _render_form() -> void:
	var card := UI.card(16)
	var v := UI.vbox(10)
	if _mode == "signup":
		var name_field := UI.line_edit("Nom d'affichage")
		name_field.name = "AccountName"
		v.add_child(name_field)
	var mail := UI.line_edit("Adresse e-mail")
	mail.name = "AccountEmail"
	mail.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_EMAIL_ADDRESS
	# Dernier compte utilisé : pré-rempli (jamais le mot de passe).
	if DataStore.last_email() != "":
		mail.text = DataStore.last_email()
	v.add_child(mail)
	if _mode != "recover":
		var pwd := UI.line_edit("Mot de passe")
		pwd.name = "AccountPassword"
		pwd.secret = true
		pwd.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_PASSWORD
		v.add_child(pwd)
	card.add_child(v)
	_body.add_child(card)

	if _error != "":
		_body.add_child(UI.label(_error, 12, UI.DANGER, false, true))
	if _info != "":
		_body.add_child(UI.label(_info, 12, UI.TEXT_2, false, true))

	var main_btn := UI.primary_button(_primary_label())
	main_btn.name = "AccountPrimary"
	main_btn.disabled = _busy
	main_btn.pressed.connect(_on_primary)
	_body.add_child(main_btn)

	var alt := UI.ghost_button(_alt_label(), UI.TEXT_2)
	alt.name = "AccountAlt"
	alt.pressed.connect(_on_alt)
	_body.add_child(alt)

	if _mode == "signin":
		var forgot := UI.ghost_button("Mot de passe oublié", UI.ACCENT)
		forgot.name = "AccountForgot"
		forgot.pressed.connect(_on_forgot)
		_body.add_child(forgot)

func _primary_label() -> String:
	match _mode:
		"signup": return "Créer un compte"
		"recover": return "Envoyer le lien"
	return "Se connecter"

func _alt_label() -> String:
	match _mode:
		"signup": return "J'ai déjà un compte"
		"recover": return "Retour"
	return "Créer un compte"

func _on_alt() -> void:
	_error = ""
	_info = ""
	match _mode:
		"signup": _mode = "signin"
		"recover": _mode = "signin"
		_: _mode = "signup"
	_render()

func _on_forgot() -> void:
	_error = ""
	_info = ""
	_mode = "recover"
	_render()

func _field_text(field_name: String) -> String:
	var n := _body.find_child(field_name, true, false)
	if n is LineEdit:
		return (n as LineEdit).text.strip_edges()
	return ""

func _on_primary() -> void:
	if _busy:
		return
	var mail := _field_text("AccountEmail")
	var pwd := _field_text("AccountPassword")
	var display := _field_text("AccountName")
	_error = ""
	_info = ""
	if mail == "" or not mail.contains("@"):
		_error = "Adresse e-mail invalide."
		_render()
		return
	if _mode != "recover" and pwd.length() < 6:
		_error = "Mot de passe : 6 caractères minimum."
		_render()
		return
	_busy = true
	var res: Dictionary
	if _mode == "signup":
		res = await DataStore.auth.sign_up(mail, pwd, display)
	elif _mode == "recover":
		res = await DataStore.auth.recover(mail)
	else:
		res = await DataStore.auth.sign_in(mail, pwd)
	_busy = false
	if bool(res.get("ok", false)):
		if _mode == "recover":
			_info = "Lien de réinitialisation envoyé."
			_mode = "signin"
		elif bool(res.get("needs_confirmation", false)):
			_info = "Compte créé. Validez votre adresse avec le lien reçu par e-mail."
			_mode = "signin"
		else:
			_mode = "manage"
	else:
		_error = str(res.get("error", "Action impossible."))
	_render()

func _render_manage() -> void:
	var auth := DataStore.auth
	var card := UI.card(16)
	var v := UI.vbox(6)
	v.add_child(UI.label(auth.display_name() if auth.display_name() != "" else "Compte", 17, UI.TEXT, true, true))
	v.add_child(UI.label(auth.email(), 12, UI.TEXT_2, false, true))
	card.add_child(v)
	_body.add_child(card)

	if _error != "":
		_body.add_child(UI.label(_error, 12, UI.DANGER, false, true))
	if _info != "":
		_body.add_child(UI.label(_info, 12, UI.TEXT_2, false, true))

	var name_field := UI.line_edit("Nom d'affichage")
	name_field.name = "AccountName"
	name_field.text = auth.display_name()
	_body.add_child(name_field)
	var save_name := UI.ghost_button("Enregistrer le nom", UI.ACCENT)
	save_name.name = "AccountSaveName"
	save_name.pressed.connect(_on_save_name)
	_body.add_child(save_name)

	var mail_field := UI.line_edit("Nouvelle adresse e-mail")
	mail_field.name = "AccountNewEmail"
	mail_field.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_EMAIL_ADDRESS
	_body.add_child(mail_field)
	var save_mail := UI.ghost_button("Changer d'adresse", UI.ACCENT)
	save_mail.name = "AccountSaveEmail"
	save_mail.pressed.connect(_on_save_email)
	_body.add_child(save_mail)

	var out := UI.ghost_button("Se déconnecter", UI.TEXT_2)
	out.name = "AccountSignOut"
	out.pressed.connect(_on_sign_out)
	_body.add_child(out)

	if _confirm_delete:
		var warn := UI.card(16)
		var wv := UI.vbox(8)
		wv.add_child(UI.label("Supprimer définitivement le compte ?", 15, UI.TEXT, true, true))
		wv.add_child(UI.label("Cette action est irréversible.", 12, UI.TEXT_2, false, true))
		warn.add_child(wv)
		_body.add_child(warn)
		var row := UI.hbox(10)
		var cancel := UI.ghost_button("Annuler", UI.TEXT_2)
		cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cancel.pressed.connect(func() -> void:
			_confirm_delete = false
			_render())
		row.add_child(cancel)
		var ok := UI.primary_button("Supprimer", UI.DANGER)
		ok.name = "AccountDeleteConfirm"
		ok.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ok.pressed.connect(_on_delete)
		row.add_child(ok)
		_body.add_child(row)
	else:
		var del := UI.ghost_button("Supprimer le compte", UI.DANGER)
		del.name = "AccountDelete"
		del.pressed.connect(func() -> void:
			_confirm_delete = true
			_render())
		_body.add_child(del)

func _on_save_name() -> void:
	var display := _field_text("AccountName")
	if display == "":
		_error = "Le nom ne peut pas être vide."
		_render()
		return
	var res: Dictionary = await DataStore.auth.update_display_name(display)
	_info = "Nom mis à jour." if bool(res.get("ok", false)) else ""
	_error = "" if bool(res.get("ok", false)) else str(res.get("error", "Modification impossible."))
	_render()

func _on_save_email() -> void:
	var mail := _field_text("AccountNewEmail")
	if mail == "" or not mail.contains("@"):
		_error = "Adresse e-mail invalide."
		_render()
		return
	var res: Dictionary = await DataStore.auth.update_email(mail)
	if bool(res.get("ok", false)):
		_info = "Validation envoyée à l'ancienne et à la nouvelle adresse."
		_error = ""
	else:
		_error = str(res.get("error", "Modification impossible."))
		_info = ""
	_render()

func _on_sign_out() -> void:
	await DataStore.auth.sign_out()
	_mode = "signin"
	_info = "Déconnecté."
	_error = ""
	_render()

func _on_delete() -> void:
	var res: Dictionary = await DataStore.auth.delete_account()
	if bool(res.get("ok", false)):
		_mode = "signin"
		_info = "Compte supprimé."
		_error = ""
	else:
		_error = str(res.get("error", "Suppression impossible."))
	_confirm_delete = false
	_render()
