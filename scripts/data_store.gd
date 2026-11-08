extends Node
## FaillesCheck — magasin de données central (autoload "DataStore").
## Orchestre : fournisseurs (démo / NVD), synchronisation distante (Supabase),
## cache local et préférences. Aucune clé n'est écrite dans ce fichier.

signal data_changed
signal selection_changed
signal toast(message: String)
## Indicateur de chargement global (spinner centré) pour les actions longues.
signal busy_started(message: String)
signal busy_finished
signal loading_changed(is_loading: bool)
signal fetch_finished(ok: bool, message: String, source: String)
## Réglage d'accessibilité (transparence réduite) modifié.
signal accessibility_changed
## État du compte utilisateur modifié (connexion, déconnexion, profil).
signal auth_changed

const SAVE_PATH := "user://faillescheck_save.json"
const SAVE_VERSION := 3
const DEFAULT_SETTINGS := {
	"client_id": "",
	"online": true,
	"reduce_transparency": false,
	"notifications": true,
}
const MAX_RESULTS := 25

var settings: Dictionary = DEFAULT_SETTINGS.duplicate(true)
var software: Array = []
var vulnerabilities: Array = []
var selected_id: String = ""
var last_sync_at: String = ""
## Failles mises de côté (signet), indépendant des favoris logiciels.
var saved_ids: Array = []
var _sync_timer: Timer
var _live_timer: Timer
var _syncing := false
## Section IA : historique local et quota connu.
var ai_usage = null

var auth: AuthClient

var _nvd_provider: NvdProvider
var _sync: SyncProvider
var _catalog: SoftwareCatalog
var _loading := false

func _ready() -> void:
	auth = AuthClient.new()
	auth.name = "AuthClient"
	auth.state_changed.connect(_on_auth_state)

	# Synchronisation automatique en arrière-plan (silencieuse).
	_sync_timer = Timer.new()
	_sync_timer.name = "AutoSyncTimer"
	_sync_timer.wait_time = 300.0
	_sync_timer.autostart = true
	_sync_timer.timeout.connect(_auto_sync)
	add_child(_sync_timer)

	# Notifications réelles du téléphone (sans effet sur ordinateur).
	NotificationService.setup(self)
	Loc.setup(self)
	Loc.lang = str(settings.get("language", "fr"))

	# Session précédente : on reste connecté au prochain lancement.
	_restore_session()

	# Actualisation en direct : un autre appareil du même compte.
	_live_timer = Timer.new()
	_live_timer.name = "LiveRefreshTimer"
	_live_timer.wait_time = 20.0
	_live_timer.autostart = true
	_live_timer.timeout.connect(_live_refresh)
	add_child(_live_timer)
	add_child(auth)

	_nvd_provider = NvdProvider.new()
	_nvd_provider.name = "NvdProvider"
	_nvd_provider.completed.connect(_on_nvd_completed)
	add_child(_nvd_provider)

	_sync = SyncProvider.new()
	_sync.name = "SyncProvider"
	add_child(_sync)

	_catalog = SoftwareCatalog.new()
	_catalog.name = "SoftwareCatalog"
	add_child(_catalog)

# --- Accès -----------------------------------------------------------------
## Aucune donnée fictive : la source réelle (NVD) et son cache local sont les
## seules origines possibles.
func is_online() -> bool:
	return bool(settings.get("online", true))

func notifications_enabled() -> bool:
	return bool(settings.get("notifications", true))

func set_notifications(value: bool) -> void:
	settings["notifications"] = value
	save_data()
	if value:
		toast.emit("Notifications activées")

func is_loading() -> bool:
	return _loading

## Dernier compte utilisé (mémorisé localement, jamais le mot de passe).
func last_email() -> String:
	return str(settings.get("last_email", ""))

func last_display_name() -> String:
	return str(settings.get("last_display_name", ""))

func _on_auth_state() -> void:
	if auth.is_signed_in():
		settings["last_email"] = auth.email()
		settings["last_display_name"] = auth.display_name()
		save_data()
	auth_changed.emit()

