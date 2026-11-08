class_name AiPage
extends AppPage
## Onglet Assistant — conversation réelle (service IA côté Supabase).
## Bulles : utilisateur à droite (bleu), assistant à gauche (gris). Quota
## mensuel vérifié côté serveur, matérialisé par un petit cercle près de l'envoi.

var _messages: VBoxContainer
var _input: LineEdit
var _send: Button
var _ring: QuotaRing
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

	_messages = UI.vbox(10)
	content.add_child(_messages)
	_build_input_bar()

	var pad := Control.new()
	pad.custom_minimum_size = Vector2(0, 92)
	content.add_child(pad)

	_history = DataStore.ai_history()
	_render_history()

# --- Barre de saisie -------------------------------------------------------
func _build_input_bar() -> void:
	var bar := PanelContainer.new()
	bar.name = "AiInputBar"
	bar.anchor_left = 0.0
	bar.anchor_right = 1.0
	bar.anchor_top = 1.0
	bar.anchor_bottom = 1.0
	bar.offset_top = -70.0
	bar.offset_bottom = -8.0
	bar.offset_left = 14.0
	bar.offset_right = -14.0
	bar.mouse_filter = Control.MOUSE_FILTER_STOP
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 1) if UI.transparency_reduced else Color(1, 1, 1, 0.98)
	sb.set_corner_radius_all(20)
	sb.border_color = UI.BORDER_STRONG if UI.transparency_reduced else UI.BORDER
	sb.set_border_width_all(1)
	sb.shadow_color = Color(0, 0, 0, 0.12)
	sb.shadow_size = 12
	sb.set_content_margin_all(6)
	bar.add_theme_stylebox_override("panel", sb)
	add_child(bar)

	var row := UI.hbox(8)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.add_child(row)

	_input = UI.line_edit(Loc.t("ai_placeholder"))
	_input.name = "AiInput"
	_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_input.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_DEFAULT
	_input.text_submitted.connect(func(_t: String) -> void:
		_on_send())
	row.add_child(_input)

	_ring = QuotaRing.new()
	_ring.name = "AiQuotaRing"
	_ring.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_ring.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_ring.tapped.connect(_show_quota_detail)
	row.add_child(_ring)

	_send = Button.new()
	_send.name = "AiSend"
	_send.custom_minimum_size = Vector2(38, 38)
	_send.focus_mode = Control.FOCUS_NONE
	_send.icon = UI.svg_texture(UI.ICON_ARROW_UP, 17)
	_send.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_send.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_send.add_theme_color_override("icon_normal_color", Color.WHITE)
	_send.add_theme_color_override("icon_hover_color", Color.WHITE)
	_send.add_theme_color_override("icon_pressed_color", Color.WHITE)
	_send.add_theme_color_override("icon_disabled_color", Color(1, 1, 1, 0.6))
	_send.add_theme_stylebox_override("normal", UI.stylebox(UI.ACCENT, 19, 0, Color(0, 0, 0, 0), 0))
	_send.add_theme_stylebox_override("hover", UI.stylebox(UI.ACCENT.darkened(0.06), 19, 0, Color(0, 0, 0, 0), 0))
	_send.add_theme_stylebox_override("pressed", UI.stylebox(UI.ACCENT.darkened(0.16), 19, 0, Color(0, 0, 0, 0), 0))
	_send.add_theme_stylebox_override("disabled", UI.stylebox(Color(0.72, 0.76, 0.82), 19, 0, Color(0, 0, 0, 0), 0))
	_send.pressed.connect(_on_send)
	_send.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_send.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	row.add_child(_send)

# --- Quota -----------------------------------------------------------------
func _update_quota() -> void:
	var total := 300
	var remaining := DataStore.ai_remaining()
	var used := 0 if remaining < 0 else maxi(0, total - remaining)
	if _ring != null:
		_ring.set_usage(0 if remaining < 0 else used, total)
	_update_input_state()

func _show_quota_detail() -> void:
	var remaining := DataStore.ai_remaining()
	if not DataStore.auth.is_signed_in():
		DataStore.toast.emit(Loc.t("ai_need_account"))
		return
	if not DataStore.is_online():
		DataStore.toast.emit(Loc.t("ai_offline"))
		return
	if remaining < 0:
		DataStore.toast.emit(Loc.t("ai_quota_unknown"))
		return
	if remaining <= 0:
		var when := DataStore.ai_resets_at()
		var day := when.substr(0, 10) if when.length() >= 10 else ""
		DataStore.toast.emit(Loc.t("ai_quota_out") + (" " + (Loc.t("ai_reset_on") % day) if day != "" else ""))
		return
	var msg := Loc.t("ai_remaining") % remaining
	var when2 := DataStore.ai_resets_at()
	if when2.length() >= 10:
		msg += " · " + (Loc.t("ai_reset_on") % when2.substr(0, 10))
	DataStore.toast.emit(msg)

