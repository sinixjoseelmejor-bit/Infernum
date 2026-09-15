extends Node
## Catalogue d'objets (autoload `ItemDB`) et tirage pondéré par rareté.
##
## ÉQUILIBRAGE DU POOL — six garde-fous appliqués à chaque entrée :
##
## A. AUCUN OBJET NE CUMULE DEUX STATS MULTIPLICATIVES SANS CONTREPARTIE.
##    Dégâts %, cadence % et projectiles se multiplient entre eux dans le calcul
##    final du DPS. Un objet donnant « +30 % dégâts ET +30 % cadence » vaudrait
##    à lui seul deux objets et dominerait le pool : ici, tout objet touchant
##    deux de ces trois axes paie un malus sur le troisième.
## B. LES OBJETS FORTS ONT UN COÛT RÉEL, pas cosmétique. Le malus porte sur un
##    axe que la build concernée utilise vraiment.
## C. AUCUN EFFET « PAR KILL » NON PLAFONNÉ. Le seul stacking permanent
##    (Griffe du moissonneur) est borné à +40 % de dégâts.
## D. LES BONUS PLATS RESTENT PETITS. Un bonus en pourcentage se dilue dans le
##    pool additif à mesure que la build grandit ; un bonus plat, non. Un « +3
##    dégâts » sur une arme à 12 vaut +25 % de DPS pour toujours — plus que le
##    meilleur objet rare, pour le prix d'une commune.
## E. AUCUN OBJET NE SATURE UN PLAFOND À LUI SEUL. Si `mods[axe] * max_stacks`
##    atteint le plafond, celui-ci cesse d'être une incitation à diversifier et
##    devient « achetez 4 fois le même objet ». Seule exception assumée : Éclat
##    trifide, seule source de projectiles — c'est la taxe multishot globale, et
##    non le plafond, qui borne cet axe. Lance de Longin suit la même logique
##    pour la perforation : 2 piles sur un plafond de 3, et une décote par corps
##    traversé qui rend le troisième ennemi deux fois moins rentable que le
##    premier.
## F. UN OBJET PUREMENT DÉFENSIF NE PEUT PAS EMPILER SANS LIMITE. Les i-frames
##    du joueur (0,4 s) bornent les dégâts entrants à 2,5 coups/seconde : les PV
##    effectifs sont l'axe le plus rentable du jeu, et il faut le brider par les
##    piles autant que par le plafond d'armure. Sceau du gardien empilé 5 fois
##    valait ×6.12 de PV effectifs à lui seul.
##
## Résultat visé : plusieurs archétypes viables (cadence, gros coups critiques,
## multishot, tank/régénération, mobilité-ramassage) sans qu'aucun objet ne soit
## le choix évident quel que soit le contexte.

signal catalog_ready

