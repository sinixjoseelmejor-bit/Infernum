class_name ItemOrbit
extends Node2D
## Les objets ramassés tournent autour du joueur.
##
## POURQUOI. L'inventaire n'existait qu'à l'écran de pause : en pleine vague, le
## joueur ne voyait rien de ce qu'il avait acheté. Une run se construit pourtant
## objet par objet, et ne rien montrer de cette construction pendant qu'elle a
## lieu revient à cacher le sujet du jeu.
##
## UNE ICÔNE PAR OBJET DISTINCT, jamais par exemplaire. La Braise ardente se
## cumule cinq fois : cinq braises identiques sur le même cercle seraient un
## bruit qui n'apprend rien, et rempliraient l'orbite bien avant que le joueur
## ait fait le tour du catalogue. Le nombre d'exemplaires se lit dans la fiche,
## qui est faite pour ça.
##
## AUCUN EFFET DE JEU. Les icônes ne blessent pas, ne bloquent pas, ne ramassent
## rien. C'est un `Node2D` d'affichage : le supprimer ne change aucune règle.
##
## POURQUOI PAS UN ANNEAU RÉGULIER. Un cercle parfait de N icônes équidistantes
## tournant d'un bloc lit comme un engrenage, et il s'effondre visuellement dès
## qu'il y a plus d'une dizaine d'objets : les icônes se touchent. Chaque icône a
## donc son propre rayon, sa propre vitesse et son propre balancement vertical,
## tirés une fois pour toutes de son identifiant. Le résultat flotte au lieu de
## tourner, et deux runs avec les mêmes objets donnent la même orbite — un
## hasard qui change à chaque image ferait vibrer les icônes sur place.

## Rayon de base. Le joueur fait 48 px de haut (16 px à l'échelle 3) : en deçà de
## 40 les icônes se posent sur lui, au-delà de 70 elles sortent de sa silhouette
## et se confondent avec les ramassages au sol.
@export var rayon: float = 60.0
## Écart maximal au rayon de base, par icône.
@export var rayon_jeu: float = 11.0
@export var vitesse: float = 0.55
## Écart maximal de vitesse, par icône. Sans lui, l'ensemble tourne d'un bloc.
@export var vitesse_jeu: float = 0.22
@export var balancement: float = 5.0
## Échelle des icônes. ENTIÈRE : les icônes font 16 px et le jeu est en pixel
## art, une échelle fractionnaire donnerait des pixels de tailles inégales.
@export var echelle: int = 1
@export var opacite: float = 0.85

## Aplatissement vertical : un cercle vu de dessus en vue 3/4 est une ellipse,
## et un cercle parfait flotterait à la verticale du joueur.
const APLATISSEMENT := 0.5

## Au-delà, l'orbite passe à deux cercles. Douze icônes de 16 px sur un cercle
## de 60 px de rayon occupent déjà les trois quarts de sa circonférence.
const SEUIL_SECOND_CERCLE := 12
const ECART_SECOND_CERCLE := 26.0

var _temps: float = 0.0
var _icones: Array[Sprite2D] = []


func _ready() -> void:
	# Au-dessus du joueur : une icône qui passerait derrière lui disparaîtrait à
	# moitié, et l'œil lirait un clignotement plutôt qu'une orbite.
	z_index = 1
	# Les icônes ne suivent PAS la rotation ni le miroir du porteur : le joueur
	# se retourne, son orbite non.
	top_level = false
	RunState.item_gained.connect(_on_objet_gagne)
	# Le vidage de l'inventaire doit être écouté, pas supposé. Recharger la
	# scène reconstruit bien le joueur, mais `_ready()` d'un ENFANT tourne AVANT
	# celui de son parent : l'orbite se construisait donc sur l'inventaire de la
	# run précédente, que `main.gd` vidait juste après, en silence. Les objets
	# de la partie d'avant restaient à tourner.
	RunState.run_reset.connect(_reconstruire)
	# La revente aussi : `item_gained` n'annonce que les ajouts, et une icône qui
	# continue de tourner après la vente ment sur l'inventaire.
	RunState.item_lost.connect(_on_objet_perdu)
	_reconstruire()


func _on_objet_gagne(_item: ItemData, _piles: int) -> void:
	_reconstruire()


func _on_objet_perdu(_item: ItemData, _piles: int) -> void:
	_reconstruire()


func _process(delta: float) -> void:
	_temps += delta
	for i in _icones.size():
		var icone := _icones[i]
		var base: float = icone.get_meta(&"angle")
		var r: float = icone.get_meta(&"rayon")
		var v: float = icone.get_meta(&"vitesse")
		var angle := base + _temps * v
		icone.position = Vector2(cos(angle) * r, sin(angle) * r * APLATISSEMENT)
		icone.position.y += sin(_temps * v * 2.3 + base) * balancement
		# Devant ou derrière : l'icône passe sous le joueur sur la moitié
		# arrière de l'orbite, sinon elle glisse sur lui sans profondeur.
		icone.z_index = 1 if sin(angle) > 0.0 else -2


## Reconstruit l'orbite entière. Ajouter l'icône manquante serait plus économe,
## mais les angles de base sont répartis sur le TOTAL : en ajouter une sans
## redistribuer laisserait un trou grandissant à chaque achat.
func _reconstruire() -> void:
	for icone in _icones:
		icone.queue_free()
	_icones.clear()

	var vus := {}
	var distincts: Array[ItemData] = []
	for item in RunState.owned_items:
		if item == null or vus.has(item.id):
			continue
		vus[item.id] = true
		distincts.append(item)

	var total := distincts.size()
	for i in total:
		var item := distincts[i]
		if item.icon == null:
			continue
		var icone := Sprite2D.new()
		icone.texture = item.icon
		icone.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icone.scale = Vector2(echelle, echelle)
		icone.modulate = Color(1.0, 1.0, 1.0, opacite)

		var second := total > SEUIL_SECOND_CERCLE and i % 2 == 1
		# Le grain vient de l'IDENTIFIANT et non de l'indice : un objet garde sa
		# place et son allure quand un autre s'ajoute à côté de lui.
		var grain := float(hash(item.id) & 0xFFFF) / 65535.0
		icone.set_meta(&"angle", TAU * float(i) / float(maxi(1, total)) + grain * 0.4)
		icone.set_meta(&"rayon", rayon + (ECART_SECOND_CERCLE if second else 0.0)
			+ (grain - 0.5) * 2.0 * rayon_jeu)
		icone.set_meta(&"vitesse", vitesse + (grain - 0.5) * 2.0 * vitesse_jeu)
		add_child(icone)
		_icones.append(icone)
