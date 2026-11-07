class_name SyncProvider
extends Node
## FaillesCheck — synchronisation avec la base distante (Supabase / PostgREST).
## Aucune clé n'est écrite dans le projet : voir RemoteConfig et docs/supabase_setup.md.
## Si la configuration est absente, toutes les opérations échouent proprement
## et l'application continue en mode local (cache + données de démonstration).

var _client: SupabaseClient

func _ready() -> void:
	_client = SupabaseClient.new()
	_client.name = "SupabaseClient"
	add_child(_client)

static func is_configured() -> bool:
	return RemoteConfig.is_configured()

static func status_text() -> String:
	return RemoteConfig.status_text()

# --- Logiciels -------------------------------------------------------------
func push_software(client_id: String, item: Dictionary) -> Dictionary:
	var body := {
		"client_id": client_id,
		"local_id": str(item.get("id", "")),
		"name": str(item.get("name", "")),
		"version": str(item.get("version", "")),
		"editor": str(item.get("editor", "")),
		"identifier": str(item.get("identifier", "")),
	}
	var res: Dictionary = await _client.request(HTTPClient.METHOD_POST, _table_software(), {}, body)
	return res

func delete_software(client_id: String, local_id: String) -> Dictionary:
	var res: Dictionary = await _client.request(HTTPClient.METHOD_DELETE, _table_software(),
		{"client_id": "eq." + client_id, "local_id": "eq." + local_id}, null)
	return res

func pull_software(client_id: String) -> Dictionary:
	var res: Dictionary = await _client.request(HTTPClient.METHOD_GET, _table_software(),
		{"select": "local_id,name,version,editor,identifier", "client_id": "eq." + client_id}, null)
	if bool(res.get("ok", false)):
		var data: Variant = res.get("data", [])
		res["items"] = data if typeof(data) == TYPE_ARRAY else []
	else:
		res["items"] = []
	return res

# --- Vulnérabilités --------------------------------------------------------
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

func pull_vulnerabilities(limit: int = 100) -> Dictionary:
	var res: Dictionary = await _client.request(HTTPClient.METHOD_GET, _table_vuln(),
		{"select": "*", "limit": str(limit), "order": "published.desc"}, null)
	if bool(res.get("ok", false)):
		var data: Variant = res.get("data", [])
		res["items"] = data if typeof(data) == TYPE_ARRAY else []
	else:
		res["items"] = []
	return res

# --- Interne ---------------------------------------------------------------
func _table_software() -> String:
	return str(RemoteConfig.load_config().get("software_table", RemoteConfig.DEFAULT_TABLE_SOFTWARE))

func _table_vuln() -> String:
	return str(RemoteConfig.load_config().get("vuln_table", RemoteConfig.DEFAULT_TABLE_VULN))