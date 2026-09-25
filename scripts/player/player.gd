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

## Durée d'invulnérabilité accordée par la seconde chance. Écrite ici et non en
## littéral dans `apply_damage` parce que l'anneau de [ReviveBurst] se vide
## dessus : deux valeurs séparées dériveraient, et l'anneau mentirait sur la
## protection qui reste.
const REVIVE_INVULNERABILITE := 1.5

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

## Ruée : réservée aux personnages qui la portent (`CharacterData.dash`).
var _peut_foncer: bool = false
## Pouvoir non-déplacement du personnage, s'il en a un. Le joueur ne l'exécute
## pas : il annonce l'appui, et le système qui possède la ressource répond.
var _pouvoir: StringName = &""
## Parade : minuteurs des trois temps (amorce, fenêtre, sanction) et recharge.
var _parade_amorce: float = 0.0
var _parade_fenetre: float = 0.0
var _parade_racine: float = 0.0
var _parade_recharge: float = 0.0
var _jauge_parade: ParryGauge
var _jauge_marque: MarkGauge
var _marque_plafond: float = 1.0
var _dash_direction: Vector2 = Vector2.RIGHT
var _dash_restant: float = 0.0
var _dash_recharge: float = 0.0
var _trace_restante: float = 0.0
var _jauge: DashGauge = null


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
		# Seules les armes DU JOUEUR sonnent. Les cultistes tirent aussi, et
		# ajouter leur salve au même son remplirait la banque de voix avec du
		# bruit sur lequel le joueur n'a aucune prise.
		weapon.fired.connect(func(_target: Node2D) -> void: Audio.play(&"tir"))

	RunState.stats_recomputed.connect(_on_stats_recomputed)
	apply_stats(RunState.stats)

	GameEvents.player_spawned.emit(self)
	GameEvents.player_health_changed.emit(health.current, health.max_health)


func _physics_process(delta: float) -> void:
	move_input = PlayerInput.get_move_vector(Settings.eight_way)
	if move_input != Vector2.ZERO:
		facing = move_input.normalized()

	_dash_recharge = maxf(0.0, _dash_recharge - delta)
	# UNE SEULE TOUCHE, un pouvoir par personnage. Elle s'appelle encore `dash`
	# dans la table d'entrées, du nom du premier qui l'a utilisée.
	if Input.is_action_just_pressed(&"dash") and not health.is_dead:
		if _ruee_disponible():
			_lancer_ruee()
		elif _pouvoir == &"steadfast":
			_lancer_parade()
		elif _pouvoir != &"":
			GameEvents.power_requested.emit()
	if _pouvoir == &"steadfast":
		_avancer_parade(delta)

	if _dash_restant > 0.0:
		_avancer_ruee(delta)
	elif _parade_racine > 0.0:
		# CLOUÉ. La sanction d'une parade ratée n'est pas un malus abstrait :
		# il reste sur place, dans la mêlée, et encaisse ce qu'il a voulu parer.
		_move_velocity = _move_velocity.move_toward(Vector2.ZERO, friction * 3.0 * delta)
		_knockback = _knockback.move_toward(Vector2.ZERO, knockback_friction * delta)
		velocity = _move_velocity + _knockback
		move_and_slide()
	else:
		if move_input != Vector2.ZERO:
			_move_velocity = _move_velocity.move_toward(
				move_input * move_speed, acceleration * delta)
		else:
			_move_velocity = _move_velocity.move_toward(Vector2.ZERO, friction * delta)
		_knockback = _knockback.move_toward(Vector2.ZERO, knockback_friction * delta)
		velocity = _move_velocity + _knockback
		move_and_slide()

	if _jauge != null:
		var reste := _dash_recharge / maxf(0.01, _recharge_ruee())
		_jauge.remplissage = clampf(1.0 - reste, 0.0, 1.0)

	if _jauge_marque != null:
		# La jauge lit la MÊME valeur que les dégâts : le bonus déjà appliqué,
		# divisé par son plafond. Elle ne peut donc pas mentir sur la charge.
		var marque: float = RunState.character_bonus.get(&"damage_pct", 0.0)
		_jauge_marque.remplissage = clampf(marque / _marque_plafond, 0.0, 1.0)

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
	# Pendant la ruée, la démarche est figée : à 1090 px/s elle battrait quatre
	# fois plus vite qu'au pas de course et le personnage vibrerait sur place.
	waddle.advance(delta, 0.0 if _dash_restant > 0.0 else ratio)


