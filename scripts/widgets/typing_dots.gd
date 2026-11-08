class_name TypingDots
extends Control
## Trois points qui pulsent discrètement pendant la réponse de l'assistant.

var _phase := 0.0
var _tween: Tween

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tween = create_tween().set_loops()
	_tween.tween_method(_set_phase, 0.0, 1.0, 1.1)

func _set_phase(v: float) -> void:
	_phase = v
	queue_redraw()

func _draw() -> void:
	var base := Color(0.42, 0.46, 0.55)
	var n := 3
	var gap := 7.0
	var total := gap * float(n - 1)
	var start := (size.x - total) * 0.5
	for i in n:
		var t := fmod(_phase + float(i) * 0.18, 1.0)
		var a := 0.35 + 0.65 * (1.0 - absf(t * 2.0 - 1.0))
		var c := Vector2(start + gap * float(i), size.y * 0.5)
		draw_circle(c, 3.0, Color(base.r, base.g, base.b, a))
