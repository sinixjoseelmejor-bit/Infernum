extends Node
## Préférences de jeu (autoload `Settings`).
##
## Volontairement GLOBALES et non liées à un profil : ce sont des réglages de
## confort (affichage, accessibilité), pas de la progression.
##
## Chaque option agit réellement sur quelque chose — pas de curseur décoratif.
## Fichier : `user://infernum_settings.cfg`.

signal changed()
## Une touche a été réassignée (ou toutes remises par défaut) : les touches
## dessinées à l'écran (`Touche`) se relisent.
signal touches_changees()

enum JoystickMode { AUTO, ALWAYS, NEVER }

const PATH := "user://infernum_settings.cfg"

## Les langues du jeu, chacune écrite dans sa propre langue : un joueur perdu
## dans une langue qu'il ne lit pas doit reconnaître la sienne. Le français est
## la langue source (voir `tools/traductions.py`).
const LANGUES := {
	"fr": "Français",
	"en": "English",
}

## LES TOUCHES RÉASSIGNABLES (0.10.2), dans l'ordre de l'écran d'options.
##
## Chaque action a UNE touche principale au clavier — la première de sa liste
## dans la table d'entrées, celle que l'interface affiche — et UN bouton
## principal à la manette. Ce sont eux qu'on réassigne ; les secondaires
## restent (les flèches à côté de ZQSD, les sticks à côté de la croix). Les
## actions des menus (`ui_*`) et Échap ne se réassignent pas : un joueur qui
## les perdrait ne pourrait plus revenir en arrière.
const TOUCHES_REGLABLES: Array[StringName] = [
	&"move_up", &"move_down", &"move_left", &"move_right", &"dash", &"show_stats", &"restart",
]

const JOYSTICK_LABELS := {
	JoystickMode.AUTO: "Automatique (tactile)",
	JoystickMode.ALWAYS: "Toujours affiché",
	JoystickMode.NEVER: "Masqué",
}

@export var fullscreen: bool = false
## Vide = celle du système, le français pour un système en français et
## l'anglais pour tout autre : c'est la seule traduction, et la langue la plus
## lue de ceux qui ne lisent pas le français.
@export var langue: String = ""
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
## Les touches réassignées, et elles seules : action -> {"clavier": code
## physique, "manette": bouton}. Une action absente garde celle du projet.
var touches := {}


func _ready() -> void:
	load_settings()
	apply_langue()
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
	return tr(JOYSTICK_LABELS[joystick_mode])


# --- Modification ------------------------------------------------------------

## La langue réellement affichée, réglage automatique résolu.
func get_langue() -> String:
	return langue if LANGUES.has(langue) else get_langue_systeme()


## Celle que choisit le réglage automatique.
func get_langue_systeme() -> String:
	return "fr" if OS.get_locale_language() == "fr" else "en"


func set_langue(value: String) -> void:
	langue = value if LANGUES.has(value) else ""
	apply_langue()
	_commit()


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
	reset_touches()
	fullscreen = false
	joystick_mode = JoystickMode.AUTO
	shake_scale = 1.0
	eight_way = true
	music_volume = 1.0
	sfx_volume = 0.9
	apply_display()
	apply_audio()
	_commit()


## Les textes posés tels quels dans un contrôle se retraduisent seuls ; ceux que
## le code compose (un nombre dans une phrase) attendent leur prochaine mise à
## jour, d'où le signal `changed` que les écrans ouverts écoutent.
func apply_langue() -> void:
	TranslationServer.set_locale(get_langue())


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


# --- Touches -----------------------------------------------------------------

## Le code physique de la touche principale d'une action, KEY_NONE sans touche.
## Les touches du projet sont tantôt physiques (ZQSD, Espace), tantôt logiques
## (Tab) : on lit celui des deux qui est renseigné.
func touche_de(action: StringName) -> Key:
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey:
			return _code(ev as InputEventKey)
	return KEY_NONE


func bouton_de(action: StringName) -> int:
	for ev in InputMap.action_get_events(action):
		if ev is InputEventJoypadButton:
			return (ev as InputEventJoypadButton).button_index
	return -1


static func _code(ev: InputEventKey) -> Key:
	return ev.physical_keycode if ev.physical_keycode != KEY_NONE else ev.keycode


