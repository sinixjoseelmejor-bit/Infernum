class_name BossBaal
extends Boss
## BAAL — « Le Seigneur de l'Orage ».
##
## Identité : divinité cananéenne de l'orage et de la fertilité, « le Seigneur »,
## dont le culte par le feu revient sans cesse dans la Bible hébraïque. Il ne
## court pas après le joueur : il tient ses distances et fait tomber la foudre.
## En phase 2 la pluie devient fournaise — il laisse derrière lui un sillage de
## braise qui ferme peu à peu les trajectoires.
##
## Anti-immobilisation — LE DÉLUGE : c'est le boss qui rend le kiting absurde par
## nature, puisque sa portée est l'arène entière. À saturation, la foudre tombe
## en couronne autour du joueur, et d'autant plus dense qu'il est loin. Rester au
## loin ne met à l'abri de rien ; il faut venir le faire taire.
##
## POURQUOI IL A ÉTÉ DURCI. Sa phase 1 posait UNE zone toutes les 1,5 seconde,
## annoncée 0,8 seconde à l'avance, large de 95 px. Le joueur se déplace à
## 288 px/s : il sortait du cercle en marchant, sans le regarder, et rien
## d'autre n'occupait l'espace. Le combat n'avait pas d'autre difficulté que sa
## longueur.
##
## Ce qui a changé est de la DENSITÉ et de la LECTURE, jamais du dégât par coup
## ni du préavis : la règle du jeu est qu'un boss ne touche pas sans préavis, et
## la durcir en raccourcissant la mèche l'aurait cassée.
##
##   - chaque frappe est un DOUBLET, une zone là où le joueur va, une là où il
##     est. Rester immobile est puni par la seconde, courir tout droit par la
##     première : il faut CHANGER de direction, pas seulement bouger ;
##   - une frappe sur trois devient une SACCADE de trois zones alignées sur son
##     axe de course, qui ferme la fuite en ligne droite ;
##   - un anneau de projectiles occupe enfin l'intervalle, que la phase 1
##     n'avait pas du tout ;
##   - en phase 2, deux anneaux contrarotatifs et une nuée de petites zones
##     autour du joueur ;
##   - le Déluge compte ses zones selon la distance, comme l'Aube de Lucifer.
##
## LA LIGNE D'ORAGE (0.10.1) remplace la nuée de la phase 2 : cinq petites zones
## tirées AU HASARD autour du joueur, qui tombaient parfois sur le doublet,
## parfois nulle part, et ne se lisaient pas — on ne pouvait que les subir. La
## ligne en pose six, en travers de l'axe Baal-joueur et centrée sur lui : un
## mur bref qu'on franchit en avançant vers Baal ou en reculant, jamais en
## glissant de côté. Même dégât, même préavis, et plus rare (toutes les 5 s
## au lieu de 2,6) : c'est la lecture qui change, pas la menace.

@export_group("Baal")
@export var keep_distance: float = 380.0
@export var bolt_radius: float = 95.0
## Fenêtre d'esquive. Le joueur couvre 288 px/s : à 0,62 s il parcourt 180 px
## pour un rayon de 95, donc sortir reste toujours possible — mais il faut s'en
## occuper, ce qui n'était pas le cas à 0,8 s.
@export var bolt_delay: float = 0.62
@export var bolt_damage: float = 17.0
## 1,2 s jusqu'à la 0.10.1. Baal orbite maintenant VRAIMENT à sa distance (voir
## `Boss._update_movement`) au lieu de dériver vers le joueur, et le joueur qui
## le poursuit court plus droit : les zones anticipées le touchaient 0,08 fois
## de plus par seconde. Le rythme rend le niveau d'avant.
@export var storm_interval: float = 1.3
## Une frappe sur trois est une saccade alignée sur la course du joueur.
@export var volley_period: int = 3
@export var volley_count: int = 3
@export var volley_spacing: float = 155.0
## 0,95 s jusqu'à la 0.10.1, pour la même raison que `storm_interval` : avec la
## vraie orbite, la phase 2 passait de 0,72 à 0,88 coup/s à 380 px. À 1,15 s
## elle revient à 0,73 (banc, huit répétitions à 260, 380 et 520 px).
@export var furnace_interval: float = 1.15
@export var ember_interval: float = 0.45
@export var ember_radius: float = 58.0
@export var ember_delay: float = 1.1
@export var ember_damage: float = 9.0
@export var ring_interval: float = 3.0
@export var ring_count: int = 10
@export var ring_speed: float = 265.0
@export var ring_damage: float = 12.0
## Anneau de la phase 1, qui n'en avait aucun : l'intervalle entre deux frappes
## était vide, et c'est là que le combat se lisait tout seul.
@export var storm_ring_interval: float = 4.5
@export var storm_ring_count: int = 8
## Ligne d'orage, en phase 2 : six zones jointives en travers du joueur.
## 2,6 s pour l'ancienne nuée. La ligne, posée en travers de la course d'un
## joueur qui tourne autour de Baal, le touche plus souvent qu'une nuée tirée
## au hasard : au même rythme, elle ajoutait 0,13 coup/s en phase 2 (banc, dix
## répétitions). Plus rare, elle rend le niveau d'avant.
@export var swarm_interval: float = 5.0
@export var swarm_count: int = 6
@export var swarm_radius: float = 52.0
## Pas entre deux zones de la ligne : sous le diamètre, pour qu'elle n'ait pas
## de trou.
@export var swarm_spacing: float = 95.0

