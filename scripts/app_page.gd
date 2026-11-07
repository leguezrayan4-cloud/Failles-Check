class_name AppPage
extends Control
## Classe de base des onglets. Fournit l'échafaudage : en-tête + zone scrollable.

var content: VBoxContainer

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS
	content = _make_scaffold(page_title(), page_subtitle())
	build()

func page_title() -> String:
	return ""

func page_subtitle() -> String:
	return ""

## À surcharger : afficher le bouton Retour dans l'en-tête.
func has_back_button() -> bool:
	return false

func _on_back_pressed() -> void:
	var scene := get_tree().current_scene
	if scene != null and scene.has_method("go_back"):
		scene.go_back()

## À surcharger : construction du contenu de la page.
func build() -> void:
	pass

## À surcharger : reconstruction du contenu (ex. changement de données).
func refresh() -> void:
	pass

func clear_content() -> void:
	if content == null:
		return
	for c in content.get_children():
		content.remove_child(c)
		c.queue_free()

## En-tête (grand titre iOS) + ScrollContainer + marge latérale.
func _make_scaffold(title: String, subtitle: String) -> VBoxContainer:
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 0)
	root.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(root)

	var header_margin := MarginContainer.new()
	header_margin.add_theme_constant_override("margin_left", 20)
	header_margin.add_theme_constant_override("margin_right", 20)
	header_margin.add_theme_constant_override("margin_top", 18)
	header_margin.add_theme_constant_override("margin_bottom", 12)
	header_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(header_margin)

	var header := VBoxContainer.new()
	header.add_theme_constant_override("separation", 3)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header_margin.add_child(header)

	if has_back_button():
		var back := UI.back_button()
		back.name = "BackButton"
		back.pressed.connect(_on_back_pressed)
		var back_row := UI.hbox(0)
		back_row.mouse_filter = Control.MOUSE_FILTER_PASS
		back_row.add_child(back)
		back_row.add_child(UI.spacer())
		header.add_child(back_row)

	var t := UI.label(title, 30, UI.TEXT, true)
	header.add_child(t)
	if subtitle != "":
		header.add_child(UI.label(subtitle, 13, UI.TEXT_2))

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	root.add_child(scroll)

	var content_margin := MarginContainer.new()
	content_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_margin.add_theme_constant_override("margin_left", 20)
	content_margin.add_theme_constant_override("margin_right", 20)
	content_margin.add_theme_constant_override("margin_top", 4)
	content_margin.add_theme_constant_override("margin_bottom", 28)
	content_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scroll.add_child(content_margin)

	var c := VBoxContainer.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.add_theme_constant_override("separation", 12)
	c.mouse_filter = Control.MOUSE_FILTER_PASS
	content_margin.add_child(c)
	return c