## Assigne une touche clavier. Si une autre action réglable l'avait déjà comme
## touche principale, les deux ÉCHANGENT leurs touches — sinon l'autre action
## se retrouverait sans touche, ou deux actions sur la même. Si elle ne l'avait
## qu'en secondaire, elle la perd simplement.
func lier_clavier(action: StringName, code: Key) -> void:
	var ancienne := touche_de(action)
	for autre in TOUCHES_REGLABLES:
		if autre == action:
			continue
		if touche_de(autre) == code:
			_poser_clavier(autre, ancienne)
		else:
			_retirer_clavier(autre, code)
	_poser_clavier(action, code)
	_commit_touches()


## Même règle à la manette.
func lier_manette(action: StringName, bouton: int) -> void:
	var ancien := bouton_de(action)
	for autre in TOUCHES_REGLABLES:
		if autre != action and bouton_de(autre) == bouton:
			_poser_manette(autre, ancien)
	_poser_manette(action, bouton)
	_commit_touches()


func reset_touches() -> void:
	InputMap.load_from_project_settings()
	touches.clear()
	touches_changees.emit()


## Remplace la touche principale (la première de la liste) et garde le reste
## dans le même ordre : c'est la première que l'interface affiche.
func _poser_clavier(action: StringName, code: Key) -> void:
	if code == KEY_NONE:
		return
	var nouvelle := InputEventKey.new()
	nouvelle.physical_keycode = code
	_remplacer(action, nouvelle, func(ev: InputEvent) -> bool: return ev is InputEventKey)
	# Assignée à sa propre touche secondaire (Haut sur la flèche du haut), elle
	# l'aurait en double.
	var vue := false
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey and _code(ev as InputEventKey) == code:
			if vue:
				InputMap.action_erase_event(action, ev)
			vue = true
	_retenir(action, "clavier", int(code))


func _poser_manette(action: StringName, bouton: int) -> void:
	if bouton < 0:
		return
	var nouveau := InputEventJoypadButton.new()
	nouveau.button_index = bouton as JoyButton
	nouveau.device = -1
	_remplacer(action, nouveau, func(ev: InputEvent) -> bool: return ev is InputEventJoypadButton)
	_retenir(action, "manette", bouton)


func _remplacer(action: StringName, nouvel: InputEvent, du_type: Callable) -> void:
	var events := InputMap.action_get_events(action)
	InputMap.action_erase_events(action)
	var pose := false
	for ev in events:
		if not pose and du_type.call(ev):
			InputMap.action_add_event(action, nouvel)
			pose = true
		else:
			InputMap.action_add_event(action, ev)
	if not pose:
		InputMap.action_add_event(action, nouvel)


func _retirer_clavier(action: StringName, code: Key) -> void:
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey and _code(ev as InputEventKey) == code:
			InputMap.action_erase_event(action, ev)


func _retenir(action: StringName, cle: String, valeur: int) -> void:
	var entree: Dictionary = touches.get(String(action), {})
	entree[cle] = valeur
	touches[String(action)] = entree


func _commit_touches() -> void:
	save_settings()
	touches_changees.emit()


func _appliquer_touches() -> void:
	for action: String in touches:
		if not StringName(action) in TOUCHES_REGLABLES:
			continue
		var entree: Dictionary = touches[action]
		if entree.has("clavier"):
			_poser_clavier(StringName(action), int(entree["clavier"]) as Key)
		if entree.has("manette"):
			_poser_manette(StringName(action), int(entree["manette"]))


# --- Persistance -------------------------------------------------------------

func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("general", "langue", langue)
	config.set_value("video", "fullscreen", fullscreen)
	config.set_value("input", "joystick_mode", int(joystick_mode))
	config.set_value("input", "eight_way", eight_way)
	config.set_value("accessibility", "shake_scale", shake_scale)
	config.set_value("audio", "music", music_volume)
	config.set_value("audio", "sfx", sfx_volume)
	config.set_value("touches", "assignees", touches)
	config.save(PATH)


func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(PATH) != OK:
		return
	langue = str(config.get_value("general", "langue", ""))
	fullscreen = config.get_value("video", "fullscreen", false)
	joystick_mode = config.get_value("input", "joystick_mode", JoystickMode.AUTO) as JoystickMode
	eight_way = config.get_value("input", "eight_way", true)
	shake_scale = clampf(config.get_value("accessibility", "shake_scale", 1.0), 0.0, 1.5)
	music_volume = clampf(config.get_value("audio", "music", 0.7), 0.0, 1.0)
	sfx_volume = clampf(config.get_value("audio", "sfx", 0.9), 0.0, 1.0)
	var lues: Variant = config.get_value("touches", "assignees", {})
	touches = lues if lues is Dictionary else {}
	_appliquer_touches()
