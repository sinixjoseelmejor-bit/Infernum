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

enum Head { BULL, MAN, RAM }

@export_group("Asmodée")
@export var charge_speed: float = 700.0
@export var charge_duration: float = 0.42
@export var charge_windup: float = 0.45
@export var bolt_speed: float = 330.0
@export var bolt_damage: float = 14.0
@export var wave_count: int = 14
@export var wave_speed: float = 240.0
@export var wave_damage: float = 12.0
@export var cycle_interval: float = 2.2
@export var frenzy_interval: float = 1.35

@export_group("Chaîne de Salomon")
@export var chain_pull_speed: float = 900.0
@export var chain_damage: float = 10.0
## Distance en deçà de laquelle la chaîne ne tire plus : le joueur est ramené
## à portée de mêlée, jamais collé dans le corps du boss.
@export var chain_min_gap: float = 170.0

var _head: Head = Head.BULL
var _winding_up: bool = false


func _on_phase_entered(phase: int) -> void:
	match phase:
		0:
			sprite.modulate = Color.WHITE
		1:
			# La troisième tête se réveille.
			sprite.modulate = Color(1.3, 0.7, 0.7)
			move_speed *= 1.2


func _run_phase(_delta: float) -> void:
	if not is_instance_valid(target) or is_dashing():
		return
	if _attack_timer > 0.0:
		return
	_attack_timer = frenzy_interval if current_phase >= 1 else cycle_interval
	_next_head()
	match _head:
		Head.BULL:
			_bull_charge()
		Head.MAN:
			fire_at_target(5, 34.0, bolt_speed, bolt_damage)
		Head.RAM:
			fire_ring(wave_count, wave_speed, wave_damage, randf() * TAU)


## En phase 1, la tête de bélier dort : seules le taureau et l'homme tournent.
func _next_head() -> void:
	_attack_step += 1
	var heads := 3 if current_phase >= 1 else 2
	_head = (_attack_step % heads) as Head


func _bull_charge() -> void:
	if not is_instance_valid(target):
		return
	var destination := predicted_target_position(charge_windup)
	# La charge est annoncée : le couloir d'arrivée est visible avant l'impact.
	telegraph_at(destination, 110.0, charge_windup, bolt_damage, Color(1.0, 0.45, 0.3))
	_winding_up = true
	var tree := get_tree()
	if tree == null:
		return
	await tree.create_timer(charge_windup).timeout
	if not is_instance_valid(self) or health.is_dead:
		return
	_winding_up = false
	dash_toward(destination, charge_speed, charge_duration)


func _update_movement(delta: float) -> void:
	# Il se fige pendant l'armement de la charge : c'est la fenêtre du joueur.
	if _winding_up:
		velocity = velocity.move_toward(Vector2.ZERO, acceleration * 2.0 * delta)
		return
	super(delta)


## LA CHAÎNE DE SALOMON : le joueur est ramené de force, puis chargé.
func _release_pressure() -> void:
	if not is_instance_valid(target):
		return
	_jeter_la_chaine()
	var offset := global_position - target.global_position
	if offset.length() > chain_min_gap and target.has_method(&"apply_impulse"):
		var strength := minf(chain_pull_speed, (offset.length() - chain_min_gap) * 3.0)
		target.call(&"apply_impulse", offset.normalized() * strength)
	if target.has_method(&"apply_damage"):
		target.call(&"apply_damage", _outgoing_damage(chain_damage), self, Vector2.ZERO)
	telegraph_at(global_position, 150.0, 0.7, bolt_damage, Color(0.95, 0.75, 0.3))
	GameEvents.request_shake(8.0)
	_attack_timer = 0.8


## Le dessin de la chaîne, et rien d'autre : la traction et les dégâts sont
## au-dessus. Le lien ne faisait l'objet d'AUCUNE image — le joueur se voyait
## aspiré vers Asmodée sans que rien n'explique pourquoi.
##
## Elle est montée sur le conteneur de projectiles et non sur le boss : montée
## sur lui, elle mourrait avec lui, et un boss tué pendant sa propre traction
## laisserait le joueur glisser au bout d'une chaîne effacée.
func _jeter_la_chaine() -> void:
	var lien := ChainLash.new()
	lien.ancre = self
	lien.proie = target
	lien.depuis = global_position
	lien.vers = target.global_position
	_projectile_parent().add_child(lien)
