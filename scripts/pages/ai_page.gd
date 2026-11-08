class_name AiPage
extends AppPage
## Onglet IA — conversation réelle avec Claude (via la fonction Supabase),
## quota mensuel de 300 messages vérifié côté serveur.

var _messages: VBoxContainer
var _input: LineEdit
var _send: Button
var _quota_label: Label
var _busy_row: HBoxContainer
var _stop_row: Control
var _history: Array = []
var _busy := false
var _pending_vuln: Dictionary = {}
var _ai: AiClient

func page_title() -> String:
	return Loc.t("ai_title")

func page_subtitle() -> String:
	return Loc.t("ai_sub")

func build() -> void:
	_ai = AiClient.new()
	_ai.name = "AiClient"
	add_child(_ai)
	_ai.quota_changed.connect(_on_quota)

	content.add_child(_quota_card())
	_messages = UI.vbox(10)
	content.add_child(_messages)
	_build_input_bar()

	var pad := Control.new()
	pad.custom_minimum_size = Vector2(0, 96)
	content.add_child(pad)

	_history = DataStore.ai_history()
	_render_history()
	_update_quota_label()

# --- Barre de saisie fixée en bas -----------------------------------------
func _build_input_bar() -> void:
	var bar := PanelContainer.new()
	bar.name = "AiInputBar"
	bar.anchor_left = 0.0
	bar.anchor_right = 1.0
	bar.anchor_top = 1.0
	bar.anchor_bottom = 1.0
	bar.offset_top = -74.0
	bar.offset_bottom = -8.0
	bar.offset_left = 14.0
	bar.offset_right = -14.0
	bar.mouse_filter = Control.MOUSE_FILTER_STOP
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 1)
	sb.set_corner_radius_all(18)
	sb.border_color = UI.BORDER
	sb.set_border_width_all(1)
	sb.shadow_color = Color(0, 0, 0, 0.12)
	sb.shadow_size = 12
	sb.set_content_margin_all(8)
	bar.add_theme_stylebox_override("panel", sb)
	add_child(bar)

	var row := UI.hbox(8)
	bar.add_child(row)
	_input = UI.line_edit(Loc.t("ai_placeholder"))
	_input.name = "AiInput"
	_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_input.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_DEFAULT
	_input.text_submitted.connect(func(_t: String) -> void:
		_on_send())
	row.add_child(_input)
	_send = UI.primary_button(Loc.t("ai_send"))
	_send.name = "AiSend"
	_send.custom_minimum_size = Vector2(92, 44)
	_send.pressed.connect(_on_send)
	row.add_child(_send)

func _quota_card() -> Control:
	var card := UI.card(16)
	var v := UI.vbox(6)
	_quota_label = UI.label("", 13, UI.TEXT_2, false, true)
	v.add_child(_quota_label)
	_stop_row = UI.label("", 12, UI.TEXT_3, false, true)
	v.add_child(_stop_row)
	_busy_row = UI.hbox(10)
	_busy_row.visible = false
	var sp := Spinner.new(16, UI.ACCENT)
	_busy_row.add_child(sp)
	_busy_row.add_child(UI.label(Loc.t("ai_thinking"), 12, UI.TEXT_2))
	v.add_child(_busy_row)
	card.add_child(v)
	_update_quota_label()
	return card

func _update_quota_label() -> void:
	if _quota_label == null:
		return
	if not DataStore.auth.is_signed_in():
		_quota_label.text = Loc.t("ai_need_account")
		_stop_row.visible = false
		return
	if not DataStore.is_online():
		_quota_label.text = Loc.t("ai_offline")
		_stop_row.visible = false
		return
	var remaining := DataStore.ai_remaining()
	if remaining < 0:
		_quota_label.text = Loc.t("ai_quota_unknown")
		_stop_row.visible = false
		return
	_quota_label.text = Loc.t("ai_remaining") % remaining
	if remaining <= 0:
		var when := DataStore.ai_resets_at()
		var day := when.substr(0, 10) if when.length() >= 10 else ""
		_quota_label.text = Loc.t("ai_quota_out")
		_stop_row.visible = day != ""
		_stop_row.text = (Loc.t("ai_reset_on") % day) if day != "" else ""
	else:
		_stop_row.visible = false
	_update_input_state()

func _update_input_state() -> void:
	if _input == null:
		return
	var blocked := _busy or not DataStore.auth.is_signed_in() or not DataStore.is_online() or DataStore.ai_remaining() == 0
	_input.editable = not blocked
	_send.disabled = blocked
	_input.placeholder_text = Loc.t("ai_placeholder") if not blocked else Loc.t("ai_input_locked")

