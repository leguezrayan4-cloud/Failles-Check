class_name Spinner
extends Control
## Indicateur de chargement animé (arc rotatif), adapté au tactile.

var _icon: TextureRect

func _init(icon_size: int = 18, color: Color = UI.ACCENT) -> void:
	custom_minimum_size = Vector2(icon_size, icon_size)
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon = UI.icon(UI.ICON_SPINNER, icon_size, color)
	_icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_icon.pivot_offset = Vector2(icon_size, icon_size) / 2.0
	add_child(_icon)

func _ready() -> void:
	var tween := create_tween().set_loops()
	tween.tween_property(_icon, "rotation", TAU, 0.9).from(0.0).set_trans(Tween.TRANS_LINEAR)

func set_color(color: Color) -> void:
	if _icon != null:
		_icon.modulate = color