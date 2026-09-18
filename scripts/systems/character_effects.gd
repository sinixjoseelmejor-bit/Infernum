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
##
## LA BRANCHE DE FORGE DU PERSONNAGE se branche ici, et nulle part ailleurs :
## chacun de ses nœuds ne fait qu'ajuster un chiffre de ce fichier. Les lire via
## `Forge.get_special_total` suffit à garantir qu'ils ne peuvent pas fuir sur un
## autre personnage — la Forge ne rend que les nœuds de celui qui est choisi.

var _player: Player

# Caïn — La Marque
var _wave_kills: int = 0
var _mark_bonus: float = 0.0

# Job — La Patience et la Dîme
var _time_since_hit: float = 0.0
var _regen_carry: float = 0.0
var _dime_carry: float = 0.0

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
	_appliquer_marque()


## La Marque, telle que la branche de Caïn la modifie : elle monte plus vite
## (`mark_per_kill`), plus haut (`mark_max`), et « Fratricide » lui fait donner
## la moitié de sa valeur en cadence.
##
## Les deux pools restent ceux de tout le monde, plafonds compris : la branche
## accélère la montée, elle n'ouvre pas de canal parallèle.
func _appliquer_marque() -> void:
	var par_kill := Characters.MARK_PER_KILL + Forge.get_special_total(&"mark_per_kill")
	var plafond := Characters.MARK_MAX + Forge.get_special_total(&"mark_max")
	var bonus := minf(_wave_kills * par_kill, plafond)
	if is_equal_approx(bonus, _mark_bonus):
		return  # plafond atteint : plus rien à recalculer
	_mark_bonus = bonus
	RunState.set_character_bonus(&"damage_pct", _mark_bonus)
	var cadence := Forge.get_special_total(&"mark_fire_rate")
	if cadence > 0.0:
		RunState.set_character_bonus(&"fire_rate_pct", _mark_bonus * cadence)


func _on_wave_started(_index: int) -> void:
	if not Characters.has_special(&"mark_of_cain"):
		return
	# « Le sang ne sèche pas » : la Marque ne repart plus de zéro. On garde les
	# ÉLIMINATIONS et non le bonus, pour que le compte reste juste si la valeur
	# par élimination ou le plafond changent en cours de run.
	_wave_kills = int(_wave_kills * Forge.get_special_total(&"mark_carry"))
	_mark_bonus = -1.0  # force le recalcul, même si le résultat est identique
	_appliquer_marque()


# --- Job : régénération conditionnée à ne pas avoir été touché ---------------

func _process_patience(delta: float) -> void:
	if not Characters.has_special(&"patience"):
		return
	# « Il n'a pas plié » : le délai tombe de moitié et la régénération double.
	var boost := Forge.get_special_total(&"patience_boost") > 0.0
	var delai := Characters.PATIENCE_DELAY * (0.5 if boost else 1.0)
	var regen := Characters.PATIENCE_REGEN * (2.0 if boost else 1.0)
	# `invulnerability_time` remet le compteur : on lit les PV plutôt qu'un signal.
	_time_since_hit += delta
	if _time_since_hit < delai:
		return
	_regen_carry += regen * delta
	if _regen_carry >= 1.0:
		var whole := floorf(_regen_carry)
		_regen_carry -= whole
		_player.health.heal(whole)


func _on_player_damaged(amount: float, _source: Node) -> void:
	_time_since_hit = 0.0
	_regen_carry = 0.0
	_verser_dime(amount)


## LA DÎME DE L'ÉPROUVÉ — la réponse au vrai problème d'un personnage qui
## encaisse.
##
## Les âmes tombent des éliminations : un revenu proportionnel aux dégâts
## infligés. Job frappe 30 % moins fort que Caïn, donc il s'équipe moins bien,
## donc il frappe encore moins fort — l'écart se creuse tout seul. Ce nœud lui
## donne une seconde source, branchée sur ce qu'il sait faire : survivre à ce
## qui le touche.
##
## TROIS BORNES, et aucune n'est arbitraire :
## 1. les i-frames du joueur limitent l'encaisse à deux coups par seconde ;
## 2. l'armure RÉDUIT les dégâts reçus, donc réduit la dîme — s'empiler en
##    défense coûte des âmes, ce qui est la tension qu'on voulait ;
## 3. le débit soutenable est celui de ses soins (1,4 PV/s, 2,8 avec « Il n'a pas
##    plié »), soit environ 18 âmes par vague de 30 s. Au-delà, il paie en points
##    de vie — et mourir termine la run.
##
## Compté sur les dégâts RÉELLEMENT subis, après armure : c'est la souffrance
## qui est payée, pas la menace.
func _verser_dime(amount: float) -> void:
	var taux := Forge.get_special_total(&"souls_per_damage")
	if taux <= 0.0:
		return
	_dime_carry += amount * taux
	if _dime_carry < 1.0:
		return
	var entier := floorf(_dime_carry)
	_dime_carry -= entier
	RunState.add_souls(int(entier))


# --- Loth : cadence bonus tant qu'il bouge ----------------------------------

func _process_flight() -> void:
	if not Characters.has_special(&"never_look_back"):
		return
	var moving: bool = _player.move_input != Vector2.ZERO
	if moving == _was_moving:
		return  # pas de transition : on ne recalcule rien
	_was_moving = moving
	var cadence := Characters.FLIGHT_FIRE_RATE + Forge.get_special_total(&"flight_boost")
	RunState.set_character_bonus(&"fire_rate_pct", cadence if moving else 0.0)
	# « Fuite en avant » : la course rend aussi des dégâts. Le seul personnage
	# pour qui une statistique dépend de la façon de jouer, et non de l'achat.
	var degats := Forge.get_special_total(&"flight_damage")
	if degats > 0.0:
		RunState.set_character_bonus(&"damage_pct", degats if moving else 0.0)
