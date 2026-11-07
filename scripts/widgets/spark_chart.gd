class_name SparkChart
extends Control
## FaillesCheck — histogramme simple, alimenté uniquement par des données
## réelles (nombre de vulnérabilités publiées par mois).

var _labels: Array = []
var _values: Array = []
var _color: Color = UI.ACCENT

func set_data(labels: Array, values: Array, color: Color = UI.ACCENT) -> void:
	_labels = labels
	_values = values
	_color = color
	custom_minimum_size = Vector2(0, 118)
	queue_redraw()

func has_data() -> bool:
	return not _values.is_empty()

func _draw() -> void:
	if _values.is_empty():
		return
	var w := size.x
	var h := size.y
	var n := _values.size()
	var maxv := 1
	for v in _values:
		maxv = maxi(maxv, int(v))
	var gap := 6.0
	var bw := minf(28.0, maxf(6.0, (w - gap * float(n - 1)) / float(n)))
	var total := bw * float(n) + gap * float(n - 1)
	var x0 := maxf(0.0, (w - total) / 2.0)
	var base := h - 16.0
	draw_line(Vector2(0, base), Vector2(w, base), UI.BORDER, 1.0)
	for i in n:
		var v := float(_values[i])
		var bh := maxf(2.0, (base - 8.0) * (v / float(maxv)))
		var x := x0 + float(i) * (bw + gap)
		draw_rect(Rect2(x, base - bh, bw, bh), _color, true)
	var f := UI.font_reg()
	if n > 0:
		draw_string(f, Vector2(0, h - 2), str(_labels[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UI.TEXT_3)
		if n > 1:
			draw_string(f, Vector2(w - 44, h - 2), str(_labels[n - 1]), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UI.TEXT_3)
