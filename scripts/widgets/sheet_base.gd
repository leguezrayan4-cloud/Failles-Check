class_name SheetBase
extends Control
## FaillesCheck — base commune des petits panneaux superposés.
## Voile semi-transparent, panneau arrondi, bouton Retour rond, contenu
## défilant au doigt, fermeture par glissement vers le bas.

signal closed

const SHEET_RATIO := 0.90

var _backdrop: ColorRect
var _panel: PanelContainer
var _body: VBoxContainer
var _is_open := false
var _tween: Tween
var _drag_active := false
var _drag_start_y := 0.0
var _drag_base_y := 0.0
var _drag_dy := 0.0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false

	_backdrop = ColorRect.new()
	_backdrop.name = "SheetBackdrop"
	_backdrop.color = Color(0.03, 0.05, 0.10, 0.55 if UI.transparency_reduced else 0.42)
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_backdrop.z_index = 0
	_backdrop.gui_input.connect(_on_backdrop_input)
	add_child(_backdrop)

	_panel = PanelContainer.new()
	_panel.name = "SheetPanel"
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.z_index = 1
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.976, 0.980, 0.988)
	sb.corner_radius_top_left = 24
	sb.corner_radius_top_right = 24
	sb.set_content_margin_all(0)
	sb.shadow_color = Color(0, 0, 0, 0.28)
	sb.shadow_size = 18
	_panel.add_theme_stylebox_override("panel", sb)
	add_child(_panel)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 0)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(root)

	var grab := MarginContainer.new()
	grab.name = "SheetGrabber"
	grab.add_theme_constant_override("margin_top", 10)
	grab.add_theme_constant_override("margin_bottom", 8)
	grab.mouse_filter = Control.MOUSE_FILTER_STOP
	grab.gui_input.connect(_on_grabber_input)
	root.add_child(grab)
	var handle := PanelContainer.new()
	handle.custom_minimum_size = Vector2(42, 5)
	handle.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var hsb := StyleBoxFlat.new()
	hsb.bg_color = Color(0.78, 0.80, 0.84)
	hsb.set_corner_radius_all(3)
	hsb.set_content_margin_all(0)
	handle.add_theme_stylebox_override("panel", hsb)
	handle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grab.add_child(handle)

	var bar_margin := MarginContainer.new()
	bar_margin.add_theme_constant_override("margin_left", 14)
	bar_margin.add_theme_constant_override("margin_right", 14)
	bar_margin.add_theme_constant_override("margin_bottom", 4)
	bar_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bar_margin)
	var bar_row := UI.hbox(10)
	bar_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_margin.add_child(bar_row)
	var back := UI.back_icon_button(40)
	back.name = "SheetBackButton"
	back.pressed.connect(close)
	bar_row.add_child(back)
	var title := UI.label(sheet_title(), 17, UI.TEXT, true)
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar_row.add_child(title)
	bar_row.add_child(UI.spacer())

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	scroll.scroll_deadzone = 8
	root.add_child(scroll)

	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 30)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scroll.add_child(margin)

	_body = UI.vbox(12)
	margin.add_child(_body)

	resized.connect(_layout)
	build_body()

## À surcharger : titre affiché à côté du bouton Retour.
func sheet_title() -> String:
	return ""

## À surcharger : construction du contenu initial.
func build_body() -> void:
	pass

func body() -> VBoxContainer:
	return _body

func is_open() -> bool:
	return _is_open

func clear_body() -> void:
	for c in _body.get_children():
		_body.remove_child(c)
		c.queue_free()

func open() -> void:
	visible = true
	_is_open = true
	_layout()
	_panel.position = Vector2(0, size.y)
	_backdrop.modulate.a = 0.0
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(_backdrop, "modulate:a", 1.0, 0.26)
	_tween.tween_property(_panel, "position:y", size.y - _panel.size.y, 0.34).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	UI.stagger_in(_body, 6)

func close() -> void:
	if not _is_open:
		return
	_is_open = false
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(_backdrop, "modulate:a", 0.0, 0.24)
	_tween.tween_property(_panel, "position:y", size.y, 0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_tween.chain().tween_callback(func() -> void:
		visible = false
		closed.emit())

func _layout() -> void:
	var h := size.y * SHEET_RATIO
	_panel.size = Vector2(size.x, h)
	_panel.position = Vector2(0, size.y - h) if _is_open else Vector2(0, size.y)

func _on_backdrop_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		close()
	elif event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		close()

# --- Fermeture par glissement vers le bas ----------------------------------
func _on_grabber_input(event: InputEvent) -> void:
	if not _is_open:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed:
			_begin_drag(mb.global_position.y)
		else:
			_end_drag()
	elif event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			_begin_drag(st.position.y)
		else:
			_end_drag()
	elif event is InputEventScreenDrag:
		_apply_drag((event as InputEventScreenDrag).position.y)
	elif event is InputEventMouseMotion and _drag_active:
		_apply_drag((event as InputEventMouseMotion).global_position.y)

func _begin_drag(y: float) -> void:
	_drag_active = true
	_drag_start_y = y
	_drag_base_y = _panel.position.y
	_drag_dy = 0.0
	if _tween != null and _tween.is_valid():
		_tween.kill()

func _apply_drag(y: float) -> void:
	if not _drag_active:
		return
	_drag_dy = maxf(0.0, y - _drag_start_y)
	_panel.position.y = _drag_base_y + _drag_dy

func _end_drag() -> void:
	if not _drag_active:
		return
	_drag_active = false
	if _drag_dy > 90.0:
		close()
	else:
		var t := create_tween()
		t.tween_property(_panel, "position:y", _drag_base_y, 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_drag_dy = 0.0
