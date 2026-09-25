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

const PRIX_VFX := preload("res://scenes/vfx/explosion.tscn")
## Largeur utile du dessin d'explosion, en pixels : l'IMAGE DE POINTE de la
## planche, la même mesure que celle qui sert à Braise éternelle. L'union des
## images vaut 111 px et rapetissait le dessin d'un tiers.
const PRIX_VFX_CONTENU := 82.0

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
	GameEvents.power_requested.connect(_on_power_requested)
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


## LE PRIX DU SANG. La Marque partait à la poubelle à chaque vague sans que le
## joueur puisse en faire quoi que ce soit ; elle devient une ressource qu'on
## choisit de garder ou de brûler.
##
## LE COUP VAUT CE QUE VALAIT LA MARQUE. Les dégâts suivent l'arme principale —
## comme l'explosion de Braise éternelle, donc ils profitent des objets de
## dégâts mais pas de la cadence ni du multishot — et sont multipliés par la
## CHARGE, pas par un chiffre à part. Le plafond du coup est donc le plafond de
## la Marque, celui que la branche de Forge de Caïn déplace déjà : aucun canal
## de scaling nouveau ne s'ouvre ici.
##
## EN DESSOUS DU MINIMUM, RIEN NE PART. Sans ce test, un appui réflexe à trois
## éliminations grillerait la vague entière pour un coup qui ne tue rien : le
## pouvoir se retournerait contre celui qui l'utilise.
func _on_power_requested() -> void:
	if not Characters.has_special(&"mark_of_cain"):
		return
	if not is_instance_valid(_player) or _player.health.is_dead:
		return
	var plafond := Characters.MARK_MAX + Forge.get_special_total(&"mark_max")
	var charge := _mark_bonus / maxf(0.01, plafond)
	if charge < Characters.PRIX_MINIMUM:
		return
	var degats := _degats_arme() * Characters.PRIX_RATIO * charge
	if degats <= 0.0:
		return

	var centre: Vector2 = _player.global_position
	_effet_prix_du_sang(centre)
	GameEvents.damage_dealt.emit(degats, centre, false)
	GameEvents.request_shake(5.0)
	for enemy in get_tree().get_nodes_in_group(Groups.ENEMIES):
		var node := enemy as Node2D
		if node == null or node.is_queued_for_deletion():
			continue
		var ecart: Vector2 = node.global_position - centre
		if ecart.length() > Characters.PRIX_RAYON:
			continue
		if node.has_method(&"apply_damage"):
			node.call(&"apply_damage", degats, _player,
				ecart.normalized() * Characters.PRIX_KNOCKBACK)

	# LA MARQUE EST DÉPENSÉE, et c'est le prix. On remet les ÉLIMINATIONS à zéro
	# plutôt que le bonus : c'est le compteur qui fait foi, comme au changement
	# de vague, pour que le compte reste juste si le plafond change en cours de
	# run. Le Serpent d'airain en garde une part : c'est sa « recharge ».
	var gardee := Characters.PRIX_MARQUE_GARDEE if RunState.has_special(&"power_haste") else 0.0
	_wave_kills = int(_wave_kills * gardee)
	_mark_bonus = -1.0
	_appliquer_marque()


## L'effet reprend la planche d'explosion, à la TAILLE du rayon qui blesse, et
## teinté du rouge de Caïn : la même image en orange est déjà celle de Braise
## éternelle, et deux effets identiques pour deux causes différentes se lisent
## comme un seul.
func _effet_prix_du_sang(at: Vector2) -> void:
	var bacs := get_tree().get_nodes_in_group(Groups.PROJECTILE_CONTAINER)
	if bacs.is_empty():
		return
	var vfx := PRIX_VFX.instantiate() as Node2D
	if vfx == null:
		return
	bacs[0].add_child(vfx)
	vfx.global_position = at
	vfx.scale = Vector2.ONE * (Characters.PRIX_RAYON * 2.0 / PRIX_VFX_CONTENU)
	vfx.modulate = Color(1.0, 0.45, 0.42)


## Les dégâts de référence : ceux de l'arme principale, projectile compris.
func _degats_arme() -> float:
	if not is_instance_valid(_player):
		return 0.0
	var armes := _player.get_weapons()
	if armes.is_empty():
		return 0.0
	return armes[0].get_projectile_damage()


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
