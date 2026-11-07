extends Node
## FaillesCheck — magasin de données central (autoload "DataStore").
## Orchestre les FOURNISSEURS de données (démo / NVD) et sépare clairement
## la logique métier du STOCKAGE local (JSON). Ce fichier ne contient
## aucune clé API : une clé facultative est lue depuis l'environnement
## par le fournisseur distant (NVD_API_KEY).

signal data_changed
signal selection_changed
signal toast(message: String)
signal loading_changed(is_loading: bool)
signal fetch_finished(ok: bool, message: String, source: String)

const SAVE_PATH := "user://faillescheck_save.json"
const SAVE_VERSION := 2
const DEFAULT_SETTINGS := {"demo_data": false, "online": false}
const MAX_RESULTS := 25

var settings: Dictionary = DEFAULT_SETTINGS.duplicate(true)
var software: Array = []
var vulnerabilities: Array = []
var selected_id: String = ""

var _demo_provider: DemoProvider
var _nvd_provider: NvdProvider
var _loading := false

func _ready() -> void:
	_demo_provider = DemoProvider.new()
	_demo_provider.name = "DemoProvider"
	add_child(_demo_provider)
	_nvd_provider = NvdProvider.new()
	_nvd_provider.name = "NvdProvider"
	_nvd_provider.completed.connect(_on_nvd_completed)
	add_child(_nvd_provider)
	load_data()

# --- Accès -----------------------------------------------------------------
func is_demo() -> bool:
	return bool(settings.get("demo_data", false))

func is_online() -> bool:
	return bool(settings.get("online", false))

func is_loading() -> bool:
	return _loading

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

## Source actuellement affichée, pour l'étiquetage de l'interface.
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

# --- Persistance -----------------------------------------------------------
func load_data() -> void:
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
	rebuild()
	data_changed.emit()

func save_data() -> void:
	var d := {
		"version": SAVE_VERSION,
		"settings": settings,
		"software": software,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(d, "  "))
		f.close()
	data_changed.emit()

func reset_all() -> void:
	settings = DEFAULT_SETTINGS.duplicate(true)
	software = []
	selected_id = ""
	VulnCache.clear()
	rebuild()
	save_data()
	selection_changed.emit()
	toast.emit("Données réinitialisées")

# --- Sources de données ----------------------------------------------------
## Reconstruit le catalogue affiché selon la source active.
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

## Interroge la source publique (NVD). Met l'état de chargement à jour,
## gère le délai maximal et les erreurs côté fournisseur, puis met en cache.
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
	if not bool(meta.get("ok", false)):
		fetch_finished.emit(false, str(meta.get("error", "Erreur de récupération inconnue.")), str(meta.get("source", "")))
		return
	if not results.is_empty():
		VulnCache.merge(results)
		if not is_demo():
			rebuild()
			data_changed.emit()
	fetch_finished.emit(true, "%d vulnérabilité(s) récupérée(s) depuis le NVD." % results.size(), "NVD")

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

# --- Logiciels -------------------------------------------------------------
## Retourne "" en cas de succès, sinon un message d'erreur lisible.
func add_software(app_name: String, version: String, editor: String) -> String:
	var n := app_name.strip_edges()
	if n == "":
		return "Le nom du logiciel est obligatoire."
	for s in software:
		if str(s.get("name", "")).strip_edges().to_lower() == n.to_lower():
			return "« %s » est déjà dans votre liste." % n
	var item := {
		"id": "SW-%d-%d" % [int(Time.get_unix_time_from_system()), randi() % 100000],
		"name": n,
		"version": version.strip_edges(),
		"editor": editor.strip_edges(),
	}
	software.append(item)
	save_data()
	toast.emit("Logiciel ajouté")
	return ""

func remove_software(id: String) -> void:
	for i in range(software.size()):
		var item: Variant = software[i]
		if typeof(item) == TYPE_DICTIONARY and str(item.get("id", "")) == id:
			software.remove_at(i)
			break
	save_data()
	toast.emit("Logiciel supprimé")