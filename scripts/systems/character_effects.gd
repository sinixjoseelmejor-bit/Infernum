class_name CharacterEffects
extends Node
## Passifs des personnages jouables.
##
## Chacun est borné et passe par `RunState.character_bonus`, c'est-à-dire par les
## pools plafonnés habituels : un passif ne peut pas dépasser les limites
## d'équilibrage, il aide seulement à s'en approcher plus vite sur un axe.
##
## Les recalculs de stats ne se font QUE sur transition (palier de Marque
## franchi, mise en mouvement/arrêt) — jamais chaque frame.

var _player: Player

# Caïn — La Marque
var _wave_kills: int = 0
var _mark_bonus: float = 0.0

# Job — La Patience
var _time_since_hit: float = 0.0
var _regen_carry: float = 0.0

# Loth — Ne pas se retourner
var _was_moving: bool = false


func _ready() -> void:
	GameEvents.player_spawned.connect(_bind_player)
	GameEvents.enemy_died.connect(_on_enemy_died)
	GameEvents.wave_started.connect(_on_wave_started)
	_bind_player(get_tree().get_first_node_in_group(Groups.PLAYER))


func _bind_player(node: Node2D) -> void:
	_player = node as Player
	if _player == null:
		return
	# La Patience se remet à zéro au moindre coup encaissé.
	if not _player.health.damaged.is_connected(_on_player_damaged):
		_player.health.damaged.connect(_on_player_damaged)


func _process(delta: float) -> void:
	if not is_instance_valid(_player) or _player.health.is_dead:
		return
	_process_patience(delta)
	_process_flight()


# --- Caïn : +1 % de dégâts par élimination, plafonné, remis à zéro par vague ---

func _on_enemy_died(_enemy: Node2D, _position: Vector2) -> void:
	if not Characters.has_special(&"mark_of_cain"):
		return
	_wave_kills += 1
	var bonus := minf(_wave_kills * Characters.MARK_PER_KILL, Characters.MARK_MAX)
	if is_equal_approx(bonus, _mark_bonus):
		return  # plafond atteint : plus rien à recalculer
	_mark_bonus = bonus
	RunState.set_character_bonus(&"damage_pct", _mark_bonus)


func _on_wave_started(_index: int) -> void:
	if not Characters.has_special(&"mark_of_cain"):
		return
	_wave_kills = 0
	_mark_bonus = 0.0
	RunState.set_character_bonus(&"damage_pct", 0.0)


# --- Job : régénération conditionnée à ne pas avoir été touché ---------------

func _process_patience(delta: float) -> void:
	if not Characters.has_special(&"patience"):
		return
	# `invulnerability_time` remet le compteur : on lit les PV plutôt qu'un signal.
	_time_since_hit += delta
	if _time_since_hit < Characters.PATIENCE_DELAY:
		return
	_regen_carry += Characters.PATIENCE_REGEN * delta
	if _regen_carry >= 1.0:
		var whole := floorf(_regen_carry)
		_regen_carry -= whole
		_player.health.heal(whole)


func _on_player_damaged(_amount: float, _source: Node) -> void:
	_time_since_hit = 0.0
	_regen_carry = 0.0


# --- Loth : cadence bonus tant qu'il bouge ----------------------------------

func _process_flight() -> void:
	if not Characters.has_special(&"never_look_back"):
		return
	var moving: bool = _player.move_input != Vector2.ZERO
	if moving == _was_moving:
		return  # pas de transition : on ne recalcule rien
	_was_moving = moving
	RunState.set_character_bonus(
		&"fire_rate_pct", Characters.FLIGHT_FIRE_RATE if moving else 0.0)
