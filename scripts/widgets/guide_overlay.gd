class_name GuideOverlay
extends Control
## FaillesCheck — guide de démarrage (3 écrans, une seule fois, bouton Passer).

signal finished

var _index := 0
var _title: Label
var _text: Label
var _slide: Control
var _tween: Tween
var _dots: HBoxContainer
var _next: Button
var _is_open := false

const PAGES := [
	["guide_1_title", "guide_1_text", "ICON_APPS"],
	["guide_2_title", "guide_2_text", "ICON_SHIELD"],
	["guide_3_title", "guide_3_text", "ICON_AI"],
]

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	z_index = 120

	var bg := ColorRect.new()
	bg.color = Color(0.953, 0.969, 0.996)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 46)
	margin.add_theme_constant_override("margin_bottom", 34)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 18)
	margin.add_child(root)

	var top := UI.hbox(8)
	top.add_child(UI.spacer())
	var skip := UI.ghost_button(Loc.t("skip"), UI.TEXT_2)
	skip.name = "GuideSkip"
	skip.pressed.connect(_finish)
	top.add_child(skip)
	root.add_child(top)

	root.add_child(UI.spacer())

	var icon_holder := CenterContainer.new()
	icon_holder.custom_minimum_size = Vector2(0, 96)
	var logo := TextureRect.new()
	logo.texture = preload("res://Logo_Fond_Noir.png")
	logo.custom_minimum_size = Vector2(88, 88)
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_holder.add_child(logo)
	root.add_child(icon_holder)

	_slide = Control.new()
	_slide.custom_minimum_size = Vector2(0, 120)
	_slide.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_slide)

	var slide_box := VBoxContainer.new()
	slide_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	slide_box.add_theme_constant_override("separation", 10)
	slide_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_slide.add_child(slide_box)

	_title = UI.label("", 24, UI.TEXT, true, true)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	slide_box.add_child(_title)

	_text = UI.label("", 14, UI.TEXT_2, false, true)
	_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	slide_box.add_child(_text)

	root.add_child(UI.spacer())

	_dots = UI.hbox(8)
	_dots.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(_dots)
	for i in PAGES.size():
		var d := PanelContainer.new()
		d.custom_minimum_size = Vector2(8, 8)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.78, 0.81, 0.86)
		sb.set_corner_radius_all(4)
		sb.set_content_margin_all(0)
		d.add_theme_stylebox_override("panel", sb)
		_dots.add_child(d)

	_next = UI.primary_button(Loc.t("next"))
	_next.name = "GuideNext"
	_next.pressed.connect(_advance)
	root.add_child(_next)

func open() -> void:
	_index = 0
	visible = true
	_is_open = true
	_render()

func is_open() -> bool:
	return _is_open

func show_guide() -> void:
	open()

func _render() -> void:
	_fill()
	var tw := create_tween()
	_slide.modulate.a = 0.0
	_slide.position.x = 46.0
	tw.set_parallel(true)
	tw.tween_property(_slide, "modulate:a", 1.0, 0.24)
	tw.tween_property(_slide, "position:x", 0.0, 0.30).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _fill() -> void:
	var page: Array = PAGES[_index]
	_title.text = Loc.t(str(page[0]))
	_text.text = Loc.t(str(page[1]))
	_next.text = Loc.t("start") if _index == PAGES.size() - 1 else Loc.t("next")
	var i := 0
	for d in _dots.get_children():
		var sb := StyleBoxFlat.new()
		sb.bg_color = UI.ACCENT if i == _index else Color(0.78, 0.81, 0.86)
		sb.set_corner_radius_all(4)
		sb.set_content_margin_all(0)
		(d as PanelContainer).add_theme_stylebox_override("panel", sb)
		i += 1
func _advance() -> void:
	Haptics.tap()
	if _index >= PAGES.size() - 1:
		_finish()
		return
	_index += 1
	# La nouvelle étape glisse depuis la droite (aucun écran de derrière visible).
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_slide, "modulate:a", 0.0, 0.12)
	_tween.tween_property(_slide, "position:x", -42.0, 0.12)
	_tween.tween_callback(func() -> void:
		_slide.position.x = 46.0
		_fill())
	_tween.tween_property(_slide, "modulate:a", 1.0, 0.22)
	_tween.parallel().tween_property(_slide, "position:x", 0.0, 0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _finish() -> void:
	_is_open = false
	visible = false
	DataStore.settings["guide_seen"] = true
	DataStore.save_data()
	finished.emit()