## LA RUÉE — le seul verbe que le jeu ajoute à « se déplacer » et « tirer ».
##
## L'action `dash` était déclarée dans la table d'entrées depuis le début et
## n'était implémentée nulle part : une liaison morte. Elle ne sert qu'à Loth,
## et c'est là tout son intérêt — les trois personnages se jouaient avec les
## mêmes mains et ne différaient que par des chiffres.
##
## SUR RAIL, comme la charge d'un boss : ni accélération, ni frottement, ni
## recul. Le recul est remis à zéro au départ, sans quoi une ruée prise juste
## après un coup partirait de travers — c'est-à-dire exactement au moment où on
## en a besoin et où l'on a le plus besoin qu'elle aille où on l'envoie.
##
## ELLE TRAVERSE LES CORPS, ET RIEN D'AUTRE. `collision_mask` perd la couche des
## ennemis le temps du trajet, et `enemy.gd` s'abstient d'infliger ses dégâts de
## contact à une cible en pleine ruée : sans ce second garde-fou, traverser une
## mêlée coûterait un coup à chaque fois, puisque l'ennemi, lui, continue de
## voir le joueur.
##
## ELLE NE DONNE AUCUNE INVULNÉRABILITÉ, et c'est la décision structurante.
## Zones annoncées, projectiles et rayons touchent pendant la ruée comme avant.
## Deux raisons, et aucune n'est une précaution de principe :
##
##   1. Toute la difficulté du jeu est dans le PLACEMENT — « la difficulté
##      vient du nombre et du placement des zones, jamais d'un coup impossible à
##      lire ». Une ruée invulnérable effacerait la lecture qu'elle est censée
##      récompenser : on ne sortirait plus d'une zone, on la traverserait.
##   2. Les 0,4 s d'i-frames du joueur sont DÉJÀ la borne des dégâts entrants,
##      à 2,5 coups par seconde. Une seconde source d'invulnérabilité serait un
##      canal parallèle, c'est-à-dire ce que tout le reste de l'équilibrage
##      s'interdit.
##
## La ruée sert donc à être AILLEURS, pas à être intouchable.
func _ruee_disponible() -> bool:
	return _peut_foncer and _dash_restant <= 0.0 and _dash_recharge <= 0.0 \
		and not health.is_dead


func _lancer_ruee() -> void:
	_dash_direction = move_input.normalized() if move_input != Vector2.ZERO else facing
	if _dash_direction == Vector2.ZERO:
		_dash_direction = Vector2.RIGHT
	_dash_restant = Characters.DASH_TIME
	_dash_recharge = _recharge_ruee()
	_knockback = Vector2.ZERO
	collision_mask &= ~Layers.ENEMY
	_trace_restante = 0.0
	_poser_trace()


func _avancer_ruee(delta: float) -> void:
	_dash_restant = maxf(0.0, _dash_restant - delta)
	velocity = _dash_direction * Characters.DASH_SPEED
	move_and_slide()
	_trace_restante -= delta
	if _trace_restante <= 0.0:
		_trace_restante = Characters.DASH_TIME / 6.0
		_poser_trace()
	if _dash_restant <= 0.0:
		collision_mask |= Layers.ENEMY
		# On ne s'arrête pas net : la course repart à pleine vitesse dans l'axe,
		# sinon la ruée se termine par un temps mort, ce qui est le contraire de
		# ce qu'on lui demande.
		_move_velocity = _dash_direction * move_speed


## LA PARADE DE JOB — les trois temps, puis la recharge.
##
## Elle n'accorde AUCUNE invulnérabilité : elle annule un coup, un seul, et
## consomme la fenêtre en le faisant. Voir `apply_damage`.
func _lancer_parade() -> void:
	if _parade_recharge > 0.0 or _parade_racine > 0.0:
		return
	if _parade_amorce > 0.0 or _parade_fenetre > 0.0:
		return
	_parade_amorce = Characters.PARADE_AMORCE