func _update_input_state() -> void:
	if _input == null:
		return
	var blocked := _busy or not DataStore.auth.is_signed_in() or not DataStore.is_online() or DataStore.ai_remaining() == 0
	_input.editable = not blocked
	_send.disabled = blocked
	if blocked:
		_input.placeholder_text = Loc.t("ai_placeholder")
		if not DataStore.is_online():
			_input.placeholder_text = Loc.t("ai_offline")
		elif not DataStore.auth.is_signed_in():
			_input.placeholder_text = Loc.t("ai_need_account")
		elif DataStore.ai_remaining() == 0:
			_input.placeholder_text = Loc.t("ai_quota_out")

# --- Bulles ----------------------------------------------------------------
func _render_history() -> void:
	for c in _messages.get_children():
		_messages.remove_child(c)
		c.queue_free()
	if _history.is_empty():
		_messages.add_child(_bubble(Loc.t("ai_welcome"), true))
		_update_quota()
		return
	for m in _history:
		if typeof(m) != TYPE_DICTIONARY:
			continue
		var role := str((m as Dictionary).get("role", "user"))
		var text := str((m as Dictionary).get("content", ""))
		_messages.add_child(_bubble(text, role == "assistant"))
	_update_quota()
	_scroll_to_end()

## `from_ai` = true : bulle à gauche, grise. Sinon à droite, bleue.
func _bubble(text: String, from_ai: bool, typing := false) -> Control:
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 8)
	line.mouse_filter = Control.MOUSE_FILTER_PASS

	var holder := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	if from_ai:
		sb.bg_color = Color(0.914, 0.929, 0.953) if not UI.transparency_reduced else Color(0.886, 0.906, 0.937)
	else:
		sb.bg_color = UI.ACCENT.darkened(0.05) if UI.transparency_reduced else UI.ACCENT
	sb.set_corner_radius_all(16)
	if from_ai:
		sb.corner_radius_top_left = 5
	else:
		sb.corner_radius_top_right = 5
	sb.set_content_margin_all(12)
	holder.add_theme_stylebox_override("panel", sb)
	holder.size_flags_horizontal = Control.SIZE_SHRINK_END if not from_ai else Control.SIZE_FILL
	holder.custom_minimum_size = Vector2(0, 0)

	if typing:
		var dots := TypingDots.new()
		dots.name = "TypingDots"
		dots.custom_minimum_size = Vector2(46, 18)
		holder.add_child(dots)
	else:
		var l := UI.label(text, 14, Color.WHITE if not from_ai else UI.TEXT, false, true)
		l.name = "BubbleText"
		holder.add_child(l)
		# Largeur maximale : 78 % de l'écran.
		l.custom_minimum_size = Vector2(minf(280.0, maxf(120.0, float(text.length()) * 7.2)), 0)

	if from_ai:
		line.add_child(holder)
		line.add_child(UI.spacer())
	else:
		line.add_child(UI.spacer())
		line.add_child(holder)
	return line

func _typing_row() -> Control:
	var row := _bubble("", true, true)
	row.name = "TypingRow"
	return row

func _scroll_to_end() -> void:
	if content == null:
		return
	await get_tree().process_frame
	var node: Node = content
	while node != null and not (node is ScrollContainer):
		node = node.get_parent()
	if node is ScrollContainer:
		var s := node as ScrollContainer
		s.scroll_vertical = int(s.get_v_scroll_bar().max_value)

# --- Envoi -----------------------------------------------------------------
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
	Haptics.tap()
	_update_input_state()

	_history.append({"role": "user", "content": text})
	DataStore.ai_save_history(_history)
	_messages.add_child(_bubble(text, false))
	var typing := _typing_row()
	_messages.add_child(typing)
	_scroll_to_end()

	var payload: Array = []
	for m in _history:
		if typeof(m) == TYPE_DICTIONARY:
			payload.append({"role": str((m as Dictionary).get("role", "user")), "content": str((m as Dictionary).get("content", ""))})
	var res: Dictionary = await _ai.ask(payload, vuln)
	_busy = false

	if is_instance_valid(typing):
		_messages.remove_child(typing)
		typing.queue_free()

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
		if not vuln.is_empty():
			DataStore.set_ai_translation(str(vuln.get("id", "")), reply)
		Haptics.tap()
	else:
		var err := str(res.get("error", "Service indisponible."))
		_messages.add_child(_bubble("⚠ " + err, true))
		DataStore.toast.emit(err)

	_update_quota()
	_scroll_to_end()

func _on_quota(remaining: int, resets_at: String) -> void:
	DataStore.set_ai_quota(remaining, resets_at)
	_update_quota()

## Appelée depuis la fiche d'une faille : traduit la fiche en français.
func request_translation(vuln: Dictionary) -> void:
	var id := str(vuln.get("id", ""))
	var known := DataStore.ai_translation_for(id)
	if known != "":
		_messages.add_child(_bubble(Loc.t("ai_cached") + "\n\n" + known, true))
		_scroll_to_end()
		_update_quota()
		return
	_update_quota()
	var prompt := Loc.t("ai_translate_prompt") % [str(vuln.get("id", "")), str(vuln.get("title", ""))]
	_send_message(prompt, vuln)

func _close_keyboard() -> void:
	var vp := get_viewport()
	if vp != null:
		vp.gui_release_focus()
	if OS.has_feature("mobile"):
		DisplayServer.virtual_keyboard_hide()
