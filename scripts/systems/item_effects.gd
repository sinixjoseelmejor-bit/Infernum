class_name ItemEffects
extends Node
## Effets d'objets qui ne se réduisent pas à un modificateur de statistique.
##
## Chaque effet est explicitement borné. Les deux pièges classiques du genre
## sont neutralisés ici :
##   - l'explosion à la mort ne s'enchaîne pas (pas de réaction en chaîne qui
##     nettoie l'écran depuis un seul kill) ;
##   - le vol de vie est plafonné en soin par seconde, sinon cadence élevée
##     + multishot rendent le joueur intuable.

const EXPLOSION_VFX := preload("res://scenes/vfx/explosion.tscn")
## Largeur utile de la planche d'explosion, en pixels — mesurée sur l'IMAGE DE
## POINTE, pas sur le nom du fichier ni sur l'union des images.
##
## La cellule fait 120 px, l'union des 29 images 111, et l'image de pointe 82.
## Prise sur l'union, l'échelle comptait les étoiles projetées au loin à l'image
## 9 et rapetissait l'explosion pendant tout le reste de l'animation : mesuré en
## jeu, 278 px dessinés pour une zone de 400. C'est exactement l'erreur corrigée
## sur les impacts de boss en 0.8.1, restée ici parce que ce correctif-là n'avait
## touché que la planche des boss.
const EXPLOSION_VFX_CONTENT := 82.0

const IMPACT_FEU := preload("res://scenes/vfx/impact_flamme.tscn")

@export var explosion_radius: float = 135.0
@export var explosion_damage_ratio: float = 0.70
@export var thorns_ratio: float = 0.30

# --- Les objets à effets de la 0.9.2 -----------------------------------------
# Chiffres réunis ici plutôt que dans le catalogue : ce sont des règles de jeu,
# pas des modificateurs de statistique, et le catalogue ne sait pas les lire.

## Soufre : part des dégâts du coup ajoutée à la réserve de brûlure.
const SOUFRE_PART := 0.40
## Clou du Golgotha : part des dégâts d'un CRITIQUE mise en brûlure.
const CLOU_PART := 1.0
## Chaînes du Tartare (et Clou) : vitesse retirée, et pour combien de temps.
const ENTRAVE_PART := 0.40
const ENTRAVE_DUREE := 2.0
## Fronde de David : sur une cible encore intacte.
const FRONDE_BONUS := 1.60
## Sel de Sodome : sur une cible en feu ou entravée.
const SEL_BONUS := 1.35
## Feu grégeois. Deux propagations au plus : sans borne, une mêlée serrée
## brûlerait de proche en proche jusqu'au bord de l'écran à partir d'un seul
## corps — la réaction en chaîne que la Braise éternelle s'interdit déjà.
const FEU_RAYON := 150.0
const FEU_VOISINS := 3
const FEU_GENERATIONS := 2
## Ce qui passe au voisin : 80 % de la réserve du mort, et au moins la moitié
## des dégâts d'un tir — sans plancher, un corps tué juste après avoir pris feu
## ne transmettait presque rien.
const FEU_PART := 0.80
const FEU_PLANCHER := 0.40
## Mâchoire de Samson : sous ce seuil de PV, ces bonus.
const SAMSON_SEUIL := 0.5
const SAMSON_MODS := {&"damage_pct": 0.30, &"fire_rate_pct": 0.15}
## Trente deniers : part des âmes gardées versée à chaque fin de vague. Bornée
## hors Déchaînement — sans borne, garder 1 000 âmes en rapportait 100 par vague
## et la bonne stratégie devenait de ne plus rien acheter.
const INTERETS_TAUX := 0.10
const INTERETS_MAX := 40
## Trompette de Jéricho.
const TROMPETTE_PERIODE := 6.0
const TROMPETTE_RAYON := 230.0
const TROMPETTE_RATIO := 2.0
const TROMPETTE_RECUL := 700.0
## Bâton de Moïse. La recharge propre empêche la ruée de Loth, qui revient
## vite, d'en faire une onde permanente.
const MOISE_RAYON := 220.0
const MOISE_RATIO := 1.5
const MOISE_RECUL := 900.0
const MOISE_RECHARGE := 1.5

