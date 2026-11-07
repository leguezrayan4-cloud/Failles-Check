class_name NvdProvider
extends VulnProvider
## FaillesCheck — fournisseur de données réelles.
## Source publique : NVD (National Vulnerability Database, NIST).
##   https://nvd.nist.gov/  — API 2.0, sans clé obligatoire.
## Une clé facultative peut être fournie par la variable d'environnement
## NVD_API_KEY. Elle n'est JAMAIS écrite dans les fichiers du projet.

const BASE_URL := "https://services.nvd.nist.gov/rest/json/cves/2.0"
const REQUEST_TIMEOUT := 8.0
const DETAIL_URL := "https://nvd.nist.gov/vuln/detail/"

var _http: HTTPRequest
var _timer: Timer
var _active := false

func _ready() -> void:
	_http = HTTPRequest.new()
	_http.timeout = REQUEST_TIMEOUT
	add_child(_http)
	_http.request_completed.connect(_on_request_completed)

	# Garde-fou supplémentaire : délai maximal même si HTTPRequest reste bloqué.
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.wait_time = REQUEST_TIMEOUT + 1.5
	add_child(_timer)
	_timer.timeout.connect(_on_timeout)

func source_name() -> String:
	return "NVD"

func is_busy() -> bool:
	return _active

func fetch(query: String, max_results: int) -> void:
	if _active:
		cancel()
	var per_page := clampi(max_results, 1, 50)
	var url := "%s?resultsPerPage=%d&noRejected" % [BASE_URL, per_page]
	var q := query.strip_edges()
	if q != "":
		url += "&keywordSearch=" + q.uri_encode()

	var headers := PackedStringArray(["Accept: application/json"])
	var api_key := OS.get_environment("NVD_API_KEY")
	if api_key != "":
		headers.append("apiKey: " + api_key)

	_active = true
	var err := _http.request(url, headers)
	if err != OK:
		_active = false
		_finish([], _error("Impossible de démarrer la requête (code %d)." % err))
		return
	_timer.start()

func cancel() -> void:
	if _active:
		_http.cancel_request()
		_timer.stop()
		_active = false

func _on_timeout() -> void:
	if not _active:
		return
	_http.cancel_request()
	_active = false
	_finish([], _error("Délai dépassé : la source NVD ne répond pas. Les données locales sont conservées."))

func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if not _active:
		return
	_timer.stop()
	_active = false

	if result != HTTPRequest.RESULT_SUCCESS:
		_finish([], _error("Connexion au NVD impossible (%s). Vérifiez votre réseau." % _result_name(result)))
		return
	if response_code == 404:
		_finish([], _error("Le NVD n'a renvoyé aucun résultat pour cette recherche."))
		return
	if response_code == 403 or response_code == 429:
		_finish([], _error("Source NVD momentanément limitée (HTTP %d). Réessayez dans un instant." % response_code))
		return
	if response_code != 200:
		_finish([], _error("La source NVD a répondu avec une erreur (HTTP %d)." % response_code))
		return

	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if typeof(parsed) != TYPE_DICTIONARY:
		_finish([], _error("Réponse illisible de la source NVD."))
		return
	var list := _parse(parsed)
	_finish(list, _ok(list))

# --- Analyse ---------------------------------------------------------------
func _parse(root: Dictionary) -> Array:
	var out: Array = []
	var raw: Variant = root.get("vulnerabilities", [])
	if typeof(raw) != TYPE_ARRAY:
		return out
	for entry in raw:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var cve: Variant = entry.get("cve", {})
		if typeof(cve) != TYPE_DICTIONARY:
			continue
		var item := _to_item(cve)
		if not item.is_empty():
			out.append(item)
	return out

func _to_item(cve: Dictionary) -> Dictionary:
	var id := str(cve.get("id", ""))
	if id == "":
		return {}
	var desc := _english_description(cve)
	var score := 0.0
	var severity := "moyenne"
	var vector := "—"
	var metrics: Variant = cve.get("metrics", {})
	if typeof(metrics) == TYPE_DICTIONARY:
		var picked := _pick_metric(metrics)
		if not picked.is_empty():
			score = float(picked.get("score", 0.0))
			# Le barème officiel (score CVSS) est plus fiable que le libellé de
			# la source, qui varie selon la version du CVSS (« HIGH », …).
			severity = _severity_from_score(score)
			if score <= 0.0:
				severity = _map_severity(str(picked.get("severity", "")))
			vector = str(picked.get("vector", "—"))

	var product := "—"
	var version := "—"
	var cpe := _first_cpe(cve)
	if cpe != "":
		var parsed_cpe := _parse_cpe(cpe)
		product = str(parsed_cpe.get("product", "—"))
		version = str(parsed_cpe.get("version", "—"))

	var published := str(cve.get("published", ""))
	var date := published.substr(0, 10) if published.length() >= 10 else "—"

	return {
		"id": id,
		"title": _short_title(desc),
		"severity": severity,
		"score": score,
		"product": product,
		"version": version,
		"date": date,
		"status": "Publiée",
		"summary": _truncate(desc, 260),
		"description": desc,
		"remediation": "Consultez la fiche officielle %s sur le NVD pour appliquer le correctif recommandé par l'éditeur." % id,
		"vector": vector,
		"url": DETAIL_URL + id,
		"source": "NVD",
		"demo": false,
	}