const ITEMS: Array[Dictionary] = [
	# ------------------------------ COMMUNES (6) ------------------------------
	# Petits gains, sans malus : la base de n'importe quelle build.
	{
		"id": &"ember", "name": "Braise ardente", "rarity": 0,
		"desc": "Les projectiles portent une braise.",
		"mods": {"damage_flat": 1.5},
	},
	{
		"id": &"ash_soles", "name": "Semelles de cendre", "rarity": 0,
		"desc": "Marcher sur les braises, ça forme.",
		"mods": {"move_speed_pct": 0.08},
	},
	{
		"id": &"rusty_striker", "name": "Percuteur rouillé", "rarity": 0,
		"desc": "Ça grince, mais ça part plus vite.",
		"mods": {"fire_rate_pct": 0.10},
	},
	{
		"id": &"tanned_hide", "name": "Cuir tanné", "rarity": 0,
		"desc": "Prélevé sur quelque chose de gros.",
		"mods": {"max_health_flat": 10.0}, "max_stacks": 4,
	},
	{
		"id": &"chipped_fang", "name": "Croc ébréché", "rarity": 0,
		"desc": "Trouve toujours le point faible.",
		"mods": {"crit_chance": 0.06},
	},
	{
		"id": &"soul_magnet", "name": "Aimant d'âmes", "rarity": 0,
		"desc": "Les âmes viennent à vous.",
		"mods": {"pickup_radius_pct": 0.35, "soul_gain_pct": 0.10},
	},

	# -------------------------------- RARES (6) -------------------------------
	{
		"id": &"demon_bile", "name": "Fiel de démon", "rarity": 1,
		"desc": "Corrosif. Très corrosif.",
		"mods": {"damage_pct": 0.18},
	},
	{
		"id": &"infernal_breech", "name": "Culasse infernale", "rarity": 1,
		"desc": "Cadence en hausse, puissance en baisse.",
		"mods": {"fire_rate_pct": 0.25, "damage_pct": -0.08},
	},
	{
		"id": &"basalt_scales", "name": "Écailles de basalte", "rarity": 1,
		"desc": "Lourdes, mais on encaisse.",
		"mods": {"armor": 16.0, "move_speed_pct": -0.05},
		"max_stacks": 3,
	},
	{
		"id": &"hunter_eye", "name": "Œil du chasseur", "rarity": 1,
		"desc": "Voit plus loin, vise mieux.",
		"mods": {"range_pct": 0.20, "crit_chance": 0.08},
	},
	{
		"id": &"leech", "name": "Sangsue", "rarity": 1,
		"desc": "Chaque blessure infligée vous nourrit. Le soin par seconde est plafonné.",
		"mods": {"lifesteal_pct": 0.02},
		"max_stacks": 2,
	},
	{
		"id": &"spectral_drift", "name": "Dérive spectrale", "rarity": 1,
		"desc": "Plus rapide, plus vif.",
		"mods": {"move_speed_pct": 0.14, "fire_rate_pct": 0.12},
		"max_stacks": 4,
	},

	# ------------------------------- ÉPIQUES (5) ------------------------------
	# Objets structurants : ils orientent la build et coûtent quelque chose.
	{
		"id": &"trifid_shard", "name": "Éclat trifide", "rarity": 2,
		"desc": "+1 projectile. Les projectiles supplémentaires frappent plus faiblement.",
		"mods": {"projectile_bonus": 1},
		"max_stacks": 4,
	},
	{
		"id": &"forge_heart", "name": "Cœur de forge", "rarity": 2,
		"desc": "Des coups lourds, plus espacés.",
		"mods": {"damage_pct": 0.38, "fire_rate_pct": -0.10},
	},
	{
		"id": &"blood_pact", "name": "Pacte de sang", "rarity": 2,
		"desc": "La puissance contre la chair.",
		"mods": {"damage_pct": 0.50, "max_health_flat": -18.0},
		"max_stacks": 2,
	},
	{
		"id": &"predator_crown", "name": "Couronne du prédateur", "rarity": 2,
		"desc": "Frapper juste plutôt que frapper souvent.",
		"mods": {"crit_chance": 0.15, "crit_damage_pct": 0.40, "fire_rate_pct": -0.08},
		"max_stacks": 3,
	},
	{
		"id": &"longinus_lance", "name": "Lance de Longin", "rarity": 2,
		"desc": "Le fer qui a percé le flanc. Les traits ne s'arrêtent plus au premier corps.",
		"mods": {"pierce": 1, "fire_rate_pct": -0.08},
		"max_stacks": 2,
	},
	{
		"id": &"guardian_seal", "name": "Sceau du gardien", "rarity": 2,
		"desc": "Tenir la ligne, quitte à tirer moins.",
		"mods": {"max_health_flat": 30.0, "armor": 14.0, "fire_rate_pct": -0.18},
		"max_stacks": 2,
	},

	# ----------------------------- LÉGENDAIRES (3) ----------------------------
	# Effets uniques, non cumulables, chacun avec une vraie contrepartie.
	{
		"id": &"eternal_ember", "name": "Braise éternelle", "rarity": 3,
		"desc": "Les ennemis tués explosent (70 % des dégâts de l'arme). Les explosions ne s'enchaînent pas.",
		"mods": {},
		"special": &"explode_on_kill", "max_stacks": 1,
	},
	{
		"id": &"damned_clock", "name": "Horloge damnée", "rarity": 3,
		"desc": "Le temps s'accélère, vous vous usez.",
		"mods": {"fire_rate_pct": 0.50, "damage_pct": -0.10},
		"max_stacks": 1,
	},
	{
		"id": &"reaper_claw", "name": "Griffe du moissonneur", "rarity": 3,
		"desc": "+2 % de dégâts toutes les 25 éliminations, plafonné à +40 %.",
		"mods": {},
		"special": &"reaper_stacks", "max_stacks": 1,
	},

	# ------------- À DÉBLOQUER AVEC DES CLÉS (contenu persistant) -------------
	{
		"id": &"thorn_mantle", "name": "Manteau d'épines", "rarity": 1,
		"desc": "Renvoie 30 % des dégâts de contact subis.",
		"mods": {"armor": 10.0},
		"special": &"thorns", "max_stacks": 1, "key_cost": 2,
	},
	{
		"id": &"phoenix_down", "name": "Duvet de phénix", "rarity": 2,
		"desc": "Régénère 1.2 PV par seconde.",
		"mods": {"regen": 1.2, "max_health_flat": 10.0},
		"max_stacks": 1, "key_cost": 3,
	},
	{
		"id": &"void_siphon", "name": "Siphon du vide", "rarity": 3,
		"desc": "Beaucoup plus d'âmes récoltées, au prix de la puissance.",
		"mods": {"soul_gain_pct": 0.45, "damage_pct": -0.05, "pickup_radius_pct": 0.50},
		"max_stacks": 1, "key_cost": 5,
	},
]