## --- Section IA -------------------------------------------------------------
const AI_CHAT_PATH := "user://faillescheck_ai_chat.json"

func ai_history() -> Array:
	var out: Array = []
	if FileAccess.file_exists(AI_CHAT_PATH):
		var txt := FileAccess.get_file_as_string(AI_CHAT_PATH)
		var parsed: Variant = JSON.parse_string(txt) if txt.strip_edges() != "" else null
		if typeof(parsed) == TYPE_ARRAY:
			out = parsed
	return out

func ai_save_history(messages: Array) -> void:
	var f := FileAccess.open(AI_CHAT_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(messages))
	f.close()

func ai_clear_history() -> void:
	if FileAccess.file_exists(AI_CHAT_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(AI_CHAT_PATH))

func ai_translation_for(id: String) -> String:
	var all: Dictionary = settings.get("ai_translations", {})
	return str(all.get(id, ""))

func set_ai_translation(id: String, text: String) -> void:
	if id == "" or text.strip_edges() == "":
		return
	var all: Dictionary = settings.get("ai_translations", {})
	all[id] = text.strip_edges()
	settings["ai_translations"] = all
	save_data()

func ai_remaining() -> int:
	return int(settings.get("ai_remaining", -1))

func ai_resets_at() -> String:
	return str(settings.get("ai_resets_at", ""))

func set_ai_quota(remaining: int, resets_at: String) -> void:
	settings["ai_remaining"] = remaining
	if resets_at != "":
		settings["ai_resets_at"] = resets_at
	save_data()

## --- Failles lues / récentes / commentaires --------------------------------
func mark_read(id: String) -> void:
	if id == "":
		return
	var read_ids: Array = settings.get("read_ids", [])
	if read_ids.has(id):
		return
	read_ids.append(id)
	settings["read_ids"] = read_ids
	save_data()

func is_read(id: String) -> bool:
	var read_ids: Array = settings.get("read_ids", [])
	return read_ids.has(id)

func unread_critical() -> int:
	var n := 0
	for v in vulnerabilities:
		if str(v.get("severity", "")) == "critique" and not is_read(str(v.get("id", ""))):
			n += 1
	return n

func push_recent(id: String) -> void:
	if id == "":
		return
	var list: Array = settings.get("recent_ids", [])
	list.erase(id)
	list.insert(0, id)
	while list.size() > 20:
		list.pop_back()
	settings["recent_ids"] = list
	save_data()

func recent_ids() -> Array:
	return settings.get("recent_ids", [])

func comment_for(id: String) -> String:
	var all: Dictionary = settings.get("comments", {})
	return str(all.get(id, ""))

func set_comment(id: String, text: String) -> void:
	var all: Dictionary = settings.get("comments", {})
	if text.strip_edges() == "":
		all.erase(id)
	else:
		all[id] = text.strip_edges()
	settings["comments"] = all
	save_data()
	toast.emit("Commentaire enregistré")

## Indicateur de chargement global (utilisé par les écrans).
func start_busy(message: String) -> void:
	busy_started.emit(message)

func end_busy() -> void:
	busy_finished.emit()

func language() -> String:
	return str(settings.get("language", "fr"))

func set_language(code: String) -> void:
	settings["language"] = code
	Loc.lang = code
	save_data()
	toast.emit("Langue : " + ("Français" if code == "fr" else "English"))

## Suppression des données de CET appareil (le compte distant est conservé).
func clear_local_data() -> void:
	software = []
	saved_ids = []
	selected_id = ""
	settings["recent_ids"] = []
	settings["comments"] = {}
	settings["read_ids"] = []
	settings["ai_translations"] = {}
	settings.erase("last_sync_at")
	VulnCache.clear()
	ai_clear_history()
	rebuild()
	save_data()
	toast.emit("Données locales supprimées")

func is_reduce_transparency() -> bool:
	return bool(settings.get("reduce_transparency", false))

