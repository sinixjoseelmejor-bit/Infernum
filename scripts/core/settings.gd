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
## Volumes 0..1. Ils agissent sur les bus `Musique` et `Effets`, donc sur tout
## ce qui y est branché — aucun lecteur n'a à être au courant.
##
## La musique part à fond : le haut du curseur EST le niveau de référence, déjà
## 8 dB sous la saturation (voir `MUSIC_HEADROOM` dans `audio.gd`). Baisser par
## défaut une piste déjà calibrée reviendrait à corriger deux fois.
@export_range(0.0, 1.0, 0.05) var music_volume: float = 1.0
@export_range(0.0, 1.0, 0.05) var sfx_volume: float = 0.9


func _ready() -> void:
	load_settings()
	apply_display()
	apply_audio()


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


func set_music_volume(value: float) -> void:
	music_volume = clampf(value, 0.0, 1.0)
	apply_audio()
	_commit()


func set_sfx_volume(value: float) -> void:
	sfx_volume = clampf(value, 0.0, 1.0)
	apply_audio()
	_commit()


func reset() -> void:
	fullscreen = false
	joystick_mode = JoystickMode.AUTO
	shake_scale = 1.0
	eight_way = true
	music_volume = 1.0
	sfx_volume = 0.9
	apply_display()
	apply_audio()
	_commit()


func apply_display() -> void:
	# En headless il n'y a pas de fenêtre à basculer.
	if DisplayServer.get_name() == "headless":
		return
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen
		else DisplayServer.WINDOW_MODE_WINDOWED)


## Les bus sont écrits directement plutôt que via l'autoload `Audio` : les
## réglages se chargent avant lui, et un bus coupé doit l'être dès la première
## image. `AudioServer` est disponible immédiatement, lui.
func apply_audio() -> void:
	_set_bus(&"Musique", music_volume)
	_set_bus(&"Effets", sfx_volume)


## LE CURSEUR EST AU CARRÉ, et ce n'est pas une coquetterie.
##
## Pris tel quel comme amplitude — `linear_to_db(v)`, soit 20 log v — le bas du
## curseur ne descend presque pas : le cran le plus bas avant la coupure vaut
## -26 dB, et le suivant -20 dB. Un joueur qui trouve la musique trop forte à
## ce cran-là n'a plus RIEN entre lui et le silence total. C'est exactement ce
## qui a été remonté, et c'est un défaut du curseur, pas des pistes.
##
## Au carré — 40 log v — le même cran vaut -48 dB et le curseur garde du grain
## jusqu'en bas, sans rien changer en haut de la course :
##
##     cran       0.05    0.10    0.20    0.35    0.50    0.70    1.00
##     avant      -26.0   -20.0   -14.0    -9.1    -6.0    -3.1     0.0  (dB)
##     après      -52.0   -40.0   -28.0   -18.2   -12.0    -6.2     0.0  (dB)
##
## Les deux bus suivent la même règle : deux curseurs côte à côte qui ne
## réagiraient pas pareil seraient pires que le défaut d'origine.
func _set_bus(bus: StringName, volume: float) -> void:
	var index := AudioServer.get_bus_index(bus)
	if index < 0:
		return
	# À zéro on coupe le bus : `linear_to_db(0)` vaut -inf, et un volume de -inf
	# reste un calcul de mixage inutile à chaque image.
	AudioServer.set_bus_mute(index, volume <= 0.001)
	var v := maxf(volume, 0.001)
	AudioServer.set_bus_volume_db(index, linear_to_db(v * v))


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
	config.set_value("audio", "music", music_volume)
	config.set_value("audio", "sfx", sfx_volume)
	config.save(PATH)


func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(PATH) != OK:
		return
	fullscreen = config.get_value("video", "fullscreen", false)
	joystick_mode = config.get_value("input", "joystick_mode", JoystickMode.AUTO) as JoystickMode
	eight_way = config.get_value("input", "eight_way", true)
	shake_scale = clampf(config.get_value("accessibility", "shake_scale", 1.0), 0.0, 1.5)
	music_volume = clampf(config.get_value("audio", "music", 0.7), 0.0, 1.0)
	sfx_volume = clampf(config.get_value("audio", "sfx", 0.9), 0.0, 1.0)
