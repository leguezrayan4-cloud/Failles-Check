class_name SyncProvider
extends Node
## FaillesCheck — synchronisation avec Supabase (PostgREST).
## Toutes les opérations utilisent le JWT de l'utilisateur connecté : les
## règles RLS de `profiles` et `user_software` s'appliquent côté serveur.
## Aucune clé secrète n'est utilisée (voir RemoteConfig).
##
## Schéma réel du projet :
##   profiles(id, display_name, created_at)
##   user_software(id, user_id, name, version, publisher, is_favorite, created_at)

var _client: SupabaseClient

func _ready() -> void:
	_client = SupabaseClient.new()
	_client.name = "SupabaseClient"
	add_child(_client)

static func is_configured() -> bool:
	return RemoteConfig.is_configured()

static func status_text() -> String:
	return RemoteConfig.status_text()

# --- Profils ---------------------------------------------------------------
## Crée ou met à jour la ligne `profiles` de l'utilisateur connecté.
func upsert_profile(user_id: String, token: String, display_name: String) -> Dictionary:
	if user_id == "" or token == "":
		return {"ok": false, "error": "Session absente."}
	var body := {
		"id": user_id,
		"display_name": display_name,
	}
	return await _client.request(HTTPClient.METHOD_POST, _table_profiles(),
		{"on_conflict": "id"}, body, token)

func pull_profile(user_id: String, token: String) -> Dictionary:
	var res: Dictionary = await _client.request(HTTPClient.METHOD_GET, _table_profiles(),
		{"select": "id,display_name", "id": "eq." + user_id}, null, token)
	if bool(res.get("ok", false)):
		var data: Variant = res.get("data", [])
		res["item"] = (data as Array)[0] if typeof(data) == TYPE_ARRAY and not (data as Array).is_empty() else {}
	return res

# --- Logiciels (user_software) ---------------------------------------------
## Enregistre un logiciel : mise à jour de la ligne existante (même nom) ou
## création. Aucune contrainte unique n'est supposée côté serveur.
func save_software(user_id: String, token: String, item: Dictionary) -> Dictionary:
	if user_id == "" or token == "":
		return {"ok": false, "error": "Session absente."}
	var app_name := str(item.get("name", "")).strip_edges()
	if app_name == "":
		return {"ok": false, "error": "Nom vide."}
	var body := {
		"user_id": user_id,
		"name": app_name,
		"version": str(item.get("version", "")),
		"publisher": str(item.get("editor", "")),
		"is_favorite": bool(item.get("favorite", false)),
	}
	var patch: Dictionary = await _client.request(HTTPClient.METHOD_PATCH, _table_user_software(),
		{"user_id": "eq." + user_id, "name": "eq." + app_name}, body, token)
	if bool(patch.get("ok", false)):
		var data: Variant = patch.get("data", [])
		if typeof(data) == TYPE_ARRAY and not (data as Array).is_empty():
			return patch
	return await _client.request(HTTPClient.METHOD_POST, _table_user_software(), {}, body, token)

func delete_software(user_id: String, token: String, app_name: String) -> Dictionary:
	if user_id == "" or token == "":
		return {"ok": false, "error": "Session absente."}
	return await _client.request(HTTPClient.METHOD_DELETE, _table_user_software(),
		{"user_id": "eq." + user_id, "name": "eq." + app_name}, null, token)

func pull_software(user_id: String, token: String) -> Dictionary:
	if user_id == "" or token == "":
		return {"ok": false, "error": "Session absente.", "items": []}
	var res: Dictionary = await _client.request(HTTPClient.METHOD_GET, _table_user_software(),
		{"select": "id,name,version,publisher,is_favorite", "user_id": "eq." + user_id}, null, token)
	if bool(res.get("ok", false)):
		var data: Variant = res.get("data", [])
		res["items"] = data if typeof(data) == TYPE_ARRAY else []
	else:
		res["items"] = []
	return res

# --- Vulnérabilités (miroir public, optionnel) -----------------------------
func push_vulnerabilities(items: Array) -> Dictionary:
	if items.is_empty():
		return {"ok": true, "code": 0, "data": null, "error": "", "count": 0}
	var rows: Array = []
	for v in items:
		if typeof(v) != TYPE_DICTIONARY:
			continue
		rows.append({
			"id": str(v.get("id", "")),
			"title": str(v.get("title", "")),
			"severity": str(v.get("severity", "")),
			"score": float(v.get("score", 0.0)),
			"product": str(v.get("product", "")),
			"affected_version": str(v.get("version", "")),
			"status": str(v.get("status", "")),
			"summary": str(v.get("summary", "")),
			"description": str(v.get("description", "")),
			"remediation": str(v.get("remediation", "")),
			"vector": str(v.get("vector", "")),
			"url": str(v.get("url", "")),
			"source": str(v.get("source", "")),
			"published": str(v.get("date", "")),
		})
	var res: Dictionary = await _client.request(HTTPClient.METHOD_POST, _table_vuln(), {}, rows)
	res["count"] = rows.size()
	return res

# --- Interne ---------------------------------------------------------------
func _table_profiles() -> String:
	return str(RemoteConfig.load_config().get("profiles_table", RemoteConfig.DEFAULT_TABLE_PROFILES))

func _table_user_software() -> String:
	return str(RemoteConfig.load_config().get("user_software_table", RemoteConfig.DEFAULT_TABLE_USER_SOFTWARE))

func _table_vuln() -> String:
	return str(RemoteConfig.load_config().get("vuln_table", RemoteConfig.DEFAULT_TABLE_VULN))
