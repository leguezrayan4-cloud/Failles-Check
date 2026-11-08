class_name RemoteConfig
extends RefCounted
## FaillesCheck — configuration de la couche distante (Supabase).
##
## Configuration publique intégrée (URL + clé publishable, sans secret) :
##   EMBEDDED_URL / EMBEDDED_KEY. Elles peuvent être remplacées par :
##  1) le fichier LOCAL : user://faillescheck_remote.json
##  2) les variables d'environnement (prioritaires) :
##       FAILLESCHECK_SUPABASE_URL
##       FAILLESCHECK_SUPABASE_ANON_KEY
## Seule la clé PUBLIQUE (publishable / anon) est acceptée : une clé
## service_role est refusée explicitement.
## Voir res://docs/supabase_setup.md pour la procédure complète.

const FILE_PATH := "user://faillescheck_remote.json"
const ENV_URL := "FAILLESCHECK_SUPABASE_URL"
const ENV_KEY := "FAILLESCHECK_SUPABASE_ANON_KEY"

const EMBEDDED_URL := "https://shxsxgezfsjhorknnsaq.supabase.co"
const EMBEDDED_KEY := "sb_publishable_vJ-S_vOGSE1_2ITlHryPvw_lmJt-_P6"

const DEFAULT_TABLE_PROFILES := "profiles"
const DEFAULT_TABLE_USER_SOFTWARE := "user_software"
const DEFAULT_TABLE_VULN := "vulnerabilities"

static func load_config() -> Dictionary:
	var cfg := {
		"url": EMBEDDED_URL,
		"anon_key": EMBEDDED_KEY,
		"profiles_table": DEFAULT_TABLE_PROFILES,
		"user_software_table": DEFAULT_TABLE_USER_SOFTWARE,
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
	for k in ["profiles_table", "user_software_table", "vuln_table"]:
		if str(cfg.get(k, "")) == "":
			cfg[k] = {"profiles_table": DEFAULT_TABLE_PROFILES,
				"user_software_table": DEFAULT_TABLE_USER_SOFTWARE,
				"vuln_table": DEFAULT_TABLE_VULN}[k]
	return cfg

static func is_configured() -> bool:
	var cfg := load_config()
	return str(cfg["url"]).begins_with("http") and str(cfg["anon_key"]) != ""

static func status_text() -> String:
	return "configurée" if is_configured() else "non configurée"

## Rôle porté par une clé : "publishable", "anon", "service_role" ou "inconnu".
## Les clés modernes (sb_publishable_…) ne sont pas des JWT : on les accepte.
static func key_role(key: String) -> String:
	var k := key.strip_edges()
	if k.begins_with("sb_publishable_"):
		return "publishable"
	if k.begins_with("sb_secret_"):
		return "service_role"
	var parts := k.split(".")
	if parts.size() != 3:
		return "inconnu"
	var payload := str(parts[1])
	# Décodage base64url du corps du JWT.
	payload = payload.replace("-", "+").replace("_", "/")
	while payload.length() % 4 != 0:
		payload += "="
	var raw := Marshalls.base64_to_utf8(payload)
	var data: Variant = JSON.parse_string(raw)
	if typeof(data) != TYPE_DICTIONARY:
		return "inconnu"
	return str((data as Dictionary).get("role", "inconnu"))

## Vrai si la clé est utilisable côté mobile (jamais service_role).
static func is_public_key(key: String) -> bool:
	var role := key_role(key)
	return role == "publishable" or role == "anon"

## Clé masquée pour l'affichage (jamais la clé complète).
static func masked_key() -> String:
	var k := str(load_config().get("anon_key", ""))
	if k.length() <= 8:
		return "—"
	return k.substr(0, 6) + "…" + k.substr(k.length() - 4, 4)

## Enregistre la configuration locale (hors projet, jamais versionnée).
## Refuse toute clé service_role.
static func save_config(url: String, key: String) -> Dictionary:
	var u := url.strip_edges().rstrip("/")
	var k := key.strip_edges()
	if not u.begins_with("http"):
		return {"ok": false, "error": "URL du projet invalide."}
	if k == "":
		return {"ok": false, "error": "Clé publique manquante."}
	if not is_public_key(k):
		return {"ok": false, "error": "Clé refusée : seule la clé publique (publishable / anon) est autorisée."}
	var cfg := load_config()
	cfg["url"] = u
	cfg["anon_key"] = k
	var f := FileAccess.open(FILE_PATH, FileAccess.WRITE)
	if f == null:
		return {"ok": false, "error": "Écriture de la configuration impossible."}
	f.store_string(JSON.stringify({
		"url": u,
		"anon_key": k,
		"profiles_table": str(cfg.get("profiles_table", DEFAULT_TABLE_PROFILES)),
		"user_software_table": str(cfg.get("user_software_table", DEFAULT_TABLE_USER_SOFTWARE)),
		"vuln_table": str(cfg.get("vuln_table", DEFAULT_TABLE_VULN)),
	}, "  "))
	f.close()
	return {"ok": true, "error": ""}

static func clear_config() -> void:
	if FileAccess.file_exists(FILE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(FILE_PATH))

static func help_text() -> String:
	return ("Comptes et synchronisation non configurés. Renseignez l'URL du projet "
		+ "et la clé publique « anon » dans user://faillescheck_remote.json "
		+ "(procédure : docs/supabase_setup.md).")