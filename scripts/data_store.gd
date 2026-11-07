extends Node
## FaillesCheck — magasin de données central (autoload "DataStore").
## Orchestre : fournisseurs (démo / NVD), synchronisation distante (Supabase),
## cache local et préférences. Aucune clé n'est écrite dans ce fichier.

signal data_changed
signal selection_changed
signal toast(message: String)
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

var auth: AuthClient

var _nvd_provider: NvdProvider
var _sync: SyncProvider
var _catalog: SoftwareCatalog
var _loading := false

func _ready() -> void:
	auth = AuthClient.new()
	auth.name = "AuthClient"
	auth.state_changed.connect(func() -> void: auth_changed.emit())
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
			elif txt.strip_edges() != "":
				push_warning("FaillesCheck : sauvegarde illisible, état conservé.")
	_ensure_client_id()
	UI.transparency_reduced = is_reduce_transparency()
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
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(d, "  "))
		f.close()

func save_data() -> void:
	_write_file()
	data_changed.emit()

func reset_all() -> void:
	var cid := client_id()
	settings = DEFAULT_SETTINGS.duplicate(true)
	settings["client_id"] = cid
	software = []
	selected_id = ""
	last_sync_at = ""
	VulnCache.clear()
	rebuild()
	save_data()
	toast.emit("Données réinitialisées")

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
func search_online(query: String) -> void:
	if _loading:
		return
	if not is_online():
		fetch_finished.emit(false, "Source en ligne désactivée.", "")
		return
	_set_loading(true)
	_nvd_provider.fetch(query, MAX_RESULTS)

func _on_nvd_completed(results: Array, meta: Dictionary) -> void:
	_set_loading(false)
	var ok := bool(meta.get("ok", false))
	if ok and not results.is_empty():
		VulnCache.merge(results)
		rebuild()
		data_changed.emit()
	var message := ""
	if ok:
		message = "%d vulnérabilité(s) récupérée(s)." % results.size()
	else:
		message = str(meta.get("error", "Erreur de récupération."))
	fetch_finished.emit(ok, message, str(meta.get("source", "")))

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
	await _sync.save_software(auth.user_id(), auth.access_token, item)

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