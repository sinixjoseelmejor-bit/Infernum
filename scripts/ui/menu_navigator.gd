extends Node
## Navigation des menus à la manette (autoload `MenuNav`).
##
## Godot sait déplacer le focus tout seul, mais pas assez bien pour une manette :
##
## - UN APPUI, UN PAS, ET RIEN D'AUTRE. Une touche de croix ou un stick tenu ne
##   se répète pas : descendre une liste de onze malédictions demandait onze
##   appuis. Ici, tenir une direction répète, après un court délai.
## - LE STICK EN DIAGONALE déclenchait les deux axes à la fois — deux pas pour un
##   geste. On ne garde que l'axe dominant, avec une marge pour ne pas basculer
##   de l'un à l'autre quand le pouce passe près de 45°.
## - LES GRILLES. L'ancien anneau haut/bas suivait l'ordre de l'arbre : dans une
##   grille de trois cartes, « bas » passait à la carte de DROITE. Les voisins se
##   cherchent maintenant par géométrie, dans les quatre directions, et on
##   repart du bord opposé quand il n'y a plus rien devant.
## - LE FOCUS HORS CHAMP. Aucune zone de défilement ne suivait le focus : on
##   pouvait descendre sur un bouton invisible.
## - LE BOUTON A EST AUSSI LA RUÉE. La boutique s'ouvre au dernier ennemi, focus
##   sur « Continuer » : un joueur qui ruait la fermait sans l'avoir vue. Un écran
##   qui apparaît par-dessus la partie ignore A et B pendant un instant.
##
## Et à la souris, le focus suit le survol : sans ça, deux boutons brillent en
## même temps — celui qu'on survole et celui qui a le focus — et on ne sait plus
## lequel A activerait.

## Délai avant la première répétition, puis intervalle entre deux pas.
const REPEAT_DELAY := 0.36
const REPEAT_INTERVAL := 0.09
## Seuils du stick, avec hystérésis : il faut pousser franchement pour partir,
## et relâcher nettement pour s'arrêter.
const STICK_PRESS := 0.6
const STICK_RELEASE := 0.35
## Il faut que l'autre axe dépasse l'axe tenu de ce facteur pour changer de
## direction en cours de maintien.
const AXIS_SWITCH := 1.5
## Temps pendant lequel un écran surgi par-dessus la partie ignore A et B.
const INPUT_GRACE := 0.35
## Poids du décalage latéral face à la distance : on préfère le voisin ALIGNÉ,
## même un peu plus loin, à celui qui est proche mais en biais.
const ORTHO_WEIGHT := 2.5

const DIRECTIONS := [&"ui_left", &"ui_right", &"ui_up", &"ui_down"]

var _clock: float = 0.0
var _dir: Vector2i = Vector2i.ZERO
var _repeat_at: float = INF
var _grace_until: float = 0.0
var _had_focus: bool = false
var _mouse_mode: bool = false
## Dernier focus connu : si un écran perd le sien (bouton désactivé, reconstruit),
## on repart de là plutôt que de rester sans rien.
var _last_rect: Rect2
var _last_scope: Node
## Une cinématique joue par-dessus un écran : elle prend la main sur A, B et les
## directions, et l'écran dessous ne doit pas bouger dans le dos du joueur.
var _suspended: int = 0


## Vrai quand la dernière entrée venait de la souris. Un écran s'en sert pour
## ne pas réagir au simple survol comme à un choix fait à la manette.
func is_mouse_mode() -> bool:
	return _mouse_mode


func suspend() -> void:
	_suspended += 1


func resume() -> void:
	_suspended = maxi(0, _suspended - 1)
	# Même règle qu'un écran qui surgit sur la partie : le A qui finissait la
	# cinématique ne doit pas presser le premier bouton de l'écran rendu.
	if _suspended == 0:
		_grace_until = _clock + INPUT_GRACE


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_viewport().gui_focus_changed.connect(_on_focus_changed)


func _on_focus_changed(control: Control) -> void:
	# Le focus arrive de NULLE PART : un écran vient de surgir sur la partie.
	if not _had_focus:
		_grace_until = _clock + INPUT_GRACE
	_had_focus = true
	if not _mouse_mode:
		_scroll_into_view.call_deferred(control)


