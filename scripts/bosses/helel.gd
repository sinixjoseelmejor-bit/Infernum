class_name BossHelel
extends BossLucifer
## HÉLEL — « Fils de l'Aurore ».
##
## Le nom d'avant la chute : Isaïe 14:12, *Hêlēl ben Šāḥar*, que la Vulgate
## traduit *lucifer*. Il ne se bat qu'au-delà du portail, une fois les trois
## sceaux brisés, et c'est Lucifer AVANT qu'il tombe : la même grammaire
## d'attaques, mais dans sa lumière d'origine, et une quatrième phase que
## Lucifer n'a plus — l'Aurore, où tout part en même temps.
##
## Pendant ce combat, les trois damnés se relaient dans un seul corps (voir
## `StoryDirector`) : le boss ne sait rien de ces changements, et n'a pas à
## le savoir. Il vise le joueur, quel qu'il soit.

## LA LUMIÈRE D'ORIGINE. Le sprite est celui de Lucifer, un chevalier noir : le
## teinter ne le rendait que plus terne, un `modulate` ne fait que multiplier
## des couleurs sombres. Le shader garde la luminance du pixel art — donc son
## modelé — et la repeint de l'or bruni à l'or blanc. C'est le même être, et il
## ne lui ressemble plus. Partagé avec les cinématiques.
const AURORE_SHADER := """
shader_type canvas_item;
uniform float eclat = 1.0;
// La modulation (flash des coups) est gardée à part : en fragment, COLOR
// contient déjà la texture sombre, et la remultiplier éteignait tout l'or.
varying vec4 modulation;
void vertex() {
	modulation = COLOR;
}
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float l = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	vec3 or_sombre = vec3(0.55, 0.36, 0.12);
	vec3 or_blanc = vec3(1.0, 0.96, 0.78);
	vec3 teinte = mix(or_sombre, or_blanc, smoothstep(0.0, 0.6, l));
	COLOR = vec4(teinte * eclat, c.a) * modulation;
}
"""
const AURORE := Color(1.0, 1.0, 1.0)


static func make_aurore_material() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = AURORE_SHADER
	material.shader = shader
	return material

@export_group("Hélel")
@export var dawn_interval: float = 1.3
@export var dawn_spiral_step: float = 17.0
## LE VERROU DE PHASE : durée minimale de chaque phase, en secondes de combat.
##
## Tant qu'elle n'est pas écoulée, Hélel ne descend pas sous le seuil de la phase
## suivante — et pas sous 1 PV dans la dernière. Les coups en trop sont absorbés
## par la lumière. Voir README, « Hélel face à une Forge complète ».
@export var min_phase_time: float = 14.0

@export_group("Voile de l'Aurore")
## LE VOILE DE L'AURORE : un bouclier qui compte les COUPS, pas les dégâts.
##
## Chaque tir retire exactement un point, quelle que soit sa force : pendant le
## voile, une build à 100 objets ne vaut que sa cadence, et l'écart entre les
## builds se resserre — la cadence varie bien moins que les dégâts, qui se
## multiplient entre eux. Il se marie avec les changements de corps : tomber sur
## Loth (5,2 tirs/s) pendant un voile est une chance, sur Caïn (2,9) une épreuve.
##
## C'est une ATTAQUE, pas un mur : s'il tient jusqu'au bout du compte à rebours,
## le Jugement de l'Aube s'abat. Brisé à temps, Hélel est sonné et vulnérable.
## Taille mesurée sur la cadence réelle : README, « Le Voile de l'Aurore ».
@export var shield_hits: int = 110
@export var shield_time: float = 6.0
## Un voile se lève à chaque nouvelle phase ; dans l'Aurore, il revient en plus
## à intervalle tiré au sort entre ces deux bornes.
@export var shield_interval_min: float = 22.0
@export var shield_interval_max: float = 30.0
@export var stun_time: float = 2.5
@export var vulnerable_multiplier: float = 1.3

const SHIELD_COLOR := Color(1.0, 0.9, 0.55)

