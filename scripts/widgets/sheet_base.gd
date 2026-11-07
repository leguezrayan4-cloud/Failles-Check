class_name SheetBase
extends Control
## FaillesCheck — base commune des panneaux superposés.
## Voile semi-transparent, panneau arrondi, croix de fermeture à droite,
## contenu défilant au doigt, fermeture par glissement vers le bas dès que
## le contenu est en haut (comme les feuilles iOS).

signal closed

const SHEET_RATIO := 0.90
const PULL_THRESHOLD := 90.0
const PULL_START := 12.0

var _backdrop: ColorRect
var _panel: PanelContainer
var _body: VBoxContainer
var _scroll: ScrollContainer
var _is_open := false
var _tween: Tween
var _pull_active := false
var _pull_start := Vector2.ZERO
var _pull_dy := 0.0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	set_process_input(true)

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

	# Poignée visuelle (le glissement fonctionne depuis tout le panneau).
	var grab := MarginContainer.new()
	grab.name = "SheetGrabber"
	grab.add_theme_constant_override("margin_top", 10)
	grab.add_theme_constant_override("margin_bottom", 8)
	grab.mouse_filter = Control.MOUSE_FILTER_IGNORE
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

	# Barre : titre à gauche, croix de fermeture à droite.
	var bar_margin := MarginContainer.new()
	bar_margin.add_theme_constant_override("margin_left", 20)
	bar_margin.add_theme_constant_override("margin_right", 14)
	bar_margin.add_theme_constant_override("margin_bottom", 6)
	bar_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bar_margin)
	var bar_row := UI.hbox(10)
	bar_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_margin.add_child(bar_row)
	var title := UI.label(sheet_title(), 17, UI.TEXT, true)
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar_row.add_child(title)
	bar_row.add_child(UI.spacer())
	var close_btn := UI.close_button(38)
	close_btn.name = "SheetCloseButton"
	close_btn.pressed.connect(close)
	bar_row.add_child(close_btn)

	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_scroll.scroll_deadzone = 8
	root.add_child(_scroll)

	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 30)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scroll.add_child(margin)

	_body = UI.vbox(12)
	margin.add_child(_body)

	resized.connect(_layout)
	build_body()

## À surcharger : titre affiché à gauche de la croix.
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
	_tween.tween_property(_panel, "position:y", _open_panel_y(), 0.34).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	UI.stagger_in(_body, 6)

func close() -> void:
	if not _is_open:
		return
	_is_open = false
	_pull_active = false
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(_backdrop, "modulate:a", 0.0, 0.24)
	_tween.tween_property(_panel, "position:y", size.y, 0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_tween.chain().tween_callback(func() -> void:
		visible = false
		closed.emit())

func _open_panel_y() -> float:
	return size.y - _panel.size.y

func _layout() -> void:
	var h := size.y * SHEET_RATIO
	_panel.size = Vector2(size.x, h)
	_panel.position = Vector2(0, _open_panel_y()) if _is_open else Vector2(0, size.y)

func _on_backdrop_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		close()
	elif event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		close()

# --- Fermeture par glissement vers le bas (depuis tout le panneau) ---------
func _input(event: InputEvent) -> void:
	if not _is_open:
		return
	if event is InputEventScreenTouch:
		if (event as InputEventScreenTouch).pressed:
			_begin_pull((event as InputEventScreenTouch).position)
		else:
			_end_pull()
	elif event is InputEventScreenDrag:
		_update_pull((event as InputEventScreenDrag).position)
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_begin_pull(mb.global_position)
			else:
				_end_pull()
	elif event is InputEventMouseMotion and _pull_active:
		_update_pull((event as InputEventMouseMotion).global_position)

func _begin_pull(pos: Vector2) -> void:
	_pull_active = false
	_pull_dy = 0.0
	if _scroll == null or _scroll.scroll_vertical > 0:
		return
	if not _panel.get_global_rect().has_point(pos):
		return
	_pull_active = true
	_pull_start = pos

func _update_pull(pos: Vector2) -> void:
	if not _pull_active:
		return
	var dy := pos.y - _pull_start.y
	if dy < PULL_START:
		return
	_pull_dy = dy
	_panel.position.y = _open_panel_y() + dy
	get_viewport().set_input_as_handled()

func _end_pull() -> void:
	if not _pull_active:
		return
	_pull_active = false
	if _pull_dy > PULL_THRESHOLD:
		close()
	else:
		var t := create_tween()
		t.tween_property(_panel, "position:y", _open_panel_y(), 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_pull_dy = 0.0
