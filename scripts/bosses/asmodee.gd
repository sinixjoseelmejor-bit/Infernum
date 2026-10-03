class_name BossAsmodee
extends Boss
## ASMODÉE — « Les Trois Têtes ».
##
## Identité : roi des démons du Livre de Tobie, représenté avec trois têtes —
## taureau, homme, bélier. Chaque tête a son attaque : le TAUREAU charge, l'HOMME
## tire, le BÉLIER envoie une onde circulaire. En phase 1 deux têtes alternent ;
## en phase 2 les trois s'enchaînent sans répit.
##
## Anti-immobilisation — LA CHAÎNE DE SALOMON : la légende veut que Salomon ait
## enchaîné Asmodée pour bâtir le Temple. Il retourne la chaîne contre le joueur :
## à saturation, un lien se referme et le TIRE vers lui, avant une charge. C'est
## la sanction anti-kite la plus littérale du jeu — la distance est révoquée.
##
## CE QUI A CHANGÉ EN 0.10.1, et pourquoi :
##
##   - CHAQUE TÊTE S'ANNONCE. L'homme et le bélier tiraient sans prévenir, et le
##     bélier, au contact — là où la pression pousse le joueur —, n'était pas
##     esquivable : quatorze projectiles nés à 42 px du corps. Chaque tête a
##     maintenant son geste, sa couleur et un temps d'armement pendant lequel
##     il se fige. Le rythme ne change pas : l'armement est pris DANS
##     l'intervalle entre deux têtes.
##   - L'HOMME TIRE DEUX FOIS. La première phase ne touchait presque jamais un
##     joueur qui tournait autour de lui (0,02 coup/s au banc, le plus bas des
##     cinq) : une salve de cinq traits toutes les 4,4 s, visée là où le joueur
##     ÉTAIT — à 260 px, il avait fait 190 px de plus quand elle arrivait. Il
##     en tire deux : la première là où il est, la seconde là où il VA. Le
##     principe du doublet de Baal : rester immobile est puni par l'une,
##     tourner en rond par l'autre ; il faut changer de direction.
##   - LA CHAÎNE S'ANNONCE, ET NE BLESSE PLUS. Elle frappait le joueur au moment
##     où elle le saisissait : dix points de dégâts sans préavis, la seule
##     exception du jeu à la règle des boss. Un trait de visée la précède, la
##     traction ne blesse plus, et la charge qu'elle promettait arrive vraiment.
##   - SA CHARGE TOMBE SUR SA ZONE (voir `Boss.ruee_annoncee`).

enum Head { BULL, MAN, RAM }

@export_group("Asmodée")
@export var charge_speed: float = 700.0
## Délai entre la zone rouge et l'impact. 0,45 s jusqu'à la 0.10.1 : impossible
## à esquiver, le même défaut que le plongeon de Lucifer — sortir d'une zone de
## 110 px depuis son centre demande 0,51 s de marche à 215 px/s, sans compter
## le temps de réaction.
@export var charge_windup: float = 0.9
## Anticipation de la zone, gardée à l'ancien délai : à 0,9 s, elle aurait visé
## deux fois plus loin devant le joueur.
@export var charge_prediction: float = 0.45
@export var bolt_speed: float = 330.0
@export var bolt_damage: float = 14.0
@export var wave_count: int = 14
@export var wave_speed: float = 240.0
@export var wave_damage: float = 12.0
@export var cycle_interval: float = 2.2
@export var frenzy_interval: float = 1.35
## Armement de l'homme et du bélier : il se fige, la tête s'allume, puis il tire.
@export var head_windup: float = 0.45
## Écart entre les deux salves de l'homme.
@export var man_second_volley: float = 0.3

@export_group("Chaîne de Salomon")
@export var chain_pull_speed: float = 900.0
## Distance en deçà de laquelle la chaîne ne tire plus : le joueur est ramené
## à portée de mêlée, jamais collé dans le corps du boss.
@export var chain_min_gap: float = 170.0
## Le trait de visée qui précède la chaîne.
@export var chain_aim: float = 0.6
@export var chain_landing_radius: float = 120.0

## La couleur de chaque tête, posée sur le corps pendant l'armement : rouge du
## taureau, or de l'homme, blanc du bélier.
const TEINTES_TETES := [Color(1.9, 0.6, 0.5), Color(1.8, 1.5, 0.6), Color(1.7, 1.7, 1.9)]
const GESTES_TETES: Array[StringName] = [&"attaque1", &"attaque2", &"attaque3"]

var _head: Head = Head.BULL
var _winding_up: bool = false
## La chaîne promet une charge : la prochaine tête sera le taureau.
var _taureau_promis: bool = false


func _on_phase_entered(phase: int) -> void:
	match phase:
		0:
			teinter_phase(Color.WHITE)
		1:
			# La troisième tête se réveille.
			teinter_phase(Color(1.3, 0.7, 0.7))
			move_speed *= 1.2


func _run_phase(_delta: float) -> void:
	if not is_instance_valid(target) or is_dashing() or _winding_up:
		return
	if _attack_timer > 0.0:
		return
	_attack_timer = frenzy_interval if current_phase >= 1 else cycle_interval
	_next_head()
	match _head:
		Head.BULL:
			_bull_charge()
		Head.MAN:
			_armer(Head.MAN)
		Head.RAM:
			_armer(Head.RAM)


## En phase 1, la tête de bélier dort : seules le taureau et l'homme tournent.
func _next_head() -> void:
	if _taureau_promis:
		_taureau_promis = false
		_head = Head.BULL
		return
	_attack_step += 1
	var heads := 3 if current_phase >= 1 else 2
	_head = (_attack_step % heads) as Head


func _vivant() -> bool:
	return is_instance_valid(self) and not health.is_dead and is_instance_valid(target)