const LIGHTNING := Color(0.55, 0.8, 1.0)
const FIRE := Color(1.0, 0.5, 0.15)

## L'ÉCLAIR (0.10.1) : ses zones de foudre — salves, essaim, frappe ciblée —
## jouent une vraie foudre qui tombe du ciel, ses braises gardent la flamme
## courte de la scène. Avant, les deux jouaient la même flamme.
const IMPACT_FOUDRE := preload("res://scenes/vfx/impact_foudre.tscn")
## Largeur de l'impact au sol sur la planche (240 px sur une image de 256) :
## c'est elle qui se cale sur le diamètre de la zone.
const LARGEUR_FOUDRE := 240.0

var _ember_timer: float = 0.0
var _ring_timer: float = 0.0
var _storm_ring_timer: float = 0.0
var _swarm_timer: float = 0.0
var _clockwise: bool = true


func _ready() -> void:
	couleur_titre = LIGHTNING
	super()


## Toutes ses zones passent par ici : la couleur dit si c'est de la foudre.
func telegraph_at(point: Vector2, radius: float, delay: float, damage: float,
		color: Color = Color(1.0, 0.35, 0.2)) -> void:
	if color != LIGHTNING:
		super(point, radius, delay, damage, color)
		return
	var impact := telegraph_impact
	var largeur := telegraph_impact_width
	telegraph_impact = IMPACT_FOUDRE
	telegraph_impact_width = LARGEUR_FOUDRE
	super(point, radius, delay, damage, color)
	telegraph_impact = impact
	telegraph_impact_width = largeur


func _on_phase_entered(phase: int) -> void:
	match phase:
		0:
			teinter_phase(Color.WHITE)
		1:
			teinter_phase(Color(1.3, 0.8, 0.55))
			move_speed *= 1.2
			keep_distance *= 0.85


func _run_phase(delta: float) -> void:
	if not is_instance_valid(target):
		return
	strafe_around(keep_distance, move_speed, delta, _clockwise)

	match current_phase:
		0:
			if _attack_timer <= 0.0:
				_attack_timer = storm_interval
				_attack_step += 1
				if _attack_step % volley_period == 0:
					_saccade()
				else:
					_doublet()
				if _attack_step % 4 == 0:
					_clockwise = not _clockwise

			# L'intervalle entre deux frappes n'était occupé par rien.
			_storm_ring_timer = maxf(0.0, _storm_ring_timer - delta)
			if _storm_ring_timer <= 0.0:
				_storm_ring_timer = storm_ring_interval
				geste(&"attaque2", 0.5)
				fire_ring(storm_ring_count, ring_speed * 0.9, ring_damage, randf() * TAU)
		1:
			if _attack_timer <= 0.0:
				_attack_timer = furnace_interval
				_attack_step += 1
				if _attack_step % volley_period == 0:
					_saccade()
				else:
					_doublet()

			# Sillage de braise : ferme progressivement les lignes de fuite.
			_ember_timer = maxf(0.0, _ember_timer - delta)
			if _ember_timer <= 0.0:
				_ember_timer = ember_interval
				telegraph_at(global_position, ember_radius, ember_delay, ember_damage, FIRE)

			_ring_timer = maxf(0.0, _ring_timer - delta)
			if _ring_timer <= 0.0:
				_ring_timer = ring_interval
				# Deux anneaux contrarotatifs : il faut lire les interstices, et
				# non attendre qu'un anneau passe.
				var angle := randf() * TAU
				geste(&"attaque2", 0.5)
				fire_ring(ring_count, ring_speed, ring_damage, angle)
				fire_ring(ring_count, ring_speed * 0.72, ring_damage, -angle)

			_swarm_timer = maxf(0.0, _swarm_timer - delta)
			if _swarm_timer <= 0.0:
				_swarm_timer = swarm_interval
				_ligne_d_orage()


