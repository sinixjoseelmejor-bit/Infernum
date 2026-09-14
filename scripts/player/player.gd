class_name Player
extends CharacterBody2D
## Joueur : déplacement 8 directions, tir automatique via les armes enfants.
##
## Le joueur ne tire pas lui-même : chaque `Weapon` sous `%Weapons` gère son
## propre cooldown et interroge le `TargetingSystem` partagé. Ajouter une arme
## = ajouter un nœud enfant, rien d'autre.
##
## Toutes les statistiques dérivent de `RunState.stats` et sont RECALCULÉES
## INTÉGRALEMENT depuis les valeurs de base à chaque changement d'inventaire.
## Appliquer des deltas successifs dériverait au bout de quelques objets.

@export_group("Déplacement")
@export var move_speed: float = 235.0
@export var acceleration: float = 2400.0
@export var friction: float = 2800.0
@export var knockback_friction: float = 900.0
## Plafond de recul cumulé. Sans lui, plusieurs impacts dans la même frame
## (couronne de zones d'un boss) s'additionnent et catapultent le joueur.
@export var max_knockback: float = 900.0

@export_group("Survie")
@export var max_health: float = 100.0
@export var hit_shake: float = 6.0

@onready var targeting: TargetingSystem = %Targeting
@onready var weapons: Node2D = %Weapons
@onready var health: Health = %Health
@onready var sprite: Sprite2D = %Sprite
@onready var waddle: Waddle = %Waddle
@onready var animator: SpriteAnimator = %Animator

## Direction de déplacement courante ; sert d'indice de visée aux armes.
var move_input: Vector2 = Vector2.ZERO
var facing: Vector2 = Vector2.RIGHT

var _base_move_speed: float = 0.0
## Grandeur de l'échelle du sprite. Le demi-tour se fait par le SIGNE de
## `scale.x` : il faut donc mémoriser la valeur, sinon retourner le personnage
## le ramènerait à l'échelle 1 et il rapetisserait d'un coup.
var _sprite_scale: float = 1.0
var _base_max_health: float = 0.0
var _base_range: float = 0.0
## Vitesse de déplacement volontaire, tenue SÉPARÉE du recul.
## `velocity` est réécrite par `move_and_slide()` : y ajouter le recul frame
## après frame le réinjectait en boucle et catapultait le joueur (plusieurs
## milliers de px/s après une seule impulsion de boss).
var _move_velocity: Vector2 = Vector2.ZERO
var _knockback: Vector2 = Vector2.ZERO


func _ready() -> void:
	add_to_group(Groups.PLAYER)
	# Le personnage choisi redéfinit les VALEURS DE BASE avant toute autre chose :
	# tout le reste (objets, Forge, malédictions) se calcule ensuite par-dessus.
	_apply_character(Characters.get_selected())
	_base_move_speed = move_speed
	_base_max_health = max_health
	_base_range = targeting.range_radius

	health.max_health = max_health
	health.current = max_health
	health.health_changed.connect(_on_health_changed)
	health.died.connect(_on_died)

	for weapon in get_weapons():
		weapon.setup(targeting)

	RunState.stats_recomputed.connect(_on_stats_recomputed)
	apply_stats(RunState.stats)

	GameEvents.player_spawned.emit(self)
	GameEvents.player_health_changed.emit(health.current, health.max_health)