## La tête s'allume, il se fige, puis elle frappe.
func _allumer(tete: Head, duree: float) -> void:
	geste(GESTES_TETES[tete], duree)
	eclairer(TEINTES_TETES[tete], duree)


func _armer(tete: Head) -> void:
	_winding_up = true
	_allumer(tete, head_windup + 0.2)
	await get_tree().create_timer(head_windup, false, true).timeout
	if not _vivant():
		return
	_winding_up = false
	match tete:
		Head.MAN:
			fire_at_target(5, 34.0, bolt_speed, bolt_damage)
			await get_tree().create_timer(man_second_volley, false, true).timeout
			if _vivant():
				var vol := global_position.distance_to(target.global_position) / bolt_speed
				var visee := predicted_target_position(vol) - global_position
				# Trois traits sur un arc étroit, et non cinq : la seconde salve
				# ferme une direction, elle ne fait pas un mur. À cinq, un joueur
				# qui esquive prenait 0,32 coup/s en première phase (banc),
				# plus que face à Baal.
				fire_spread(visee.normalized(), 3, 20.0, bolt_speed, bolt_damage)
		Head.RAM:
			fire_ring(wave_count, wave_speed, wave_damage, randf() * TAU)


func _bull_charge() -> void:
	if not is_instance_valid(target):
		return
	var destination := predicted_target_position(charge_prediction)
	Audio.play(&"meuglement")
	_allumer(Head.BULL, charge_windup)
	# La charge est annoncée : le couloir d'arrivée est visible avant l'impact.
	telegraph_at(destination, 110.0, charge_windup, bolt_damage, Color(1.0, 0.45, 0.3))
	_winding_up = true
	await ruee_annoncee(destination, charge_windup, charge_speed)
	if not is_instance_valid(self):
		return
	_winding_up = false


func _update_movement(delta: float) -> void:
	# Il se fige pendant l'armement : c'est la fenêtre du joueur.
	if _winding_up:
		velocity = velocity.move_toward(Vector2.ZERO, acceleration * 2.0 * delta)
		return
	super(delta)


## LA CHAÎNE DE SALOMON : un trait de visée, puis le joueur est ramené de force,
## et le taureau charge.
func _release_pressure() -> void:
	if not is_instance_valid(target):
		return
	_chaine()


func _chaine() -> void:
	var visee := ChainAim.new()
	visee.ancre = self
	visee.proie = target
	visee.duree = chain_aim
	_projectile_parent().add_child(visee)
	await get_tree().create_timer(chain_aim, false, true).timeout
	if not _vivant():
		return
	_jeter_la_chaine()
	var offset := global_position - target.global_position
	if offset.length() > chain_min_gap and target.has_method(&"apply_impulse"):
		var strength := minf(chain_pull_speed, (offset.length() - chain_min_gap) * 3.0)
		target.call(&"apply_impulse", offset.normalized() * strength)
	GameEvents.request_shake(8.0)
	_taureau_promis = true
	_attack_timer = maxf(_attack_timer, 0.8)
	# LE SOL OÙ IL RETOMBE. La zone était posée autour d'Asmodée, sur 150 px —
	# mais la chaîne ramène le joueur à 170 px au plus près : elle ne pouvait
	# toucher personne, et toute la sanction tenait dans les dégâts de la
	# chaîne, sans préavis. Elle s'ouvre maintenant là où le joueur atterrit,
	# une fois la traction amortie, avec le préavis de toutes les zones.
	await get_tree().create_timer(0.2, false, true).timeout
	if _vivant():
		telegraph_at(target.global_position, chain_landing_radius, 0.75, bolt_damage,
			Color(0.95, 0.75, 0.3))


## Le dessin de la chaîne, et rien d'autre : la traction est au-dessus. Le lien
## ne faisait l'objet d'AUCUNE image — le joueur se voyait aspiré vers Asmodée
## sans que rien n'explique pourquoi.
##
## Elle est montée sur le conteneur de projectiles et non sur le boss : montée
## sur lui, elle mourrait avec lui, et un boss tué pendant sa propre traction
## laisserait le joueur glisser au bout d'une chaîne effacée.
func _jeter_la_chaine() -> void:
	Audio.play(&"chaine")
	var lien := ChainLash.new()
	lien.ancre = self
	lien.proie = target
	lien.depuis = global_position
	lien.vers = target.global_position
	_projectile_parent().add_child(lien)


## LE TRAIT DE VISÉE : un pointillé qui suit le joueur et se resserre avant que
## la chaîne parte. Sans effet de jeu.
class ChainAim extends Node2D:
	var ancre: Node2D
	var proie: Node2D
	var duree: float = 0.6
	var _t: float = 0.0

	func _ready() -> void:
		z_index = 20

	func _process(delta: float) -> void:
		_t += delta
		if _t >= duree or not is_instance_valid(ancre) or not is_instance_valid(proie):
			queue_free()
			return
		global_position = ancre.global_position
		queue_redraw()

	func _draw() -> void:
		var vers := proie.global_position - global_position
		var longueur := vers.length()
		if longueur < 1.0:
			return
		var u := _t / duree
		var direction := vers / longueur
		# Les tirets défilent vers le joueur et se resserrent : la chaîne arrive.
		var pas := lerpf(46.0, 22.0, u)
		var debut := fmod(_t * 260.0, pas)
		var couleur := Color(0.95, 0.75, 0.3, 0.35 + 0.5 * u)
		var d := debut
		while d < longueur:
			draw_line(direction * d, direction * minf(longueur, d + pas * 0.5), couleur, 3.0, true)
			d += pas
		draw_arc(vers, lerpf(34.0, 18.0, u), 0.0, TAU, 24, couleur, 2.0, true)