# --- Conversation ----------------------------------------------------------
func _render_history() -> void:
	for c in _messages.get_children():
		_messages.remove_child(c)
		c.queue_free()
	if _history.is_empty():
		_messages.add_child(_bubble(Loc.t("ai_welcome"), false))
	else:
		for m in _history:
			if typeof(m) != TYPE_DICTIONARY:
				continue
			var role := str((m as Dictionary).get("role", "user"))
			var text := str((m as Dictionary).get("content", ""))
			_messages.add_child(_bubble(text, role == "assistant"))
	_scroll_to_end()

func _bubble(text: String, from_ai: bool) -> Control:
	var row := UI.hbox(0)
	var card := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.945, 0.961, 0.988) if from_ai else UI.ACCENT
	sb.set_corner_radius_all(16)
	sb.set_content_margin_all(12)
	card.add_theme_stylebox_override("panel", sb)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var l := UI.label(text, 14, UI.TEXT if from_ai else Color.WHITE, false, true)
	l.name = "BubbleText"
	card.add_child(l)
	row.add_child(card)
	return row

func _scroll_to_end() -> void:
	if content == null:
		return
	await get_tree().process_frame
	# La zone de défilement de la page est le premier ScrollContainer parent.
	var node: Node = content
	while node != null and not (node is ScrollContainer):
		node = node.get_parent()
	if node is ScrollContainer:
		var s := node as ScrollContainer
		s.scroll_vertical = int(s.get_v_scroll_bar().max_value)

func _on_send() -> void:
	if _busy:
		return
	var text := _input.text.strip_edges()
	if text == "":
		return
	_input.text = ""
	_close_keyboard()
	_send_message(text, _pending_vuln)
	_pending_vuln = {}

## Envoi d'un message (discussion libre ou demande de traduction).
func _send_message(text: String, vuln: Dictionary) -> void:
	if not DataStore.auth.is_signed_in():
		DataStore.toast.emit(Loc.t("ai_need_account"))
		return
	if not DataStore.is_online():
		DataStore.toast.emit(Loc.t("ai_offline"))
		return
	if DataStore.ai_remaining() == 0:
		DataStore.toast.emit(Loc.t("ai_quota_out"))
		return
	if _busy:
		return
	_busy = true
	_busy_row.visible = true
	_update_input_state()

	_history.append({"role": "user", "content": text})
	DataStore.ai_save_history(_history)
	_messages.add_child(_bubble(text, false))
	_scroll_to_end()

	var payload: Array = []
	for m in _history:
		if typeof(m) == TYPE_DICTIONARY:
			payload.append({"role": str((m as Dictionary).get("role", "user")), "content": str((m as Dictionary).get("content", ""))})
	var res: Dictionary = await _ai.ask(payload, vuln)
	_busy = false
	_busy_row.visible = false

	if bool(res.get("ok", false)):
		var reply := str(res.get("text", ""))
		_history.append({"role": "assistant", "content": reply})
		DataStore.ai_save_history(_history)
		var bubble := _bubble(reply, true)
		_messages.add_child(bubble)
		var lbl := bubble.find_child("BubbleText", true, false)
		if lbl is Label:
			var l := lbl as Label
			l.visible_ratio = 0.0
			var tw := create_tween()
			tw.tween_property(l, "visible_ratio", 1.0, 0.55)
		if int(res.get("remaining", -1)) >= 0:
			DataStore.set_ai_quota(int(res.get("remaining", -1)), str(res.get("resets_at", "")))
		if vuln != null and not vuln.is_empty():
			DataStore.set_ai_translation(str(vuln.get("id", "")), reply)
		Haptics.tap()
		_scroll_to_end()
	else:
		var err := str(res.get("error", "Service indisponible."))
		_messages.add_child(_bubble("⚠ " + err, true))
		DataStore.toast.emit(err)
		_scroll_to_end()
	_update_quota_label()

func _on_quota(remaining: int, resets_at: String) -> void:
	DataStore.set_ai_quota(remaining, resets_at)
	_update_quota_label()

## Appelée depuis la fiche d'une faille : traduit la fiche en français.
func request_translation(vuln: Dictionary) -> void:
	var id := str(vuln.get("id", ""))
	var known := DataStore.ai_translation_for(id)
	if known != "":
		_render_history()
		_messages.add_child(_bubble(Loc.t("ai_cached") + "\n\n" + known, true))
		_scroll_to_end()
		_update_quota_label()
		return
	_update_quota_label()
	var prompt := Loc.t("ai_translate_prompt") % [str(vuln.get("id", "")), str(vuln.get("title", ""))]
	_send_message(prompt, vuln)

func _close_keyboard() -> void:
	var vp := get_viewport()
	if vp != null:
		vp.gui_release_focus()
	if OS.has_feature("mobile"):
		DisplayServer.virtual_keyboard_hide()