func _avancer_parade(delta: float) -> void:
	_parade_recharge = maxf(0.0, _parade_recharge - delta)
	_parade_racine = maxf(0.0, _parade_racine - delta)
	if _parade_amorce > 0.0:
		_parade_amorce = maxf(0.0, _parade_amorce - delta)
		if _parade_amorce <= 0.0:
			_parade_fenetre = Characters.PARADE_FENETRE
	elif _parade_fenetre > 0.0:
		_parade_fenetre = maxf(0.0, _parade_fenetre - delta)
		if _parade_fenetre <= 0.0:
			# Fenêtre écoulée sans rien parer : c'est un coup dans le vide.
			_parade_racine = Characters.PARADE_RACINE
			_parade_recharge = _recharge_parade()
	if _jauge_parade == null:
		return
	if _parade_amorce > 0.0:
		_jauge_parade.etat = ParryGauge.Etat.AMORCE
		_jauge_parade.progression = 1.0 - _parade_amorce / Characters.PARADE_AMORCE
	elif _parade_fenetre > 0.0:
		_jauge_parade.etat = ParryGauge.Etat.FENETRE
		_jauge_parade.progression = _parade_fenetre / Characters.PARADE_FENETRE
	elif _parade_recharge > 0.0:
		_jauge_parade.etat = ParryGauge.Etat.RECHARGE
		_jauge_parade.progression = 1.0 - _parade_recharge / _recharge_parade()
	else:
		_jauge_parade.etat = ParryGauge.Etat.PRET


## Serpent d'airain : les verbes reviennent plus vite. La jauge lit la MÊME
## durée que le minuteur, sinon elle se remplirait à côté de la vraie recharge.
func _recharge_ruee() -> float:
	return Characters.DASH_COOLDOWN * _hate_pouvoir()


func _recharge_parade() -> float:
	return Characters.PARADE_RECHARGE * _hate_pouvoir()


func _hate_pouvoir() -> float:
	return Characters.POWER_HASTE if RunState.has_special(&"power_haste") else 1.0


func is_parrying() -> bool:
	return _parade_fenetre > 0.0


## LE CONTRE. Dégâts FIXES — un multiple des dégâts d'arme — et surtout pas une
## fraction de ce qui a été paré : au Déchaînement les dégâts ennemis montent en
## exponentielle, et un contre proportionnel y deviendrait la réponse à tout.
func _contrer(source: Node) -> void:
	_parade_fenetre = 0.0
	_parade_recharge = _recharge_parade()
	var armes := get_weapons()
	var degats: float = armes[0].get_projectile_damage() * Characters.PARADE_RATIO \
		if not armes.is_empty() else 0.0
	GameEvents.request_shake(hit_shake * 1.5)
	if _jauge_parade != null:
		_jauge_parade.reussite()
	_onde_parade()
	# RIEN À DÉTRUIRE CÔTÉ PROJECTILE, et il a fallu le vérifier : `source` est
	# le TIREUR et non le projectile — `projectile.gd` passe son `origin`. Le
	# libérer aurait tué l'ennemi qui venait de tirer. Le projectile, lui,
	# disparaît de lui-même à l'impact.
	if degats <= 0.0:
		return
	GameEvents.damage_dealt.emit(degats, global_position, false)
	for enemy in get_tree().get_nodes_in_group(Groups.ENEMIES):
		var node := enemy as Node2D
		if node == null or node.is_queued_for_deletion():
			continue
		var ecart: Vector2 = node.global_position - global_position
		if ecart.length() > Characters.PARADE_RAYON:
			continue
		if node.has_method(&"apply_damage"):
			node.call(&"apply_damage", degats, self,
				ecart.normalized() * Characters.PARADE_RECUL)


func _onde_parade() -> void:
	var onde := ParryWave.new()
	onde.rayon = Characters.PARADE_RAYON
	var bacs := get_tree().get_nodes_in_group(Groups.PROJECTILE_CONTAINER)
	var bac: Node = bacs[0] if not bacs.is_empty() else get_parent()
	bac.add_child(onde)
	onde.global_position = global_position


func is_dashing() -> bool:
	return _dash_restant > 0.0


