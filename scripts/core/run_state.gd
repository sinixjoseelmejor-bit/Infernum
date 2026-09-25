extends Node
## État de la run en cours (autoload `RunState`).
##
## Source de vérité unique pour : vague courante, monnaies, inventaire et stats
## agrégées. Tout ce qui est ici meurt avec la run (sauf les clés, qui sont
## versées à `SaveGame` à la fin).

signal souls_changed(amount: int)
signal keys_changed(amount: int)
signal item_gained(item: ItemData, stack_count: int)
## L'inventaire a été VIDÉ par le début d'une nouvelle run.
##
## `item_gained` ne suffisait pas : il n'annonce que les ajouts. Tout ce qui
## garde une copie de l'inventaire — l'orbite d'objets autour du joueur — se
## retrouvait à afficher celui de la run précédente, sans jamais l'apprendre.
signal run_reset()
## Un exemplaire a été REVENDU. Distinct de `run_reset` : l'inventaire n'est pas
## vide, il a juste perdu une pile — et tout ce qui en garde une copie doit
## l'apprendre, sans quoi l'orbite continue d'afficher un objet qu'on a vendu.
signal item_lost(item: ItemData, stack_count: int)
signal stats_recomputed(stats: PlayerStats)
signal run_ended(summary: Dictionary)

## Bonus plafonné de la Griffe du moissonneur.
## En POURCENTAGE et non en plat : un bonus plat ne se dilue jamais dans le pool
## additif, donc +30 dégâts plats sur une arme à 12 valaient +250 % de DPS.
const REAPER_KILLS_PER_STACK := 25
const REAPER_PCT_PER_STACK := 0.02
const REAPER_MAX_PCT := 0.40

var stats := PlayerStats.new()

var souls: int = 0
var keys: int = 0

## DÉCHAÎNEMENT : plafonds et taxes levés, piles d'objets multipliées.
##
## N'est PAS choisi ici : il est armé à la Forge, par personnage, et recopié au
## début de chaque run. Une seule source de vérité, dans la sauvegarde.
var unleashed: bool = false
var wave: int = 0
var kills: int = 0
var run_time: float = 0.0
var is_running: bool = false

## {StringName: int} nombre d'exemplaires possédés par objet.
var owned_counts: Dictionary = {}
var owned_items: Array[ItemData] = []

## Âmes arrachées aux survivants de la dernière vague. Lu par la boutique pour
## le dire : des âmes qui arrivent sans explication ne s'attribuent à rien, et
## le joueur n'apprendrait jamais que blesser sans achever rapporte quelque
## chose.
var leftover_souls: int = 0
var leftover_count: int = 0

## Secondes chances restantes (nœud de Forge « Seconde chance »).
var revives_left: int = 0

## Modificateurs fixes du personnage choisi (figés au début de la run).
var character_mods: Dictionary = {}
## Bonus dynamiques des passifs (Marque de Caïn, fuite de Loth...).
var character_bonus: Dictionary = {}


func _ready() -> void:
	GameEvents.enemy_died.connect(_on_enemy_died)


func reset_run() -> void:
	WaveMods.clear_current()
	# Relu à chaque run : armer le Déchaînement à la Forge puis lancer une partie
	# doit suffire, sans passer par un second interrupteur.
	unleashed = SaveGame.is_unleashed(Characters.selected_id)
	souls = Forge.get_start_souls()
	keys = 0
	wave = 0
	kills = 0
	run_time = 0.0
	is_running = true
	owned_counts.clear()
	owned_items.clear()
	character_bonus.clear()
	leftover_souls = 0
	leftover_count = 0
	revives_left = int(Forge.get_special_total(&"revive"))
	var character := Characters.get_selected()
	character_mods = character.starting_mods.duplicate() if character != null else {}
	recompute_stats()
	souls_changed.emit(souls)
	keys_changed.emit(keys)
	run_reset.emit()


## Le damné a changé en cours de run : ses modificateurs de départ remplacent
## ceux du précédent, ses bonus de passif repartent de zéro, et la Forge — lue
## en direct sur le personnage sélectionné — suit d'elle-même. Les objets, les
## âmes et les clés appartiennent à la run, pas au personnage : ils restent.
func swap_character() -> void:
	var character := Characters.get_selected()
	character_mods = character.starting_mods.duplicate() if character != null else {}
	character_bonus.clear()
	recompute_stats()


func end_run() -> void:
	if not is_running:
		return
	is_running = false
	# Seules les clés sont capitalisées entre les runs.
	SaveGame.add_keys(keys)
	SaveGame.register_run_result(wave)
	run_ended.emit(get_summary())


