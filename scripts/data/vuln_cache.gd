class_name VulnCache
extends RefCounted
## FaillesCheck — cache local des données réelles (hors ligne).
## Stockage séparé du stockage des préférences/logiciels.
## Les entrées proviennent des fournisseurs distants (ex. NVD).

const PATH := "user://faillescheck_cache.json"
const MAX_ITEMS := 300

static func _read() -> Dictionary:
	var empty := {"updated": "", "items": []}
	if not FileAccess.file_exists(PATH):
		return empty
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return empty
	var txt := f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(txt)
	if typeof(parsed) == TYPE_DICTIONARY:
		if typeof(parsed.get("items", null)) != TYPE_ARRAY:
			parsed["items"] = []
		if typeof(parsed.get("updated", null)) != TYPE_STRING:
			parsed["updated"] = ""
		return parsed
	return empty

static func _write(data: Dictionary) -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(data))
		f.close()

## Fusionne des résultats distants (déduplication par identifiant).
## Retourne le nombre de nouvelles entrées.
static func merge(results: Array) -> int:
	var data := _read()
	var items: Array = data.get("items", [])
	var index := {}
	for i in items.size():
		if typeof(items[i]) == TYPE_DICTIONARY:
			index[str(items[i].get("id", ""))] = i
	var added := 0
	for r in results:
		if typeof(r) != TYPE_DICTIONARY:
			continue
		var id := str(r.get("id", ""))
		if id == "":
			continue
		if index.has(id):
			items[index[id]] = r
		else:
			index[id] = items.size()
			items.append(r)
			added += 1
	while items.size() > MAX_ITEMS:
		items.pop_front()
	data["items"] = items
	data["updated"] = Time.get_datetime_string_from_system(false, true)
	_write(data)
	return added

static func all_items() -> Array:
	return _read().get("items", [])

static func updated_at() -> String:
	return str(_read().get("updated", ""))

static func size() -> int:
	return all_items().size()

static func clear() -> void:
	_write({"updated": "", "items": []})