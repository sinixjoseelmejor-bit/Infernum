extends Node
## Forge Éternelle (autoload `Forge`) : arbre de méta-progression persistant.
##
## 26 nœuds par personnage — 21 communs sur trois branches, plus une quatrième
## branche qui n'existe que pour lui. Débloqués avec des clés, conservés entre
## les runs, et jamais partagés : investir dans Caïn ne renforce pas Job.
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
## 5. LES TROIS PREMIÈRES BRANCHES RESTENT IDENTIQUES POUR TOUT LE MONDE. C'est
##    le tronc comparable : sans lui, on ne saurait plus ce que vaut un nœud.
##    Tout ce qui est propre à un personnage vit dans sa quatrième branche.
## 6. CHAQUE BRANCHE PROPRE PORTE UN NŒUD D'ÉCONOMIE. Les âmes tombent des
##    éliminations, donc le revenu suit les dégâts : un personnage bâti pour
##    encaisser s'équipe moins bien, frappe donc encore moins fort, et l'écart
##    se creuse tout seul. Chacun doit pouvoir acheter des âmes avec ce qu'il
##    sait faire — la chaîne d'éliminations pour Caïn, les coups encaissés pour
##    Job, le ramassage pour Loth.
##
## RYTHME : 82 clés pour une Forge complète — 66 pour le tronc commun, 16 pour
## la branche du personnage. Une run qui meurt à Lilith rapporte 2 clés, à Baal
## 4, à Asmodée 7, à Lucifer 10 : le tronc se termine vers la dixième run si le
## joueur gagne un boss toutes les deux runs, et la branche propre coûte deux
## runs de plus. Les clés, elles, restent COMMUNES au profil : jouer Caïn
## finance Job, sinon changer de personnage serait repartir de rien.

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

	# ===================== BRANCHES PROPRES AUX PERSONNAGES =====================
	#
	# Les trois branches ci-dessus sont IDENTIQUES pour tout le monde, et doivent
	# le rester : c'est le tronc comparable, celui qui dit ce qu'un nœud vaut. La
	# branche qui suit est ce qui fait qu'une Forge dédiée valait la peine — sans
	# elle, « chaque personnage a sa Forge » n'était qu'un coût triplé.
	#
	# CHACUNE PORTE UN NŒUD D'ÉCONOMIE, et c'est le point d'équilibrage : les
	# âmes tombent des éliminations, donc le revenu suit les dégâts. Un
	# personnage bâti pour encaisser serait condamné à s'équiper moins bien que
	# les autres, et l'écart se creuserait tout seul — moins d'objets, encore
	# moins de dégâts. Chaque branche rend donc des âmes contre ce que le
	# personnage sait faire : les éliminations en chaîne pour Caïn, les coups
	# encaissés pour Job, le ramassage pour Loth.
	#
	# ------------------------------ CAÏN · MARQUE ------------------------------
	{
		"id": &"cain_fresh", "branch": "Marque", "character": &"cain",
		"name": "Marque vive",
		"desc": "La Marque monte de 1,5 % par élimination au lieu de 1 %.",
		"cost": 1, "requires": [], "mods": {},
		"special": &"mark_per_kill", "value": 0.005,
	},
	{
		"id": &"cain_deep", "branch": "Marque", "character": &"cain",
		"name": "Marque profonde",
		"desc": "La Marque plafonne à +45 % au lieu de +25 %.",
		"cost": 2, "requires": [&"cain_fresh"], "mods": {},
		"special": &"mark_max", "value": 0.20,
	},
	{
		"id": &"cain_dry", "branch": "Marque", "character": &"cain",
		"name": "Le sang ne sèche pas",
		"desc": "La Marque ne retombe qu'à moitié entre deux vagues.",
		"cost": 3, "requires": [&"cain_deep"], "mods": {},
		"special": &"mark_carry", "value": 0.5,
	},
	{
		"id": &"cain_fratricide", "branch": "Marque", "character": &"cain",
		"name": "Fratricide",
		"desc": "La Marque donne aussi la moitié de sa valeur en cadence de tir.",
		"cost": 4, "requires": [&"cain_dry"], "mods": {},
		"special": &"mark_fire_rate", "value": 0.5,
	},
	{
		"id": &"cain_wanderer", "branch": "Marque", "character": &"cain",
		"name": "Errant",
		"desc": "Les ennemis sous 12 % de vie meurent sur le coup. Les boss sont épargnés.",
		"cost": 6, "requires": [&"cain_fratricide"], "mods": {},
		"special": &"execute", "value": 0.12,
	},

	# ------------------------------ JOB · ÉPREUVE ------------------------------
	{
		"id": &"job_tithe", "branch": "Épreuve", "character": &"job",
		"name": "Dîme de l'éprouvé",
		"desc": "Chaque coup encaissé rend des âmes : une pour cinq points de dégâts.",
		# EN TÊTE DE BRANCHE, à une seule clé, et c'est le point : Job est le
		# personnage le plus pauvre du jeu tant qu'il ne l'a pas (156 âmes par
		# run contre 189 à Caïn et 210 à Loth, mesuré sans branche). La laisser
		# en second nœud lui imposait trois runs de pauvreté ; là il l'a dès sa
		# première run qui atteint un boss, puisqu'un boss atteint vaut une clé.
		#
		# Le coût total de la branche ne change pas : 1 + 2 + 3 + 4 + 6 = 16.
		"cost": 1, "requires": [], "mods": {},
		"special": &"souls_per_damage", "value": 0.2,
	},
	{
		"id": &"job_scars", "branch": "Épreuve", "character": &"job",
		"name": "Chair marquée",
		"desc": "Ce qui a déjà été brisé se répare plus dur.",
		# 20 et non 10 : l'armure est devenue sa statistique de dégâts, donc
		# l'avoir TÔT compte deux fois. Mesuré : Lilith passe de 208 s à 164 s
		# pour le seul fait d'avancer cette armure, alors que Golgota ne bouge
		# pas — à la vague 5 les objets lui en ont déjà donné autant.
		"cost": 2, "requires": [&"job_tithe"], "mods": {"armor": 20.0},
	},
	{
		"id": &"job_old_wounds", "branch": "Épreuve", "character": &"job",
		"name": "Vieilles blessures",
		"desc": "+0,8 % de dégâts par point d'armure.",
		# LA RÉPONSE DE JOB AU CHRONOMÈTRE DES BOSS, et elle passe par l'armure
		# plutôt que par son arme — délibérément.
		#
		# Son problème mesuré : 44 DPS contre 60 à Caïn, et les pourcentages de
		# dégâts multiplient l'arme de base, donc le rapport de 73 % ne bouge
		# jamais. Or `enrage_time` est un contrôle de DPS pur : il ne price que
		# les dégâts, jamais la survie. L'échange « 27 % de dégâts contre 1,7×
		# de PV effectifs » est donc bon contre une horde et mauvais contre un
		# chronomètre.
		#
		# Monter ses dégâts de base l'aurait réglé aussi, et c'est ce qu'il faut
		# éviter : à DPS égal il garderait 2× les PV effectifs de Caïn, donc il
		# serait strictement le meilleur personnage et l'axe qui les distingue
		# disparaîtrait. Ici la puissance se PAIE en armure — il ne peut pas
		# être à la fois tank maximal et dégâts maximaux.
		#
		# MESURÉ, 6 runs par valeur, joueur invincible pour isoler les dégâts de
		# l'esquive : Golgota tombe en 100 s à 0,004 et en 82 s à 0,008.
		"cost": 3, "requires": [&"job_scars"], "mods": {},
		"special": &"armor_to_damage", "value": 0.008,
	},
	{
		"id": &"job_thorns", "branch": "Épreuve", "character": &"job",
		# L'IDENTIFIANT RESTE : les profils qui l'ont acheté le gardent, avec son
		# nouvel effet. « Œil pour œil » renvoyait les coups reçus — un effet de
		# tank passif, qui n'a plus sa place chez le paladin (0.9.0).
		"name": "Terre sainte",
		"desc": "La Consécration s'étend d'un tiers et brûle moitié plus fort.",
		# UN RETOUR ENTIER, et pas la moitié : le renvoi est un pourcentage du
		# coup reçu, or les PV ennemis montent de 10 % par vague quand les dégâts
		# ennemis n'en gagnent que 9,5 %. À 50 %, le nœud devenait décoratif
		# passé la vague 10 — 15 points rendus à un ennemi qui en a 90. À 100 %,
		# trois contacts tuent encore un imp de la vague 20.
		"cost": 4, "requires": [&"job_old_wounds"], "mods": {},
		"special": &"consecration_boost", "value": 1.0,
	},
	{
		"id": &"job_unbroken", "branch": "Épreuve", "character": &"job",
		"name": "Il n'a pas plié",
		# Même identifiant, même nom — c'est toujours la clé de voûte de sa
		# branche —, effet réécrit pour la Consécration et le Jugement.
		"desc": "Le sol se consacre dès l'arrêt et y soigne le double. Le Jugement ne demande que deux charges.",
		"cost": 6, "requires": [&"job_thorns"], "mods": {},
		"special": &"ferveur_rapide", "value": 1.0,
	},

	# ------------------------------- LOTH · EXODE ------------------------------
	{
		"id": &"loth_soles", "branch": "Exode", "character": &"loth",
		"name": "Pieds brûlés",
		"desc": "On ne s'arrête pas sur des braises.",
		"cost": 1, "requires": [], "mods": {"move_speed_pct": 0.05},
	},
	{
		"id": &"loth_never", "branch": "Exode", "character": &"loth",
		"name": "Ne jamais s'arrêter",
		"desc": "Le bonus de cadence en mouvement double : +20 % → +40 %.",
		"cost": 2, "requires": [&"loth_soles"], "mods": {},
		"special": &"flight_boost", "value": 0.20,
	},
	{
		"id": &"loth_plunder", "branch": "Exode", "character": &"loth",
		"name": "Main basse",
		"desc": "Il ne part jamais les mains vides.",
		"cost": 3, "requires": [&"loth_never"], "mods": {"soul_gain_pct": 0.12},
	},
	{
		"id": &"loth_forward", "branch": "Exode", "character": &"loth",
		"name": "Fuite en avant",
		"desc": "+20 % de dégâts tant qu'il se déplace.",
		# Les nœuds de Loth ne valaient, mesurés, que +28 % de DPS quand ceux de
		# Caïn en valaient +45 et ceux de Job +20 plus les épines et la Dîme. Sa
		# branche est la seule dont tout l'intérêt est conditionnel au
		# déplacement : elle doit payer davantage à conditions égales.
		"cost": 4, "requires": [&"loth_plunder"], "mods": {},
		"special": &"flight_damage", "value": 0.20,
	},
	{
		"id": &"loth_sodom", "branch": "Exode", "character": &"loth",
		"name": "Sodome brûle",
		"desc": "Les ennemis que vous tuez explosent.",
		"cost": 6, "requires": [&"loth_forward"], "mods": {},
		"special": &"blast_on_kill", "value": 1.0,
	},
]

