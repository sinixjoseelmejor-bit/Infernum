class_name SlimeLave
extends Enemy
## LE SLIME DE LAVE (0.9.2) — une élimination qui en fait deux.
##
## Tué, il se DIVISE en deux petits, une seule fois. C'est le premier ennemi
## dont la mort rajoute du monde : il punit la build qui ne frappe qu'un corps
## à la fois et récompense celle qui traverse ou qui brûle — la perforation, le
## multishot, le Feu grégeois trouvent là une cible faite pour eux.
##
## LE BUDGET EST TENU. 40 PV, puis deux enfants à 35 % : 68 PV en tout pour
## 4 + 1 + 1 âmes, soit 0,09 âme par PV — le 0,1 de tout le monde.
##
## IL EST FAIT DE LAVE. La lave ne le brûle pas, et il y avance 60 % plus vite :
## c'est son terrain. Un joueur qui s'est adossé à une rivière de lave pour
## que la foule s'y consume le voit arriver par là, et vite.

## Part des PV du parent donnée à chaque enfant.
@export var part_enfant: float = 0.35
@export var enfants: int = 2
## Bonus de vitesse dans la lave.
@export var elan_lave: float = 1.6

## Un enfant ne se divise plus : sans cette borne, chaque mort doublerait la
## foule jusqu'à des slimes d'un PV.
var est_enfant: bool = false


## La vitesse de BASE change le temps du calcul, pas la vitesse obtenue :
## multiplier `velocity` après coup se composerait avec l'accélération à chaque
## image et la ferait diverger.
func _update_movement(delta: float) -> void:
	var base := move_speed
	var pieds := global_position + Vector2(0.0, Carte.PIED_ENNEMI)
	if Carte.courante != null and Carte.courante.en_lave(pieds):
		move_speed *= elan_lave
	super(delta)
	move_speed = base


func _on_died(source: Node) -> void:
	if not est_enfant:
		_diviser()
	super(source)


func _diviser() -> void:
	# Chargée à la mort et non en tête de script : la scène référence ce script,
	# un `preload` de la scène ici ferait une référence circulaire.
	var moi := load(scene_file_path) as PackedScene
	if moi == null:
		return
	var cote := Vector2.RIGHT.rotated(randf() * TAU) * 16.0
	for i in enfants:
		var enfant := engendrer(moi, global_position + (cote if i == 0 else -cote)) as SlimeLave
		if enfant == null:
			continue
		enfant.est_enfant = true
		# Les PV de l'enfant partent de ceux du PARENT, élite compris, déjà mis
		# à l'échelle de la vague : `engendrer` réapplique la courbe, on la
		# retire donc en posant directement la valeur voulue.
		enfant.max_health = max_health * part_enfant
		enfant.contact_damage = contact_damage * 0.6
		enfant.move_speed = move_speed * 1.3
		enfant.soul_value = 1
		enfant.scale = Vector2.ONE * 0.62