var _player: Player
var _explosion_active: bool = false
var _lifesteal_budget: float = 0.0
var _regen_carry: float = 0.0
var _trompette: float = TROMPETTE_PERIODE
var _moise: float = 0.0
var _encensoir: Encensoir = null


func _ready() -> void:
	GameEvents.player_spawned.connect(_on_player_spawned)
	GameEvents.enemy_died.connect(_on_enemy_died)
	GameEvents.player_damage_dealt.connect(_on_player_damage_dealt)
	GameEvents.player_contact_hit.connect(_on_player_contact_hit)
	GameEvents.player_health_changed.connect(_on_player_health_changed)
	GameEvents.wave_cleared.connect(_on_wave_cleared)
	GameEvents.pouvoir_utilise.connect(_on_pouvoir_utilise)
	RunState.stats_recomputed.connect(_on_stats_recomputed)
	_player = get_tree().get_first_node_in_group(Groups.PLAYER) as Player
	_on_stats_recomputed(RunState.stats)


func _process(delta: float) -> void:
	if not is_instance_valid(_player) or _player.health.is_dead:
		return

	# Le budget de vol de vie se recharge dans le temps : les pics de dégâts ne
	# se convertissent pas intégralement en soin.
	# DÉCHAÎNEMENT : le budget de soin saute lui aussi. C'est la borne qui
	# empêchait réellement l'invulnérabilité — la laisser en place aurait vidé le
	# mode de sa promesse défensive, alors que la réduction d'armure reste, elle,
	# bornée à 90 % pour qu'une run puisse encore se terminer.
	var cap := _player.health.max_health * PlayerStats.LIFESTEAL_HEAL_CAP_PER_SEC
	if RunState.unleashed:
		cap = _player.health.max_health
	_lifesteal_budget = minf(_lifesteal_budget + cap * delta, cap)

	var regen := RunState.stats.regen
	if regen > 0.0:
		_regen_carry += regen * delta
		if _regen_carry >= 1.0:
			var whole := floorf(_regen_carry)
			_regen_carry -= whole
			_player.health.heal(whole)

	_moise = maxf(0.0, _moise - delta)
	if RunState.has_special(&"trompette"):
		_trompette = maxf(0.0, _trompette - delta)
		if _trompette <= 0.0 and _ennemi_a_portee(TROMPETTE_RAYON):
			_trompette = TROMPETTE_PERIODE
			_sonner_trompette()
	if _encensoir != null:
		_encensoir.global_position = _player.global_position
		_encensoir.degats = _get_reference_weapon_damage() * Encensoir.RATIO


func _on_player_spawned(player: Node2D) -> void:
	_player = player as Player
	_on_stats_recomputed(RunState.stats)


func _on_player_damage_dealt(amount: float, target: Node2D) -> void:
	_achever(target)
	var ratio := RunState.stats.get_lifesteal()
	if ratio <= 0.0 or not is_instance_valid(_player):
		return
	var heal := minf(amount * ratio, _lifesteal_budget)
	if heal <= 0.0:
		return
	_lifesteal_budget -= heal
	_player.health.heal(heal)


## « Errant » (branche de Caïn) : ce qui est presque mort l'est tout à fait.
##
## L'intérêt n'est pas le gain de dégâts, il est négligeable — c'est le RYTHME.
## La Marque monte par élimination : achever raccourcit chaque fin de cible et
## fait monter la Marque plus vite, qui raccourcit la suivante. C'est la boucle
## d'emballement de Caïn, et sa réponse à l'économie : plus d'éliminations, donc
## plus d'âmes.
##
## LES BOSS SONT EXCLUS. Ils sont les contrôles de build du jeu, et chacun a ses
## phases écrites pour une durée : effacer les 12 % derniers pourcents de
## Lucifer, c'est supprimer la phase pour laquelle il a été dessiné.
func _achever(cible: Node2D) -> void:
	# Les tests se suivent du moins cher au plus cher : cette fonction passe a
	# CHAQUE projectile qui touche, et un build rapide en lance six cents par
	# seconde. Le parcours des noeuds de Forge vient donc en dernier.
	if cible == null or not is_instance_valid(cible):
		return
	if cible.is_in_group(Groups.BOSSES) or not cible.is_in_group(Groups.ENEMIES):
		return
	var vie := cible.get(&"health") as Health
	if vie == null or vie.is_dead or vie.max_health <= 0.0:
		return
	var seuil := Forge.get_special_total(&"execute")
	if seuil <= 0.0 or vie.current > vie.max_health * seuil:
		return
	if cible.has_method(&"apply_damage"):
		cible.call(&"apply_damage", vie.current, _player, Vector2.ZERO)


