class_name Projectile
extends Area2D
## Projectile générique (tir du joueur par défaut).
##
## Le calque/masque de collision est défini dans la scène : changer le masque
## suffit pour en faire un projectile ennemi.

@export var speed: float = 720.0
@export var lifetime: float = 1.6
## Nombre d'ennemis traversés en plus du premier.
@export var pierce: int = 0
## Décote cumulative par corps traversé : le deuxième ennemi touché encaisse
## (1 - taxe), le troisième (1 - taxe)², etc. Un projectile perforant ne doit pas
## valoir autant de dégâts par ennemi que deux tirs séparés.
@export_range(0.0, 0.9, 0.05) var pierce_falloff: float = 0.0
## Après avoir traversé un corps, le trait se braque sur le suivant.
@export var redirect_on_pierce: bool = true
## Portée de cette recherche. Sans borne, un trait pouvait faire demi-tour et
## retraverser tout l'écran à l'envers pour aller chercher un retardataire.
@export var pierce_seek_radius: float = 520.0
## Correction de trajectoire vers la cible, en degrés/seconde (aide à la visée).
@export var homing_speed_deg: float = 0.0
@export var knockback: float = 140.0
@export var face_direction: bool = true

var damage: float = 10.0
var is_crit: bool = false
var direction: Vector2 = Vector2.RIGHT
var source: Node = null
var target: Node2D = null
## Fléau des géants : les boss et les élites encaissent `giant_multiplier`, le
## reste `common_multiplier`. Neutres (1,0) pour tout autre tireur.
var giant_multiplier: float = 1.0
var common_multiplier: float = 1.0

var _remaining_pierce: int = 0
var _hit: Array[int] = []


func _ready() -> void:
	_remaining_pierce = pierce
	if face_direction:
		rotation = direction.angle()
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	if lifetime > 0.0:
		get_tree().create_timer(lifetime, false).timeout.connect(queue_free)


func _physics_process(delta: float) -> void:
	if homing_speed_deg > 0.0 and is_instance_valid(target) and not target.is_queued_for_deletion():
		var desired := (target.global_position - global_position).normalized()
		var max_turn := deg_to_rad(homing_speed_deg) * delta
		direction = direction.rotated(clampf(direction.angle_to(desired), -max_turn, max_turn))
		if face_direction:
			rotation = direction.angle()
	global_position += direction * speed * delta


func _on_body_entered(body: Node2D) -> void:
	_resolve_hit(body)


func _on_area_entered(area: Area2D) -> void:
	# Support des hurtbox : l'entité est le parent de l'Area2D.
	var parent := area.get_parent()
	if parent is Node2D:
		_resolve_hit(parent as Node2D)


func _resolve_hit(node: Node2D) -> void:
	if node == null or node == source:
		return

	if not node.has_method(&"apply_damage"):
		# Mur / décor : le projectile est absorbé.
		_despawn()
		return

	var id := node.get_instance_id()
	if _hit.has(id):
		return
	_hit.append(id)

	# La source peut avoir été libérée entre le tir et l'impact (tireur tué en
	# vol) : passer une référence morte lève une erreur de type côté appelé.
	var origin: Node = source if is_instance_valid(source) else null
	var du_joueur := origin != null and origin.is_in_group(Groups.PLAYER)
	var dealt := damage * pow(1.0 - pierce_falloff, float(_hit.size() - 1))
	if giant_multiplier != common_multiplier:
		var giant: bool = node.is_in_group(Groups.BOSSES) or node.get(&"is_elite") == true
		dealt *= giant_multiplier if giant else common_multiplier
	# Lu AVANT le coup : la Fronde regarde si la cible est encore intacte.
	if du_joueur:
		dealt *= ItemEffects.multiplicateur_cible(node)
	node.call(&"apply_damage", dealt, origin, direction * knockback)
	GameEvents.damage_dealt.emit(dealt, global_position, is_crit)
	if du_joueur:
		GameEvents.player_damage_dealt.emit(dealt, node)
		ItemEffects.sur_coup(node, dealt, is_crit, origin)

	if _remaining_pierce > 0:
		_remaining_pierce -= 1
		# On ne se rebraque QUE sur ce qu'on vient de traverser : un projectile
		# ennemi perforant irait sinon chasser les ennemis.
		if redirect_on_pierce and node.is_in_group(Groups.ENEMIES):
			_seek_next()
	else:
		_despawn()


## Cible la plus proche PARMI CELLES PAS ENCORE TOUCHÉES. L'exclusion n'est pas
## un détail : `_hit` empêche déjà de blesser deux fois le même corps, mais sans
## elle le trait se rebraquait sur celui qu'il venait de traverser et restait
## collé dedans — il dépensait ses perforations sans toucher personne d'autre.
func _seek_next() -> void:
	var best: Node2D = null
	var best_distance := pierce_seek_radius
	for candidate in get_tree().get_nodes_in_group(Groups.ENEMIES):
		if not (candidate is Node2D):
			continue
		var enemy := candidate as Node2D
		if enemy.is_queued_for_deletion() or _hit.has(enemy.get_instance_id()):
			continue
		var distance := global_position.distance_to(enemy.global_position)
		if distance < best_distance:
			best_distance = distance
			best = enemy
	if best == null:
		return
	# Braquage SEC, pas une correction progressive : à 720 px/s le trait a déjà
	# quitté la mêlée avant qu'un virage doux ne l'ait réorienté.
	target = best
	direction = (best.global_position - global_position).normalized()
	if face_direction:
		rotation = direction.angle()


func _despawn() -> void:
	set_physics_process(false)
	set_deferred(&"monitoring", false)
	queue_free()