func _english_description(cve: Dictionary) -> String:
	var descs: Variant = cve.get("descriptions", [])
	if typeof(descs) == TYPE_ARRAY:
		for d in descs:
			if typeof(d) == TYPE_DICTIONARY and str(d.get("lang", "")) == "en":
				return str(d.get("value", "")).strip_edges()
		if not descs.is_empty() and typeof(descs[0]) == TYPE_DICTIONARY:
			return str(descs[0].get("value", "")).strip_edges()
	return "Description non fournie par la source."

func _pick_metric(metrics: Dictionary) -> Dictionary:
	for key in ["cvssMetricV31", "cvssMetricV30"]:
		var arr: Variant = metrics.get(key, [])
		if typeof(arr) == TYPE_ARRAY and not arr.is_empty() and typeof(arr[0]) == TYPE_DICTIONARY:
			var data: Variant = arr[0].get("cvssData", {})
			if typeof(data) == TYPE_DICTIONARY:
				return {
					"score": data.get("baseScore", 0.0),
					"severity": data.get("baseSeverity", ""),
					"vector": data.get("vectorString", "—"),
				}
	var arr2: Variant = metrics.get("cvssMetricV2", [])
	if typeof(arr2) == TYPE_ARRAY and not arr2.is_empty() and typeof(arr2[0]) == TYPE_DICTIONARY:
		var m2: Dictionary = arr2[0]
		var d2: Variant = m2.get("cvssData", {})
		if typeof(d2) == TYPE_DICTIONARY:
			return {
				"score": d2.get("baseScore", 0.0),
				"severity": m2.get("baseSeverity", ""),
				"vector": d2.get("vectorString", "—"),
			}
	return {}

func _first_cpe(cve: Dictionary) -> String:
	var configs: Variant = cve.get("configurations", [])
	if typeof(configs) != TYPE_ARRAY:
		return ""
	for cfg in configs:
		if typeof(cfg) != TYPE_DICTIONARY:
			continue
		var nodes: Variant = cfg.get("nodes", [])
		if typeof(nodes) != TYPE_ARRAY:
			continue
		for node in nodes:
			if typeof(node) != TYPE_DICTIONARY:
				continue
			var matches: Variant = node.get("cpeMatch", [])
			if typeof(matches) != TYPE_ARRAY:
				continue
			for m in matches:
				if typeof(m) == TYPE_DICTIONARY:
					var c := str(m.get("criteria", ""))
					if c.begins_with("cpe:2.3"):
						return c
	return ""

func _parse_cpe(cpe: String) -> Dictionary:
	var parts := cpe.split(":")
	if parts.size() < 6:
		return {}
	var product := str(parts[4]).replace("_", " ").strip_edges()
	if product == "":
		product = "—"
	else:
		product = product.substr(0, 1).to_upper() + product.substr(1)
	var version := str(parts[5]).replace("_", " ").strip_edges()
	if version == "" or version == "*":
		version = "toutes versions"
	return {"product": product, "version": version}

## Barème CVSS : 9.0+ critique, 7.0+ élevée, 4.0+ moyenne, sinon faible.
func _severity_from_score(score: float) -> String:
	if score >= 9.0:
		return "critique"
	if score >= 7.0:
		return "elevee"
	if score >= 4.0:
		return "moyenne"
	if score > 0.0:
		return "faible"
	return "moyenne"

func _map_severity(raw: String) -> String:
	match raw.to_upper():
		"CRITICAL":
			return "critique"
		"HIGH":
			return "elevee"
		"MEDIUM":
			return "moyenne"
		"LOW":
			return "faible"
	return "moyenne"

func _short_title(desc: String) -> String:
	var t := desc.strip_edges()
	var idx := t.find(". ")
	if idx > 20 and idx < 120:
		t = t.substr(0, idx)
	return _truncate(t, 110)

func _truncate(text: String, limit: int) -> String:
	var t := text.strip_edges()
	if t.length() <= limit:
		return t
	return t.substr(0, limit).strip_edges() + "…"

func _result_name(result: int) -> String:
	match result:
		HTTPRequest.RESULT_CANT_CONNECT:
			return "connexion refusée"
		HTTPRequest.RESULT_CANT_RESOLVE:
			return "adresse introuvable"
		HTTPRequest.RESULT_CONNECTION_ERROR:
			return "erreur de connexion"
		HTTPRequest.RESULT_TLS_HANDSHAKE_ERROR:
			return "échec de la négociation TLS"
		HTTPRequest.RESULT_TIMEOUT:
			return "délai dépassé"
		HTTPRequest.RESULT_NO_RESPONSE:
			return "aucune réponse"
	return "erreur %d" % result