func get_summary() -> Dictionary:
	return {
		"wave": wave,
		"kills": kills,
		"time": run_time,
		"keys": keys,
		"items": owned_items.size(),
	}


# --- Monnaies ---

func add_souls(amount: int) -> void:
	if amount == 0:
		return
	souls = maxi(0, souls + amount)
	souls_changed.emit(souls)


func spend_souls(amount: int) -> bool:
	if amount > souls:
		return false
	souls -= amount
	souls_changed.emit(souls)
	return true


func add_keys(amount: int) -> void:
	if amount <= 0:
		return
	keys += amount
	keys_changed.emit(keys)


## Consomme une seconde chance. Retourne false s'il n'en reste pas.
func consume_revive() -> bool:
	if revives_left <= 0:
		return false
	revives_left -= 1
	return true


# --- Inventaire ---

## Piles maximales d'un objet. Déchaîné, elles sont MULTIPLIÉES.
##
## Sans ça, le mode ne tiendrait pas sa promesse : le catalogue entier au maximum
## de piles n'atteint même pas la plupart des plafonds actuels, donc les lever ne
## servirait à rien tant que le nombre d'exemplaires reste le vrai frein. C'est
## la mesure qui l'a montré, pas l'intuition.
const PILES_DECHAINEES := 4


func get_max_stacks(item: ItemData) -> int:
	if item == null:
		return 0
	# Les objets à effet scripté restent UNIQUES même déchaînés : ils sont
	# écrits pour un exemplaire, et les empiler ne les renforcerait pas — ça
	# déclencherait le même effet plusieurs fois sur le même événement.
	if item.special != &"":
		return item.max_stacks
	return item.max_stacks * PILES_DECHAINEES if unleashed else item.max_stacks


func can_take(item: ItemData) -> bool:
	return item != null and int(owned_counts.get(item.id, 0)) < get_max_stacks(item)


func add_item(item: ItemData) -> void:
	if not can_take(item):
		return
	owned_counts[item.id] = int(owned_counts.get(item.id, 0)) + 1
	owned_items.append(item)
	recompute_stats()
	item_gained.emit(item, int(owned_counts[item.id]))


## REVENTE : retire UN exemplaire. Retourne false s'il n'y en avait pas.
##
## La boutique rend la moitié du prix de base — jamais le prix payé, qui monte
## avec la vague et la richesse. Revendre est donc toujours une perte sèche, et
## ne peut pas servir de robinet à âmes : c'est une sortie de secours pour une
## build enfermée, pas une source de revenu.
##
## On retire la DERNIÈRE occurrence : les exemplaires d'un même objet sont
## identiques (même ressource partagée), donc lequel part n'a aucune
## conséquence, mais parcourir à l'envers évite de décaler ce qu'on n'a pas
## encore lu.
func remove_item(item: ItemData) -> bool:
	if item == null:
		return false
	var reste := int(owned_counts.get(item.id, 0)) - 1
	if reste < 0:
		return false
	if reste == 0:
		owned_counts.erase(item.id)
	else:
		owned_counts[item.id] = reste
	for i in range(owned_items.size() - 1, -1, -1):
		if owned_items[i] != null and owned_items[i].id == item.id:
			owned_items.remove_at(i)
			break
	# Recalcul complet : les effets scriptés sont reconstruits depuis
	# l'inventaire, donc vendre le dernier exemplaire retire bien son `special`.
	recompute_stats()
	item_lost.emit(item, reste)
	return true


func has_special(key: StringName) -> bool:
	return stats.has_special(key)


## Recalcule intégralement les stats. Toujours repartir de zéro : additionner
## des deltas au fil de l'eau finit toujours par dériver.
##
## Quatre sources, TOUTES additives dans les mêmes pools plafonnés : Forge
## (permanent), malédictions (toute la run), pacte de vague (une vague), objets.
## Aucune n'a de canal de scaling qui lui soit propre.
func recompute_stats() -> void:
	stats.clear()
	# Posé ICI et à chaque recalcul, parce que `clear()` ne le remet pas : il
	# n'est pas un modificateur mais un régime de lecture.
	stats.uncapped = unleashed
	for key in character_mods:
		stats.add_mod(String(key), float(character_mods[key]))
	for key in character_bonus:
		stats.add_mod(String(key), float(character_bonus[key]))
	for key in Forge.get_bonus_mods():
		stats.add_mod(String(key), float(Forge.get_bonus_mods()[key]))
	for key in Curses.get_reward_mods():
		stats.add_mod(String(key), float(Curses.get_reward_mods()[key]))
	for key in WaveMods.get_reward_mods():
		stats.add_mod(String(key), float(WaveMods.get_reward_mods()[key]))
	for item in owned_items:
		for key in item.mods:
			stats.add_mod(String(key), float(item.mods[key]))
		if item.special != &"":
			stats.specials[item.special] = true
	if has_special(&"reaper_stacks"):
		stats.damage_pct += get_reaper_bonus()
	stats.damage_pct += get_conversion_armure()
	stats_recomputed.emit(stats)


