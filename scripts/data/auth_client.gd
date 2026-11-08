class_name AuthClient
extends Node
## FaillesCheck — comptes utilisateurs via Supabase Auth (API REST publique).
##
## Aucune clé secrète : seule la clé publique « anon » est utilisée, lue dans
## user://faillescheck_remote.json ou les variables d'environnement.
## Aucun mot de passe n'est stocké : seuls les jetons de session permettent de
## rester connecté au prochain démarrage (révoqués à la déconnexion).

signal state_changed
signal failed(message: String)
signal restore_finished

const SESSION_PATH := "user://faillescheck_session.json"

var access_token := ""
var refresh_token := ""
var user: Dictionary = {}
var restoring := false

var _http: HTTPRequest
var _rest: SupabaseClient

func _ready() -> void:
	_http = HTTPRequest.new()
	_http.timeout = 20.0
	add_child(_http)
	_rest = SupabaseClient.new()
	_rest.name = "AuthRest"
	add_child(_rest)

func user_id() -> String:
	return str(user.get("id", ""))

## Crée (ou met à jour) la ligne `profiles` de l'utilisateur connecté.
## Les règles RLS garantissent qu'un utilisateur ne peut écrire que la sienne.
func ensure_profile() -> Dictionary:
	_ensure_http()
	if not is_signed_in():
		return {"ok": false, "error": "Non connecté."}
	var uid := user_id()
	if uid == "":
		return {"ok": false, "error": "Identifiant utilisateur absent."}
	var table := str(RemoteConfig.load_config().get("profiles_table", RemoteConfig.DEFAULT_TABLE_PROFILES))
	# Colonnes réelles de la table profiles : id, display_name, created_at.
	var body := {
		"id": uid,
		"display_name": display_name(),
	}
	return await _rest.request(HTTPClient.METHOD_POST, table, {"on_conflict": "id"}, body, access_token)

func is_configured() -> bool:
	return RemoteConfig.is_configured()

func is_signed_in() -> bool:
	return access_token != "" and not user.is_empty()

func display_name() -> String:
	var md: Variant = user.get("user_metadata", {})
	if typeof(md) == TYPE_DICTIONARY:
		return str((md as Dictionary).get("display_name", ""))
	return ""

func email() -> String:
	return str(user.get("email", ""))

func _base() -> String:
	return str(RemoteConfig.load_config().get("url", ""))

func _key() -> String:
	return str(RemoteConfig.load_config().get("anon_key", ""))

## Crée les nœuds réseau si nécessaire (l'autoload peut être prêt avant eux).
func _ensure_http() -> void:
	if _http == null:
		_http = HTTPRequest.new()
		_http.name = "AuthHttp"
		_http.timeout = 20.0
		add_child(_http)
	if _rest == null:
		_rest = SupabaseClient.new()
		_rest.name = "AuthRest"
		add_child(_rest)

func _request(method: int, path: String, body: Dictionary, token: String = "") -> Dictionary:
	_ensure_http()
	if not is_configured():
		return {"ok": false, "error": "Configuration requise."}
	var headers := PackedStringArray([
		"apikey: " + _key(),
		"Content-Type: application/json",
		"Authorization: Bearer " + (token if token != "" else _key()),
	])
	var payload := JSON.stringify(body) if not body.is_empty() else ""
	var err := _http.request(_base() + path, headers, method, payload)
	if err != OK:
		return {"ok": false, "error": "Requête impossible."}
	var res: Array = await _http.request_completed
	var code := int(res[1])
	var text := (res[3] as PackedByteArray).get_string_from_utf8()
	var data: Variant = JSON.parse_string(text) if text != "" else null
	if code >= 200 and code < 300:
		return {"ok": true, "data": data if data != null else {}}
	var msg := "Erreur réseau."
	if typeof(data) == TYPE_DICTIONARY:
		var d: Dictionary = data
		msg = str(d.get("msg", d.get("error_description", d.get("error", msg))))
	return {"ok": false, "error": msg, "code": code}

func _apply_session(d: Dictionary) -> void:
	access_token = str(d.get("access_token", ""))
	refresh_token = str(d.get("refresh_token", ""))
	var u: Variant = d.get("user", {})
	user = u if typeof(u) == TYPE_DICTIONARY else {}
	_save_session()
	state_changed.emit()

func _clear_session() -> void:
	access_token = ""
	refresh_token = ""
	user = {}
	remove_session_file()
	state_changed.emit()

# --- Session persistante (rester connecté au prochain lancement) -----------
func is_restoring() -> bool:
	return restoring

func remove_session_file() -> void:
	if FileAccess.file_exists(SESSION_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SESSION_PATH))

func _save_session() -> void:
	if refresh_token == "":
		return
	var f := FileAccess.open(SESSION_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({
		"refresh_token": refresh_token,
		"email": str(user.get("email", "")),
		"user": user,
	}, "  "))
	f.close()

