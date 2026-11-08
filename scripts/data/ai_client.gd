class_name AiClient
extends Node
## FaillesCheck — accès à la section IA (Claude).
##
## Aucune clé d'API n'est présente dans l'application : les requêtes passent
## par une fonction Supabase (`supabase/functions/ai-chat`) qui détient la clé
## et vérifie le quota côté serveur (300 messages par mois et par compteur).

signal quota_changed(remaining: int, resets_at: String)

const FUNCTION_PATH := "/functions/v1/ai-chat"
const TIMEOUT := 45.0

var _http: HTTPRequest
var _busy := false

func _ready() -> void:
	_ensure_http()

func _ensure_http() -> void:
	if _http == null:
		_http = HTTPRequest.new()
		_http.name = "AiHttp"
		_http.timeout = TIMEOUT
		add_child(_http)

func is_busy() -> bool:
	return _busy

## Envoie l'historique complet ; renvoie {ok, text, remaining, resets_at, error}.
func ask(history: Array, vuln: Dictionary = {}) -> Dictionary:
	_ensure_http()
	if not RemoteConfig.is_configured():
		return {"ok": false, "error": "Service IA non configuré."}
	if not DataStore.auth.is_signed_in():
		return {"ok": false, "error": "Connectez-vous pour utiliser l'IA."}
	if _busy:
		return {"ok": false, "error": "Une réponse est déjà en cours."}
	if not DataStore.is_online():
		return {"ok": false, "error": "Hors ligne : la section IA est indisponible."}
	_busy = true
	var cfg := RemoteConfig.load_config()
	var base := str(cfg.get("url", ""))
	var key := str(cfg.get("anon_key", ""))
	var body := {"messages": history}
	if not vuln.is_empty():
		body["vuln"] = vuln
	var headers := PackedStringArray([
		"apikey: " + key,
		"Content-Type: application/json",
		"Authorization: Bearer " + DataStore.auth.access_token,
	])
	var err := _http.request(base + FUNCTION_PATH, headers, HTTPClient.METHOD_POST, JSON.stringify(body))
	if err != OK:
		_busy = false
		return {"ok": false, "error": "Requête impossible."}
	var res: Array = await _http.request_completed
	_busy = false
	var code := int(res[1])
	var text := (res[3] as PackedByteArray).get_string_from_utf8()
	var data: Variant = JSON.parse_string(text) if text.strip_edges() != "" else null
	if code == 200 and typeof(data) == TYPE_DICTIONARY:
		var d: Dictionary = data
		var remaining := int(d.get("remaining", -1))
		var resets := str(d.get("resets_at", ""))
		if remaining >= 0:
			quota_changed.emit(remaining, resets)
		var reply := str(d.get("reply", "")).strip_edges()
		if reply == "":
			return {"ok": false, "error": "Réponse vide du service IA."}
		return {"ok": true, "text": reply, "remaining": remaining, "resets_at": resets}
	if code == 429:
		var sub := ""
		if typeof(data) == TYPE_DICTIONARY:
			sub = str((data as Dictionary).get("resets_at", ""))
		quota_changed.emit(0, sub)
		return {"ok": false, "error": "Quota atteint (300 messages par mois).", "quota": true, "resets_at": sub}
	if code == 401 or code == 403:
		return {"ok": false, "error": "Session expirée : reconnectez-vous."}
	if code == 404:
		return {"ok": false, "error": "Service IA non déployé sur le projet Supabase."}
	if code == 0:
		return {"ok": false, "error": "Délai dépassé : vérifiez votre connexion."}
	var msg := "Service indisponible."
	if typeof(data) == TYPE_DICTIONARY:
		var d2: Dictionary = data
		msg = str(d2.get("error", d2.get("message", msg)))
	return {"ok": false, "error": msg}
