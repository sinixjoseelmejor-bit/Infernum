extends Node
## Forge Éternelle (autoload `Forge`) : arbre de méta-progression persistant.
##
## 21 nœuds, 3 branches, débloqués avec des clés et conservés entre les runs.
##
## CE QUE LA FORGE DOIT FAIRE — et ce qu'elle ne faisait pas. Le jeu est fait
## pour être REJOUÉ : une run se termine sur un boss, et c'est la Forge qui doit
## rendre le boss suivant atteignable. L'ancien arbre valait +33 % de puissance
## au total, soit une vague et demie d'avance : dix runs de clés ne changeaient
## pas quel boss vous tuait. Le budget a été triplé et surtout complété par des
## nœuds à EFFET (seconde chance, soin après boss, étal élargi, clés doublées)
## dont chacun change visiblement la run suivante.
##
## GARDE-FOUS :
## 1. Les bonus de statistiques alimentent LES MÊMES POOLS PLAFONNÉS que les
##    objets (`PlayerStats`) : la Forge avance le curseur, elle ne le déplace pas.
## 2. Les effets sont bornés à l'unité : une seule seconde chance par run, un
##    seul objet de plus en boutique, une seule clé de plus par boss.
## 3. Le début de partie ne se trivialise pas : les vagues 1-4 sont déjà
##    confortables sans Forge (DPS de base 50 pour 21 requis en vague 1), et les
##    boss sont remis à l'échelle de la vague, pas de la Forge.
## 4. AUCUN NŒUD NE TOUCHE DEUX AXES MULTIPLICATIFS à la fois.
##
## RYTHME : 66 clés au total. Une run qui meurt à Lilith rapporte 2 clés, à Baal
## 4, à Asmodée 7, à Lucifer 10 : l'arbre se termine vers la dixième run si le
## joueur gagne un boss toutes les deux runs — c'est la cadence visée.

signal node_unlocked(id: StringName)

