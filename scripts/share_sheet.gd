class_name ShareSheet
extends SheetBase
## FaillesCheck — panneau de partage d'une fiche de vulnérabilité.
## Propose de vraies actions : copier, ouvrir la source officielle, e-mail, SMS.

var _vuln: Dictionary = {}

func sheet_title() -> String:
	return "Partager"

func show_for(v: Dictionary) -> void:
	_vuln = v
	clear_body()
	_fill()
	if not is_open():
		open()

func _text() -> String:
	var lines: Array = [
		"FaillesCheck — %s" % str(_vuln.get("id", "")),
		str(_vuln.get("title", "")),
		"Gravité : %s (%.1f)" % [UI.sev_label(str(_vuln.get("severity", ""))), float(_vuln.get("score", 0.0))],
		"Logiciel : %s %s" % [str(_vuln.get("product", "—")), str(_vuln.get("version", ""))],
	]
	var url := str(_vuln.get("url", ""))
	if url != "":
		lines.append(url)
	return "\n".join(lines)

func _fill() -> void:
	var id := str(_vuln.get("id", ""))
	var card := UI.card(16)
	var v := UI.vbox(6)
	v.add_child(UI.label(id, 13, UI.ACCENT, true))
	v.add_child(UI.label(str(_vuln.get("title", "")), 13, UI.TEXT, false, true))
	card.add_child(v)
	_body.add_child(card)

	var copied := UI.ghost_button("Copier la fiche", UI.TEXT_2)
	copied.icon = UI.svg_texture(UI.ICON_SHARE, 18)
	copied.pressed.connect(func() -> void:
		DisplayServer.clipboard_set(_text())
		DataStore.toast.emit("Fiche copiée"))
	_body.add_child(copied)

	var url := str(_vuln.get("url", ""))
	if url != "":
		var open_btn := UI.ghost_button("Ouvrir la fiche officielle", UI.ACCENT)
		open_btn.pressed.connect(func() -> void: OS.shell_open(url))
		_body.add_child(open_btn)

	var subject := "Faille %s — %s" % [id, str(_vuln.get("title", ""))]
	var share_body := _text()
	var mail := UI.ghost_button("Envoyer par e-mail", UI.TEXT_2)
	mail.pressed.connect(func() -> void:
		OS.shell_open("mailto:?subject=%s&body=%s" % [subject.uri_encode(), share_body.uri_encode()]))
	_body.add_child(mail)

	var sms := UI.ghost_button("Envoyer par message", UI.TEXT_2)
	sms.pressed.connect(func() -> void:
		OS.shell_open("sms:&body=%s" % share_body.uri_encode()))
	_body.add_child(sms)
