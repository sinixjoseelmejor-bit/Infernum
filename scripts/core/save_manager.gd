extends Node
## Progression persistante (autoload `SaveGame`), répartie en PROFILS.
##
## Trois emplacements indépendants, chacun avec ses clés, ses déblocages de Forge
## et ses statistiques. Changer de profil ou en effacer un permet de repartir de
## zéro sans perdre une progression existante — c'est le seul moyen de
## « recommencer », puisque les clés sont irréversibles au sein d'un profil.
##
## Un fichier par profil (`user://infernum_profile_N.cfg`) plus un index
## (`user://infernum_profiles.cfg`) qui retient l'emplacement actif.

signal keys_changed(total: int)
signal item_unlocked(id: StringName)
signal profile_changed(slot: int)

const PROFILE_COUNT := 3
const INDEX_PATH := "user://infernum_profiles.cfg"

var active_slot: int = 0
var profile_name: String = ""
var banked_keys: int = 0
var best_wave: int = 0
var total_runs: int = 0
var last_character: StringName = &""

var _unlocked: Dictionary = {}


func _ready() -> void:
	var index := ConfigFile.new()
	if index.load(INDEX_PATH) == OK:
		active_slot = clampi(int(index.get_value("index", "active_slot", 0)), 0, PROFILE_COUNT - 1)
	load_profile(active_slot, false)


# --- Profils -----------------------------------------------------------------

static func get_profile_path(slot: int) -> String:
	return "user://infernum_profile_%d.cfg" % slot


static func get_default_name(slot: int) -> String:
	return "Profil %d" % (slot + 1)


func profile_exists(slot: int) -> bool:
	return FileAccess.file_exists(get_profile_path(slot))


## Lit un profil SANS l'activer : sert à afficher la liste dans le menu.
func get_profile_summary(slot: int) -> Dictionary:
	var summary := {
		"slot": slot,
		"exists": profile_exists(slot),
		"name": get_default_name(slot),
		"keys": 0, "best_wave": 0, "total_runs": 0, "forge_nodes": 0,
	}
	if not summary["exists"]:
		return summary
	var config := ConfigFile.new()
	if config.load(get_profile_path(slot)) != OK:
		return summary
	summary["name"] = config.get_value("meta", "profile_name", get_default_name(slot))
	summary["keys"] = config.get_value("meta", "banked_keys", 0)
	summary["best_wave"] = config.get_value("meta", "best_wave", 0)
	summary["total_runs"] = config.get_value("meta", "total_runs", 0)
	summary["forge_nodes"] = (config.get_value("meta", "unlocked", []) as Array).size()
	return summary


func get_all_summaries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for slot in PROFILE_COUNT:
		result.append(get_profile_summary(slot))
	return result


## Active un emplacement. Un emplacement vide démarre une progression neuve.
func load_profile(slot: int, notify: bool = true) -> void:
	active_slot = clampi(slot, 0, PROFILE_COUNT - 1)
	_reset_memory()

	var config := ConfigFile.new()
	if config.load(get_profile_path(active_slot)) == OK:
		profile_name = config.get_value("meta", "profile_name", get_default_name(active_slot))
		banked_keys = config.get_value("meta", "banked_keys", 0)
		best_wave = config.get_value("meta", "best_wave", 0)
		total_runs = config.get_value("meta", "total_runs", 0)
		last_character = StringName(config.get_value("meta", "last_character", ""))
		for id in config.get_value("meta", "unlocked", []):
			_unlocked[StringName(id)] = true

	_save_index()
	if notify:
		profile_changed.emit(active_slot)
		keys_changed.emit(banked_keys)


## Efface définitivement un profil. Si c'est le profil actif, il redevient neuf.
func delete_profile(slot: int) -> void:
	var path := get_profile_path(slot)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if slot == active_slot:
		load_profile(slot)


func rename_profile(new_name: String) -> void:
	profile_name = new_name.strip_edges()
	if profile_name == "":
		profile_name = get_default_name(active_slot)
	save_game()
	profile_changed.emit(active_slot)


func _reset_memory() -> void:
	profile_name = get_default_name(active_slot)
	banked_keys = 0
	best_wave = 0
	total_runs = 0
	last_character = &""
	_unlocked.clear()


# --- Déblocages et monnaie ---------------------------------------------------

func is_unlocked(id: StringName) -> bool:
	return _unlocked.has(id)


func get_unlocked_ids() -> Array:
	return _unlocked.keys()


func add_keys(amount: int) -> void:
	if amount <= 0:
		return
	banked_keys += amount
	keys_changed.emit(banked_keys)
	save_game()


## Débite des clés. Retourne false si le solde est insuffisant.
func spend_keys(amount: int) -> bool:
	if amount <= 0 or banked_keys < amount:
		return false
	banked_keys -= amount
	keys_changed.emit(banked_keys)
	save_game()
	return true


## Marque un identifiant comme débloqué (objet ou nœud de Forge : les deux
## partagent le même registre, les identifiants ne se recoupent pas).
func unlock_id(id: StringName) -> void:
	if _unlocked.has(id):
		return
	_unlocked[id] = true
	item_unlocked.emit(id)
	save_game()


## Reverrouille des identifiants. RÉSERVÉ AU PANNEAU DE DÉVELOPPEMENT.
##
## Prend une LISTE explicite et ne vide jamais le registre en entier : objets et
## nœuds de Forge le partagent, et « réinitialiser la Forge » ne doit pas
## reverrouiller les objets achetés au fil des runs.
func dev_lock_ids(ids: Array) -> void:
	var touche := false
	for id in ids:
		if _unlocked.erase(id):
			touche = true
	if touche:
		save_game()


## Tente de débloquer un objet. Retourne false si clés insuffisantes.
func unlock_item(item: ItemData) -> bool:
	if item == null or item.key_cost <= 0 or is_unlocked(item.id):
		return false
	if not spend_keys(item.key_cost):
		return false
	unlock_id(item.id)
	return true


func set_last_character(id: StringName) -> void:
	last_character = id
	save_game()


func register_run_result(wave_reached: int) -> void:
	total_runs += 1
	best_wave = maxi(best_wave, wave_reached)
	save_game()


# --- Écriture ----------------------------------------------------------------

func save_game() -> void:
	var config := ConfigFile.new()
	config.set_value("meta", "profile_name", profile_name)
	config.set_value("meta", "banked_keys", banked_keys)
	config.set_value("meta", "best_wave", best_wave)
	config.set_value("meta", "total_runs", total_runs)
	config.set_value("meta", "last_character", String(last_character))
	config.set_value("meta", "unlocked", _unlocked.keys())
	var err := config.save(get_profile_path(active_slot))
	if err != OK:
		push_warning("SaveGame : échec de la sauvegarde (%d)" % err)


func _save_index() -> void:
	var index := ConfigFile.new()
	index.set_value("index", "active_slot", active_slot)
	index.save(INDEX_PATH)


## Utilitaire de test / debug : remet le profil actif à neuf.
func wipe() -> void:
	_reset_memory()
	save_game()
	keys_changed.emit(banked_keys)
