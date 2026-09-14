extends Node
## Préférences de jeu (autoload `Settings`).
##
## Volontairement GLOBALES et non liées à un profil : ce sont des réglages de
## confort (affichage, accessibilité), pas de la progression.
##
## Chaque option agit réellement sur quelque chose — pas de curseur décoratif.
## Fichier : `user://infernum_settings.cfg`.

signal changed()

enum JoystickMode { AUTO, ALWAYS, NEVER }

const PATH := "user://infernum_settings.cfg"

const JOYSTICK_LABELS := {
	JoystickMode.AUTO: "Automatique (tactile)",
	JoystickMode.ALWAYS: "Toujours affiché",
	JoystickMode.NEVER: "Masqué",
}

@export var fullscreen: bool = false
@export var joystick_mode: JoystickMode = JoystickMode.AUTO
## Multiplicateur du tremblement de caméra. 0 = désactivé (confort visuel).
@export var shake_scale: float = 1.0
## Quantifie l'entrée analogique sur 8 axes (le clavier l'est nativement).
@export var eight_way: bool = true


func _ready() -> void:
	load_settings()
	apply_display()


# --- Accès ------------------------------------------------------------------

## Le joystick virtuel doit-il être visible dans le contexte courant ?
func should_show_joystick() -> bool:
	match joystick_mode:
		JoystickMode.ALWAYS:
			return true
		JoystickMode.NEVER:
			return false
		_:
			return DisplayServer.is_touchscreen_available() or OS.has_feature("mobile")


func get_joystick_label() -> String:
	return JOYSTICK_LABELS[joystick_mode]


# --- Modification ------------------------------------------------------------

func set_fullscreen(value: bool) -> void:
	fullscreen = value
	apply_display()
	_commit()


func set_joystick_mode(mode: JoystickMode) -> void:
	joystick_mode = mode
	_commit()


func set_shake_scale(value: float) -> void:
	shake_scale = clampf(value, 0.0, 1.5)
	_commit()


func set_eight_way(value: bool) -> void:
	eight_way = value
	_commit()


func reset() -> void:
	fullscreen = false
	joystick_mode = JoystickMode.AUTO
	shake_scale = 1.0
	eight_way = true
	apply_display()
	_commit()


func apply_display() -> void:
	# En headless il n'y a pas de fenêtre à basculer.
	if DisplayServer.get_name() == "headless":
		return
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen
		else DisplayServer.WINDOW_MODE_WINDOWED)


func _commit() -> void:
	save_settings()
	changed.emit()


# --- Persistance -------------------------------------------------------------

func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("video", "fullscreen", fullscreen)
	config.set_value("input", "joystick_mode", int(joystick_mode))
	config.set_value("input", "eight_way", eight_way)
	config.set_value("accessibility", "shake_scale", shake_scale)
	config.save(PATH)


func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(PATH) != OK:
		return
	fullscreen = config.get_value("video", "fullscreen", false)
	joystick_mode = config.get_value("input", "joystick_mode", JoystickMode.AUTO) as JoystickMode
	eight_way = config.get_value("input", "eight_way", true)
	shake_scale = clampf(config.get_value("accessibility", "shake_scale", 1.0), 0.0, 1.5)
