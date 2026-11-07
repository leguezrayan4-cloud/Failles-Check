class_name ConfirmSheet
extends Control
## FaillesCheck — confirmation simple, centrée au milieu de l'écran.
## (Remplace l'ancien panneau bas : plus de glissement, plus de confusion.)

signal closed

var _backdrop: ColorRect
var _card: PanelContainer
var _title: Label
var _message: Label
var _ok: Button
var _on_confirm: Callable
var _is_open := false
var _tween: Tween

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false

	_backdrop = ColorRect.new()
	_backdrop.name = "ConfirmBackdrop"
	_backdrop.color = Color(0.03, 0.05, 0.10, 0.45)
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_backdrop.gui_input.connect(_on_backdrop_input)
	add_child(_backdrop)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	_card = PanelContainer.new()
	_card.name = "ConfirmCard"
	_card.custom_minimum_size = Vector2(300, 0)
	_card.mouse_filter = Control.MOUSE_FILTER_STOP
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1)
	sb.set_corner_radius_all(20)
	sb.set_content_margin_all(20)
	sb.shadow_color = Color(0, 0, 0, 0.25)
	sb.shadow_size = 20
	_card.add_theme_stylebox_override("panel", sb)
	_card.resized.connect(func() -> void: _card.pivot_offset = _card.size / 2.0)
	center.add_child(_card)

	var v := UI.vbox(12)
	_title = UI.label("", 17, UI.TEXT, true, true)
	_message = UI.label("", 13, UI.TEXT_2, false, true)
	v.add_child(_title)
	v.add_child(_message)
	var row := UI.hbox(10)
	var cancel := UI.ghost_button("Annuler", UI.TEXT_2)
	cancel.name = "ConfirmCancel"
	cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel.pressed.connect(close)
	row.add_child(cancel)
	_ok = UI.primary_button("Confirmer", UI.DANGER)
	_ok.name = "ConfirmOk"
	_ok.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ok.pressed.connect(_confirm)
	row.add_child(_ok)
	v.add_child(row)
	_card.add_child(v)

func is_open() -> bool:
	return _is_open

func ask(title: String, message: String, confirm_label: String, on_confirm: Callable) -> void:
	_title.text = title
	_message.text = message
	_ok.text = confirm_label
	_on_confirm = on_confirm
	visible = true
	_is_open = true
	_backdrop.modulate.a = 0.0
	_card.scale = Vector2(0.94, 0.94)
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(_backdrop, "modulate:a", 1.0, 0.16)
	_tween.tween_property(_card, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func close() -> void:
	if not _is_open:
		return
	_is_open = false
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(_backdrop, "modulate:a", 0.0, 0.14)
	_tween.tween_property(_card, "scale", Vector2(0.96, 0.96), 0.14)
	_tween.chain().tween_callback(func() -> void:
		visible = false
		closed.emit())

func _confirm() -> void:
	var cb := _on_confirm
	close()
	if cb.is_valid():
		cb.call()

func _on_backdrop_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		close()
	elif event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		close()
