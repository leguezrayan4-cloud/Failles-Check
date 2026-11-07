class_name Loc
extends RefCounted
## FaillesCheck — langue de l'application et traduction du contenu des failles.
## Les fiches du NVD sont rédigées en anglais : elles sont traduites dans la
## langue choisie, puis mises en cache (aucune traduction inventée : si le
## service est indisponible, le texte d'origine est affiché).

const CACHE_PATH := "user://faillescheck_translations.json"
const ENDPOINT := "https://translate.googleapis.com/translate_a/single"

static var lang := "fr"
static var _cache: Dictionary = {}
static var _loaded := false
static var _http: HTTPRequest
static var _queue: Array = []
static var _busy := false

const STRINGS := {
	"fr": {
		"tab_home": "Accueil", "tab_search": "Recherche", "tab_software": "Logiciels", "tab_settings": "Paramètres",
		"home_title": "Accueil", "home_sub": "Vue d'ensemble",
		"search_title": "Recherche", "search_sub": "Catalogue de failles",
		"software_title": "Mes logiciels", "software_sub": "Suivi et favoris",
		"settings_title": "Paramètres", "settings_sub": "Compte et préférences",
		"detail": "Détail", "software": "Logiciel", "affected_version": "Version affectée",
		"status": "Statut", "date": "Date", "your_version": "Votre version",
		"description": "Description", "recommendations": "Recommandations",
		"reference": "Référence", "save": "Enregistrer", "saved": "Enregistrée",
		"share": "Partager", "score": "Score CVSS", "source": "Source",
		"language": "Langue", "language_desc": "Langue du contenu des failles.",
	},
	"en": {
		"tab_home": "Home", "tab_search": "Search", "tab_software": "Software", "tab_settings": "Settings",
		"home_title": "Home", "home_sub": "Overview",
		"search_title": "Search", "search_sub": "Vulnerability catalogue",
		"software_title": "My software", "software_sub": "Tracking and favourites",
		"settings_title": "Settings", "settings_sub": "Account and preferences",
		"detail": "Details", "software": "Software", "affected_version": "Affected version",
		"status": "Status", "date": "Date", "your_version": "Your version",
		"description": "Description", "recommendations": "Recommendations",
		"reference": "Reference", "save": "Save", "saved": "Saved",
		"share": "Share", "score": "CVSS score", "source": "Source",
		"language": "Language", "language_desc": "Language of vulnerability content.",
	},
}

static func t(key: String) -> String:
	var table: Dictionary = STRINGS.get(lang, STRINGS["fr"])
	return str(table.get(key, key))

static func setup(parent: Node) -> void:
	if _http != null:
		return
	_http = HTTPRequest.new()
	_http.name = "LocHttp"
	_http.timeout = 10.0
	parent.add_child(_http)
	_load_cache()

static func _load_cache() -> void:
	if _loaded:
		return
	_loaded = true
	if not FileAccess.file_exists(CACHE_PATH):
		return
	var txt := FileAccess.get_file_as_string(CACHE_PATH)
	var parsed: Variant = JSON.parse_string(txt) if txt.strip_edges() != "" else null
	if typeof(parsed) == TYPE_DICTIONARY:
		_cache = parsed

static func _save_cache() -> void:
	var f := FileAccess.open(CACHE_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(_cache))
	f.close()

static func _key(text: String) -> String:
	return "%s|%s" % [lang, text.md5_text()]

## Traduction en cache (synchrone) : renvoie "" si inconnue.
static func cached(text: String) -> String:
	_load_cache()
	return str(_cache.get(_key(text), ""))

## Traduit un texte puis appelle `cb` avec le résultat ("" si échec).
static func translate(text: String, cb: Callable) -> void:
	var src := text.strip_edges()
	if src == "" or lang == "en":
		cb.call("")
		return
	var hit := cached(src)
	if hit != "":
		cb.call(hit)
		return
	_queue.append({"text": src, "cb": cb})
	_pump()

static func _pump() -> void:
	if _busy or _queue.is_empty() or _http == null:
		return
	_busy = true
	var job: Dictionary = _queue.pop_front()
	var src := str(job.get("text", ""))
	var cb: Callable = job.get("cb", Callable())
	# L'API accepte de longs textes : on borne pour rester rapide.
	if src.length() > 1200:
		src = src.substr(0, 1200)
	var url := "%s?client=gtx&sl=en&tl=%s&dt=t&q=%s" % [ENDPOINT, lang, src.uri_encode()]
	var err := _http.request(url)
	if err != OK:
		_busy = false
		cb.call("")
		_pump()
		return
	var res: Array = await _http.request_completed
	_busy = false
	var out := ""
	if int(res[1]) == 200:
		var body := (res[3] as PackedByteArray).get_string_from_utf8()
		var parsed: Variant = JSON.parse_string(body)
		if typeof(parsed) == TYPE_ARRAY and (parsed as Array).size() > 0:
			var parts: Variant = (parsed as Array)[0]
			if typeof(parts) == TYPE_ARRAY:
				for p in parts:
					if typeof(p) == TYPE_ARRAY and (p as Array).size() > 0:
						out += str((p as Array)[0])
	if out.strip_edges() != "":
		_cache[_key(str(job.get("text", "")))] = out
		_save_cache()
	cb.call(out)
	_pump()