## Une zone là où le joueur VA, une là où il EST.
##
## Une seule zone anticipée récompensait paradoxalement l'immobilité : sans
## vitesse, la prédiction retombe sur la position courante, et le joueur n'avait
## qu'à faire un pas au dernier moment. Avec le doublet, faire un pas rentre
## dans l'autre zone — il faut changer de direction.
func _doublet() -> void:
	geste(&"attaque1", bolt_delay)
	_strike(predicted_target_position(bolt_delay * 0.9))
	if not is_instance_valid(target):
		return
	_strike(target.global_position)


## SACCADE : trois zones alignées sur l'axe de course, devant le joueur. C'est
## ce qui interdit la fuite en ligne droite, la seule esquive que l'ancienne
## version demandait.
func _saccade() -> void:
	if not is_instance_valid(target):
		return
	var axe := Vector2.ZERO
	if target is CharacterBody2D:
		axe = (target as CharacterBody2D).velocity
	# Immobile, il n'y a pas d'axe de course : la saccade part vers le boss,
	# ce qui ferme la retraite au lieu de tomber trois fois au même endroit.
	if axe.length() < 30.0:
		axe = global_position - target.global_position
	var direction := axe.normalized()
	geste(&"attaque1", bolt_delay + 0.14 * float(volley_count - 1))
	for i in volley_count:
		telegraph_at(target.global_position + direction * volley_spacing * float(i),
			bolt_radius * 0.9, bolt_delay + 0.14 * float(i), bolt_damage, LIGHTNING)


## LIGNE D'ORAGE : un mur bref de petites zones en travers du joueur.
func _ligne_d_orage() -> void:
	if not is_instance_valid(target):
		return
	var axe := (target.global_position - global_position).normalized()
	if axe == Vector2.ZERO:
		axe = Vector2.RIGHT
	var travers := axe.orthogonal()
	var milieu := float(swarm_count - 1) * 0.5
	for i in swarm_count:
		telegraph_at(target.global_position + travers * swarm_spacing * (float(i) - milieu),
			swarm_radius, bolt_delay + 0.3, ember_damage, FIRE)


func _strike(at: Vector2) -> void:
	telegraph_at(at, bolt_radius, bolt_delay, bolt_damage, LIGHTNING)


## LE DÉLUGE : la foudre tombe en couronne, là où le joueur se croyait tranquille.
##
## Le nombre de zones suit la DISTANCE, comme l'Aube brûlante de Lucifer : la
## couronne était de huit zones quelle que soit la distance, donc elle
## s'espaçait à mesure que le joueur reculait — la sanction anti-kite
## s'affaiblissait précisément quand on kitait le plus.
func _release_pressure() -> void:
	if not is_instance_valid(target):
		return
	var distance := global_position.distance_to(target.global_position)
	var zones := clampi(roundi(distance / 48.0), 8, 16)
	geste(&"attaque2", 0.95)
	telegraph_ring(target.global_position, zones, 150.0, 80.0, 0.95,
		bolt_damage * 0.85, LIGHTNING)
	# Le centre tombe APRÈS la couronne : se réfugier au milieu marche une fois,
	# et une seule.
	telegraph_at(target.global_position, 105.0, 1.35, bolt_damage, LIGHTNING)
	GameEvents.request_shake(7.0)