## Poids de rareté à la vague 1, puis dérive contrôlée et bornée.
const BASE_WEIGHTS := [60.0, 27.0, 10.0, 3.0]
const WEIGHT_DRIFT := [-3.0, 1.0, 1.5, 0.7]
const WEIGHT_MIN := [25.0, 0.0, 0.0, 0.0]
const WEIGHT_MAX := [100.0, 40.0, 25.0, 10.0]

var _catalog: Dictionary = {}
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	for entry in ITEMS:
		var item := ItemData.new()
		item.id = entry["id"]
		item.display_name = entry["name"]
		item.description = entry.get("desc", "")
		item.rarity = entry["rarity"] as ItemData.Rarity
		item.mods = entry.get("mods", {})
		item.special = entry.get("special", &"")
		item.max_stacks = entry.get("max_stacks", 5)
		item.key_cost = entry.get("key_cost", 0)
		_catalog[item.id] = item
	catalog_ready.emit()


func get_item(id: StringName) -> ItemData:
	return _catalog.get(id)


func get_all() -> Array[ItemData]:
	var result: Array[ItemData] = []
	for item in _catalog.values():
		result.append(item)
	return result


## Objets qui doivent encore être achetés avec des clés.
func get_locked() -> Array[ItemData]:
	var result: Array[ItemData] = []
	for item in get_all():
		if item.key_cost > 0 and not SaveGame.is_unlocked(item.id):
			result.append(item)
	result.sort_custom(func(a: ItemData, b: ItemData) -> bool: return a.key_cost < b.key_cost)
	return result


## Objets réellement tirables : débloqués et pas encore au nombre max de piles.
func get_available(owned_counts: Dictionary) -> Array[ItemData]:
	var result: Array[ItemData] = []
	for item in get_all():
		if item.key_cost > 0 and not SaveGame.is_unlocked(item.id):
			continue
		if int(owned_counts.get(item.id, 0)) >= item.max_stacks:
			continue
		result.append(item)
	return result


func get_rarity_weights(wave: int, luck: float = 0.0) -> Array[float]:
	var steps := maxf(0.0, wave - 1.0)
	var weights: Array[float] = []
	for i in 4:
		var w: float = BASE_WEIGHTS[i] + WEIGHT_DRIFT[i] * steps
		# La chance déplace la masse vers le haut, sans créer de nouveau plafond.
		if i > 0:
			w += luck * float(i)
		else:
			w -= luck * 3.0
		weights.append(clampf(w, WEIGHT_MIN[i], WEIGHT_MAX[i]))
	return weights


## Tirage d'une offre de boutique, sans doublon dans la même offre.
func roll_offer(count: int, wave: int, owned_counts: Dictionary, luck: float = 0.0) -> Array[ItemData]:
	var pool := get_available(owned_counts)
	var weights := get_rarity_weights(wave, luck)
	var offer: Array[ItemData] = []
	for _i in count:
		if pool.is_empty():
			break
		var picked := _weighted_pick(pool, weights)
		if picked == null:
			break
		offer.append(picked)
		pool.erase(picked)
	return offer


func _weighted_pick(pool: Array[ItemData], weights: Array[float]) -> ItemData:
	# Une rareté absente du pool ne doit pas consommer de poids : on repondère à
	# partir des seules raretés réellement présentes.
	var by_rarity := {0: [], 1: [], 2: [], 3: []}
	for item in pool:
		by_rarity[int(item.rarity)].append(item)

	var total := 0.0
	for r in 4:
		if not (by_rarity[r] as Array).is_empty():
			total += weights[r]
	if total <= 0.0:
		return pool[_rng.randi_range(0, pool.size() - 1)]

	var roll := _rng.randf() * total
	for r in 4:
		var bucket: Array = by_rarity[r]
		if bucket.is_empty():
			continue
		roll -= weights[r]
		if roll <= 0.0:
			return bucket[_rng.randi_range(0, bucket.size() - 1)]
	return pool[_rng.randi_range(0, pool.size() - 1)]
