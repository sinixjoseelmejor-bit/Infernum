class_name CharacterData
extends Resource
## Définition d'un personnage jouable.
##
## Un personnage change les VALEURS DE BASE (PV, vitesse, portée, arme), et ses
## modificateurs de départ tombent dans les mêmes pools plafonnés que les
## objets : il ne peut donc pas dépasser les plafonds d'équilibrage, il choisit
## seulement d'où l'on part.
##
## UNE SEULE EXCEPTION, ET ELLE EST ASSUMÉE : `dash`. Les trois personnages se
## jouaient avec les mêmes mains — mêmes touches, même arme, mêmes déplacements
## — et ne différaient que par des chiffres. Le README l'admettait déjà pour les
## passifs, « quasi permanents en pratique », donc équilibrés comme des bonus
## plats. Un verbe de plus vaut dix pourcents de plus : Loth ne court pas plus
## vite qu'avant, il TRAVERSE, ce qu'aucun autre ne sait faire.

@export var id: StringName = &""
@export var display_name: String = ""
## Épithète affichée sous le nom.
@export var title: String = ""
## Étiquette d'archétype : « Dégâts », « Survie », « Mobilité ».
@export var archetype: String = ""
@export var description: String = ""
@export var color: Color = Color.WHITE
## Planches d'animation : bandes d'images carrées (repos et marche).
@export var sprite_idle: Texture2D
@export var sprite_walk: Texture2D
## Première image de la planche de repos, pour les vignettes d'interface : une
## fiche de personnage ne doit pas afficher la bande entière.
@export var portrait: Texture2D
## Recalage du sprite. Les planches dessinent le personnage POSÉ SUR UNE LIGNE DE
## SOL, pas centré dans son image : sans ce décalage il est rendu au-dessus de son
## propre cercle de collision. Mesurer la boîte opaque sur toutes les images de la
## planche et indiquer l'écart entre son centre et celui de l'image.
@export var sprite_offset: Vector2 = Vector2.ZERO
## Les planches font 100 px alors que le joueur a un rayon de 17 : sans mise à
## l'échelle le personnage serait minuscule.
@export var sprite_scale: float = 1.0

@export_group("Base")
@export var max_health: float = 100.0
@export var move_speed: float = 235.0
@export var targeting_range: float = 340.0

@export_group("Arme de départ")
@export var weapon_damage: float = 12.0
@export var weapon_fire_rate: float = 4.0
@export var weapon_projectile_speed: float = 720.0
@export var weapon_crit_chance: float = 0.05
@export var weapon_crit_multiplier: float = 2.0

@export_group("Déplacement")
## Donne à ce personnage la ruée (touche `dash`). Un booléen et non un
## `special` : `special` est lu par `character_effects.gd`, qui n'agit que sur
## des statistiques ; la ruée vit dans `player.gd` parce qu'elle touche au
## déplacement, et rien d'autre du jeu n'y touche.
@export var dash: bool = false

@export_group("Départ et passif")
## Modificateurs injectés dans PlayerStats au début de la run (mêmes plafonds).
@export var starting_mods: Dictionary = {}
@export var passive_name: String = ""
@export var passive_description: String = ""
## Identifiant lu par `character_effects.gd`. Vide = pas de passif scripté.
@export var special: StringName = &""
## Part de sa valeur en âmes qu'un ennemi SURVIVANT lui rend à la fin de la
## vague, au prorata des dégâts encaissés (voir `wave_manager.gd`).
##
## C'EST UNE DIFFÉRENCE DE PERSONNAGE, et non un réglage global, parce que la
## moisson était le seul filet du jeu à profiter également à tout le monde — et
## mesurée, elle profitait même le MOINS à celui pour qui elle avait été écrite
## (Loth 100 âmes sur 10 vagues, Caïn 87, Job 78 : elle paie les dégâts répartis
## sur des cibles qui survivent, donc elle va à qui arrose). Job la touche au
## taux plein parce qu'user sans achever est littéralement son registre ; les
## deux autres à moitié, pour qui reste une sortie de secours sans devenir un
## revenu.
@export_range(0.0, 1.0, 0.05) var leftover_ratio: float = 0.25


## DPS théorique de départ, pour l'affichage comparatif du menu.
func get_base_dps() -> float:
	var crit := 1.0 + weapon_crit_chance * (weapon_crit_multiplier - 1.0)
	return weapon_damage * weapon_fire_rate * crit