## Copie figée du sprite, posée dans le conteneur des projectiles pour qu'elle
## RESTE où elle tombe. Enfant du joueur, elle le suivrait.
func _poser_trace() -> void:
	var trace := DashTrail.new()
	trace.texture = sprite.texture
	trace.hframes = sprite.hframes
	trace.vframes = sprite.vframes
	trace.frame = sprite.frame
	trace.offset = sprite.offset
	trace.scale = sprite.scale
	trace.global_position = sprite.global_position
	var bacs := get_tree().get_nodes_in_group(Groups.PROJECTILE_CONTAINER)
	var bac: Node = bacs[0] if not bacs.is_empty() else get_parent()
	bac.add_child(trace)
	trace.global_position = sprite.global_position


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
	_peut_foncer = character.dash
	if _peut_foncer and _jauge == null:
		_jauge = DashGauge.new()
		add_child(_jauge)
	_pouvoir = character.power
	if _pouvoir == &"steadfast" and _jauge_parade == null:
		_jauge_parade = ParryGauge.new()
		add_child(_jauge_parade)
	if _pouvoir == &"blood_price" and _jauge_marque == null:
		_jauge_marque = MarkGauge.new()
		_jauge_marque.minimum = Characters.PRIX_MINIMUM
		add_child(_jauge_marque)
		# Le plafond ne bouge pas pendant une run : la Forge s'achète entre deux
		# parties. On le lit une fois plutôt qu'à chaque image.
		_marque_plafond = maxf(0.01,
			Characters.MARK_MAX + Forge.get_special_total(&"mark_max"))
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
## Soin externe (butin, fin de vague). Le plafonnement aux PV max et le cas
## « déjà mort » sont gérés par `Health` : rien à vérifier ici.
func heal(amount: float) -> void:
	health.heal(amount)


func apply_damage(amount: float, source: Node = null, impulse: Vector2 = Vector2.ZERO) -> void:
	var reduced := amount * (1.0 - RunState.stats.get_damage_reduction())
	if health.is_dead or health.is_invulnerable():
		return
	# LA PARADE ANNULE UN COUP, ET UN SEUL. Elle est testée ici, après les
	# i-frames — un coup qui n'allait pas passer n'a pas à la consommer — et
	# avant les dégâts, pour qu'elle n'en laisse rien.
	#
	# `source == null` EXCLUT LES ZONES ANNONCÉES. C'est structurel : une zone
	# qui détone ne passe pas d'auteur, un ennemi au contact, un projectile et un
	# rayon en passent un. Le placement reste donc le seul recours contre ce qui
	# est annoncé au sol, et c'est le cœur du jeu.
	#
	# UN COUP PARÉ NE DÉCLENCHE PAS LES 0,4 s D'I-FRAMES, puisqu'on sort avant
	# `take_damage`. Parer dans une mêlée laisse donc exposé plus tôt que
	# d'encaisser : la parade n'est pas gratuite, même réussie.
	if source != null and is_instance_valid(source) and is_parrying():
		_contrer(source)
		return
	if reduced >= health.current and RunState.consume_revive():
		# Seconde chance (Forge) : le coup fatal relève à mi-vie, hors d'atteinte
		# le temps de s'écarter. Une fois par run.
		health.revive(0.5, REVIVE_INVULNERABILITE)
		_knockback = (_knockback + impulse).limit_length(max_knockback)
		GameEvents.player_revived.emit(self)
		GameEvents.request_shake(hit_shake * 2.0)
		_montrer_seconde_chance()
		return
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


## Être sauvé ne doit pas ressembler à être touché.
##
## La seconde chance rejouait `_flash()` — le même éclair ROUGE que n'importe
## quel coup encaissé — avec une secousse deux fois plus forte, et rien d'autre.
## Le seul événement du jeu qui annule une mort se lisait donc comme un gros
## dégât, c'est-à-dire exactement comme son contraire.
##
## Trois signaux, tous distincts de ceux d'un coup : un éclair DORÉ sur le
## personnage, l'anneau de [ReviveBurst] qui décompte l'invulnérabilité, et le
## son des objets obtenus — celui de la banque qui dit « quelque chose vient de
## vous être donné », ce qui est littéralement le cas.
##
## L'effet est monté SUR LE JOUEUR et non sur le conteneur de projectiles : il
## doit le suivre pendant la seconde et demie où il s'extrait, et ce conteneur
## est vidé en fin de vague — une seconde chance consommée sur le dernier coup
## d'une vague perdrait son anneau au pire moment.
func _montrer_seconde_chance() -> void:
	var tween := create_tween()
	sprite.modulate = Color(2.2, 1.9, 0.9)
	tween.tween_property(sprite, ^"modulate", Color.WHITE, 0.45)
	var eclat := ReviveBurst.new()
	eclat.duree = REVIVE_INVULNERABILITE
	add_child(eclat)
	Audio.play(&"objet")


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