## Épines : l'objet (Manteau d'épines) et le nœud de Job (« Ce qu'on lui rend »)
## alimentent le MÊME effet et s'additionnent. Deux mécaniques identiques
## côte-à-côte auraient divergé à la première retouche.
func _on_player_contact_hit(attacker: Node2D, amount: float) -> void:
	var ratio := Forge.get_special_total(&"thorns_bonus")
	if RunState.has_special(&"thorns"):
		ratio += thorns_ratio
	if ratio <= 0.0:
		return
	if attacker == null or not is_instance_valid(attacker):
		return
	if attacker.has_method(&"apply_damage"):
		attacker.call(&"apply_damage", amount * ratio, _player, Vector2.ZERO)


## L'explosion à la mort vient de l'objet (Braise éternelle) ou du nœud de Loth
## (« Sodome brûle »). La garde anti-chaîne vaut pour les deux : sans elle, une
## explosion qui tue en déclenche une autre et un seul kill nettoie l'écran.
func _on_enemy_died(enemy: Node2D, death_position: Vector2) -> void:
	_propager_feu(enemy, death_position)
	if not RunState.has_special(&"explode_on_kill") 			and Forge.get_special_total(&"blast_on_kill") <= 0.0:
		return
	# Garde anti-chaîne : une explosion qui tue ne déclenche pas d'explosion.
	if _explosion_active:
		return
	_explosion_active = true
	_explode(death_position)
	_explosion_active = false


func _explode(at: Vector2) -> void:
	var damage := _get_reference_weapon_damage() * explosion_damage_ratio
	if damage <= 0.0:
		return
	_spawn_explosion_vfx(at)
	GameEvents.damage_dealt.emit(damage, at, false)
	GameEvents.request_shake(3.0)
	for enemy in get_tree().get_nodes_in_group(Groups.ENEMIES):
		var node := enemy as Node2D
		if node == null or node.is_queued_for_deletion():
			continue
		if node.global_position.distance_to(at) > explosion_radius:
			continue
		if node.has_method(&"apply_damage"):
			node.call(&"apply_damage", damage, _player, Vector2.ZERO)


## L'effet est purement décoratif, mais sa TAILLE ne l'est pas : elle est
## calculée depuis `explosion_radius`, pour que le joueur voie la portée réelle
## de l'explosion au lieu de la deviner. Changer le rayon change le dessin.
##
## Il vit dans le conteneur des projectiles : c'est le seau des objets de monde
## éphémères, et la fin de vague le vide — un effet en cours y disparaît, ce qui
## est exactement le comportement voulu.
func _spawn_explosion_vfx(at: Vector2) -> void:
	var containers := get_tree().get_nodes_in_group(Groups.PROJECTILE_CONTAINER)
	if containers.is_empty():
		return
	var vfx := EXPLOSION_VFX.instantiate() as Node2D
	if vfx == null:
		return
	containers[0].add_child(vfx)
	vfx.global_position = at
	vfx.scale = Vector2.ONE * (explosion_radius * 2.0 / EXPLOSION_VFX_CONTENT)


## L'explosion suit l'arme principale : elle profite des objets de dégâts, mais
## pas de la cadence ni du multishot — c'est ce qui l'empêche de scaler seule.
func _get_reference_weapon_damage() -> float:
	if not is_instance_valid(_player):
		return 0.0
	var weapons := _player.get_weapons()
	if weapons.is_empty():
		return 0.0
	return weapons[0].get_projectile_damage()


# --- Les objets à effets de la 0.9.2 -----------------------------------------

