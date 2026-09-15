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
## partent côte à côte. Pas de rotation : elle ferait tourner l'éclairage de
## l'effet, qui vient d'en haut.
@export var random_flip: bool = true

var _time: float = 0.0


func _ready() -> void:
	if last_frame < 0:
		last_frame = hframes * vframes - 1
	frame = first_frame
	if random_flip and randi() % 2 == 0:
		flip_h = true


func _process(delta: float) -> void:
	_time += delta
	var index := first_frame + int(_time * fps)
	if index > last_frame:
		queue_free()
		return
	frame = index
