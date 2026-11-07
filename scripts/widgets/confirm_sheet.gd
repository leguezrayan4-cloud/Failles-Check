class_name ConfirmSheet
extends SheetBase
## FaillesCheck — confirmation explicite avant une action destructive.

var _on_confirm: Callable
var _message := ""

func sheet_title() -> String:
	return "Confirmation"

func ask(title: String, message: String, confirm_label: String, on_confirm: Callable) -> void:
	_message = message
	_on_confirm = on_confirm
	clear_body()
	var card := UI.card(16)
	var v := UI.vbox(10)
	v.add_child(UI.label(title, 16, UI.TEXT, true, true))
	v.add_child(UI.label(message, 13, UI.TEXT_2, false, true))
	card.add_child(v)
	_body.add_child(card)

	var row := UI.hbox(10)
	var cancel := UI.ghost_button("Annuler", UI.TEXT_2)
	cancel.name = "ConfirmCancel"
	cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel.pressed.connect(close)
	row.add_child(cancel)
	var ok := UI.primary_button(confirm_label, UI.DANGER)
	ok.name = "ConfirmOk"
	ok.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ok.pressed.connect(_confirm)
	row.add_child(ok)
	_body.add_child(row)
	open()

func _confirm() -> void:
	var cb := _on_confirm
	close()
	if cb.is_valid():
		cb.call()