var _spiral: float = 0.0
var _phase_started: float = 0.0
var _shield_left: int = 0
var _shield_total: int = 0
var _shield_timer: float = 0.0
var _next_shield: float = 0.0
var _stun: float = 0.0
var _shield_ring: ShieldRing
## Compteurs lus par les bancs : coups reçus, voiles brisés, jugements lâchés.
var hits_taken: int = 0
var shields_broken: int = 0
var judgments: int = 0


## Le voile dessiné autour d'Hélel : un anneau de segments, un par tranche du
## bouclier restant, et un arc intérieur qui se vide avec le compte à rebours.
## Lisible sans lire un chiffre : combien il reste à frapper, combien de temps.
class ShieldRing extends Node2D:
	var ratio: float = 1.0
	var time_ratio: float = 1.0
	const RADIUS := 92.0
	const SEGMENTS := 20

	func _draw() -> void:
		var lit := ceili(ratio * SEGMENTS)
		var step := TAU / SEGMENTS
		for i in SEGMENTS:
			var color := SHIELD_COLOR if i < lit else Color(1, 1, 1, 0.12)
			draw_arc(Vector2.ZERO, RADIUS, -PI / 2 + i * step + 0.04,
				-PI / 2 + (i + 1) * step - 0.04, 6, color, 6.0)
		draw_arc(Vector2.ZERO, RADIUS - 12.0, -PI / 2, -PI / 2 + TAU * time_ratio, 48,
			Color(1.0, 0.45, 0.25, 0.9), 3.0)


## Plancher de PV tant que la phase en cours n'a pas assez duré, -1 sinon.
##
## PAS DANS LE DÉCHAÎNEMENT : c'est un défi de classement où rien n'est
## replafonné côté joueur, et un plancher de durée en serait un. Hélel y suit la
## courbe de l'enfer, comme tout ce qui résiste au joueur.
func _phase_floor() -> float:
	if RunState.unleashed or fight_time - _phase_started >= min_phase_time:
		return -1.0
	if current_phase < phase_thresholds.size():
		# Juste au-dessus du seuil : à ce ratio-là la phase suivante se déclenche.
		return health.max_health * phase_thresholds[current_phase] + 1.0
	return 1.0


func apply_damage(amount: float, source: Node = null, impulse: Vector2 = Vector2.ZERO) -> void:
	hits_taken += 1
	if _shield_left > 0:
		_shield_left -= 1
		# Comme sous le verrou : frapper le voile compte pour la jauge de pression.
		_time_since_damage = 0.0
		_absorb_flash()
		if _shield_left <= 0:
			_break_shield()
		return
	if _stun > 0.0:
		amount *= vulnerable_multiplier
	var floor_hp := _phase_floor()
	if floor_hp >= 0.0:
		var allowed := maxf(0.0, health.current - floor_hp)
		if allowed <= 0.0:
			# La lumière encaisse : un éclat blanc au lieu du rouge des coups, pour
			# que le joueur voie que ses dégâts ne passent pas, et pourquoi.
			# Le coup COMPTE pour la jauge de pression : sinon celle-ci se croirait
			# ignorée et punirait justement le joueur qui tape sans relâche.
			_time_since_damage = 0.0
			_absorb_flash()
			return
		amount = minf(amount, allowed)
	super(amount, source, impulse)


func _absorb_flash() -> void:
	var tween := create_tween()
	sprite.modulate = Color(2.4, 2.4, 2.8)
	tween.tween_property(sprite, ^"modulate", AURORE, 0.15)


func _physics_process(delta: float) -> void:
	super(delta)
	_update_shield(delta)


func _update_shield(delta: float) -> void:
	_stun = maxf(0.0, _stun - delta)
	if _shield_left > 0:
		_shield_timer -= delta
		if is_instance_valid(_shield_ring):
			_shield_ring.ratio = float(_shield_left) / float(maxi(1, _shield_total))
			_shield_ring.time_ratio = clampf(_shield_timer / shield_time, 0.0, 1.0)
			_shield_ring.queue_redraw()
		if _shield_timer <= 0.0:
			_judgment()
		return
	_next_shield -= delta
	if _next_shield <= 0.0 and _stun <= 0.0:
		_raise_shield()