const NODES: Array[Dictionary] = [
	# ------------------------------ BRANCHE FER -------------------------------
	{
		"id": &"forge_ember", "branch": "Fer", "name": "Braise de forge",
		"desc": "Les armes sortent du feu plus mordantes.",
		"cost": 1, "requires": [], "mods": {"damage_pct": 0.04},
	},
	{
		"id": &"forge_temper", "branch": "Fer", "name": "Trempe",
		"desc": "Le métal garde le tranchant.",
		"cost": 2, "requires": [&"forge_ember"], "mods": {"damage_pct": 0.05},
	},
	{
		"id": &"forge_oiled", "branch": "Fer", "name": "Mécanisme huilé",
		"desc": "Plus rien ne grippe.",
		"cost": 2, "requires": [&"forge_ember"], "mods": {"fire_rate_pct": 0.06},
	},
	{
		"id": &"forge_razor", "branch": "Fer", "name": "Fil rasoir",
		"desc": "Trouve la faille plus souvent.",
		"cost": 3, "requires": [&"forge_temper"], "mods": {"crit_chance": 0.05},
	},
	{
		"id": &"forge_blacksteel", "branch": "Fer", "name": "Acier noir",
		"desc": "Forgé dans quelque chose de très ancien.",
		"cost": 4, "requires": [&"forge_oiled", &"forge_razor"],
		"mods": {"damage_pct": 0.08},
	},
	{
		"id": &"forge_pierce", "branch": "Fer", "name": "Fer qui traverse",
		"desc": "Les traits ne s'arrêtent plus au premier corps.",
		"cost": 5, "requires": [&"forge_blacksteel"], "mods": {"pierce": 1},
	},
	{
		"id": &"forge_wrath", "branch": "Fer", "name": "Colère",
		"desc": "Ce qui reste quand tout le reste a brûlé.",
		"cost": 6, "requires": [&"forge_pierce"], "mods": {"damage_pct": 0.10},
	},

	# ----------------------------- BRANCHE CHAIR ------------------------------
	{
		"id": &"forge_hide", "branch": "Chair", "name": "Cuir cousu",
		"desc": "Une couche de plus entre vous et eux.",
		"cost": 1, "requires": [], "mods": {"max_health_flat": 10.0},
	},
	{
		"id": &"forge_plates", "branch": "Chair", "name": "Plaques rivetées",
		"desc": "Ça pèse, mais ça tient.",
		"cost": 2, "requires": [&"forge_hide"], "mods": {"armor": 8.0},
	},
	{
		"id": &"forge_breath", "branch": "Chair", "name": "Souffle lent",
		"desc": "Les plaies se referment d'elles-mêmes.",
		"cost": 2, "requires": [&"forge_hide"], "mods": {"regen": 0.4},
	},
	{
		"id": &"forge_carcass", "branch": "Chair", "name": "Carcasse épaisse",
		"desc": "Il en faut plus pour vous abattre.",
		"cost": 3, "requires": [&"forge_plates"], "mods": {"max_health_flat": 15.0},
	},
	{
		"id": &"forge_scale", "branch": "Chair", "name": "Écaille de forge",
		"desc": "Trempée dans la même cuve que les armes.",
		"cost": 4, "requires": [&"forge_breath", &"forge_carcass"],
		"mods": {"armor": 12.0},
	},
	{
		"id": &"forge_boss_heal", "branch": "Chair", "name": "Repos du vainqueur",
		"desc": "Abattre un boss rend deux coups de plus.",
		"cost": 4, "requires": [&"forge_carcass"], "mods": {},
		"special": &"boss_heal_hits", "value": 2.0,
	},
	{
		"id": &"forge_revive", "branch": "Chair", "name": "Seconde chance",
		"desc": "Une fois par run, le coup fatal vous relève à mi-vie au lieu de vous achever.",
		"cost": 7, "requires": [&"forge_scale", &"forge_boss_heal"], "mods": {},
		"special": &"revive", "value": 1,
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
		"cost": 2, "requires": [&"forge_embers"], "mods": {"move_speed_pct": 0.05},
	},
	{
		"id": &"forge_call", "branch": "Cendre", "name": "Marchandage",
		"desc": "La boutique baisse ses prix de 10 %.",
		"cost": 2, "requires": [&"forge_embers"], "mods": {},
		"special": &"shop_discount", "value": 0.10,
	},
	{
		"id": &"forge_augur", "branch": "Cendre", "name": "Augure",
		"desc": "La boutique propose de meilleures raretés.",
		"cost": 3, "requires": [&"forge_light_step", &"forge_call"],
		"mods": {"luck": 1.0},
	},
	{
		"id": &"forge_chest", "branch": "Cendre", "name": "Coffre de forge",
		"desc": "Chaque run commence avec 60 âmes.",
		"cost": 3, "requires": [&"forge_augur"], "mods": {},
		"special": &"start_souls", "value": 60,
	},
	{
		"id": &"forge_stall", "branch": "Cendre", "name": "Étal élargi",
		"desc": "La boutique propose un objet de plus.",
		"cost": 4, "requires": [&"forge_augur"], "mods": {},
		"special": &"shop_slots", "value": 1,
	},
	{
		"id": &"forge_keys", "branch": "Cendre", "name": "Clé du geôlier",
		"desc": "Chaque boss abattu laisse une clé de plus.",
		"cost": 5, "requires": [&"forge_chest", &"forge_stall"], "mods": {},
		"special": &"boss_keys", "value": 1,
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


## Somme des effets spéciaux débloqués portant cette clé. Chaque consommateur
## (boutique, vagues, boss, joueur) lit la sienne : `start_souls`,
## `shop_discount`, `shop_slots`, `boss_heal_hits`, `boss_keys`, `revive`.
func get_special_total(key: StringName) -> float:
	var total := 0.0
	for node in NODES:
		if is_unlocked(node["id"]) and node.get("special", &"") == key:
			total += float(node.get("value", 0.0))
	return total


func get_start_souls() -> int:
	return int(get_special_total(&"start_souls"))


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