## Accessibilité : fonds plus opaques et contrastes renforcés (inspiré d'iOS).
## Le réglage est enregistré localement et appliqué immédiatement.
func set_reduce_transparency(value: bool) -> void:
	settings["reduce_transparency"] = value
	UI.transparency_reduced = value
	save_data()
	accessibility_changed.emit()
	toast.emit("Transparence réduite" if value else "Transparence normale")

func catalog() -> SoftwareCatalog:
	return _catalog

func sync_configured() -> bool:
	return SyncProvider.is_configured()

func get_vulnerability(id: String) -> Dictionary:
	for v in vulnerabilities:
		if str(v.get("id", "")) == id:
			return v
	return {}

func selected() -> Dictionary:
	return get_vulnerability(selected_id)

func select(id: String) -> void:
	selected_id = id
	selection_changed.emit()

func severity_keys() -> Array:
	return ["critique", "elevee", "moyenne", "faible"]

func source_label() -> String:
	for v in vulnerabilities:
		if not bool(v.get("demo", false)):
			return "NVD (NIST)"
	return "Aucune"

func has_real_data() -> bool:
	for v in vulnerabilities:
		if not bool(v.get("demo", false)):
			return true
	return false

func client_id() -> String:
	_ensure_client_id()
	return str(settings.get("client_id", ""))

## Génère l'identifiant d'appareil en mémoire uniquement : il ne sera écrit
## qu'au prochain enregistrement réel, pour ne jamais écraser une sauvegarde.
func _ensure_client_id() -> void:
	if str(settings.get("client_id", "")) == "":
		settings["client_id"] = "fc-%08x%08x" % [randi(), randi()]

# --- Chargement / persistance ----------------------------------------------
## Étape 1 du chargement : données locales uniquement (instantané, hors ligne).
## Lecture NON destructive : si la sauvegarde est illisible (fichier en cours
## d'écriture, contenu tronqué…), on conserve l'état courant au lieu de
## repartir sur les valeurs par défaut.
func load_local() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
		if f != null:
			var txt := f.get_as_text()
			f.close()
			var parsed: Variant = JSON.parse_string(txt)
			if typeof(parsed) == TYPE_DICTIONARY:
				var d: Dictionary = parsed
				var s: Variant = d.get("settings", null)
				if typeof(s) == TYPE_DICTIONARY:
					var merged: Dictionary = DEFAULT_SETTINGS.duplicate(true)
					merged.merge(s, true)
					settings = merged
				var sw: Variant = d.get("software", null)
				if typeof(sw) == TYPE_ARRAY:
					software = sw
				var sv: Variant = d.get("saved", null)
				if typeof(sv) == TYPE_ARRAY:
					saved_ids = sv
			elif txt.strip_edges() != "":
				push_warning("FaillesCheck : sauvegarde illisible, état conservé.")
	_ensure_client_id()
	UI.transparency_reduced = is_reduce_transparency()
	Loc.lang = str(settings.get("language", "fr"))
	data_changed.emit()

## Étape 2 : catalogue hors ligne construit depuis le cache local.
func refresh_from_cache() -> void:
	rebuild()
	data_changed.emit()

func emit_changed() -> void:
	data_changed.emit()

func _write_file() -> void:
	var d := {
		"version": SAVE_VERSION,
		"settings": settings,
		"software": software,
		"saved": saved_ids,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(d, "  "))
		f.close()

func save_data() -> void:
	_write_file()
	data_changed.emit()
	_schedule_auto_sync()

# --- Synchronisation automatique (déclenchée par chaque modification) ------
var _auto_sync_timer: Timer
var _auto_sync_retry := 0
var _auto_sync_failing := false

func _schedule_auto_sync() -> void:
	if not SyncProvider.is_configured() or not auth.is_signed_in():
		return
	if _auto_sync_timer == null:
		_auto_sync_timer = Timer.new()
		_auto_sync_timer.one_shot = true
		_auto_sync_timer.wait_time = 1.2
		_auto_sync_timer.timeout.connect(_run_auto_sync)
		add_child(_auto_sync_timer)
	_auto_sync_timer.start()

