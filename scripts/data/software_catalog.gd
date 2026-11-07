class_name SoftwareCatalog
extends Node
## FaillesCheck — suggestions de logiciels.
## 1) Liste locale embarquée : fonctionne hors ligne, instantanée.
## 2) Complément en ligne : dictionnaire CPE public du NVD (sans clé).

signal remote_ready(query: String, items: Array)

const CPE_URL := "https://services.nvd.nist.gov/rest/json/cpes/2.0"
const REQUEST_TIMEOUT := 7.0
const MAX_REMOTE := 8

var _http: HTTPRequest
var _active := false
var _query := ""

func _ready() -> void:
	_http = HTTPRequest.new()
	_http.timeout = REQUEST_TIMEOUT
	add_child(_http)
	_http.request_completed.connect(_on_completed)

# --- Suggestions locales ---------------------------------------------------
static func local_suggestions(query: String, limit: int = 8) -> Array:
	var q := query.strip_edges().to_lower()
	if q == "":
		return []
	var starts: Array = []
	var contains: Array = []
	for entry in SEED:
		var label := str(entry[0])
		var low := label.to_lower()
		if low.begins_with(q):
			starts.append(_seed_item(entry))
		elif low.contains(q):
			contains.append(_seed_item(entry))
	var out: Array = starts + contains
	return out.slice(0, limit)

static func _seed_item(entry: Array) -> Dictionary:
	return {
		"name": str(entry[0]),
		"editor": str(entry[1]),
		"version": "",
		"identifier": str(entry[2]),
		"source": "locale",
	}

# --- Suggestions distantes (NVD CPE) ---------------------------------------
func request_remote(query: String) -> void:
	var q := query.strip_edges()
	if q.length() < 2:
		return
	if _active:
		_http.cancel_request()
		_active = false
	_query = q
	var url := "%s?resultsPerPage=20&keywordSearch=%s" % [CPE_URL, q.uri_encode()]
	_active = true
	var err := _http.request(url, PackedStringArray(["Accept: application/json"]))
	if err != OK:
		_active = false
		remote_ready.emit(q, [])

func is_busy() -> bool:
	return _active

func _on_completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if not _active:
		return
	_active = false
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		remote_ready.emit(_query, [])
		return
	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if typeof(parsed) != TYPE_DICTIONARY:
		remote_ready.emit(_query, [])
		return
	remote_ready.emit(_query, _parse(parsed, _query))

func _parse(root: Dictionary, query: String) -> Array:
	var out: Array = []
	var products: Variant = root.get("products", [])
	if typeof(products) != TYPE_ARRAY:
		return out
	var q := query.to_lower()
	for p in products:
		if typeof(p) != TYPE_DICTIONARY:
			continue
		var cpe: Variant = p.get("cpe", {})
		if typeof(cpe) != TYPE_DICTIONARY or bool(cpe.get("deprecated", false)):
			continue
		var cpe_name := str(cpe.get("cpeName", ""))
		var parts := cpe_name.split(":")
		if parts.size() < 6:
			continue
		var vendor := str(parts[3]).replace("_", " ").strip_edges()
		var product := str(parts[4]).replace("_", " ").strip_edges()
		var version := str(parts[5]).strip_edges()
		if version == "-" or version == "*" or version == "":
			version = ""
		var item_name := _clean_name(_title_of(cpe), product, version)
		if item_name == "":
			continue
		var hay := "%s %s %s" % [item_name.to_lower(), product.to_lower(), vendor.to_lower()]
		if not hay.contains(q):
			continue
		out.append({
			"name": item_name,
			"editor": _capitalize(vendor),
			"version": version,
			"identifier": cpe_name,
			"source": "NVD",
		})
		if out.size() >= MAX_REMOTE:
			break
	return out

static func _title_of(cpe: Dictionary) -> String:
	var titles: Variant = cpe.get("titles", [])
	if typeof(titles) == TYPE_ARRAY and not titles.is_empty() and typeof(titles[0]) == TYPE_DICTIONARY:
		return str(titles[0].get("title", "")).strip_edges()
	return ""

static func _clean_name(title: String, product: String, version: String) -> String:
	var n := title.strip_edges().replace("_", " ")
	if n == "":
		return _capitalize(product)
	if version != "" and n.ends_with(version):
		n = n.substr(0, n.length() - version.length()).strip_edges()
	return n

static func _capitalize(text: String) -> String:
	var t := text.strip_edges()
	if t == "":
		return ""
	return t.substr(0, 1).to_upper() + t.substr(1)

