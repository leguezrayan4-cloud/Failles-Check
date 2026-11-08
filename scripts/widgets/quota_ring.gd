class_name QuotaRing
extends Control
## FaillesCheck — petit cercle de quota (se remplit selon les messages utilisés).
## Un appui affiche le détail (messages restants et date de réinitialisation).

signal tapped

const RING_SIZE := 26.0

var _ratio := 0.0
var _full := false

func _ready() -> void:
	custom_minimum_size = Vector2(RING_SIZE, RING_SIZE)
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

func set_usage(used: int, total: int) -> void:
	var t := maxi(1, total)
	_ratio = clampf(float(used) / float(t), 0.0, 1.0)
	_full = used >= total
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		Haptics.tap()
		tapped.emit()
		accept_event()
	elif event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		Haptics.tap()
		tapped.emit()
		accept_event()

func _draw() -> void:
	var c := Vector2(RING_SIZE, RING_SIZE) * 0.5
	var r := RING_SIZE * 0.5 - 2.0
	draw_circle(c, r, Color(UI.BORDER.r, UI.BORDER.g, UI.BORDER.b, 0.55))
	var col := UI.DANGER if _full else UI.ACCENT
	if _ratio > 0.0:
		draw_arc(c, r, -PI * 0.5, -PI * 0.5 + TAU * _ratio, 32, col, 3.0, true)
	else:
		draw_arc(c, r, 0.0, TAU, 32, Color(UI.BORDER.r, UI.BORDER.g, UI.BORDER.b, 0.9), 2.0, true)
	# Petit point central
	draw_circle(c, 2.0, col)
