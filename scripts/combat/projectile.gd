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
## Correction de trajectoire vers la cible, en degrés/seconde (aide à la visée).
@export var homing_speed_deg: float = 0.0
@export var knockback: float = 140.0
@export var face_direction: bool = true

var damage: float = 10.0
var is_crit: bool = false
var direction: Vector2 = Vector2.RIGHT
var source: Node = null
var target: Node2D = null

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
	node.call(&"apply_damage", damage, origin, direction * knockback)
	GameEvents.damage_dealt.emit(damage, global_position, is_crit)
	if origin != null and origin.is_in_group(Groups.PLAYER):
		GameEvents.player_damage_dealt.emit(damage, node)

	if _remaining_pierce > 0:
		_remaining_pierce -= 1
	else:
		_despawn()


func _despawn() -> void:
	set_physics_process(false)
	set_deferred(&"monitoring", false)
	queue_free()
