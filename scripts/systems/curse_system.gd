extends Node
## Malédictions (autoload `Curses`) : difficulté volontaire contre récompenses.
##
## ENTIÈREMENT OPTIONNEL. Une run sans aucune malédiction est la run de
## référence, celle sur laquelle l'équilibrage a été mesuré ; les malédictions
## sont un levier pour joueurs qui trouvent ça trop facile ou qui veulent
## farmer des clés plus vite.
##
## ÉQUILIBRAGE :
## - les pénalités s'additionnent (1 + somme), jamais ne se composent : 3
##   malédictions à +25 % de PV ennemis donnent +75 %, pas ×1.95 ;
## - les récompenses en âmes alimentent `soul_gain_pct`, déjà plafonné à +100 %,
##   donc empiler les 6 malédictions ne peut pas faire exploser l'économie ;
## - chaque malédiction rapporte un peu MOINS que ce qu'elle coûte en confort :
##   c'est un pari, pas un bonus déguisé ;
## - LA RÉCOMPENSE SUIT LE RISQUE MESURÉ, PAS LE RISQUE APPARENT. Les i-frames
##   du joueur (0,5 s) bornent les dégâts entrants à 2 coups/seconde : ajouter
##   des ennemis ne fait donc presque rien au danger réel, alors que cela
##   multiplie le revenu en âmes. Les malédictions de DENSITÉ paient peu, celles
##   qui augmentent les dégâts PAR COUP paient beaucoup.

signal curses_changed()

const CURSES: Array[Dictionary] = [
	{
		"id": &"hungry_pack", "name": "Meute affamée",
		"desc": "Les démons ont senti quelque chose.",
		"penalty": "Ennemis +30 % de vitesse",
		"enemy_speed": 0.30,
		"rewards": {"soul_gain_pct": 0.20},
		"danger": 2,
	},
	{
		"id": &"hardened_flesh", "name": "Chair durcie",
		"desc": "Leur peau a cuit trop longtemps.",
		"penalty": "Ennemis +50 % de PV",
		"enemy_health": 0.50,
		"rewards": {"soul_gain_pct": 0.25},
		"danger": 3,
	},
	{
		"id": &"rising_tide", "name": "Marée montante",
		"desc": "Il en sort toujours davantage.",
		"penalty": "+35 % d'ennemis",
		"spawn_rate": 0.35,
		"rewards": {"soul_gain_pct": 0.05},
		"key_chance": 0.15,
		"danger": 3,
	},
	{
		"id": &"mortal_frailty", "name": "Fragilité mortelle",
		"desc": "Vous êtes venu sans armure.",
		"penalty": "-30 PV max",
		"rewards": {"max_health_flat": -30.0, "luck": 1.0, "soul_gain_pct": 0.15},
		"danger": 3,
	},
	{
		"id": &"blood_rite", "name": "Rituel de sang",
		"desc": "Chaque coup porte plus loin qu'il ne devrait.",
		"penalty": "Ennemis +45 % de dégâts",
		"enemy_damage": 0.45,
		"rewards": {"soul_gain_pct": 0.32, "luck": 1.5},
		"danger": 4,
	},
	{
		"id": &"void_eye", "name": "Œil du vide",
		"desc": "Les grands sont là dès le début.",
		"penalty": "Élites dès la vague 1, deux fois plus fréquentes",
		"elite_mult": 2.0, "elite_from_wave_one": true,
		"rewards": {"soul_gain_pct": 0.08},
		"key_chance": 0.25,
		"danger": 4,
	},
]

var active: Array[StringName] = []

var _by_id: Dictionary = {}


func _ready() -> void:
	for curse in CURSES:
		_by_id[curse["id"]] = curse


func get_curse(id: StringName) -> Dictionary:
	return _by_id.get(id, {})


func is_active(id: StringName) -> bool:
	return active.has(id)


func toggle(id: StringName) -> void:
	if active.has(id):
		active.erase(id)
	else:
		active.append(id)
	curses_changed.emit()


func clear_all() -> void:
	active.clear()
	curses_changed.emit()


func get_danger() -> int:
	var total := 0
	for id in active:
		total += int(get_curse(id).get("danger", 0))
	return total


func _sum(key: String) -> float:
	var total := 0.0
	for id in active:
		total += float(get_curse(id).get(key, 0.0))
	return total


# --- Multiplicateurs consommés par le WaveManager et le DropSystem ---

func get_enemy_health_mult() -> float:
	return 1.0 + _sum("enemy_health")


func get_enemy_damage_mult() -> float:
	return 1.0 + _sum("enemy_damage")


func get_enemy_speed_mult() -> float:
	return 1.0 + _sum("enemy_speed")


func get_spawn_rate_mult() -> float:
	return 1.0 + _sum("spawn_rate")


func get_elite_mult() -> float:
	var mult := 1.0
	for id in active:
		mult *= float(get_curse(id).get("elite_mult", 1.0))
	return mult


func starts_elites_immediately() -> bool:
	for id in active:
		if bool(get_curse(id).get("elite_from_wave_one", false)):
			return true
	return false


## Bonus de chance de clé, en valeur ADDITIVE (et non en multiplicateur) :
## `DropSystem` somme celui-ci et celui du pacte au lieu de les composer.
func get_key_chance_bonus() -> float:
	return _sum("key_chance")


## Modificateurs joueur, injectés dans `RunState.recompute_stats()` comme
## n'importe quel objet : mêmes pools, mêmes plafonds.
func get_reward_mods() -> Dictionary:
	var total: Dictionary = {}
	for id in active:
		for key in get_curse(id).get("rewards", {}):
			total[key] = float(total.get(key, 0.0)) + float(get_curse(id)["rewards"][key])
	return total
