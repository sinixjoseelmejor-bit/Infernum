class_name Pickup
extends Area2D
## Butin ramassable (âme ou clé).
##
## Le rayon d'attraction vient des stats du joueur : c'est le pickup qui va
## chercher le joueur, ce qui évite une seconde Area2D sur le joueur et rend le
## stat « rayon de ramassage » immédiatement lisible.
##
## AIMANT, PAS GRAVITÉ. La distinction n'est pas cosmétique, elle décide si le
## butin arrive ou non :
##
## - Un champ de gravité AJOUTE une accélération vers le joueur. La composante
##   latérale de la vitesse initiale (l'éjection) n'est jamais annulée : le butin
##   met en orbite, dépasse, ressort du rayon. Mesuré : 2 âmes sur 12 rataient le
##   joueur même IMMOBILE.
## - Un aimant réaligne la VITESSE vers le joueur. `move_toward` dans l'espace des
##   vitesses annule la dérive latérale en même temps qu'il pousse vers l'avant :
##   la trajectoire converge au lieu de tourner autour.
##
## ET UN AIMANT NE LÂCHE PAS. Le rayon décidait à chaque image, donc un joueur qui
## bouge (c'est-à-dire : toujours) sortait du rayon en une fraction de seconde et
## l'âme s'arrêtait net derrière lui, perdue. Mesuré : 9 âmes sur 12 abandonnées
## dès que le joueur se déplaçait. Le rayon ne sert donc plus qu'à ACCROCHER ; une
## fois accroché, le butin poursuit, et sa vitesse de poursuite monte jusqu'à
## dépasser celle du joueur — sinon il le suivrait sans jamais le rejoindre.
##
## Le rayon d'accroche a été mesuré, pas choisi : une âme tombe en moyenne à
## 209 px du joueur (là où l'ennemi meurt, donc jusqu'à la portée de l'arme). Avec
## un rayon de 95 px, la quasi-totalité du butin naissait hors d'atteinte et il
## fallait aller marcher dessus un par un — 75 % de ramassage sur 90 s de jeu.
## À 180 px : 89 %.

enum Kind { SOULS, KEYS, HEAL, ABYSS_KEY }

@export var kind: Kind = Kind.SOULS
@export var value: int = 1

@export_group("Attraction")
## Distance d'ACCROCHE. Au-delà, le butin attend ; en deçà, il est pris et suivra
## le joueur où qu'il aille.
@export var base_magnet_radius: float = 180.0
## Raideur de l'aimant : vitesse de réalignement du vecteur vitesse, et vitesse de
## montée en régime de la poursuite.
@export var magnet_acceleration: float = 2600.0
## Vitesse de poursuite à l'instant de l'accroche.
@export var min_magnet_speed: float = 240.0
## Vitesse de poursuite maximale. DOIT dépasser la vitesse maximale du joueur
## (235 de base, +60 % au plafond, soit ~380) ou le butin ne le rattrape jamais.
@export var max_magnet_speed: float = 900.0
## Ramassage direct sous cette distance. À 900 px/s le butin franchit 15 px par
## image : s'en remettre au seul recouvrement des formes, c'est accepter qu'il
## traverse le joueur entre deux images.
@export var capture_radius: float = 20.0
## Délai avant que le butin puisse être attiré (petit effet d'éjection).
@export var settle_time: float = 0.15
@export var spawn_impulse: float = 90.0

@export_group("Soin")
## Soin exprimé en COUPS ENCAISSABLES à la vague courante — voir la note du
## `WaveManager`. Un soin libellé en PV, ou même en fraction des PV max, ne suit
## pas les dégâts ennemis et perd toute valeur en fin de partie.
@export var heal_hits: float = 0.35
## Plancher, pour que le soin reste lisible dans les premières vagues.
@export var heal_minimum: float = 8.0

var _velocity: Vector2 = Vector2.ZERO
var _timer: float = 0.0
var _player: Node2D
var _latched: bool = false
var _chase_speed: float = 0.0
var _collected: bool = false


func _ready() -> void:
	add_to_group(Groups.PICKUPS)
	body_entered.connect(_on_body_entered)
	_player = get_tree().get_first_node_in_group(Groups.PLAYER)
	var angle := randf() * TAU
	_velocity = Vector2.RIGHT.rotated(angle) * spawn_impulse


