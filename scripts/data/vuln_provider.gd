class_name VulnProvider
extends Node
## FaillesCheck — fournisseur de données de vulnérabilités (abstraction).
## Séparé du stockage local : les fournisseurs produisent des résultats,
## DataStore orchestre et met en cache. Aucune clé n'est écrite dans le projet.

signal completed(results: Array, meta: Dictionary)

## Nom lisible de la source (ex. « démo », « NVD »).
func source_name() -> String:
	return "?"

## Lance une récupération. Émet `completed` (même en cas d'erreur).
## `meta` = { "ok": bool, "error": String, "source": String, "count": int }.
func fetch(_query: String, _max_results: int) -> void:
	push_error("VulnProvider.fetch() n'est pas implémenté par %s" % source_name())

## Annule une requête en cours (sans effet si le fournisseur est synchrone).
func cancel() -> void:
	pass

func _finish(results: Array, meta: Dictionary) -> void:
	completed.emit(results, meta)

func _ok(results: Array) -> Dictionary:
	return {"ok": true, "error": "", "source": source_name(), "count": results.size()}

func _error(message: String) -> Dictionary:
	return {"ok": false, "error": message, "source": source_name(), "count": 0}