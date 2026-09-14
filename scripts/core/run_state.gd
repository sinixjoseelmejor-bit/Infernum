extends Node
## État de la run en cours (autoload `RunState`).
##
## Source de vérité unique pour : vague courante, monnaies, inventaire et stats
## agrégées. Tout ce qui est ici meurt avec la run (sauf les clés, qui sont
## versées à `SaveGame` à la fin).

signal souls_changed(amount: int)
signal keys_changed(amount: int)
signal item_gained(item: ItemData, stack_count: int)
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
var wave: int = 0
var kills: int = 0
var run_time: float = 0.0
var is_running: bool = false

## {StringName: int} nombre d'exemplaires possédés par objet.
var owned_counts: Dictionary = {}
var owned_items: Array[ItemData] = []

## Modificateurs fixes du personnage choisi (figés au début de la run).
var character_mods: Dictionary = {}
## Bonus dynamiques des passifs (Marque de Caïn, fuite de Loth...).
var character_bonus: Dictionary = {}


func _ready() -> void:
	GameEvents.enemy_died.connect(_on_enemy_died)


func reset_run() -> void:
	WaveMods.clear_current()
	souls = Forge.get_start_souls()
	keys = 0
	wave = 0
	kills = 0
	run_time = 0.0
	is_running = true
	owned_counts.clear()
	owned_items.clear()
	character_bonus.clear()
	var character := Characters.get_selected()
	character_mods = character.starting_mods.duplicate() if character != null else {}
	recompute_stats()
	souls_changed.emit(souls)
	keys_changed.emit(keys)


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


# --- Inventaire ---

func can_take(item: ItemData) -> bool:
	return item != null and int(owned_counts.get(item.id, 0)) < item.max_stacks


func add_item(item: ItemData) -> void:
	if not can_take(item):
		return
	owned_counts[item.id] = int(owned_counts.get(item.id, 0)) + 1
	owned_items.append(item)
	recompute_stats()
	item_gained.emit(item, int(owned_counts[item.id]))


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
	stats_recomputed.emit(stats)


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