## « Vieilles blessures » (branche de Job) : l'armure se convertit en dégâts.
##
## Appliqué APRÈS la somme des sources, parce qu'il porte sur le TOTAL d'armure
## et non sur une contribution. Lu sur `get_armor()`, donc sur l'armure
## réellement utile : au-delà du plafond, l'armure ne protège plus et ne rend
## plus de dégâts non plus — sinon elle deviendrait une statistique de dégâts
## déguisée, sans plafond propre.
func get_conversion_armure() -> float:
	var taux := Forge.get_special_total(&"armor_to_damage")
	return stats.get_armor() * taux if taux > 0.0 else 0.0


## Détail des statistiques par SOURCE, pour la fiche de run.
##
## Recalculé à la demande plutôt que tenu à jour au fil de l'eau : la fiche est
## le seul consommateur et elle ne s'ouvre qu'à la touche.
##
## LES VALEURS SONT BRUTES, SANS PLAFOND, et c'est le point. Les plafonds
## s'appliquent au TOTAL, jamais à une source prise à part. Quand la somme des
## colonnes dépasse le total affiché, la différence est exactement ce que le
## joueur a acheté pour rien — et c'est le genre de chose qu'une fiche doit
## montrer plutôt que laisser deviner.
func get_stat_sources() -> Array:
	var perso := PlayerStats.new()
	_verser(perso, character_mods)
	_verser(perso, character_bonus)

	var forge := PlayerStats.new()
	_verser(forge, Forge.get_bonus_mods())
	# La conversion d'armure est portée au crédit de la Forge : c'est un de ses
	# nœuds qui la crée, même si elle se calcule sur l'armure de toutes les
	# sources réunies.
	forge.damage_pct += get_conversion_armure()

	# Malédictions et pactes de vague sont réunis : ce sont les deux leviers de
	# risque volontaire, l'un sur la run, l'autre sur une seule vague.
	var pactes := PlayerStats.new()
	_verser(pactes, Curses.get_reward_mods())
	_verser(pactes, WaveMods.get_reward_mods())

	# Les objets sacrés sont comptés à part : ce sont ceux qu'on ouvre avec des
	# CLÉS, donc les seuls dont le prix se paie en runs précédentes. Les mêler
	# aux objets de boutique effacerait ce que les clés ont acheté.
	var sacres := PlayerStats.new()
	var objets := PlayerStats.new()
	for item in owned_items:
		_verser(sacres if item.key_cost > 0 else objets, item.mods)
	# La Griffe du moissonneur compte dans les objets : c'est un objet de
	# boutique qui la donne, et il ne coûte aucune clé.
	if has_special(&"reaper_stacks"):
		objets.damage_pct += get_reaper_bonus()

	return [
		["Personnage", perso],
		["Forge", forge],
		["Sacrés", sacres],
		["Objets", objets],
		["Pactes", pactes],
	]


func _verser(cible: PlayerStats, mods: Dictionary) -> void:
	for key in mods:
		cible.add_mod(String(key), float(mods[key]))


## Écrit un bonus de passif et ne recalcule que s'il a réellement changé.
func set_character_bonus(key: StringName, value: float) -> void:
	var previous := float(character_bonus.get(key, 0.0))
	if is_equal_approx(previous, value):
		return
	if is_zero_approx(value):
		character_bonus.erase(key)
	else:
		character_bonus[key] = value
	recompute_stats()


func get_reaper_bonus() -> float:
	var stacks := float(kills / REAPER_KILLS_PER_STACK)
	return minf(stacks * REAPER_PCT_PER_STACK, REAPER_MAX_PCT)


func _on_enemy_died(_enemy: Node2D, _position: Vector2) -> void:
	kills += 1
	# Le bonus est plafonné : inutile de recalculer une fois le plafond atteint.
	if has_special(&"reaper_stacks") and kills % REAPER_KILLS_PER_STACK == 0:
		if get_reaper_bonus() < REAPER_MAX_PCT + REAPER_PCT_PER_STACK:
			recompute_stats()


func _process(delta: float) -> void:
	if is_running:
		run_time += delta
