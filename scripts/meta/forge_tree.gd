extends Node
## Forge Éternelle (autoload `Forge`) : arbre de méta-progression persistant.
##
## 15 nœuds, 3 branches, débloqués avec des clés et conservés entre les runs.
##
## ÉQUILIBRAGE — pourquoi ça ne trivialise pas le début de partie :
##
## 1. LES BONUS ALIMENTENT LES MÊMES POOLS PLAFONNÉS que les objets
##    (`PlayerStats`). Un joueur avec +12 % de dégâts de Forge démarre à 12 %
##    des 200 % autorisés : la Forge avance le curseur, elle ne le déplace pas.
## 2. BUDGET TOTAL VOLONTAIREMENT MODESTE. Arbre complet ≈ +33 % de puissance,
##    soit ~8 objets communs, soit environ 1.5 à 2 vagues d'avance. Le mur de
##    difficulté (vague ~15-20) recule à peine.
## 3. COÛT ÉTALÉ : 42 clés au total, soit ~8 à 10 runs. Un débutant joue sans,
##    un vétéran ne saute pas les vagues 1-5 pour autant — elles sont déjà
##    confortables sans Forge (DPS de base 50 pour 21 requis en vague 1).
## 4. AUCUN NŒUD NE TOUCHE DEUX AXES MULTIPLICATIFS à la fois.

signal node_unlocked(id: StringName)

const NODES: Array[Dictionary] = [
	# ------------------------------ BRANCHE FER -------------------------------
	{
		"id": &"forge_ember", "branch": "Fer", "name": "Braise de forge",
		"desc": "Les armes sortent du feu plus mordantes.",
		"cost": 1, "requires": [], "mods": {"damage_pct": 0.03},
	},
	{
		"id": &"forge_temper", "branch": "Fer", "name": "Trempe",
		"desc": "Le métal garde le tranchant.",
		"cost": 2, "requires": [&"forge_ember"], "mods": {"damage_pct": 0.04},
	},
	{
		"id": &"forge_oiled", "branch": "Fer", "name": "Mécanisme huilé",
		"desc": "Plus rien ne grippe.",
		"cost": 3, "requires": [&"forge_ember"], "mods": {"fire_rate_pct": 0.05},
	},
	{
		"id": &"forge_razor", "branch": "Fer", "name": "Fil rasoir",
		"desc": "Trouve la faille plus souvent.",
		"cost": 3, "requires": [&"forge_temper"], "mods": {"crit_chance": 0.04},
	},
	{
		"id": &"forge_blacksteel", "branch": "Fer", "name": "Acier noir",
		"desc": "Forgé dans quelque chose de très ancien.",
		"cost": 5, "requires": [&"forge_oiled", &"forge_razor"],
		"mods": {"damage_pct": 0.05},
	},

	# ----------------------------- BRANCHE CHAIR ------------------------------
	{
		"id": &"forge_hide", "branch": "Chair", "name": "Cuir cousu",
		"desc": "Une couche de plus entre vous et eux.",
		"cost": 1, "requires": [], "mods": {"max_health_flat": 8.0},
	},
	{
		"id": &"forge_plates", "branch": "Chair", "name": "Plaques rivetées",
		"desc": "Ça pèse, mais ça tient.",
		"cost": 2, "requires": [&"forge_hide"], "mods": {"armor": 6.0},
	},
	{
		"id": &"forge_breath", "branch": "Chair", "name": "Souffle lent",
		"desc": "Les plaies se referment d'elles-mêmes.",
		"cost": 3, "requires": [&"forge_hide"], "mods": {"regen": 0.3},
	},
	{
		"id": &"forge_carcass", "branch": "Chair", "name": "Carcasse épaisse",
		"desc": "Il en faut plus pour vous abattre.",
		"cost": 3, "requires": [&"forge_plates"], "mods": {"max_health_flat": 10.0},
	},
	{
		"id": &"forge_scale", "branch": "Chair", "name": "Écaille de forge",
		"desc": "Trempée dans la même cuve que les armes.",
		"cost": 5, "requires": [&"forge_breath", &"forge_carcass"],
		"mods": {"armor": 10.0},
	},

	# ----------------------------- BRANCHE CENDRE -----------------------------
	{
		"id": &"forge_embers", "branch": "Cendre", "name": "Braises tièdes",
		"desc": "Les âmes se laissent mieux saisir.",
		"cost": 1, "requires": [], "mods": {"soul_gain_pct": 0.08},
	},
	{
		"id": &"forge_light_step", "branch": "Cendre", "name": "Pas léger",
		"desc": "La cendre ne ralentit plus.",
		"cost": 2, "requires": [&"forge_embers"], "mods": {"move_speed_pct": 0.04},
	},
	{
		"id": &"forge_call", "branch": "Cendre", "name": "Appel des âmes",
		"desc": "Elles viennent de plus loin.",
		"cost": 2, "requires": [&"forge_embers"], "mods": {"pickup_radius_pct": 0.40},
	},
	{
		"id": &"forge_augur", "branch": "Cendre", "name": "Augure",
		"desc": "La boutique propose de meilleures raretés.",
		"cost": 4, "requires": [&"forge_light_step", &"forge_call"],
		"mods": {"luck": 1.0},
	},
	{
		"id": &"forge_chest", "branch": "Cendre", "name": "Coffre de forge",
		"desc": "Chaque run commence avec 60 âmes.",
		"cost": 5, "requires": [&"forge_augur"], "mods": {},
		"special": &"start_souls", "value": 60,
	},
]

const BRANCHES := ["Fer", "Chair", "Cendre"]

var _by_id: Dictionary = {}


func _ready() -> void:
	for node in NODES:
		_by_id[node["id"]] = node


func get_node_data(id: StringName) -> Dictionary:
	return _by_id.get(id, {})


func get_branch(branch: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for node in NODES:
		if node["branch"] == branch:
			result.append(node)
	return result


func is_unlocked(id: StringName) -> bool:
	return SaveGame.is_unlocked(id)


## Les prérequis sont-ils satisfaits ? (indépendant du solde de clés)
func requirements_met(id: StringName) -> bool:
	var node := get_node_data(id)
	if node.is_empty():
		return false
	for req in node.get("requires", []):
		if not is_unlocked(req):
			return false
	return true


func can_unlock(id: StringName) -> bool:
	if is_unlocked(id) or not requirements_met(id):
		return false
	return SaveGame.banked_keys >= int(get_node_data(id).get("cost", 0))


func unlock(id: StringName) -> bool:
	if not can_unlock(id):
		return false
	if not SaveGame.spend_keys(int(get_node_data(id)["cost"])):
		return false
	SaveGame.unlock_id(id)
	node_unlocked.emit(id)
	return true


## Somme des modificateurs de tous les nœuds débloqués. Additive, comme les
## objets : la Forge n'a aucun canal de scaling qui lui soit propre.
func get_bonus_mods() -> Dictionary:
	var total: Dictionary = {}
	for node in NODES:
		if not is_unlocked(node["id"]):
			continue
		for key in node.get("mods", {}):
			total[key] = float(total.get(key, 0.0)) + float(node["mods"][key])
	return total


func get_start_souls() -> int:
	var souls := 0
	for node in NODES:
		if is_unlocked(node["id"]) and node.get("special", &"") == &"start_souls":
			souls += int(node.get("value", 0))
	return souls


func get_progress() -> Vector2i:
	var done := 0
	for node in NODES:
		if is_unlocked(node["id"]):
			done += 1
	return Vector2i(done, NODES.size())


func get_total_cost() -> int:
	var total := 0
	for node in NODES:
		total += int(node["cost"])
	return total
