class_name Consecration
extends Node2D
## LA CONSÉCRATION — le sol que Job tient.
##
## Posée par `CharacterEffects` là où Job s'est arrêté, elle y RESTE : c'est une
## place qu'on défend, pas une aura qui suit. Tant que Job s'y tient, elle est
## entretenue ; il en sort, elle s'éteint en quelques instants — assez pour se
## replacer d'un pas, pas assez pour l'emporter avec soi.
##
## Elle brûle ce qui y entre et soigne Job qui s'y tient. Les deux valeurs sont
## posées par son propriétaire à chaque instant : la brûlure suit les dégâts de
## l'arme, donc toute la build, sans canal de scaling à part.

## Rayon de la zone, en pixels.
var rayon: float = 160.0
## Dégâts par seconde infligés à chaque ennemi dans la zone.
var degats_par_s: float = 0.0
## Porteur des dégâts (le joueur) : c'est lui l'auteur des coups.
var auteur: Node = null

const TICK := 0.25
const OR := Color(1.0, 0.86, 0.45)

## < 0 : entretenue. >= 0 : temps restant avant extinction.
var _extinction: float = -1.0
var _duree_extinction: float = 1.0
var _tick: float = 0.0
var _temps: float = 0.0
var _apparition: float = 0.0


func _ready() -> void:
	# Sous les corps : c'est un sol, pas un effet par-dessus la mêlée.
	z_index = -2


func entretenir() -> void:
	_extinction = -1.0


func relacher(duree: float) -> void:
	if _extinction < 0.0:
		_extinction = duree
		_duree_extinction = maxf(0.01, duree)


func est_entretenue() -> bool:
	return _extinction < 0.0


func contient(point: Vector2) -> bool:
	return global_position.distance_to(point) <= rayon


func _process(delta: float) -> void:
	_temps += delta
	_apparition = minf(1.0, _apparition + delta * 5.0)
	if _extinction >= 0.0:
		_extinction -= delta
		if _extinction <= 0.0:
			queue_free()
			return
	_tick += delta
	if _tick >= TICK:
		_tick -= TICK
		_bruler(TICK)
	queue_redraw()


func _bruler(dt: float) -> void:
	if degats_par_s <= 0.0:
		return
	var coup := degats_par_s * dt
	for enemy in get_tree().get_nodes_in_group(Groups.ENEMIES):
		var node := enemy as Node2D
		if node == null or node.is_queued_for_deletion():
			continue
		if node.global_position.distance_to(global_position) > rayon:
			continue
		if node.has_method(&"apply_damage"):
			node.call(&"apply_damage", coup, auteur, Vector2.ZERO)


func _draw() -> void:
	var force := _apparition
	if _extinction >= 0.0:
		force *= clampf(_extinction / _duree_extinction, 0.0, 1.0)
	var r := rayon * (0.85 + 0.15 * _apparition)
	var souffle := 0.5 + 0.5 * sin(_temps * 2.4)
	draw_circle(Vector2.ZERO, r, Color(OR, 0.08 + 0.04 * souffle) * Color(1, 1, 1, force))
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 64, Color(OR, 0.75 * force), 3.0)
	# Les glyphes : douze traits qui tournent lentement sur un cercle intérieur.
	# Ils disent « ce sol est actif » même quand la foule couvre le bord.
	var interieur := r * 0.72
	for i in 12:
		var a := _temps * 0.35 + TAU * float(i) / 12.0
		draw_arc(Vector2.ZERO, interieur, a, a + 0.22, 4, Color(OR, 0.55 * force), 2.0)
