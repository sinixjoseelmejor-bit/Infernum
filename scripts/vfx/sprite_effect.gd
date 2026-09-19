extends Sprite2D
## Effet visuel jetable : joue une plage d'images de sa planche, puis disparaît.
##
## POURQUOI UNE PLAGE, ET PAS TOUTE LA PLANCHE. Celle de l'explosion compte
## 42 cellules dont **13 sont vides** — une au début, douze à la fin (mesuré sur
## la couverture alpha de chaque cellule). Les jouer ferait vivre le nœud un
## cinquième de seconde de plus sans rien afficher, et surtout l'explosion
## semblerait traîner alors qu'elle est finie.
##
## L'effet n'a AUCUN effet de jeu : il ne blesse rien, ne bloque rien, et sa
## disparition n'est conditionnée à rien. Il peut être supprimé à tout moment.

## Première et dernière image jouées, incluses. `last_frame` à -1 = jusqu'au bout.
@export var first_frame: int = 0
@export var last_frame: int = -1
@export var fps: float = 60.0
## Un miroir aléatoire suffit à casser la répétition quand deux explosions
## partent côte à côte.
@export var random_flip: bool = true

## ROTATION ALÉATOIRE. Réservée aux effets SANS haut ni bas : elle fait tourner
## l'éclairage avec le dessin, donc elle ment sur un pic de pierre planté dans
## le sol, dont la face éclairée doit rester vers le ciel. Un éclatement qui
## projette ses débris dans toutes les directions, lui, n'a pas d'orientation
## à trahir — et huit zones qui partent ensemble se ressemblent beaucoup moins.
@export var random_rotation: bool = false

## LECTURE À L'ENVERS, de la dernière image vers la première.
##
## Une planche d'impact peut raconter un pic qui jaillit PUIS se désagrège en
## poussière. Lue à l'envers, la même planche raconte la poussière qui se
## rassemble en pic — et surtout elle se TERMINE sur la pierre plantée, au lieu
## de se terminer sur rien. C'est ce qui rend la tenue de la dernière image
## utile : tenir une image vide n'affiche rien.
@export var reverse: bool = false

## TENUE DE LA DERNIÈRE IMAGE, en secondes, puis fondu.
##
## Une planche d'impact au sol se termine sur son état final — la poussière
## retombée, les pics calcinés — et disparaître à l'image suivante efface ce
## que l'animation venait d'etablir. Le sol redevient intact en un dixième de
## seconde, comme si rien ne s'était passé.
##
## Le fondu n'est pas un ornement : une tenue suivie d'une disparition sèche
## remplace un défaut par un autre, la dernière image sautant au lieu de
## s'éteindre. Il est compris DANS la tenue, pas en plus.
##
## Les deux valent 0 par défaut : l'explosion de Braise éternelle et l'animation
## de mort se terminent sur du vide, elles n'ont rien à tenir.
@export var hold_time: float = 0.0
@export var hold_fade: float = 0.0

var _time: float = 0.0
var _held: float = 0.0


func _ready() -> void:
	if last_frame < 0:
		last_frame = hframes * vframes - 1
	frame = _image_de_depart()
	if random_flip and randi() % 2 == 0:
		flip_h = true
	if random_rotation:
		rotation = randf() * TAU
		# `offset` place le dessin par rapport au point touché, et il tourne avec
		# le nœud : sans contre-rotation, le dessin décrirait un cercle autour de
		# ce point au lieu de rester dessus. Contre-tourné, il retombe exactement
		# là où il serait sans rotation.
		offset = offset.rotated(-rotation)


func _process(delta: float) -> void:
	_time += delta
	var avance := int(_time * fps)
	var index := (last_frame - avance) if reverse else (first_frame + avance)
	if index >= first_frame and index <= last_frame:
		frame = index
		return

	# L'animation est finie : on tient la dernière image JOUÉE, puis on s'éteint.
	frame = _image_de_fin()
	if hold_time <= 0.0:
		queue_free()
		return
	_held += delta
	if _held >= hold_time:
		queue_free()
		return
	if hold_fade > 0.0:
		var reste := hold_time - _held
		if reste < hold_fade:
			modulate.a = reste / hold_fade


func _image_de_depart() -> int:
	return last_frame if reverse else first_frame


func _image_de_fin() -> int:
	return first_frame if reverse else last_frame
