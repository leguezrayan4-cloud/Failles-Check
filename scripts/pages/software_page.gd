class_name SoftwarePage
extends AppPage
## Onglet Mes logiciels — ajout et suppression.

var _name: LineEdit
var _version: LineEdit
var _editor: LineEdit
var _error: Label
var _list: VBoxContainer

func page_title() -> String:
	return "Mes logiciels"

func page_subtitle() -> String:
	return "Suivre les logiciels installés"

func build() -> void:
	DataStore.data_changed.connect(refresh)
	refresh()

func refresh() -> void:
	clear_content()

	var form := UI.card(16)
	var fv := UI.vbox(10)
	fv.add_child(UI.section_title("Ajouter un logiciel"))
	_name = UI.line_edit("Nom du logiciel (obligatoire)")
	_name.name = "NameField"
	_version = UI.line_edit("Version")
	_version.name = "VersionField"
	_editor = UI.line_edit("Éditeur")
	_editor.name = "EditorField"
	fv.add_child(_name)
	fv.add_child(_version)
	fv.add_child(_editor)
	_error = UI.label("", 12, UI.DANGER, true)
	_error.visible = false
	fv.add_child(_error)
	var add := UI.primary_button("Ajouter le logiciel")
	add.name = "AddButton"
	add.pressed.connect(_on_add)
	fv.add_child(add)
	form.add_child(fv)
	content.add_child(form)

	_list = UI.vbox(10)
	content.add_child(_list)
	_render_list()

func _render_list() -> void:
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()

	_list.add_child(UI.section_title("Logiciels suivis (%d)" % DataStore.software.size()))

	if DataStore.software.is_empty():
		_list.add_child(UI.empty_state("Aucun logiciel",
			"Ajoutez un logiciel pour suivre ses vulnérabilités.", UI.ICON_APPS))
		return

	for s in DataStore.software:
		_list.add_child(_software_card(s))

func _software_card(s: Dictionary) -> PanelContainer:
	var p := UI.card(14)
	var row := UI.hbox(12)
	var v := UI.vbox(3)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	v.add_child(UI.label(str(s.get("name", "")), 15, UI.TEXT, true, true))
	var parts: Array = []
	if str(s.get("version", "")) != "":
		parts.append(str(s.get("version", "")))
	if str(s.get("editor", "")) != "":
		parts.append(str(s.get("editor", "")))
	v.add_child(UI.label(" · ".join(parts) if not parts.is_empty() else "—", 12, UI.TEXT_2))
	row.add_child(v)
	var del := UI.icon_button(UI.ICON_TRASH, 40, UI.DANGER, Color(0.988, 0.937, 0.937))
	del.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	del.pressed.connect(_on_delete.bind(str(s.get("id", ""))))
	row.add_child(del)
	p.add_child(row)
	return p

func _on_add() -> void:
	var err := DataStore.add_software(_name.text, _version.text, _editor.text)
	if err != "":
		_error.text = err
		_error.visible = true
		_name.grab_focus()
		return
	_error.visible = false

func _on_delete(id: String) -> void:
	DataStore.remove_software(id)