func _physics_process(delta: float) -> void:
	_timer += delta

	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group(Groups.PLAYER)

	if not is_instance_valid(_player):
		_velocity = _velocity.move_toward(Vector2.ZERO, 600.0 * delta)
		global_position += _velocity * delta
		return

	var offset := _player.global_position - global_position
	var distance := offset.length()

	# L'accroche est testée DÈS l'apparition, éjection comprise. Sinon le joueur,
	# qui parcourt 35 px pendant le délai d'éjection, s'était déjà mis hors de
	# portée d'une âme tombée juste derrière lui : elle naissait perdue.
	if not _latched and distance <= get_magnet_radius():
		_latched = true
		_chase_speed = min_magnet_speed

	if _timer < settle_time or not _latched:
		_velocity = _velocity.move_toward(Vector2.ZERO, 600.0 * delta)
		global_position += _velocity * delta
		return

	if distance <= capture_radius:
		collect()
		return

	_chase_speed = minf(max_magnet_speed, _chase_speed + magnet_acceleration * delta)
	# Réaligner la VITESSE (et non lui ajouter une poussée) : la dérive latérale
	# est consommée par le même mouvement qui accélère vers le joueur.
	var desired := offset / distance * _chase_speed
	_velocity = _velocity.move_toward(desired, magnet_acceleration * delta)

	global_position += _velocity * delta


## ASPIRATION DE FIN DE VAGUE. L'accroche est forcée quelle que soit la distance,
## et la poursuite démarre déjà lancée : le rayon d'accroche n'a plus de sens ici,
## on ne cherche pas à récompenser la proximité mais à ne rien laisser au sol.
## Appelée à chaque image tant que la collecte dure — d'où les `maxf`, qui la
## rendent idempotente et n'annulent jamais l'élan déjà pris.
func rush(speed: float = 1400.0) -> void:
	if _collected:
		return
	_latched = true
	_timer = maxf(_timer, settle_time)
	max_magnet_speed = maxf(max_magnet_speed, speed)
	_chase_speed = maxf(_chase_speed, min_magnet_speed * 2.0)


## L'unité de soin vient du gestionnaire de vagues ; s'il est absent (banc,
## scène de test), on retombe sur une valeur de première vague.
func _hit_damage() -> float:
	for node in get_tree().get_nodes_in_group(Groups.WAVE_MANAGER):
		if node.has_method(&"get_hit_damage"):
			return node.call(&"get_hit_damage")
	return 11.0


func get_magnet_radius() -> float:
	return base_magnet_radius * (1.0 + RunState.stats.get_pickup_radius_pct())


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group(Groups.PLAYER):
		return
	collect()


func collect() -> void:
	# `body_entered` et la capture de proximité peuvent tomber sur la même image.
	if _collected:
		return
	_collected = true
	match kind:
		Kind.SOULS:
			var gain := maxi(1, roundi(value * (1.0 + RunState.stats.get_soul_gain_pct())))
			RunState.add_souls(gain)
			Audio.play(&"ame")
		Kind.KEYS:
			RunState.add_keys(value)
			Audio.play(&"cle")
		Kind.HEAL:
			var player := get_tree().get_first_node_in_group(Groups.PLAYER) as Player
			if player != null and not player.health.is_dead:
				player.health.heal(maxf(heal_minimum, heal_hits * _hit_damage()))
				Audio.play(&"soin")
		Kind.ABYSS_KEY:
			# Elle s'écrit dans le PROFIL et non dans la run : c'est la seule
			# chose que Lucifer laisse et qu'on garde après la mort.
			Audio.play(&"cle_abysses")
			if SaveGame.grant_abyss_key():
				GameEvents.announce.emit(tr("LA CLÉ DES ABYSSES"),
					tr("Armez le Déchaînement à la Forge, pour le personnage de votre"
					+ " choix : plus aucune limite, et un enfer qui répond."),
					Color(0.78, 0.45, 1.0))
			GameEvents.request_shake(6.0)
	set_physics_process(false)
	set_deferred(&"monitoring", false)
	queue_free()