func _input(event: InputEvent) -> void:
	if _suspended > 0:
		return
	if event is InputEventMouseMotion:
		_mouse_mode = true
		_focus_hovered()
		return
	if event is InputEventMouseButton:
		_mouse_mode = true
		return
	if not (event is InputEventKey or event is InputEventJoypadButton \
			or event is InputEventJoypadMotion or event is InputEventAction):
		return
	var owner := _focus_owner()
	if owner == null and not _scope_alive():
		return
	if event.is_pressed():
		_mouse_mode = false

	if _clock < _grace_until and (event.is_action(&"ui_accept") or event.is_action(&"ui_cancel")):
		get_viewport().set_input_as_handled()
		return

	# Les directions sont lues à chaque image dans `_process`, qui gère la
	# répétition. On retire les événements pour que Godot ne fasse pas un second
	# pas de son côté — sauf là où la direction a un autre sens.
	for action in DIRECTIONS:
		if event.is_action(action):
			if not _passthrough(owner, action == &"ui_left" or action == &"ui_right"):
				get_viewport().set_input_as_handled()
			return


func _process(delta: float) -> void:
	_clock += delta
	var owner := _focus_owner()
	if owner != null:
		_last_rect = owner.get_global_rect()
		_last_scope = _scope_of(owner)
	var active := _suspended == 0 and (owner != null or _scope_alive())
	if not active:
		# Rien à naviguer : la direction tenue en jouant ne doit pas faire faire
		# un pas à l'écran qui va s'ouvrir. On attend qu'elle soit relâchée.
		_dir = _read_direction()
		_repeat_at = INF
		_had_focus = false
		return

	var want := _read_direction()
	if want != _dir:
		_dir = want
		_repeat_at = _clock + REPEAT_DELAY
		if want != Vector2i.ZERO:
			_step(owner, want)
	elif want != Vector2i.ZERO and _clock >= _repeat_at:
		_repeat_at = _clock + REPEAT_INTERVAL
		_step(owner, want)
	_had_focus = owner != null


## Direction voulue, sur un seul axe. Clavier, croix et stick de TOUTES les
## manettes : les actions `ui_*` du projet ne visent que la manette 0, et une
## manette vue en 1 (Steam Input, pilote tiers) n'aurait rien pu faire.
func _read_direction() -> Vector2i:
	var v := Input.get_vector(&"ui_left", &"ui_right", &"ui_up", &"ui_down", 0.2)
	for id in Input.get_connected_joypads():
		var stick := Vector2(Input.get_joy_axis(id, JOY_AXIS_LEFT_X),
			Input.get_joy_axis(id, JOY_AXIS_LEFT_Y))
		if stick.length() > v.length():
			v = stick
		var pad := Vector2(
			float(Input.is_joy_button_pressed(id, JOY_BUTTON_DPAD_RIGHT)) \
				- float(Input.is_joy_button_pressed(id, JOY_BUTTON_DPAD_LEFT)),
			float(Input.is_joy_button_pressed(id, JOY_BUTTON_DPAD_DOWN)) \
				- float(Input.is_joy_button_pressed(id, JOY_BUTTON_DPAD_UP)))
		if pad != Vector2.ZERO:
			v = pad
	var threshold := STICK_RELEASE if _dir != Vector2i.ZERO else STICK_PRESS
	if v.length() < threshold:
		return Vector2i.ZERO
	var horizontal := absf(v.x) > absf(v.y)
	if _dir.x != 0:
		horizontal = absf(v.y) < absf(v.x) * AXIS_SWITCH
	elif _dir.y != 0:
		horizontal = absf(v.x) > absf(v.y) * AXIS_SWITCH
	return Vector2i(signi(v.x), 0) if horizontal else Vector2i(0, signi(v.y))


func _step(owner: Control, dir: Vector2i) -> void:
	if owner != null and _passthrough(owner, dir.x != 0):
		return
	if owner != null and dir.x != 0 and _adjust(owner, dir.x):
		return
	var scope: Node = _scope_of(owner) if owner != null else _last_scope
	var from := owner.get_global_rect() if owner != null else _last_rect
	var target := find_neighbor(from, Vector2(dir), UIUtils.focusable_controls(scope), owner)
	if target != null:
		target.grab_focus()
		Audio.play(&"survol")


## Gauche et droite RÈGLENT un curseur ou une liste déroulante au lieu de
## quitter la ligne : c'est ce qu'on attend d'un écran d'options.
func _adjust(owner: Control, sign_x: int) -> bool:
	if owner is Slider:
		var slider := owner as Slider
		var step := slider.step if slider.step > 0.0 else (slider.max_value - slider.min_value) / 20.0
		slider.value = clampf(slider.value + step * sign_x, slider.min_value, slider.max_value)
		Audio.play(&"survol")
		return true
	if owner is OptionButton:
		var option := owner as OptionButton
		var count := option.item_count
		if count < 2:
			return true
		var index := posmod(option.selected + sign_x, count)
		option.select(index)
		option.item_selected.emit(index)
		Audio.play(&"survol")
		return true
	return false