func _run_auto_sync() -> void:
	if _syncing or not auth.is_signed_in():
		return
	var res: Dictionary = await sync_now()
	if bool(res.get("ok", false)):
		_auto_sync_retry = 0
		# Échec prolongé seulement : l'utilisateur est prévenu.
		if _auto_sync_failing:
			_auto_sync_failing = false
			toast.emit("Synchronisation rétablie")
		return
	_auto_sync_retry += 1
	var delay := minf(120.0, 5.0 * float(_auto_sync_retry))
	if _auto_sync_retry >= 4 and not _auto_sync_failing:
		_auto_sync_failing = true
		toast.emit("Synchronisation en attente, nouvelle tentative automatique")
	var t := get_tree().create_timer(delay)
	t.timeout.connect(_run_auto_sync)

# --- Sources de données ----------------------------------------------------
## Catalogue = uniquement les données réelles récupérées (cache local).
func rebuild() -> void:
	vulnerabilities = VulnCache.all_items()
	if selected_id != "" and get_vulnerability(selected_id).is_empty():
		selected_id = ""

func set_online(value: bool) -> void:
	settings["online"] = value
	save_data()
	toast.emit("Source en ligne activée" if value else "Source en ligne désactivée")

## Coroutine : récupère les vulnérabilités depuis la source publique (NVD).
func fetch_vulnerabilities_async(query: String) -> Dictionary:
	if _loading:
		return {"ok": false, "error": "Une récupération est déjà en cours.", "count": 0}
	if not is_online():
		return {"ok": false, "error": "Source en ligne désactivée (mode hors ligne).", "count": 0}
	_set_loading(true)
	_nvd_provider.fetch(query, MAX_RESULTS)
	var args: Array = await _nvd_provider.completed
	var results: Array = args[0] if args.size() > 0 else []
	var meta: Dictionary = args[1] if args.size() > 1 else {}
	if not bool(meta.get("ok", false)):
		return {"ok": false, "error": str(meta.get("error", "Erreur de récupération.")), "count": 0}
	return {"ok": true, "error": "", "count": results.size()}

## Déclenchement depuis l'interface (résultat diffusé par fetch_finished).
var _last_query := ""
var _retry_used := false

func search_online(query: String) -> void:
	if _loading:
		return
	_last_query = query
	if not is_online():
		fetch_finished.emit(false, "Source en ligne désactivée.", "")
		return
	_set_loading(true)
	_nvd_provider.fetch(query, MAX_RESULTS)

func _on_nvd_completed(results: Array, meta: Dictionary) -> void:
	_set_loading(false)
	var ok := bool(meta.get("ok", false))
	if ok and not results.is_empty():
		# Nouvelles failles critiques touchant vos logiciels : vraie notification.
		var alerts := _new_alerts(results)
		VulnCache.merge(results)
		rebuild()
		data_changed.emit()
		_notify_alerts(alerts)
	_retry_used = ok
	var message := ""
	if ok:
		message = "%d vulnérabilité(s) récupérée(s)." % results.size()
	else:
		message = str(meta.get("error", "Erreur de récupération."))
		if not _retry_used and _last_query != "":
			_retry_used = true
			_retry_fetch()
	fetch_finished.emit(ok, message, str(meta.get("source", "")))

## Failles critiques inédites concernant un logiciel suivi.
func _new_alerts(results: Array) -> Array:
	var out: Array = []
	for v in results:
		if typeof(v) != TYPE_DICTIONARY:
			continue
		if str(v.get("severity", "")) != "critique":
			continue
		var id := str(v.get("id", ""))
		if id == "" or not get_vulnerability(id).is_empty():
			continue
		var prod := str(v.get("product", "")).strip_edges().to_lower()
		if prod == "":
			continue
		for s in software:
			if typeof(s) != TYPE_DICTIONARY:
				continue
			var n := str(s.get("name", "")).strip_edges().to_lower()
			if n != "" and (prod == n or prod.contains(n) or n.contains(prod)):
				out.append(v)
				break
	return out