func _raise_shield() -> void:
	# Hors de l'Aurore, un seul voile par phase, à son ouverture. Mesuré : levé
	# toutes les 18 à 24 s dans toutes les phases, il coûtait 6 s de dégâts à
	# chaque fois à une build moyenne, qui ne le brise jamais, et Hélel tenait
	# encore debout après 200 s. L'Aurore, elle, doit être le pire moment.
	var aurore := current_phase >= phase_thresholds.size()
	_next_shield = _rng.randf_range(shield_interval_min, shield_interval_max) if aurore else INF
	if shield_hits <= 0:
		return
	_shield_total = shield_hits
	_shield_left = shield_hits
	_shield_timer = shield_time
	if not is_instance_valid(_shield_ring):
		_shield_ring = ShieldRing.new()
		add_child(_shield_ring)
	_shield_ring.visible = true
	GameEvents.request_shake(5.0)


## Brisé à temps : Hélel vacille, cesse d'attaquer, et encaisse davantage. C'est
## la récompense d'avoir tapé au lieu de fuir.
func _break_shield() -> void:
	shields_broken += 1
	_shield_left = 0
	_stun = stun_time
	_attack_timer = maxf(_attack_timer, stun_time)
	if is_instance_valid(_shield_ring):
		_shield_ring.visible = false
	GameEvents.request_shake(8.0)
	var tween := create_tween()
	sprite.modulate = Color(0.55, 0.5, 0.6)
	tween.tween_property(sprite, ^"modulate", AURORE, stun_time)


## LE JUGEMENT DE L'AUBE : le voile a tenu. Deux couronnes de zones annoncées
## s'embrasent autour d'Hélel, puis une salve en étoile. Tout s'esquive — c'est
## le placement qui sauve, jamais une parade (rien ne pare une zone annoncée).
func _judgment() -> void:
	judgments += 1
	_shield_left = 0
	if is_instance_valid(_shield_ring):
		_shield_ring.visible = false
	telegraph_ring(global_position, 12, 170.0, 72.0, 1.2, cross_damage * 1.4, SHIELD_COLOR)
	telegraph_ring(global_position, 20, 340.0, 72.0, 1.6, cross_damage * 1.4, SHIELD_COLOR)
	fire_ring(24, ring_speed * 1.2, ring_damage, _rng.randf() * TAU)
	GameEvents.request_shake(12.0)


func _update_movement(delta: float) -> void:
	if _stun > 0.0:
		velocity = velocity.move_toward(Vector2.ZERO, acceleration * 2.0 * delta)
		return
	super(delta)


func _on_phase_entered(phase: int) -> void:
	_phase_started = fight_time
	# Chaque nouvelle phase s'ouvre sous le voile : on n'y entre pas en force.
	# Le premier arrive après quelques secondes, le temps de voir le boss.
	_next_shield = 6.0 if phase == 0 else 0.0
	if not (sprite.material is ShaderMaterial):
		sprite.material = make_aurore_material()
	# La lumière monte d'une phase à l'autre, jusqu'à l'Aurore.
	(sprite.material as ShaderMaterial).set_shader_parameter(&"eclat", 1.0 + 0.2 * phase)
	sprite.modulate = AURORE
	match phase:
		1:
			move_speed *= 1.2
		2:
			move_speed *= 1.15
			engage_distance *= 0.85
		3:
			move_speed *= 1.1


func _run_phase(delta: float) -> void:
	if not is_instance_valid(target) or _stun > 0.0:
		return
	if current_phase < 3:
		# Les trois premières phases reprennent celles de Lucifer : c'est le même
		# être, et le joueur qui l'a battu doit s'y reconnaître.
		super(delta)
		return
	if _attack_timer <= 0.0 and not is_dashing():
		_attack_timer = dawn_interval
		_dive()
	_ring_timer = maxf(0.0, _ring_timer - delta)
	if _ring_timer <= 0.0:
		_ring_timer = 1.6
		# Trois bras de spirale qui tournent : il faut lire l'interstice ET
		# bouger avec lui, ce que les phases précédentes n'exigeaient pas.
		_spiral += deg_to_rad(dawn_spiral_step)
		fire_ring(3, cross_speed * 1.1, cross_damage, _spiral)
		fire_ring(ring_count, ring_speed, ring_damage, -_spiral)
