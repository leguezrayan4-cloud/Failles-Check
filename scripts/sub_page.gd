class_name SubPage
extends Control
## FaillesCheck — sous-page plein écran des Paramètres (titre + retour).

signal closed

var _title_label: Label
var _body: VBoxContainer
var _panel: PanelContainer
var _tween: Tween
var _is_open := false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false

	_panel = PanelContainer.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.976, 0.980, 0.988)
	sb.set_corner_radius_all(0)
	sb.set_content_margin_all(0)
	_panel.add_theme_stylebox_override("panel", sb)
	add_child(_panel)

	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 0)
	_panel.add_child(root)

	var header := MarginContainer.new()
	header.add_theme_constant_override("margin_left", 14)
	header.add_theme_constant_override("margin_right", 18)
	header.add_theme_constant_override("margin_top", 22)
	header.add_theme_constant_override("margin_bottom", 10)
	root.add_child(header)
	var hrow := UI.hbox(10)
	header.add_child(hrow)
	var back := UI.back_icon_button(38)
	back.name = "SubPageBack"
	back.pressed.connect(close)
	hrow.add_child(back)
	_title_label = UI.label("", 20, UI.TEXT, true)
	_title_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hrow.add_child(_title_label)

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
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_bottom", 30)
	scroll.add_child(margin)

	_body = UI.vbox(12)
	margin.add_child(_body)

func body() -> VBoxContainer:
	return _body

func is_open() -> bool:
	return _is_open

func open_with(title: String, builder: Callable) -> void:
	_title_label.text = title
	for c in _body.get_children():
		_body.remove_child(c)
		c.queue_free()
	if builder.is_valid():
		builder.call(_body)
	visible = true
	_is_open = true
	modulate.a = 0.0
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 1.0, 0.2)
	UI.stagger_in(_body, 6)

func close() -> void:
	if not _is_open:
		return
	_is_open = false
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 0.0, 0.18)
	_tween.tween_callback(func() -> void:
		visible = false
		closed.emit())