# --- Liste locale ----------------------------------------------------------
const SEED := [
	["OBS Studio", "OBS Project", "cpe:2.3:a:obsproject:obs_studio"],
	["Mozilla Firefox", "Mozilla", "cpe:2.3:a:mozilla:firefox"],
	["Mozilla Thunderbird", "Mozilla", "cpe:2.3:a:mozilla:thunderbird"],
	["Google Chrome", "Google", "cpe:2.3:a:google:chrome"],
	["Microsoft Edge", "Microsoft", "cpe:2.3:a:microsoft:edge"],
	["Microsoft Office", "Microsoft", "cpe:2.3:a:microsoft:office"],
	["Microsoft Windows", "Microsoft", "cpe:2.3:o:microsoft:windows"],
	["Visual Studio Code", "Microsoft", "cpe:2.3:a:microsoft:visual_studio_code"],
	["VLC media player", "VideoLAN", "cpe:2.3:a:videolan:vlc_media_player"],
	["7-Zip", "Igor Pavlov", "cpe:2.3:a:7-zip:7-zip"],
	["WinRAR", "RARLAB", "cpe:2.3:a:rarlab:winrar"],
	["Notepad++", "Don Ho", "cpe:2.3:a:notepad-plus-plus:notepad\\+\\+"],
	["Adobe Acrobat Reader", "Adobe", "cpe:2.3:a:adobe:acrobat_reader"],
	["Adobe Photoshop", "Adobe", "cpe:2.3:a:adobe:photoshop"],
	["LibreOffice", "The Document Foundation", "cpe:2.3:a:libreoffice:libreoffice"],
	["GIMP", "The GIMP Team", "cpe:2.3:a:gimp:gimp"],
	["OpenSSL", "OpenSSL Software Foundation", "cpe:2.3:a:openssl:openssl"],
	["Apache HTTP Server", "Apache Software Foundation", "cpe:2.3:a:apache:http_server"],
	["Nginx", "NGINX", "cpe:2.3:a:f5:nginx"],
	["MySQL", "Oracle", "cpe:2.3:a:oracle:mysql"],
	["PostgreSQL", "PostgreSQL Global Development Group", "cpe:2.3:a:postgresql:postgresql"],
	["PHP", "The PHP Group", "cpe:2.3:a:php:php"],
	["Python", "Python Software Foundation", "cpe:2.3:a:python:python"],
	["Node.js", "OpenJS Foundation", "cpe:2.3:a:nodejs:node.js"],
	["Java SE", "Oracle", "cpe:2.3:a:oracle:jre"],
	["Git", "Git Project", "cpe:2.3:a:git-scm:git"],
	["Docker", "Docker", "cpe:2.3:a:docker:docker"],
	["Kubernetes", "Cloud Native Computing Foundation", "cpe:2.3:a:kubernetes:kubernetes"],
	["WordPress", "Automattic", "cpe:2.3:a:wordpress:wordpress"],
	["Grafana", "Grafana Labs", "cpe:2.3:a:grafana:grafana"],
	["Elasticsearch", "Elastic", "cpe:2.3:a:elastic:elasticsearch"],
	["Zoom", "Zoom Video Communications", "cpe:2.3:a:zoom:zoom"],
	["Slack", "Slack Technologies", "cpe:2.3:a:slack:slack"],
	["Discord", "Discord", "cpe:2.3:a:discord:discord"],
	["Telegram", "Telegram FZ-LLC", "cpe:2.3:a:telegram:telegram"],
	["Spotify", "Spotify AB", "cpe:2.3:a:spotify:spotify"],
	["Dropbox", "Dropbox", "cpe:2.3:a:dropbox:dropbox"],
	["Steam", "Valve", "cpe:2.3:a:valvesoftware:steam_client"],
	["Safari", "Apple", "cpe:2.3:a:apple:safari"],
	["iTunes", "Apple", "cpe:2.3:a:apple:itunes"],
	["FortiOS", "Fortinet", "cpe:2.3:o:fortinet:fortios"],
	["pfSense", "Netgate", "cpe:2.3:a:netgate:pfsense"],
	["TeamViewer", "TeamViewer", "cpe:2.3:a:teamviewer:teamviewer"],
	["AnyDesk", "AnyDesk Software", "cpe:2.3:a:anydesk:anydesk"],
	["Filezilla", "FileZilla Project", "cpe:2.3:a:filezilla-project:filezilla_client"],
	["PuTTY", "Simon Tatham", "cpe:2.3:a:putty:putty"],
	["Wireshark", "Wireshark Foundation", "cpe:2.3:a:wireshark:wireshark"],
	["VirtualBox", "Oracle", "cpe:2.3:a:oracle:vm_virtualbox"],
	["VMware Workstation", "VMware", "cpe:2.3:a:vmware:workstation"],
	["Blender", "Blender Foundation", "cpe:2.3:a:blender:blender"],
]