func _notify_alerts(alerts: Array) -> void:
	if alerts.is_empty() or not notifications_enabled():
		return
	var first: Dictionary = alerts[0]
	var title := "%d nouvelle(s) faille(s) critique(s)" % alerts.size()
	var body := "%s — %s" % [str(first.get("product", "")), str(first.get("title", ""))]
	NotificationService.notify(title, body)
	toast.emit(title)

## Un seul réessai automatique (source momentanément limitée).
func _retry_fetch() -> void:
	var q := _last_query
	await get_tree().create_timer(20.0).timeout
	if _loading or q == "":
		return
	search_online(q)

func cancel_online() -> void:
	_nvd_provider.cancel()
	_set_loading(false)

func _set_loading(value: bool) -> void:
	if _loading == value:
		return
	_loading = value
	loading_changed.emit(value)

# --- Cache -----------------------------------------------------------------
func cache_info() -> Dictionary:
	return {"count": VulnCache.size(), "updated": VulnCache.updated_at()}

func clear_cache() -> void:
	VulnCache.clear()
	rebuild()
	data_changed.emit()
	toast.emit("Cache vidé")

# --- Synchronisation distante ----------------------------------------------
## Coroutine : échange avec Supabase (profiles + user_software) pour
## l'utilisateur connecté. Les règles RLS s'appliquent côté serveur.
func sync_now() -> Dictionary:
	if _syncing:
		return {"ok": false, "error": "Synchronisation déjà en cours.", "pushed": 0, "merged": 0}
	_syncing = true
	var out := await _sync_now_inner()
	_syncing = false
	return out

func _sync_now_inner() -> Dictionary:
	if not SyncProvider.is_configured():
		return {"ok": false, "error": "Service distant non configuré.", "pushed": 0, "merged": 0}
	if not auth.is_signed_in():
		return {"ok": false, "error": "Connectez-vous pour synchroniser.", "pushed": 0, "merged": 0}
	var uid := auth.user_id()
	var token := auth.access_token
	if uid == "" or token == "":
		return {"ok": false, "error": "Session invalide.", "pushed": 0, "merged": 0}

	# Profil (créé s'il n'existe pas encore).
	await _sync.upsert_profile(uid, token, auth.display_name())

	var pulled: Dictionary = await _sync.pull_software(uid, token)
	if not bool(pulled.get("ok", false)):
		return {"ok": false, "error": str(pulled.get("error", "Récupération distante impossible.")), "pushed": 0, "merged": 0}

	var remote_items: Array = pulled.get("items", [])
	var remote_names := {}
	for r in remote_items:
		if typeof(r) == TYPE_DICTIONARY:
			remote_names[str(r.get("name", "")).strip_edges().to_lower()] = true

	var pushed := 0
	for item in software:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var res: Dictionary = await _sync.save_software(uid, token, item)
		if bool(res.get("ok", false)):
			pushed += 1

	var merged := 0
	for r in remote_items:
		if typeof(r) != TYPE_DICTIONARY:
			continue
		var rname := str(r.get("name", "")).strip_edges()
		if rname == "" or _find_software_by_name(rname) != null:
			continue
		software.append({
			"id": "SW-R-%d" % (randi() % 1000000),
			"name": rname,
			"version": str(r.get("version", "")),
			"editor": str(r.get("publisher", "")),
			"identifier": "",
			"favorite": bool(r.get("is_favorite", false)),
			"remote": true,
		})
		merged += 1

	if pushed > 0 or merged > 0:
		save_data()

	last_sync_at = Time.get_datetime_string_from_system(false, true)
	return {"ok": true, "error": "", "pushed": pushed, "merged": merged}

## Envoi d'un logiciel (silencieux : ignoré si non connecté).
func _push_remote(item: Dictionary) -> void:
	if not SyncProvider.is_configured() or not auth.is_signed_in():
		return
	var res: Dictionary = await _sync.save_software(auth.user_id(), auth.access_token, item)
	if bool(res.get("ok", false)):
		item["remote"] = true
		save_data()