## Branches COMMUNES aux trois personnages : le tronc comparable.
const BRANCHES := ["Fer", "Chair", "Cendre"]

## Quatrième branche, PROPRE à chaque personnage. Elle ne contient que des nœuds
## dont l'effet n'aurait aucun sens sur un autre : la Marque de Caïn, la Patience
## de Job, la fuite de Loth.
const BRANCHES_PERSO := {
	&"cain": "Marque",
	&"job": "Épreuve",
	&"loth": "Exode",
}

var _by_id: Dictionary = {}


## Liste des personnages, lue sur le SCRIPT et non sur l'autoload `Characters` :
## il est chargé après la Forge, donc le nœud n'existe pas encore ici.
const CATALOGUE_PERSOS := preload("res://scripts/characters/character_db.gd")


func _ready() -> void:
	_migrer()
	SaveGame.profile_changed.connect(func(_slot: int) -> void: _migrer())
	for node in NODES:
		_by_id[node["id"]] = node


func get_node_data(id: StringName) -> Dictionary:
	return _by_id.get(id, {})


func get_branch(branch: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for node in NODES:
		if node["branch"] == branch and _pour_selection(node):
			result.append(node)
	return result


## Les quatre branches du personnage choisi, dans l'ordre d'affichage.
func get_branches() -> Array[String]:
	var toutes: Array[String] = []
	for branche in BRANCHES:
		toutes.append(String(branche))
	var propre: String = String(BRANCHES_PERSO.get(Characters.selected_id, ""))
	if propre != "":
		toutes.append(propre)
	return toutes


## Ce nœud appartient-il à la Forge du personnage choisi ?
##
## Le filtre est APPLIQUÉ PARTOUT, et pas seulement à l'affichage. Sans lui,
## « 26 nœuds » deviendrait 36, le coût total afficherait la somme des trois
## personnages, et un fichier de sauvegarde modifié à la main donnerait à Job la
## Marque de Caïn. Les compteurs et les bonus doivent lire le même catalogue que
## l'écran.
func _pour_selection(node: Dictionary) -> bool:
	var perso: StringName = node.get("character", &"")
	return perso == &"" or perso == Characters.selected_id


## Chaque personnage a SA Forge. Investir dans Caïn ne renforce pas Job : c'est
## ce qui fait de l'arbre un choix plutôt qu'une case à cocher une fois pour
## toutes.
func is_unlocked(id: StringName) -> bool:
	return SaveGame.is_forge_unlocked(Characters.selected_id, id)


## Bascule l'ancien registre commun vers le registre par personnage. Sans effet
## une fois faite, et refaite à chaque changement de profil : un profil chargé
## plus tard n'a aucune raison d'avoir déjà été migré.
func _migrer() -> void:
	# Seuls les nœuds COMMUNS : l'ancien registre était antérieur aux branches de
	# personnage, il ne peut rien contenir d'autre.
	var ids: Array[StringName] = []
	for noeud in NODES:
		if not noeud.has("character"):
			ids.append(noeud["id"])
	var persos: Array[StringName] = []
	for entree in CATALOGUE_PERSOS.CHARACTERS:
		persos.append(entree["id"])
	if SaveGame.migrate_forge(ids, persos):
		print("Forge : %d nœuds repris de l'ancien registre, donnés aux %d personnages."
			% [ids.size(), persos.size()])


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
	if not _pour_selection(get_node_data(id)):
		return false
	if is_unlocked(id) or not requirements_met(id):
		return false
	return SaveGame.banked_keys >= int(get_node_data(id).get("cost", 0))


func unlock(id: StringName) -> bool:
	if not can_unlock(id):
		return false
	if not SaveGame.spend_keys(int(get_node_data(id)["cost"])):
		return false
	SaveGame.unlock_forge(Characters.selected_id, id)
	node_unlocked.emit(id)
	return true


## Somme des modificateurs de tous les nœuds débloqués. Additive, comme les
## objets : la Forge n'a aucun canal de scaling qui lui soit propre.
func get_bonus_mods() -> Dictionary:
	var total: Dictionary = {}
	for node in NODES:
		if not _pour_selection(node) or not is_unlocked(node["id"]):
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
		if not _pour_selection(node):
			continue
		if is_unlocked(node["id"]) and node.get("special", &"") == key:
			total += float(node.get("value", 0.0))
	return total


func get_start_souls() -> int:
	return int(get_special_total(&"start_souls"))


func get_progress() -> Vector2i:
	return get_progress_for(Characters.selected_id)


## Avancement de la Forge d'un personnage DONNÉ, sans passer par la sélection :
## la sélection de personnage affiche les trois côte à côte, et c'est ce qui
## rend l'investissement lisible avant de choisir.
func get_progress_for(personnage: StringName) -> Vector2i:
	var done := 0
	var total := 0
	for node in NODES:
		var pour: StringName = node.get("character", &"")
		if pour != &"" and pour != personnage:
			continue
		total += 1
		if SaveGame.is_forge_unlocked(personnage, node["id"]):
			done += 1
	return Vector2i(done, total)


## Identifiants des nœuds de la Forge du personnage choisi. Le panneau de
## développement s'en sert : débloquer « toute la Forge » ne doit pas écrire dans
## la sauvegarde les nœuds des deux autres — ils seraient filtrés à la lecture,
## mais ils fausseraient le compte de nœuds du profil.
func get_ids_for_selected() -> Array[StringName]:
	var ids: Array[StringName] = []
	for node in NODES:
		if _pour_selection(node):
			ids.append(node["id"])
	return ids


## Nœuds ouvrables sur un PROFIL ENTIER, tous personnages confondus : les nœuds
## communs comptent une fois par personnage, ceux d'une branche propre une seule
## fois. Sert au résumé de profil, qui mesure l'investissement total et non la
## puissance d'un personnage.
func count_all_nodes() -> int:
	var persos: int = CATALOGUE_PERSOS.CHARACTERS.size()
	var total := 0
	for node in NODES:
		total += 1 if node.has("character") else persos
	return total


func get_total_cost() -> int:
	var total := 0
	for node in NODES:
		if _pour_selection(node):
			total += int(node["cost"])
	return total
