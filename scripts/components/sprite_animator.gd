class_name SpriteAnimator
extends Node
## Anime un `Sprite2D` à partir de deux bandes horizontales (repos / marche).
##
## Les planches des packs sont des bandes d'images CARRÉES mises bout à bout :
## le nombre d'images se déduit donc de la texture elle-même (largeur ÷ hauteur)
## et n'a pas à être saisi entité par entité. Une planche à laquelle on ajoute
## une image se met à jour toute seule.
##
## L'état « marche » est déduit du DÉPLACEMENT RÉEL du parent, pas de sa vitesse
## désirée : un ennemi bloqué contre un mur ou ralenti garde une posture cohérente
## avec ce qu'on voit à l'écran, et le composant n'a besoin de connaître ni
## `Player` ni `Enemy`.

## Sprite animé. Laissé vide, le composant prend le premier Sprite2D frère.
@export var sprite: Sprite2D
@export var idle_texture: Texture2D
@export var walk_texture: Texture2D

@export_group("Cadence")
@export_range(1.0, 30.0, 0.5) var fps: float = 10.0
## Vitesse (px/s) au-delà de laquelle l'entité est considérée en marche.
@export var walk_threshold: float = 8.0
## Durée pendant laquelle la marche reste affichée après l'arrêt. Sans ce délai,
## une entité qui s'arrête une image sur deux clignoterait entre deux planches.
@export var walk_hold: float = 0.12

var _body: Node2D
var _last_position: Vector2 = Vector2.ZERO
var _walk_timer: float = 0.0
var _time: float = 0.0
var _current: Texture2D

## GESTE EN COURS (0.10.1) : une planche jouée une seule fois par-dessus le
## repos et la marche — l'attaque d'un boss, le coup qui le fait vaciller.
var _geste: Texture2D
var _geste_duree: float = 0.0
var _geste_temps: float = 0.0


func _ready() -> void:
	if sprite == null:
		sprite = _find_sibling_sprite()
	_body = get_parent() as Node2D
	if _body != null:
		_last_position = _body.global_position
	_set_texture(idle_texture)


## Change de planches en cours de partie (choix du personnage).
func set_sheets(idle: Texture2D, walk: Texture2D) -> void:
	idle_texture = idle
	walk_texture = walk
	_current = null
	_geste = null
	_walk_timer = 0.0
	if sprite == null:
		sprite = _find_sibling_sprite()
	_set_texture(idle_texture)


## Joue `planche` UNE fois, étirée sur `duree`, puis rend la main au repos ou à
## la marche. La durée est imposée et non la cadence : un boss cale son geste
## sur le préavis de sa zone, pour que le coup parte quand le sol explose.
## Un nouveau geste remplace celui en cours.
func jouer(planche: Texture2D, duree: float) -> void:
	if planche == null or duree <= 0.0:
		return
	if sprite == null:
		sprite = _find_sibling_sprite()
	if sprite == null:
		return
	_geste = planche
	_geste_duree = duree
	_geste_temps = 0.0
	_set_texture(planche)


func en_geste() -> bool:
	return _geste != null


func _find_sibling_sprite() -> Sprite2D:
	var parent := get_parent()
	if parent == null:
		return null
	for child in parent.get_children():
		if child is Sprite2D:
			return child as Sprite2D
	return null


func _process(delta: float) -> void:
	if sprite == null or _body == null:
		return

	var travelled := (_body.global_position - _last_position).length()
	_last_position = _body.global_position
	if delta > 0.0 and travelled / delta > walk_threshold:
		_walk_timer = walk_hold
	else:
		_walk_timer = maxf(0.0, _walk_timer - delta)

	if _geste != null:
		_geste_temps += delta
		if _geste_temps < _geste_duree:
			sprite.frame = mini(sprite.hframes - 1, int(_geste_temps / _geste_duree * sprite.hframes))
			return
		_geste = null

	var wanted := walk_texture if _walk_timer > 0.0 and walk_texture != null else idle_texture
	_set_texture(wanted)

	if sprite.hframes <= 1:
		return
	_time += delta * fps
	sprite.frame = int(_time) % sprite.hframes


func _set_texture(texture: Texture2D) -> void:
	if texture == null or texture == _current:
		return
	_current = texture
	sprite.texture = texture
	# Bande d'images carrées : la hauteur donne le côté, donc le nombre d'images.
	var height := texture.get_height()
	sprite.hframes = maxi(1, texture.get_width() / maxi(1, height))
	sprite.vframes = 1
	_time = 0.0
	sprite.frame = 0
