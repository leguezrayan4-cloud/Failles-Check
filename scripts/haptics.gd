class_name Haptics
extends RefCounted
## FaillesCheck — retours haptiques simples, sans greffon natif.
## Input.vibrate_handheld() est fourni par Godot (Android et iOS).
## Sur ordinateur (et en éditeur), l'appel est simplement ignoré.

const TAP_MS := 18
const CONFIRM_MS := 34

static var enabled := true

## Appui sur un bouton principal, un onglet, un interrupteur, un panneau.
static func tap() -> void:
	if not enabled:
		return
	if OS.has_feature("mobile"):
		Input.vibrate_handheld(TAP_MS)

## Action confirmée (suppression, enregistrement).
static func confirm() -> void:
	if not enabled:
		return
	if OS.has_feature("mobile"):
		Input.vibrate_handheld(CONFIRM_MS)
