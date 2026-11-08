class_name Loc
extends RefCounted
## FaillesCheck — langue de l'interface (Français / English).
## Le contenu des failles (NVD) reste en anglais : sa traduction est confiée
## à la section IA, jamais inventée ici.

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
		"tab_home": "Accueil", "tab_search": "Recherche", "tab_ai": "IA",
		"tab_software": "Logiciels", "tab_settings": "Paramètres",
		"home_title": "Accueil", "home_sub": "Vue d'ensemble",
		"search_title": "Recherche", "search_sub": "Catalogue de failles",
		"software_title": "Mes logiciels", "software_sub": "Logiciels suivis",
		"settings_title": "Paramètres", "settings_sub": "Compte et préférences",
		"ai_title": "IA", "ai_sub": "Assistant",
		"ai_placeholder": "Écrivez un message…", "ai_send": "Envoyer",
		"ai_thinking": "Réponse en cours…",
		"ai_need_account": "Connectez-vous pour utiliser la section IA.",
		"ai_offline": "Hors ligne : la section IA est indisponible.",
		"ai_quota_unknown": "Quota mensuel de messages.",
		"ai_remaining": "%d messages restants ce mois-ci",
		"ai_quota_out": "Quota atteint : 300 messages utilisés ce mois-ci.",
		"ai_reset_on": "Réinitialisation le %s.",
		"ai_input_locked": "Saisie désactivée",
		"ai_welcome": "Bonjour ! Posez une question sur une faille, demandez une traduction, ou vérifiez une version de logiciel.",
		"ai_cached": "Traduction déjà conservée sur votre appareil :",
		"ai_translate_prompt": "Traduis en français la faille %s « %s » et explique en deux phrases ce qu'elle implique.",
		"detail": "Détail", "software": "Logiciel", "affected_version": "Version affectée",
		"status": "Statut", "date": "Date", "your_version": "Votre version",
		"description": "Description", "recommendations": "Recommandations",
		"reference": "Référence", "save": "Enregistrer", "saved": "Enregistrée",
		"share": "Partager", "score": "Score CVSS", "source": "Source",
		"ask_translation": "Demander une traduction",
		"language": "Langue",
		"language_desc": "L'interface est traduite ; le contenu des failles (NVD) reste en anglais et peut être traduit par l'IA.",
		"french": "Français", "english": "English",
		"cancel": "Annuler", "close": "Fermer", "skip": "Passer", "next": "Suivant",
		"start": "Commencer", "retry": "Réessayer", "offline_mode": "Mode hors-ligne",
		"offline_title": "Pas de connexion",
		"offline_msg": "Impossible de joindre le réseau. Vous pouvez réessayer ou continuer avec les données déjà présentes sur l'appareil.",
		"offline_warn": "Mode hors-ligne : les failles ne seront pas mises à jour.",
		"sec_account": "Compte", "sec_appearance": "Apparence", "sec_notifications": "Notifications",
		"sec_data": "Données", "sec_help": "Aide et à propos", "sec_ai": "Intelligence artificielle",
		"row_account": "Compte", "row_reduced_transparency": "Transparence réduite",
		"row_reduced_transparency_desc": "Fonds opaques et contraste renforcé.",
		"row_dark": "Mode sombre", "row_dark_desc": "Fonds sombres, texte clair.",
		"row_language": "Langue", "row_alerts": "Alertes de vulnérabilités",
		"row_alerts_desc": "Notifications système pour les failles critiques de vos logiciels.",
		"row_test_notifs": "Notification de test (chaque minute)",
		"row_test_notifs_desc": "Sert uniquement à vérifier le système sur le téléphone.",
		"row_sync": "Synchroniser", "row_last_sync": "Dernière synchronisation",
		"row_cache": "Vider le cache", "row_export": "Exporter les logiciels (CSV)",
		"row_import": "Importer des logiciels", "row_clear_local": "Supprimer les données locales",
		"row_guide": "Guide de démarrage", "row_version": "Version de l'application",
		"row_source": "Source des données", "row_legal": "Mentions légales",
		"row_devices": "Appareils connectés",
		"never": "Jamais",
		"clear_local_title": "Supprimer les données locales ?",
		"clear_local_msg": "Les logiciels, notes, favoris et cache de cet appareil seront effacés. Votre compte distant n'est pas supprimé.",
		"confirm": "Confirmer", "delete": "Supprimer",
		"guide_1_title": "Suivez vos logiciels",
		"guide_1_text": "Ajoutez un logiciel depuis l'onglet Logiciels, puis choisissez-le dans la liste proposée.",
		"guide_2_title": "Repérez les failles",
		"guide_2_text": "L'accueil classe les failles par gravité. Touchez une carte pour lire la fiche complète.",
		"guide_3_title": "Comprenez et agissez",
		"guide_3_text": "Demandez une traduction à l'IA, enregistrez une faille, ou suivez une version précise.",
		"loading": "Chargement…",
	},
	"en": {
		"tab_home": "Home", "tab_search": "Search", "tab_ai": "AI",
		"tab_software": "Software", "tab_settings": "Settings",
		"home_title": "Home", "home_sub": "Overview",
		"search_title": "Search", "search_sub": "Vulnerability catalogue",
		"software_title": "My software", "software_sub": "Tracked software",
		"settings_title": "Settings", "settings_sub": "Account and preferences",
		"ai_title": "AI", "ai_sub": "Assistant",
		"ai_placeholder": "Write a message…", "ai_send": "Send",
		"ai_thinking": "Answering…",
		"ai_need_account": "Sign in to use the AI section.",
		"ai_offline": "Offline: the AI section is unavailable.",
		"ai_quota_unknown": "Monthly message quota.",
		"ai_remaining": "%d messages left this month",
		"ai_quota_out": "Quota reached: 300 messages used this month.",
		"ai_reset_on": "Resets on %s.",
		"ai_input_locked": "Input disabled",
		"ai_welcome": "Hello! Ask about a vulnerability, request a translation, or check a software version.",
		"ai_cached": "Translation already stored on your device:",
		"ai_translate_prompt": "Translate vulnerability %s (%s) into French and explain in two sentences what it means.",
		"detail": "Details", "software": "Software", "affected_version": "Affected version",
		"status": "Status", "date": "Date", "your_version": "Your version",
		"description": "Description", "recommendations": "Recommendations",
		"reference": "Reference", "save": "Save", "saved": "Saved",
		"share": "Share", "score": "CVSS score", "source": "Source",
		"ask_translation": "Request a translation",
		"language": "Language",
		"language_desc": "The interface is translated; vulnerability content (NVD) stays in English and can be translated by the AI.",
		"french": "Français", "english": "English",
		"cancel": "Cancel", "close": "Close", "skip": "Skip", "next": "Next",
		"start": "Start", "retry": "Retry", "offline_mode": "Offline mode",
		"offline_title": "No connection",
		"offline_msg": "The network is unreachable. You can retry or continue with the data already on this device.",
		"offline_warn": "Offline mode: vulnerabilities will not be updated.",
		"sec_account": "Account", "sec_appearance": "Appearance", "sec_notifications": "Notifications",
		"sec_data": "Data", "sec_help": "Help and about", "sec_ai": "Artificial intelligence",
		"row_account": "Account", "row_reduced_transparency": "Reduce transparency",
		"row_reduced_transparency_desc": "Opaque backgrounds and stronger contrast.",
		"row_dark": "Dark mode", "row_dark_desc": "Dark backgrounds, light text.",
		"row_language": "Language", "row_alerts": "Vulnerability alerts",
		"row_alerts_desc": "System notifications for critical vulnerabilities in your software.",
		"row_test_notifs": "Test notification (every minute)",
		"row_test_notifs_desc": "Only used to verify the system on your phone.",
		"row_sync": "Sync", "row_last_sync": "Last sync",
		"row_cache": "Clear cache", "row_export": "Export software (CSV)",
		"row_import": "Import software", "row_clear_local": "Delete local data",
		"row_guide": "Getting started guide", "row_version": "App version",
		"row_source": "Data source", "row_legal": "Legal notices",
		"row_devices": "Connected devices",
		"never": "Never",
		"clear_local_title": "Delete local data?",
		"clear_local_msg": "Software, notes, favourites and cache on this device will be erased. Your remote account is not deleted.",
		"confirm": "Confirm", "delete": "Delete",
		"guide_1_title": "Track your software",
		"guide_1_text": "Add software from the Software tab, then pick it from the suggested list.",
		"guide_2_title": "Spot vulnerabilities",
		"guide_2_text": "The home screen ranks vulnerabilities by severity. Tap a card to read the full details.",
		"guide_3_title": "Understand and act",
		"guide_3_text": "Ask the AI for a translation, save a vulnerability, or track a specific version.",
		"loading": "Loading…",
	},
}

static func t(key: String) -> String:
	var table: Dictionary = STRINGS.get(lang, STRINGS["fr"])
	if table.has(key):
		return str(table[key])
	return str((STRINGS["fr"] as Dictionary).get(key, key))

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

## Traduction rapide de secours (utilisée si la section IA n'est pas disponible).
## Renvoie "" en cas d'échec : le texte d'origine est conservé.
static func translate(text: String, cb: Callable) -> void:
	var src := text.strip_edges()
	if src == "" or lang == "en" or _http == null:
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
