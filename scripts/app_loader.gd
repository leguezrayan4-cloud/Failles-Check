class_name AppLoader
extends Node
## FaillesCheck — chargement réel et asynchrone.
## Chaque étape met à jour la progression ; les étapes réseau ont un délai
## maximal et signalent leurs erreurs. L'interface n'est jamais bloquée :
## tout se déroule entre deux images (await process_frame).

signal progress_changed(ratio: float, label: String)
signal failed(message: String)
signal completed(with_warnings: bool, summary: String)

var _running := false
var _warnings: Array = []

func is_running() -> bool:
	return _running

## Lance le chargement complet. En cas d'échec réseau, émet `failed`
## (le splash propose alors Réessayer ou continuer hors ligne).
func run() -> void:
	if _running:
		return
	_running = true
	_warnings.clear()

	progress_changed.emit(0.0, "Préparation…")
	await _next_frame()

	progress_changed.emit(0.10, "Chargement des données locales…")
	DataStore.load_local()
	await _next_frame()

	progress_changed.emit(0.22, "Lecture du cache hors ligne…")
	DataStore.refresh_from_cache()
	await _next_frame()

	if DataStore.is_demo():
		# Le catalogue de démonstration est local : aucune requête réseau.
		progress_changed.emit(0.68, "Mode démonstration")
	elif DataStore.is_online():
		progress_changed.emit(0.38, "Connexion à la source NVD…")
		var res: Dictionary = await DataStore.fetch_vulnerabilities_async("")
		if not bool(res.get("ok", false)):
			_running = false
			failed.emit(str(res.get("error", "Le chargement distant a échoué.")))
			return
		progress_changed.emit(0.68, "%d vulnérabilités (NVD)" % int(res.get("count", 0)))
	else:
		progress_changed.emit(0.68, "Mode hors ligne")
	await _next_frame()

	if SyncProvider.is_configured():
		progress_changed.emit(0.80, "Synchronisation des logiciels…")
		var sync_res: Dictionary = await DataStore.sync_now()
		if not bool(sync_res.get("ok", false)):
			_warnings.append(str(sync_res.get("error", "synchronisation distante incomplète")))
	await _next_frame()

	progress_changed.emit(0.94, "Finalisation du catalogue…")
	DataStore.rebuild()
	DataStore.emit_changed()
	await _next_frame()

	# « Terminé » n'apparaît qu'une fois toutes les étapes réellement achevées.
	progress_changed.emit(1.0, "Terminé")
	_running = false
	completed.emit(_warnings.size() > 0, summary())

## Poursuit sans la source distante (l'utilisateur a choisi le mode hors ligne).
func continue_offline() -> void:
	if _running:
		return
	if DataStore.is_online():
		DataStore.set_online(false)
	progress_changed.emit(1.0, "Hors ligne")
	completed.emit(true, summary())

func summary() -> String:
	if _warnings.is_empty():
		return "Toutes les données sont à jour."
	return "Chargé avec : " + ", ".join(_warnings) + "."

func _next_frame() -> void:
	await get_tree().process_frame