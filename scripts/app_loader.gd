class_name AppLoader
extends Node
## FaillesCheck — chargement réel et asynchrone.
## Chaque étape met à jour la progression ; les étapes réseau ont un délai
## maximal et signalent leurs erreurs. L'interface n'est jamais bloquée :
## tout se déroule entre deux images (await process_frame).

signal progress_changed(ratio: float, label: String)
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

	# La mise à jour réseau ne bloque jamais le démarrage : l'application
	# s'ouvre sur le cache local, la source réelle se rafraîchit ensuite.
	if DataStore.is_online():
		progress_changed.emit(0.60, "Connexion…")
		await _next_frame()
		progress_changed.emit(0.72, "Mise à jour en arrière-plan…")
	else:
		progress_changed.emit(0.72, "Mode hors ligne")
	await _next_frame()

	if SyncProvider.is_configured() and DataStore.auth.is_signed_in():
		progress_changed.emit(0.80, "Synchronisation…")
		var sync_res: Dictionary = await DataStore.sync_now()
		if not bool(sync_res.get("ok", false)):
			_warnings.append(str(sync_res.get("error", "synchronisation distante incomplète")))
	await _next_frame()

	progress_changed.emit(0.94, "Affichage…")
	DataStore.rebuild()
	DataStore.emit_changed()
	await _next_frame()

	# « Terminé » n'apparaît qu'une fois toutes les étapes réellement achevées.
	progress_changed.emit(1.0, "Terminé")
	_running = false
	completed.emit(_warnings.size() > 0, summary())

func summary() -> String:
	if _warnings.is_empty():
		return "Toutes les données sont à jour."
	return "Chargé avec : " + ", ".join(_warnings) + "."

func _next_frame() -> void:
	await get_tree().process_frame