func _delete_remote(app_name: String) -> void:
	if not SyncProvider.is_configured() or not auth.is_signed_in():
		return
	await _sync.delete_software(auth.user_id(), auth.access_token, app_name)

# --- Logiciels -------------------------------------------------------------
func _find_software_by_name(app_name: String) -> Variant:
	var target := app_name.strip_edges().to_lower()
	for s in software:
		if typeof(s) == TYPE_DICTIONARY and str(s.get("name", "")).strip_edges().to_lower() == target:
			return s
	return null

func _find_software_by_identifier(identifier: String) -> Variant:
	if identifier == "":
		return null
	for s in software:
		if typeof(s) == TYPE_DICTIONARY and str(s.get("identifier", "")) == identifier:
			return s
	return null

# --- Signets (failles mises de côté) ---------------------------------------
func is_saved(id: String) -> bool:
	return saved_ids.has(id)

func toggle_saved(id: String) -> void:
	if id == "":
		return
	if saved_ids.has(id):
		saved_ids.erase(id)
		toast.emit("Retiré des enregistrements")
	else:
		saved_ids.append(id)
		toast.emit("Faille enregistrée")
	save_data()

func saved_count() -> int:
	return saved_ids.size()

# --- Notes personnelles ----------------------------------------------------
func note_for(id: String) -> String:
	for s in software:
		if typeof(s) == TYPE_DICTIONARY and str(s.get("id", "")) == id:
			return str(s.get("note", ""))
	return ""

func set_note(id: String, text: String) -> void:
	for s in software:
		if typeof(s) == TYPE_DICTIONARY and str(s.get("id", "")) == id:
			s["note"] = text.strip_edges()
			save_data()
			toast.emit("Note enregistrée")
			return

# --- Session, notifications de test, actualisation en direct ---------------
func _restore_session() -> void:
	# Les nœuds réseau doivent être dans l'arbre avant toute requête.
	await get_tree().process_frame
	await get_tree().process_frame
	await auth.restore_session()
	if auth.is_signed_in():
		auth_changed.emit()
		await sync_now()

## Récupère l'état distant : un logiciel supprimé sur un autre appareil
## disparaît ici aussi, et les ajouts arrivent automatiquement.
func _live_refresh() -> void:
	if not auth.is_signed_in() or _loading or _syncing:
		return
	var uid := auth.user_id()
	var token := auth.access_token
	if uid == "" or token == "":
		return
	var res: Dictionary = await _sync.pull_software(uid, token)
	if not bool(res.get("ok", false)):
		return
	var rows: Variant = res.get("items", [])
	if typeof(rows) != TYPE_ARRAY:
		return
	var remote_names: Array = []
	for r in rows:
		if typeof(r) == TYPE_DICTIONARY:
			remote_names.append(str((r as Dictionary).get("name", "")).strip_edges().to_lower())
	var changed := false
	# Suppressions faites ailleurs.
	var kept: Array = []
	for s in software:
		if typeof(s) != TYPE_DICTIONARY:
			continue
		var n := str(s.get("name", "")).strip_edges().to_lower()
		if bool(s.get("remote", false)) and n != "" and not remote_names.has(n):
			changed = true
			continue
		kept.append(s)
	if changed:
		software = kept
	# Ajouts faits ailleurs.
	for r in rows:
		if typeof(r) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = r
		var rn := str(row.get("name", "")).strip_edges()
		if rn == "":
			continue
		var exists := false
		for s in software:
			if typeof(s) == TYPE_DICTIONARY and str(s.get("name", "")).strip_edges().to_lower() == rn.to_lower():
				exists = true
				break
		if exists:
			continue
		software.append({
			"id": "sw-" + str(Time.get_unix_time_from_system()) + "-" + str(software.size()),
			"name": rn,
			"editor": str(row.get("publisher", "")),
			"version": str(row.get("version", "")),
			"identifier": "",
			"favorite": bool(row.get("is_favorite", false)),
			"note": "",
		})
		changed = true
	if changed:
		save_data()
		toast.emit("Liste mise à jour depuis un autre appareil")

