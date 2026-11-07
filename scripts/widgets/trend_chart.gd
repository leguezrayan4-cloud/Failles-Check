class_name TrendChart
extends Control
## FaillesCheck — graphique de tendance (aire + courbe), données réelles.
## Grille discrète, points, valeurs extrêmes et libellés de période.

const PAD_LEFT := 6.0
const PAD_RIGHT := 6.0
const PAD_TOP := 18.0
const PAD_BOTTOM := 22.0

var _labels: Array = []
var _values: Array = []
var _color: Color = UI.ACCENT
var _hover := -1

func set_data(labels: Array, values: Array, color: Color = UI.ACCENT) -> void:
	_labels = labels
	_values = values
	_color = color
	custom_minimum_size = Vector2(0, 132)
	queue_redraw()

func has_data() -> bool:
	return not _values.is_empty()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	mouse_exited.connect(func() -> void:
		_hover = -1
		queue_redraw())

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and not _values.is_empty():
		var p := (event as InputEventMouseMotion).position
		var idx := _index_at(p.x)
		if idx != _hover:
			_hover = idx
			queue_redraw()

func _index_at(x: float) -> int:
	var n := _values.size()
	if n == 0:
		return -1
	var usable := size.x - PAD_LEFT - PAD_RIGHT
	if usable <= 0.0:
		return -1
	var step := usable / float(maxi(1, n - 1)) if n > 1 else usable
	var rel := (x - PAD_LEFT) / maxf(1.0, step)
	var idx := int(round(rel))
	if idx < 0 or idx >= n:
		return -1
	return idx

func _draw() -> void:
	var w := size.x
	var h := size.y
	var font := UI.font_reg()
	var font_bold := UI.font_bold()
	if _values.is_empty():
		draw_string(font, Vector2(0, h * 0.5), "Aucune donnée", HORIZONTAL_ALIGNMENT_CENTER, w, 12, UI.TEXT_3)
		return

	var n := _values.size()
	var maxv := 0.0
	for v in _values:
		maxv = maxf(maxv, float(v))
	if maxv <= 0.0:
		maxv = 1.0
	var base := h - PAD_BOTTOM
	var top := PAD_TOP
	var usable_h := base - top
	var usable_w := w - PAD_LEFT - PAD_RIGHT
	var step := usable_w / float(maxi(1, n - 1)) if n > 1 else 0.0

	# Grille horizontale discrète (3 niveaux).
	for i in 3:
		var gy := top + usable_h * float(i) / 2.0
		draw_line(Vector2(PAD_LEFT, gy), Vector2(w - PAD_RIGHT, gy), Color(UI.BORDER.r, UI.BORDER.g, UI.BORDER.b, 0.9), 1.0)

	var pts: Array = []
	for i in n:
		var x := PAD_LEFT + step * float(i) if n > 1 else PAD_LEFT + usable_w * 0.5
		var y := base - usable_h * (float(_values[i]) / maxv)
		pts.append(Vector2(x, y))

	# Aire sous la courbe (dégradé simulé par deux polygones).
	if pts.size() >= 2:
		draw_colored_polygon(_area(pts, base), Color(_color.r, _color.g, _color.b, 0.18))
		for i in range(pts.size() - 1):
			var a: Vector2 = pts[i]
			var b: Vector2 = pts[i + 1]
			draw_line(a, b, _color, 2.0, true)

	# Points + valeur de chaque point.
	for i in pts.size():
		var p: Vector2 = pts[i]
		draw_circle(p, 4.0, Color(1, 1, 1))
		draw_circle(p, 2.6, _color)

	# Ligne de base.
	draw_line(Vector2(PAD_LEFT, base), Vector2(w - PAD_RIGHT, base), UI.BORDER_STRONG, 1.0)

	# Valeur maximale en haut à droite.
	var max_idx := 0
	for i in n:
		if float(_values[i]) >= float(_values[max_idx]):
			max_idx = i
	draw_string(font_bold, Vector2(0, 12), "%d" % int(maxv), HORIZONTAL_ALIGNMENT_RIGHT, w - PAD_RIGHT, 11, UI.TEXT_2)

	# Libellés : premier, milieu et dernier.
	if not _labels.is_empty():
		var first := str(_labels[0])
		draw_string(font, Vector2(PAD_LEFT, h - 6), first, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UI.TEXT_3)
		if _labels.size() > 1:
			var last := str(_labels[_labels.size() - 1])
			draw_string(font, Vector2(0, h - 6), last, HORIZONTAL_ALIGNMENT_RIGHT, w - PAD_RIGHT, 10, UI.TEXT_3)
		if _labels.size() > 2:
			var mid := str(_labels[_labels.size() >> 1])
			draw_string(font, Vector2(0, h - 6), mid, HORIZONTAL_ALIGNMENT_CENTER, w, 10, UI.TEXT_3)

	# Infobulle au survol / appui.
	if _hover >= 0 and _hover < pts.size():
		var hp: Vector2 = pts[_hover]
		draw_line(Vector2(hp.x, top), Vector2(hp.x, base), Color(_color.r, _color.g, _color.b, 0.35), 1.0)
		draw_circle(hp, 5.5, Color(1, 1, 1))
		draw_circle(hp, 3.4, _color)
		var txt := "%d" % int(_values[_hover])
		if _hover < _labels.size():
			txt = "%s · %d" % [str(_labels[_hover]), int(_values[_hover])]
		var tw := font_bold.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x + 14.0
		var bx := clampf(hp.x - tw * 0.5, 0.0, maxf(0.0, w - tw))
		draw_rect(Rect2(bx, maxf(0.0, hp.y - 28.0), tw, 20.0), Color(0.06, 0.09, 0.16, 0.92), true)
		draw_string(font_bold, Vector2(bx + 7.0, maxf(0.0, hp.y - 28.0) + 14.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.WHITE)

func _area(pts: Array, base: float) -> PackedVector2Array:
	var poly := PackedVector2Array()
	var first: Vector2 = pts[0]
	var last: Vector2 = pts[pts.size() - 1]
	poly.append(Vector2(first.x, base))
	for p in pts:
		poly.append(p)
	poly.append(Vector2(last.x, base))
	return poly
