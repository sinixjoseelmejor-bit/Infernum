class_name DashTrail
extends Sprite2D
## Rémanence laissée par la ruée : une copie figée du personnage, qui s'efface.
##
## POURQUOI UNE TRACE PLUTÔT QU'UN EFFET AU DÉPART. La ruée dure 0,22 s et
## couvre 240 px. À 60 images par seconde, le personnage n'est dessiné que sur
## treize images le long d'un trajet plus long que l'écran n'est haut : sans
## rémanence il ne se déplace pas, il **disparaît d'un endroit et réapparaît à
## un autre**. Ce sont les copies laissées en route qui font lire un trajet, et
## c'est pour ça qu'elles sont posées le long du chemin plutôt qu'au point de
## départ.
##
## Elles vivent dans le conteneur des projectiles et non sous le joueur : une
## trace enfant du joueur le suivrait, donc resterait collée à lui — exactement
## ce qu'elle doit ne pas faire. La fin de vague vide ce conteneur, ce qui est
## le bon comportement pour un objet aussi éphémère.
##
## SANS EFFET DE JEU. Elle ne blesse rien, ne bloque rien, ne traverse rien.

## Assez longue pour que quatre ou cinq copies coexistent, assez courte pour que
## la dernière soit éteinte avant que la ruée suivante soit disponible.
var duree: float = 0.34
## Essayé à 0,45 : à l'écran, seule la copie la plus récente se voyait et la
## ruée lisait comme un saut. Au-delà de 0,6 en revanche la traînée se confond
## avec le personnage et on ne sait plus lequel on dirige.
var opacite: float = 0.55
## Teinte froide — ni rouge (le dégât) ni dorée (la seconde chance).
##
## LES TROIS COMPOSANTES SONT AU-DESSUS DE 1, et c'est ce qui manquait :
## `modulate` MULTIPLIE la couleur du sprite. Une teinte à (0,72 · 0,88 · 1,0)
## ASSOMBRIT donc une planche déjà sombre, et les copies disparaissaient dans la
## pierre de l'arène au lieu de s'en détacher. Il faut éclaircir pour qu'une
## rémanence lise comme une rémanence.
var teinte: Color = Color(1.30, 1.70, 2.20)

var _temps: float = 0.0


func _ready() -> void:
	# Derrière le personnage : la trace est ce qu'il a quitté, pas ce qu'il est.
	z_index = -1
	modulate = Color(teinte.r, teinte.g, teinte.b, opacite)


func _process(delta: float) -> void:
	_temps += delta
	if _temps >= duree:
		queue_free()
		return
	# Quadratique et non linéaire : une traînée qui s'efface à vitesse constante
	# garde une queue visible tout du long et lit comme un ruban. Il faut que les
	# copies les plus anciennes soient déjà presque parties.
	var reste := 1.0 - _temps / duree
	modulate.a = opacite * reste * sqrt(reste)