## Restaure la session enregistrée (jeton de rafraîchissement).
func restore_session() -> bool:
	if not is_configured():
		restore_finished.emit()
		return false
	if not FileAccess.file_exists(SESSION_PATH):
		restore_finished.emit()
		return false
	var txt := FileAccess.get_file_as_string(SESSION_PATH)
	var parsed: Variant = JSON.parse_string(txt) if txt.strip_edges() != "" else null
	if typeof(parsed) != TYPE_DICTIONARY:
		remove_session_file()
		restore_finished.emit()
		return false
	var stored: Dictionary = parsed
	var token := str(stored.get("refresh_token", ""))
	if token == "":
		remove_session_file()
		restore_finished.emit()
		return false
	restoring = true
	var res: Dictionary = await _request(
		HTTPClient.METHOD_POST, "/auth/v1/token?grant_type=refresh_token",
		{"refresh_token": token})
	restoring = false
	if bool(res.get("ok", false)):
		var d: Variant = res.get("data", {})
		if typeof(d) == TYPE_DICTIONARY:
			_apply_session(d)
			restore_finished.emit()
			return true
	# Jeton expiré ou révoqué : on repart proprement sur l'écran de connexion.
	# En cas de simple panne réseau, la session est conservée pour plus tard.
	var code := int(res.get("code", 0))
	if code == 400 or code == 401 or code == 403:
		refresh_token = ""
		remove_session_file()
		state_changed.emit()
	restore_finished.emit()
	return false

# --- Inscription / connexion ----------------------------------------------
func sign_up(mail: String, password: String, new_name: String) -> Dictionary:
	var res: Dictionary = await _request(HTTPClient.METHOD_POST, "/auth/v1/signup", {
		"email": mail,
		"password": password,
		"data": {"display_name": new_name},
	})
	if bool(res.get("ok", false)):
		var d: Variant = res.get("data", {})
		if typeof(d) == TYPE_DICTIONARY and (d as Dictionary).has("access_token"):
			_apply_session(d)
			await ensure_profile()
			return {"ok": true, "needs_confirmation": false}
		return {"ok": true, "needs_confirmation": true}
	failed.emit(str(res.get("error", "Inscription impossible.")))
	return res

func sign_in(mail: String, password: String) -> Dictionary:
	var res: Dictionary = await _request(HTTPClient.METHOD_POST, "/auth/v1/token?grant_type=password", {
		"email": mail,
		"password": password,
	})
	if bool(res.get("ok", false)):
		var d: Variant = res.get("data", {})
		if typeof(d) == TYPE_DICTIONARY:
			_apply_session(d)
			await ensure_profile()
			return {"ok": true}
	failed.emit(str(res.get("error", "Connexion impossible.")))
	return res

func sign_out() -> void:
	if access_token != "":
		await _request(HTTPClient.METHOD_POST, "/auth/v1/logout", {}, access_token)
	_clear_session()

## Changement de mot de passe : l'ancien est vérifié côté serveur.
func change_password(current_password: String, new_password: String) -> Dictionary:
	if not is_signed_in():
		return {"ok": false, "error": "Non connecté."}
	var mail := email()
	if mail == "":
		return {"ok": false, "error": "Adresse e-mail inconnue."}
	# Vérification de l'ancien mot de passe par une connexion de contrôle.
	var check: Dictionary = await _request(HTTPClient.METHOD_POST, "/auth/v1/token?grant_type=password", {
		"email": mail,
		"password": current_password,
	})
	if not bool(check.get("ok", false)):
		return {"ok": false, "error": "Ancien mot de passe incorrect."}
	var res: Dictionary = await _request(HTTPClient.METHOD_PUT, "/auth/v1/user", {"password": new_password}, access_token)
	if bool(res.get("ok", false)):
		return {"ok": true}
	return {"ok": false, "error": str(res.get("error", "Modification impossible."))}

func recover(mail: String) -> Dictionary:
	var res: Dictionary = await _request(HTTPClient.METHOD_POST, "/auth/v1/recover", {"email": mail})
	if not bool(res.get("ok", false)):
		failed.emit(str(res.get("error", "Envoi impossible.")))
	return res

# --- Gestion du compte -----------------------------------------------------
func update_display_name(new_name: String) -> Dictionary:
	var res: Dictionary = await _request(HTTPClient.METHOD_PUT, "/auth/v1/user",
		{"data": {"display_name": new_name}}, access_token)
	if bool(res.get("ok", false)):
		var d: Variant = res.get("data", {})
		if typeof(d) == TYPE_DICTIONARY:
			user = d
			state_changed.emit()
	else:
		failed.emit(str(res.get("error", "Modification impossible.")))
	return res

## Changement d'adresse : Supabase envoie un lien de validation à l'ancienne
## ET à la nouvelle adresse avant d'appliquer le changement.
func update_email(new_mail: String) -> Dictionary:
	var res: Dictionary = await _request(HTTPClient.METHOD_PUT, "/auth/v1/user",
		{"email": new_mail}, access_token)
	if not bool(res.get("ok", false)):
		failed.emit(str(res.get("error", "Modification impossible.")))
	return res

## Suppression du compte : passe par une fonction SQL protégée côté serveur
## (voir docs/supabase_setup.md). Aucune clé de service dans l'application.
func delete_account() -> Dictionary:
	var res: Dictionary = await _request(HTTPClient.METHOD_POST, "/rest/v1/rpc/delete_own_account", {}, access_token)
	if bool(res.get("ok", false)):
		_clear_session()
	else:
		failed.emit(str(res.get("error", "Suppression impossible.")))
	return res