func _physics_process(delta: float) -> void:
	move_input = PlayerInput.get_move_vector(Settings.eight_way)

	if move_input != Vector2.ZERO:
		facing = move_input.normalized()
		_move_velocity = _move_velocity.move_toward(move_input * move_speed, acceleration * delta)
	else:
		_move_velocity = _move_velocity.move_toward(Vector2.ZERO, friction * delta)

	_knockback = _knockback.move_toward(Vector2.ZERO, knockback_friction * delta)
	velocity = _move_velocity + _knockback
	move_and_slide()

	# Le stick droit prime s'il est poussé ; sinon les armes visent dans la
	# direction du déplacement — sur mobile le pouce sert aux deux à la fois.
	var aim := PlayerInput.get_aim_vector()
	if aim == Vector2.ZERO:
		aim = facing
	for weapon in get_weapons():
		weapon.aim_hint = aim

	if absf(facing.x) > 0.1:
		# On miroite par l'échelle et non par `flip_h` : `flip_h` retourne la
		# texture DANS son rectangle sans toucher à `offset`, donc un sprite
		# décalé saute latéralement à chaque demi-tour.
		sprite.scale.x = -_sprite_scale if facing.x < 0.0 else _sprite_scale

	# La démarche suit la vitesse RÉELLE : poussé par un recul ou ralenti contre
	# un mur, le pas ralentit avec le personnage au lieu de pédaler dans le vide.
	var ratio := _move_velocity.length() / maxf(1.0, move_speed) if move_input != Vector2.ZERO else 0.0
	waddle.advance(delta, ratio)


func get_weapons() -> Array[Weapon]:
	var result: Array[Weapon] = []
	for child in weapons.get_children():
		if child is Weapon:
			result.append(child as Weapon)
	return result


## Applique le personnage sélectionné : statistiques de base et arme de départ.
## N'écrit dans aucun pool — les pools restent réservés aux bonus cumulables.
func _apply_character(character: CharacterData) -> void:
	if character == null:
		return
	max_health = character.max_health
	move_speed = character.move_speed
	targeting.range_radius = character.targeting_range
	animator.set_sheets(character.sprite_idle, character.sprite_walk)
	sprite.offset = character.sprite_offset
	_sprite_scale = maxf(0.01, character.sprite_scale)
	sprite.scale = Vector2(_sprite_scale, _sprite_scale)
	for weapon in get_weapons():
		weapon.damage = character.weapon_damage
		weapon.fire_rate = character.weapon_fire_rate
		weapon.projectile_speed = character.weapon_projectile_speed
		weapon.crit_chance = character.weapon_crit_chance
		weapon.crit_multiplier = character.weapon_crit_multiplier


## Recalcul complet depuis les valeurs de base (jamais de delta cumulé).
func apply_stats(stats: PlayerStats) -> void:
	move_speed = _base_move_speed * (1.0 + stats.get_move_speed_pct())
	targeting.range_radius = _base_range * (1.0 + stats.get_range_pct())

	var target_max := maxf(1.0, _base_max_health + stats.max_health_flat)
	health.add_max_health(target_max - health.max_health)

	for weapon in get_weapons():
		weapon.apply_stats(stats)


## Point d'entrée unique des dégâts (projectiles et contact).
func apply_damage(amount: float, source: Node = null, impulse: Vector2 = Vector2.ZERO) -> void:
	var reduced := amount * (1.0 - RunState.stats.get_damage_reduction())
	if not health.take_damage(reduced, source):
		return
	_knockback = (_knockback + impulse).limit_length(max_knockback)
	GameEvents.request_shake(hit_shake)
	_flash()


## Poussée externe sans dégâts (chaîne d'Asmodée, souffles, explosions).
func apply_impulse(impulse: Vector2) -> void:
	_knockback = (_knockback + impulse).limit_length(max_knockback)


func _flash() -> void:
	var tween := create_tween()
	sprite.modulate = Color(2.0, 0.6, 0.6)
	tween.tween_property(sprite, ^"modulate", Color.WHITE, 0.18)


func _on_stats_recomputed(stats: PlayerStats) -> void:
	apply_stats(stats)


func _on_health_changed(current: float, maximum: float) -> void:
	GameEvents.player_health_changed.emit(current, maximum)


func _on_died(_source: Node) -> void:
	GameEvents.player_died.emit(self)
	set_physics_process(false)
	for weapon in get_weapons():
		weapon.auto_fire = false
	var tween := create_tween()
	tween.tween_property(self, ^"modulate:a", 0.0, 0.4)
