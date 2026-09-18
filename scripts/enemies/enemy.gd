class_name Enemy
extends CharacterBody2D
## Ennemi de base : poursuite directe et dégâts au contact (corps-à-corps).
##
## Les variantes de COMPORTEMENT héritent de ce script :
##   - `ranged_enemy.gd` : garde ses distances et tire ;
##   - `dasher_enemy.gd` : charge par à-coups.
## Les variantes de STATISTIQUES (brute tanky) sont de simples scènes réglant
## les exports — inutile de créer une sous-classe pour changer des chiffres.

@export_group("Déplacement")
@export var move_speed: float = 95.0
@export var acceleration: float = 900.0
@export var knockback_friction: float = 1200.0
@export_range(0.0, 1.0, 0.05) var knockback_resistance: float = 0.0

@export_group("Combat")
@export var contact_damage: float = 8.0
@export var contact_cooldown: float = 0.7
@export var max_health: float = 30.0

@export_group("Récompenses")
@export var soul_value: int = 3
## Chance de lâcher une clé. Réservé aux élites : 0 sur les ennemis normaux.
@export_range(0.0, 1.0, 0.01) var key_chance: float = 0.0
@export_range(0.0, 1.0, 0.01) var heal_chance: float = 0.0

@export_group("Élite")
@export var elite_health_multiplier: float = 4.0
## Combiné à la courbe de dégâts, 1.6 faisait de l'élite un ennemi qui tue en
## une touche en fin de partie : elle doit être une menace, pas une sentence.
@export var elite_damage_multiplier: float = 1.35
@export var elite_scale: float = 1.35
@export var elite_soul_multiplier: int = 2
## 6 % par élite faisaient tomber ~40 clés sur une run allant à la vague 20,
## alors que la Forge entière en coûte 42 : l'arbre se terminait en deux runs.
@export var elite_key_chance: float = 0.02
## Chance qu'une élite laisse un soin. Seules les élites en laissent : un
## ennemi de base est trop nombreux pour porter une ressource de survie.
@export_range(0.0, 1.0, 0.01) var elite_heal_chance: float = 0.08
@export var elite_tint: Color = Color(1.35, 0.75, 1.3)

@onready var health: Health = $Health
@onready var sprite: Sprite2D = $Sprite

var target: Node2D
var is_elite: bool = false

var _knockback: Vector2 = Vector2.ZERO
var _contact_timer: float = 0.0


func _ready() -> void:
	add_to_group(Groups.ENEMIES)
	health.max_health = max_health
	health.current = max_health
	health.died.connect(_on_died)
	if target == null:
		target = get_tree().get_first_node_in_group(Groups.PLAYER)
	if is_elite:
		sprite.modulate = elite_tint
	GameEvents.enemy_spawned.emit(self)


## Appelé par le WaveManager AVANT l'entrée dans l'arbre : la montée en
## difficulté est additive côté vague, jamais composée ici.
func apply_wave_scaling(health_mult: float, damage_mult: float, speed_mult: float) -> void:
	max_health *= health_mult
	contact_damage *= damage_mult
	move_speed *= speed_mult


func make_elite() -> void:
	is_elite = true
	max_health *= elite_health_multiplier
	contact_damage *= elite_damage_multiplier
	soul_value *= elite_soul_multiplier
	key_chance = maxf(key_chance, elite_key_chance)
	heal_chance = maxf(heal_chance, elite_heal_chance)
	scale *= elite_scale


func _physics_process(delta: float) -> void:
	_contact_timer = maxf(0.0, _contact_timer - delta)
	_update_movement(delta)

	# `velocity` porte ici la vitesse VOULUE. Le recul s'y ajoute uniquement le
	# temps du déplacement, puis on la restaure : l'ajouter durablement le
	# réinjecterait à chaque frame et ferait diverger la vitesse.
	var intent := velocity
	_knockback = _knockback.move_toward(Vector2.ZERO, knockback_friction * delta)
	velocity = intent + _knockback
	move_and_slide()
	velocity = intent

	_handle_contact_damage()


## Surchargé par les variantes de comportement.
func _update_movement(delta: float) -> void:
	if not is_instance_valid(target):
		velocity = velocity.move_toward(Vector2.ZERO, acceleration * delta)
		target = get_tree().get_first_node_in_group(Groups.PLAYER)
		return
	var direction := (target.global_position - global_position).normalized()
	velocity = velocity.move_toward(direction * move_speed, acceleration * delta)
	face(direction)


func face(direction: Vector2) -> void:
	if absf(direction.x) > 0.1:
		sprite.flip_h = direction.x < 0.0


func _handle_contact_damage() -> void:
	if _contact_timer > 0.0 or contact_damage <= 0.0:
		return
	for i in get_slide_collision_count():
		var body := get_slide_collision(i).get_collider() as Node2D
		if body == null or not body.is_in_group(Groups.PLAYER):
			continue
		# UNE CIBLE EN PLEINE RUÉE TRAVERSE LES CORPS. Le joueur a retiré la
		# couche des ennemis de son masque le temps du trajet, mais l'ennemi,
		# lui, continue de le voir : sans ce test, traverser une mêlée coûterait
		# un coup à chaque fois et la ruée cesserait d'être une sortie.
		#
		# Elle ne protège QUE du contact. Zones annoncées, projectiles et rayons
		# ne passent pas par ici et touchent comme avant — voir `_lancer_ruee`.
		if body.has_method(&"is_dashing") and body.call(&"is_dashing"):
			continue
		if body.has_method(&"apply_damage"):
			var push: Vector2 = (body.global_position - global_position).normalized() * 220.0
			body.call(&"apply_damage", contact_damage, self, push)
			GameEvents.player_contact_hit.emit(self, contact_damage)
		_contact_timer = contact_cooldown
		return


func apply_damage(amount: float, source: Node = null, impulse: Vector2 = Vector2.ZERO) -> void:
	if not health.take_damage(amount, source):
		return
	_knockback += impulse * (1.0 - knockback_resistance)
	_flash()


func _flash() -> void:
	var tween := create_tween()
	sprite.modulate = Color(3.0, 2.2, 2.2)
	tween.tween_property(sprite, ^"modulate", elite_tint if is_elite else Color.WHITE, 0.12)


func _on_died(_source: Node) -> void:
	DropSystem.spawn_drops(get_parent(), global_position, soul_value, key_chance, heal_chance)
	GameEvents.enemy_died.emit(self, global_position)
	queue_free()