## Là où une direction a un autre sens que « aller au voisin », on la laisse
## passer : curseur de texte d'un champ, liste déroulante ouverte.
func _passthrough(owner: Control, horizontal: bool) -> bool:
	if owner == null:
		return false
	if owner is OptionButton and (owner as OptionButton).get_popup().visible:
		return true
	if owner is LineEdit:
		return horizontal or owner.get_parent() is SpinBox
	return false


## Voisin dans une direction, par géométrie.
##
## On retient le candidat devant soi dont le bord est le plus proche, en
## pénalisant le décalage latéral. S'il n'y a rien devant, on repart du bord
## opposé : verticalement vers le plus aligné, horizontalement seulement sur la
## même ligne — sortir d'une ligne d'options par la gauche pour atterrir sur une
## autre serait déroutant.
static func find_neighbor(from: Rect2, dir: Vector2, candidates: Array[Control],
		exclude: Control) -> Control:
	var center := from.get_center()
	var best: Control = null
	var best_score := INF
	var wrap: Control = null
	var wrap_score := INF
	for control in candidates:
		if control == exclude:
			continue
		var rect := control.get_global_rect()
		var offset := rect.get_center() - center
		var along := offset.dot(dir)
		var ortho := _ortho_gap(from, rect, dir)
		if along > 1.0:
			var score := _edge_gap(from, rect, dir) + ortho * ORTHO_WEIGHT \
				+ absf(offset.dot(Vector2(dir.y, dir.x))) * 0.05
			if score < best_score:
				best_score = score
				best = control
		elif along < -1.0:
			if dir.x != 0.0 and ortho > 0.0:
				continue
			var score := ortho * ORTHO_WEIGHT + along
			if score < wrap_score:
				wrap_score = score
				wrap = control
	return best if best != null else wrap


static func _edge_gap(from: Rect2, to: Rect2, dir: Vector2) -> float:
	if dir.x > 0.0:
		return maxf(0.0, to.position.x - from.end.x)
	if dir.x < 0.0:
		return maxf(0.0, from.position.x - to.end.x)
	if dir.y > 0.0:
		return maxf(0.0, to.position.y - from.end.y)
	return maxf(0.0, from.position.y - to.end.y)


## Écart sur l'axe perpendiculaire : nul si les deux cases se recouvrent.
static func _ortho_gap(from: Rect2, to: Rect2, dir: Vector2) -> float:
	if dir.x != 0.0:
		return maxf(0.0, maxf(to.position.y - from.end.y, from.position.y - to.end.y))
	return maxf(0.0, maxf(to.position.x - from.end.x, from.position.x - to.end.x))


## L'écran du contrôle : sa couche (`CanvasLayer`) la plus proche, sinon la scène.
func _scope_of(control: Control) -> Node:
	var node: Node = control
	while node != null:
		if node is CanvasLayer:
			return node
		node = node.get_parent()
	return get_tree().current_scene


## Le dernier écran est-il toujours affiché ? Si oui, une direction y rend le
## focus même s'il l'a perdu.
func _scope_alive() -> bool:
	if not is_instance_valid(_last_scope) or not _last_scope.is_inside_tree():
		return false
	if _last_scope is CanvasLayer:
		return (_last_scope as CanvasLayer).visible \
			and not UIUtils.focusable_controls(_last_scope).is_empty()
	return false


func _focus_owner() -> Control:
	var owner := get_viewport().gui_get_focus_owner()
	if owner == null or not owner.is_visible_in_tree():
		return null
	return owner


## Le focus suit la souris, sur ce qui se clique ou se règle.
func _focus_hovered() -> void:
	var node: Node = get_viewport().gui_get_hovered_control()
	while node != null and not (node is BaseButton or node is Slider):
		node = node.get_parent()
		if node is CanvasLayer:
			return
	if node == null:
		return
	var control := node as Control
	if control.focus_mode == Control.FOCUS_NONE or control.has_focus():
		return
	if control is BaseButton and (control as BaseButton).disabled:
		return
	control.grab_focus()


## Toute zone de défilement qui contient le focus le garde dans le champ. Pas à
## la souris : le contenu défilerait sous le curseur au moindre survol.
func _scroll_into_view(control: Control) -> void:
	if not is_instance_valid(control) or not control.is_inside_tree():
		return
	var node := control.get_parent()
	while node != null:
		if node is ScrollContainer:
			(node as ScrollContainer).ensure_control_visible(control)
		node = node.get_parent()
