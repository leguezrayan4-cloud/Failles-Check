extends Node
## FaillesCheck — magasin de données central (autoload "DataStore").
## Orchestre : fournisseurs (démo / NVD), synchronisation distante (Supabase),
## cache local et préférences. Aucune clé n'est écrite dans ce fichier.

signal data_changed
signal selection_changed
signal toast(message: String)
signal loading_changed(is_loading: bool)
signal fetch_finished(ok: bool, message: String, source: String)

const SAVE_PATH := "user://faillescheck_save.json"
const SAVE_VERSION := 3
const DEFAULT_SETTINGS := {"demo_data": false, "online": false, "client_id": ""}
const MAX_RESULTS := 25

var settings: Dictionary = DEFAULT_SETTINGS.duplicate(true)
var software: Array = []
var vulnerabilities: Array = []
var selected_id: String = ""
var last_sync_at: String = ""

var _demo_provider: DemoProvider
var _nvd_provider: NvdProvider
var _sync: SyncProvider
var _catalog: SoftwareCatalog
var _loading := false

func _ready() -> void:
	_demo_provider = DemoProvider.new()
	_demo_provider.name = "DemoProvider"
	add_child(_demo_provider)

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
func is_demo() -> bool:
	return bool(settings.get("demo_data", false))

func is_online() -> bool:
	return bool(settings.get("online", false))

func is_loading() -> bool:
	return _loading

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
	if is_demo():
		return "DÉMO · FICTIF"
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
func rebuild() -> void:
	if is_demo():
		vulnerabilities = DemoProvider.catalog()
	else:
		vulnerabilities = VulnCache.all_items()
	if selected_id != "" and get_vulnerability(selected_id).is_empty():
		selected_id = ""

func set_demo(value: bool) -> void:
	settings["demo_data"] = value
	rebuild()
	save_data()
	toast.emit("Données de démonstration activées" if value else "Données de démonstration désactivées")

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
		fetch_finished.emit(false, "Activez « Source en ligne (NVD) » dans Réglages pour interroger la source.", "")
		return
	_set_loading(true)
	_nvd_provider.fetch(query, MAX_RESULTS)

func _on_nvd_completed(results: Array, meta: Dictionary) -> void:
	_set_loading(false)
	var ok := bool(meta.get("ok", false))
	if ok and not results.is_empty():
		VulnCache.merge(results)
		if not is_demo():
			rebuild()
			data_changed.emit()
	var message := ""
	if ok:
		message = "%d vulnérabilité(s) récupérée(s) depuis le NVD." % results.size()
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
	if not is_demo():
		rebuild()
		data_changed.emit()
	toast.emit("Cache vidé")

# --- Synchronisation distante ----------------------------------------------
## Coroutine : échange avec la base distante (Supabase) si elle est configurée.
func sync_now() -> Dictionary:
	if not SyncProvider.is_configured():
		return {"ok": false, "error": "Synchronisation distante non configurée.", "pushed": 0, "merged": 0}
	var cid := client_id()
	var pulled: Dictionary = await _sync.pull_software(cid)
	if not bool(pulled.get("ok", false)):
		return {"ok": false, "error": str(pulled.get("error", "Récupération distante impossible.")), "pushed": 0, "merged": 0}

	var remote_items: Array = pulled.get("items", [])
	var remote_ids := {}
	for r in remote_items:
		if typeof(r) == TYPE_DICTIONARY:
			remote_ids[str(r.get("local_id", ""))] = true

	var pushed := 0
	for item in software:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		if remote_ids.has(str(item.get("id", ""))):
			continue
		var res: Dictionary = await _sync.push_software(cid, item)
		if bool(res.get("ok", false)):
			pushed += 1

	var merged := 0
	for r in remote_items:
		if typeof(r) != TYPE_DICTIONARY:
			continue
		var rname := str(r.get("name", "")).strip_edges()
		if rname == "" or _find_software_by_name(rname) != null:
			continue
		var local_id := str(r.get("local_id", ""))
		if local_id == "":
			local_id = "SW-R-%d" % (randi() % 1000000)
		software.append({
			"id": local_id,
			"name": rname,
			"version": str(r.get("version", "")),
			"editor": str(r.get("editor", "")),
			"identifier": str(r.get("identifier", "")),
			"remote": true,
		})
		merged += 1

	if pushed > 0 or merged > 0:
		save_data()

	# Miroir public des vulnérabilités (non bloquant si refusé).
	if not vulnerabilities.is_empty():
		await _sync.push_vulnerabilities(vulnerabilities)

	last_sync_at = Time.get_datetime_string_from_system(false, true)
	return {"ok": true, "error": "", "pushed": pushed, "merged": merged}

func _push_remote(item: Dictionary) -> void:
	if not SyncProvider.is_configured():
		return
	await _sync.push_software(client_id(), item)

func _delete_remote(local_id: String) -> void:
	if not SyncProvider.is_configured():
		return
	await _sync.delete_software(client_id(), local_id)

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
	}
	software.append(item)
	save_data()
	toast.emit("Logiciel ajouté")
	_push_remote(item)
	return ""

func remove_software(id: String) -> void:
	for i in range(software.size()):
		var item: Variant = software[i]
		if typeof(item) == TYPE_DICTIONARY and str(item.get("id", "")) == id:
			software.remove_at(i)
			break
	save_data()
	toast.emit("Logiciel supprimé")
	_delete_remote(id)