## Multiplicateur d'un coup du joueur selon sa CIBLE, lu avant le coup.
##
## Statique : le projectile l'appelle à chaque impact sans avoir à trouver ce
## nœud. Les deux conditions sont indépendantes et se MULTIPLIENT — une entorse
## assumée à la règle « additif, jamais multiplicatif » : elles ne visent pas
## les mêmes coups (le premier sur un corps intact, les suivants sur un corps
## affaibli), et leur produit ne touche qu'un coup rare, celui qui ouvre sur
## une cible déjà en feu.
static func multiplicateur_cible(cible: Node) -> float:
	var stats := RunState.stats
	var m := 1.0
	if stats.has_special(&"premier_coup"):
		var vie := cible.get(&"health") as Health
		if vie != null and vie.current >= vie.max_health:
			m *= FRONDE_BONUS
	if stats.has_special(&"sel") and cible.has_method(&"est_en_feu"):
		if cible.call(&"est_en_feu") or cible.call(&"est_entrave"):
			m *= SEL_BONUS
	return m


## Ce qu'un coup du joueur laisse sur sa cible : brûlure, entrave.
##
## Appelé par le projectile, l'Encensoir, la Trompette et le Bâton : tout ce
## qui frappe au nom du joueur porte ses états, sans quoi le Soufre ne
## s'entendrait qu'avec l'arme et les synergies s'arrêteraient au premier
## objet qui ne tire pas.
static func sur_coup(cible: Node, degats: float, critique: bool, auteur: Node) -> void:
	if cible == null or not is_instance_valid(cible) or not cible.has_method(&"enflammer"):
		return
	var stats := RunState.stats
	var clou := critique and stats.has_special(&"clou")
	var feu := 0.0
	if stats.has_special(&"brulure"):
		feu += SOUFRE_PART
	if clou:
		feu += CLOU_PART
	if feu > 0.0:
		cible.call(&"enflammer", degats * feu, auteur, 0)
	if clou or stats.has_special(&"entrave"):
		cible.call(&"entraver", ENTRAVE_PART, ENTRAVE_DUREE)


## Feu grégeois : un corps qui meurt en feu enflamme ses plus proches voisins.
func _propager_feu(mort: Node2D, at: Vector2) -> void:
	if not RunState.has_special(&"feu_gregeois"):
		return
	if mort == null or not is_instance_valid(mort) or not mort.has_method(&"est_en_feu"):
		return
	if not mort.call(&"est_en_feu"):
		return
	var generation := int(mort.call(&"get_generation_feu"))
	if generation >= FEU_GENERATIONS:
		return
	var reserve := maxf(float(mort.call(&"get_brulure")) * FEU_PART,
		_get_reference_weapon_damage() * FEU_PLANCHER)
	if reserve <= 0.0:
		return
	var voisins: Array = []
	for noeud in get_tree().get_nodes_in_group(Groups.ENEMIES):
		var ennemi := noeud as Node2D
		if ennemi == null or ennemi == mort or ennemi.is_queued_for_deletion():
			continue
		var d := ennemi.global_position.distance_to(at)
		if d <= FEU_RAYON:
			voisins.append([d, ennemi])
	if voisins.is_empty():
		return
	voisins.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	for i in mini(FEU_VOISINS, voisins.size()):
		var cible: Node2D = voisins[i][1]
		cible.call(&"enflammer", reserve, _player, generation + 1)
	_poser_impact_feu(at)


func _poser_impact_feu(at: Vector2) -> void:
	var bacs := get_tree().get_nodes_in_group(Groups.PROJECTILE_CONTAINER)
	if bacs.is_empty():
		return
	var vfx := IMPACT_FEU.instantiate() as Node2D
	if vfx == null:
		return
	bacs[0].add_child(vfx)
	vfx.global_position = at


## Mâchoire de Samson. Réévaluée à chaque variation de PV et à chaque
## recalcul (achat, vente, PV max qui bougent) : `set_item_bonus` ne recalcule
## que si la valeur change, donc la boucle s'éteint d'elle-même.
func _evaluer_samson() -> void:
	var actif := RunState.has_special(&"samson") and is_instance_valid(_player) \
		and not _player.health.is_dead \
		and _player.health.current < _player.health.max_health * SAMSON_SEUIL
	for key: StringName in SAMSON_MODS:
		RunState.set_item_bonus(key, float(SAMSON_MODS[key]) if actif else 0.0)