# --- Synchronisation automatique -------------------------------------------
func _auto_sync() -> void:
	if not SyncProvider.is_configured() or not auth.is_signed_in():
		return
	if _loading:
		return
	await sync_now()

# --- Favoris & statistiques (données réelles uniquement) -------------------
func is_favorite(id: String) -> bool:
	for s in software:
		if typeof(s) == TYPE_DICTIONARY and str(s.get("id", "")) == id:
			return bool(s.get("favorite", false))
	return false

func toggle_favorite(id: String) -> void:
	for s in software:
		if typeof(s) == TYPE_DICTIONARY and str(s.get("id", "")) == id:
			var now := not bool(s.get("favorite", false))
			s["favorite"] = now
			save_data()
			toast.emit("Ajouté aux favoris" if now else "Retiré des favoris")
			_push_remote(s)
			return

func favorites() -> Array:
	var out: Array = []
	for s in software:
		if typeof(s) == TYPE_DICTIONARY and bool(s.get("favorite", false)):
			out.append(s)
	return out

## Vulnérabilités réelles rattachées à un logiciel (nom de produit renvoyé
## par la source). Aucune correspondance inventée.
func vulns_for_software(app_name: String) -> Array:
	var target := app_name.strip_edges().to_lower()
	var out: Array = []
	if target == "":
		return out
	for v in vulnerabilities:
		var prod := str(v.get("product", "")).strip_edges().to_lower()
		if prod == "":
			continue
		if prod == target or prod.contains(target) or target.contains(prod):
			out.append(v)
	return out

## Historique réel : nombre de vulnérabilités publiées par mois, calculé
## uniquement sur les données récupérées. Vide si la source n'a pas de date.
func software_history(app_name: String) -> Dictionary:
	var by_month := {}
	for v in vulns_for_software(app_name):
		var d := str(v.get("date", ""))
		if d.length() < 7:
			continue
		var key := d.substr(0, 7)
		by_month[key] = int(by_month.get(key, 0)) + 1
	if by_month.is_empty():
		return {"labels": [], "values": []}
	var keys: Array = by_month.keys()
	keys.sort()
	if keys.size() > 12:
		keys = keys.slice(keys.size() - 12, keys.size())
	var labels: Array = []
	var values: Array = []
	for k in keys:
		labels.append(str(k))
		values.append(int(by_month[k]))
	return {"labels": labels, "values": values}

## Retourne "" en cas de succès, sinon un message d'erreur lisible.
func add_software(app_name: String, version: String, editor: String, identifier: String = "") -> String:
	var n := app_name.strip_edges()
	if n == "":
		return "Le nom du logiciel est obligatoire."
	if _find_software_by_name(n) != null:
		return "« %s » est déjà dans votre liste." % n
	if identifier != "" and _find_software_by_identifier(identifier) != null:
		return "Ce logiciel est déjà dans votre liste."
	var item := {
		"id": "SW-%d-%d" % [int(Time.get_unix_time_from_system()), randi() % 100000],
		"name": n,
		"version": version.strip_edges(),
		"editor": editor.strip_edges(),
		"identifier": identifier,
		"favorite": false,
	}
	software.append(item)
	save_data()
	toast.emit("Logiciel ajouté")
	_push_remote(item)
	# Récupération des vulnérabilités réelles de ce logiciel (NVD).
	if is_online():
		search_online(n)
	return ""

func remove_software(id: String) -> void:
	var removed_name := ""
	for i in range(software.size()):
		var item: Variant = software[i]
		if typeof(item) == TYPE_DICTIONARY and str(item.get("id", "")) == id:
			removed_name = str(item.get("name", ""))
			software.remove_at(i)
			break
	save_data()
	toast.emit("Logiciel supprimé")
	if removed_name != "":
		_delete_remote(removed_name)