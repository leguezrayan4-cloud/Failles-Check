class_name TapCard
extends PanelContainer
## Carte tactile compatible défilement.
## - Le geste de glissement fait défiler la liste (l'événement n'est jamais
##   consommé : il remonte jusqu'au ScrollContainer).
## - Un appui n'est validé que si le doigt n'a pas dépassé un petit seuil.
## - Aucun comportement dépendant de la souris ou d'une barre de défilement.

signal tapped

const DRAG_THRESHOLD := 10.0

var _style_normal: StyleBox
var _style_hover: StyleBox
var _style_pressed: StyleBox
var _style_disabled: StyleBox
var _pressing := false
var _moved := false
var _travel := Vector2.ZERO

## État désactivé : la carte ne réagit plus et affiche son style atténué.
var disabled := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	mouse_exited.connect(_on_mouse_exited)

func set_styles(normal: StyleBox, hover: StyleBox, pressed: StyleBox, disabled_style: StyleBox = null) -> void:
	_style_normal = normal
	_style_hover = hover
	_style_pressed = pressed
	_style_disabled = disabled_style
	_apply(_style_disabled if (disabled and _style_disabled != null) else _style_normal)

## Active / désactive la carte (style dédié, plus aucune interaction).
func set_disabled(value: bool) -> void:
	disabled = value
	mouse_default_cursor_shape = Control.CURSOR_ARROW if value else Control.CURSOR_POINTING_HAND
	if value:
		_pressing = false
		_moved = false
		_apply(_style_disabled if _style_disabled != null else _style_normal)
	else:
		_apply(_style_normal)

func is_pressing() -> bool:
	return _pressing

func _apply(style: StyleBox) -> void:
	if style != null:
		add_theme_stylebox_override("panel", style)

func _on_mouse_exited() -> void:
	if not _pressing:
		_apply(_style_disabled if (disabled and _style_disabled != null) else _style_normal)

func _gui_input(event: InputEvent) -> void:
	if disabled:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed:
			_begin()
		else:
			_end()
	elif event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			_begin()
		else:
			_end()
	elif event is InputEventScreenDrag:
		_travel += (event as InputEventScreenDrag).relative
		_check_travel()
	elif event is InputEventMouseMotion:
		if _pressing:
			_travel += (event as InputEventMouseMotion).relative
			_check_travel()
		else:
			_apply(_style_hover)
	# L'événement n'est jamais accepté : le parent (ScrollContainer) doit le recevoir.

func _begin() -> void:
	if _pressing or disabled:
		return
	_pressing = true
	_moved = false
	_travel = Vector2.ZERO
	_apply(_style_pressed)

func _check_travel() -> void:
	if _pressing and not _moved and _travel.length() > DRAG_THRESHOLD:
		_moved = true
		_apply(_style_normal)

func _end() -> void:
	if not _pressing:
		return
	var was_moved := _moved
	_pressing = false
	_moved = false
	_apply(_style_hover)
	if not was_moved:
		tapped.emit()