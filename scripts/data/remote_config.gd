class_name RemoteConfig
extends RefCounted
## FaillesCheck — configuration de la couche distante (Supabase / PostgREST).
##
## AUCUNE clé n'est écrite dans le projet : la configuration est lue
##  1) dans un fichier LOCAL hors du projet : user://faillescheck_remote.json
##  2) ou dans les variables d'environnement (prioritaires) :
##       FAILLESCHECK_SUPABASE_URL
##       FAILLESCHECK_SUPABASE_ANON_KEY
## Voir res://docs/supabase_setup.md pour la procédure complète.

const FILE_PATH := "user://faillescheck_remote.json"
const ENV_URL := "FAILLESCHECK_SUPABASE_URL"
const ENV_KEY := "FAILLESCHECK_SUPABASE_ANON_KEY"

const DEFAULT_TABLE_SOFTWARE := "software"
const DEFAULT_TABLE_VULN := "vulnerabilities"

static func load_config() -> Dictionary:
	var cfg := {
		"url": "",
		"anon_key": "",
		"software_table": DEFAULT_TABLE_SOFTWARE,
		"vuln_table": DEFAULT_TABLE_VULN,
	}
	if FileAccess.file_exists(FILE_PATH):
		var f := FileAccess.open(FILE_PATH, FileAccess.READ)
		if f != null:
			var txt := f.get_as_text()
			f.close()
			var parsed: Variant = JSON.parse_string(txt)
			if typeof(parsed) == TYPE_DICTIONARY:
				cfg.merge(parsed, true)
	var env_url := OS.get_environment(ENV_URL)
	if env_url != "":
		cfg["url"] = env_url
	var env_key := OS.get_environment(ENV_KEY)
	if env_key != "":
		cfg["anon_key"] = env_key
	cfg["url"] = str(cfg.get("url", "")).strip_edges().rstrip("/")
	cfg["anon_key"] = str(cfg.get("anon_key", "")).strip_edges()
	if str(cfg.get("software_table", "")) == "":
		cfg["software_table"] = DEFAULT_TABLE_SOFTWARE
	if str(cfg.get("vuln_table", "")) == "":
		cfg["vuln_table"] = DEFAULT_TABLE_VULN
	return cfg

static func is_configured() -> bool:
	var cfg := load_config()
	return str(cfg["url"]).begins_with("http") and str(cfg["anon_key"]) != ""

static func status_text() -> String:
	return "configurée" if is_configured() else "non configurée"

static func help_text() -> String:
	return ("Synchronisation distante non configurée. Créez un projet Supabase gratuit, "
		+ "puis renseignez l'URL et la clé publique « anon » dans "
		+ "user://faillescheck_remote.json (ou via les variables d'environnement "
		+ "FAILLESCHECK_SUPABASE_URL / FAILLESCHECK_SUPABASE_ANON_KEY). "
		+ "Procédure détaillée : docs/supabase_setup.md")