func _on_player_health_changed(_current: float, _maximum: float) -> void:
	_evaluer_samson()


func _on_stats_recomputed(_stats: PlayerStats) -> void:
	_evaluer_samson()
	_regler_encensoir()


## L'Encensoir existe tant que l'objet est possédé, et suit le joueur.
func _regler_encensoir() -> void:
	var voulu := RunState.has_special(&"encensoir") and is_instance_valid(_player)
	if voulu and _encensoir == null:
		_encensoir = Encensoir.new()
		add_child(_encensoir)
		_encensoir.auteur = _player
		_encensoir.global_position = _player.global_position
	elif not voulu and _encensoir != null:
		_encensoir.queue_free()
		_encensoir = null
	if _encensoir != null:
		_encensoir.auteur = _player


## Trente deniers, versés APRÈS l'aspiration du butin (`wave_cleared` part une
## fois tout ramassé) : les âmes de la vague comptent dans l'intérêt.
func _on_wave_cleared(_index: int) -> void:
	if not RunState.has_special(&"interets"):
		return
	var gain := int(RunState.souls * INTERETS_TAUX)
	if not RunState.unleashed:
		gain = mini(gain, INTERETS_MAX)
	if gain <= 0:
		return
	RunState.add_souls(gain)
	Audio.play(&"ame")


func _ennemi_a_portee(rayon: float) -> bool:
	if not is_instance_valid(_player):
		return false
	var centre := _player.global_position
	for noeud in get_tree().get_nodes_in_group(Groups.ENEMIES):
		var ennemi := noeud as Node2D
		if ennemi != null and not ennemi.is_queued_for_deletion() \
				and ennemi.global_position.distance_to(centre) <= rayon:
			return true
	return false


## Trompette de Jéricho. Elle attend qu'un ennemi soit à portée pour sonner :
## une onde lâchée dans le vide, entre deux vagues, ne dirait rien au joueur
## et lui ferait rater celle qui compte.
func _sonner_trompette() -> void:
	_onde(TROMPETTE_RAYON, _get_reference_weapon_damage() * TROMPETTE_RATIO,
		TROMPETTE_RECUL, Color(1.0, 0.7, 0.3), 0.45)
	Audio.play(&"foudre")
	GameEvents.request_shake(4.0)


## Bâton de Moïse : le pouvoir, quel qu'il soit, ouvre la foule.
func _on_pouvoir_utilise(at: Vector2) -> void:
	if not RunState.has_special(&"baton_moise") or _moise > 0.0:
		return
	if not is_instance_valid(_player):
		return
	_moise = MOISE_RECHARGE
	_onde(MOISE_RAYON, _get_reference_weapon_damage() * MOISE_RATIO,
		MOISE_RECUL, Color(0.95, 0.85, 0.6), 0.4, at)
	Audio.play(&"roche")


## Une onde qui part du joueur : dégâts, recul vers l'extérieur, états.
## Les boss encaissent sans reculer — leur résistance au recul s'en charge.
func _onde(rayon: float, degats: float, recul: float, teinte: Color, duree: float,
		centre: Vector2 = Vector2.INF) -> void:
	if not is_instance_valid(_player):
		return
	if centre == Vector2.INF:
		centre = _player.global_position
	var onde := ParryWave.new()
	onde.rayon = rayon
	onde.teinte = teinte
	onde.duree = duree
	var bacs := get_tree().get_nodes_in_group(Groups.PROJECTILE_CONTAINER)
	(bacs[0] if not bacs.is_empty() else get_parent()).add_child(onde)
	onde.global_position = centre
	if degats <= 0.0:
		return
	GameEvents.damage_dealt.emit(degats, centre, false)
	for noeud in get_tree().get_nodes_in_group(Groups.ENEMIES):
		var ennemi := noeud as Node2D
		if ennemi == null or ennemi.is_queued_for_deletion():
			continue
		var ecart := ennemi.global_position - centre
		if ecart.length() > rayon or not ennemi.has_method(&"apply_damage"):
			continue
		ennemi.call(&"apply_damage", degats, _player, ecart.normalized() * recul)
		sur_coup(ennemi, degats, false, _player)
