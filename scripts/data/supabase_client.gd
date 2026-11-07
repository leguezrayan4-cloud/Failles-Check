class_name SupabaseClient
extends Node
## FaillesCheck — client REST minimal pour Supabase (API PostgREST).
## Ne contient aucune clé : elles sont lues via RemoteConfig.

const REQUEST_TIMEOUT := 8.0

var _http: HTTPRequest

func _ready() -> void:
	_http = HTTPRequest.new()
	_http.timeout = REQUEST_TIMEOUT
	add_child(_http)

## Coroutine. Retourne { ok, code, data, error }.
func request(method: int, path: String, params: Dictionary = {}, body: Variant = null) -> Dictionary:
	var cfg := RemoteConfig.load_config()
	var base := str(cfg.get("url", ""))
	var key := str(cfg.get("anon_key", ""))
	if base == "" or key == "":
		return {"ok": false, "code": 0, "data": null, "error": "Synchronisation distante non configurée."}

	var url := "%s/rest/v1/%s" % [base, path]
	var query := _encode_params(params)
	if query != "":
		url += "?" + query

	var headers := PackedStringArray([
		"apikey: " + key,
		"Authorization: Bearer " + key,
		"Content-Type: application/json",
		"Accept: application/json",
		"Prefer: return=representation,resolution=merge-duplicates",
	])
	var payload := ""
	if body != null:
		payload = JSON.stringify(body)

	var err := _http.request(url, headers, method, payload)
	if err != OK:
		return {"ok": false, "code": 0, "data": null, "error": "Impossible de démarrer la requête (code %d)." % err}

	var result: Array = await _http.request_completed
	var result_code := int(result[0])
	var http_code := int(result[1])
	var raw: PackedByteArray = result[3]
	var text := raw.get_string_from_utf8()
	var data: Variant = null
	if text.strip_edges() != "":
		data = JSON.parse_string(text)

	if result_code != HTTPRequest.RESULT_SUCCESS:
		if result_code == HTTPRequest.RESULT_TIMEOUT:
			return {"ok": false, "code": http_code, "data": data, "error": "Le service distant n'a pas répondu à temps."}
		return {"ok": false, "code": http_code, "data": data, "error": "Connexion au service distant impossible."}
	if http_code == 401 or http_code == 403:
		return {"ok": false, "code": http_code, "data": data, "error": "Accès refusé par le service distant (clé ou règles RLS)."}
	if http_code < 200 or http_code >= 300:
		return {"ok": false, "code": http_code, "data": data, "error": "Le service distant a répondu HTTP %d." % http_code}
	return {"ok": true, "code": http_code, "data": data, "error": ""}

func _encode_params(params: Dictionary) -> String:
	var parts: Array = []
	for k in params.keys():
		parts.append("%s=%s" % [str(k).uri_encode(), str(params[k]).uri_encode()])
	return "&".join(parts)