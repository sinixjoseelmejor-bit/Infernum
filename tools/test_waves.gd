extends Node
## Tests des courbes de vague : ce que les bancs d'essai mesuraient à la main,
## vérifié à chaque lancement.
##
##   godot --headless --path . res://tools/test_waves.tscn
##
## Code de sortie 0 si tout passe, 1 sinon. Exclu des paquets joueurs avec le
## reste de `tools/`.
##
## Les valeurs attendues sont celles du jeu AVANT la restructuration du
## WaveManager, mesurées par banc sur l'ancienne version : un écart ici est un
## changement d'équilibrage, pas un détail.
##
## Tourne dans une scène et non en `-s` : les scènes d'ennemis et de boss
## référencent des autoloads, que le mode script ne charge pas.

const BOSS_SCENES := [
	"res://scenes/bosses/golgota.tscn",
	"res://scenes/bosses/lilith.tscn",
	"res://scenes/bosses/baal.tscn",
	"res://scenes/bosses/asmodee.tscn",
	"res://scenes/bosses/lucifer.tscn",
]
const BOSS_INTERVAL := 5
const ROSTER_PATH := "res://scenes/main/enemy_roster.tres"
const EPSILON := 0.0005

var _passed := 0
var _failed := 0


func _ready() -> void:
	_test_enemy_curves()
	_test_unleashed_curves()
	_test_effective_caps()
	_test_boss_rotation()
	_test_boss_scaling()
	_test_unleashed_boss_ratio()
	_test_roster()
	_test_leftover_harvest()
	print("\ntest_waves : %d réussis, %d échoués" % [_passed, _failed])
	get_tree().quit(1 if _failed > 0 else 0)


func _test_enemy_curves() -> void:
	var c := DifficultyCurve.new()
	_near("durée vague 1", c.wave_duration(1), 20.0)
	_near("durée plafonnée", c.wave_duration(50), 45.0)
	_near("PV vague 1", c.health_multiplier(1, false), 1.0)
	_near("PV vague 15, avant la seconde pente", c.health_multiplier(15, false), 2.4)
	_near("PV vague 16, seconde pente", c.health_multiplier(16, false), 2.59)
	_near("PV vague 20 (en-tête : ×3,35)", c.health_multiplier(20, false), 3.35)
	_near("dégâts vague 20", c.damage_multiplier(20, false), 2.805)
	_near("vitesse plafonnée", c.speed_multiplier(40), 1.35)
	_near("densité vague 1", c.spawn_rate(1), 0.8)
	_near("pas d'élite avant la vague 4", c.elite_chance(3, false), 0.0)
	_near("élites dès la vague 4", c.elite_chance(4, false), 0.02)
	_near("malédiction : élites dès la vague 1", c.elite_chance(1, true), 0.02)
	_near("malédictions et pactes multiplient", c.spawn_rate(10, 2.0), 2.0 * (0.8 + 0.19 * 9))


func _test_unleashed_curves() -> void:
	var c := DifficultyCurve.new()
	_near("Déchaînement : PV vague 30",
		c.health_multiplier(30, true), c.health_multiplier(30, false) * pow(1.15, 30))
	_near("Déchaînement : dégâts vague 30",
		c.damage_multiplier(30, true), c.damage_multiplier(30, false) * pow(1.08, 30))
	_near("hors Déchaînement, facteur neutre", DifficultyCurve.unleashed_health_factor(40, false), 1.0)


## Deux plafonds : la base s'arrête d'elle-même, les options gardent TOUJOURS de
## quoi ajouter du risque. README, « Une option doit toujours coûter ».
func _test_effective_caps() -> void:
	var c := DifficultyCurve.new()
	_near("élites, vague 10, sous le plafond : inchangé", c.elite_chance(10, false), 0.14)
	_near("élites sans option : plafond 18 %", c.elite_chance(100, false), 0.18)
	_near("Nuée d'élites en fin de partie : 31,5 %", c.elite_chance(100, false, 3.0), 0.315)
	_near("Œil du vide vague 19 : coûte encore", c.elite_chance(19, true, 2.0), 0.315)
	_near("densité sans option : plafond 6/s", c.spawn_rate(100), 6.0)
	_near("Horde en fin de partie : 8,7/s", c.spawn_rate(100, 1.45), 8.7)
	_near("densité avec options : plafond 9/s", c.spawn_rate(100, 3.0), 9.0)


func _test_boss_rotation() -> void:
	_check("vague 5 : Golgota, 1er tour", WaveManager.boss_rotation(5, 5, 5) == Vector2i(0, 0))
	_check("vague 25 : Lucifer, 1er tour", WaveManager.boss_rotation(25, 5, 5) == Vector2i(4, 0))
	_check("vague 30 : Golgota, 2e tour", WaveManager.boss_rotation(30, 5, 5) == Vector2i(0, 1))
	_check("vague 55 : Golgota, 3e tour", WaveManager.boss_rotation(55, 5, 5) == Vector2i(0, 2))


## Mesuré par banc sur l'ancien WaveManager (PV, contact, multiplicateur
## d'attaque, cadence).
func _test_boss_scaling() -> void:
	var expected := {
		5: [3800.0, 22.0, 1.0, 1.0],
		10: [8120.0, 20.163, 1.3442, 1.0],
		30: [47125.0, 71.835, 3.2652, 1.15],
		55: [104500.0, 136.814, 6.2188, 1.25],
	}
	var curve := DifficultyCurve.new()
	var boss_curve := BossCurve.new()
	var floor_health := _scene_health(BOSS_SCENES[-1])
	for boss_wave: int in expected:
		var slot := WaveManager.boss_rotation(boss_wave, BOSS_INTERVAL, BOSS_SCENES.size())
		var boss := (load(BOSS_SCENES[slot.x]) as PackedScene).instantiate() as Boss
		var floor_value := floor_health if slot.y > 0 else 0.0
		boss_curve.apply(boss, boss_wave, slot.y, floor_value, BOSS_INTERVAL, curve, false)
		var e: Array = expected[boss_wave]
		_near("boss vague %d : PV" % boss_wave, boss.max_health, e[0], 0.01)
		_near("boss vague %d : contact" % boss_wave, boss.contact_damage, e[1], 0.001)
		_near("boss vague %d : attaque" % boss_wave, boss.attack_damage_multiplier, e[2], 0.0001)
		_near("boss vague %d : cadence" % boss_wave, boss.attack_speed_multiplier, e[3])
		boss.free()


## Le Déchaînement multiplie boss et piétaille par le MÊME facteur : leur rapport
## reste celui du régime normal, à chaque vague.
func _test_unleashed_boss_ratio() -> void:
	var curve := DifficultyCurve.new()
	var boss_curve := BossCurve.new()
	for boss_wave in [30, 40, 55]:
		var normal := boss_curve.health(3800.0, 10000.0, boss_wave, 1, BOSS_INTERVAL, false) \
			/ curve.health_multiplier(boss_wave, false)
		var unleashed := boss_curve.health(3800.0, 10000.0, boss_wave, 1, BOSS_INTERVAL, true) \
			/ curve.health_multiplier(boss_wave, true)
		_near("rapport boss/piétaille identique, vague %d" % boss_wave, unleashed / normal, 1.0)


func _test_roster() -> void:
	var roster := load(ROSTER_PATH) as EnemyRoster
	_check("roster chargé, 5 types", roster != null and roster.entries.size() == 5)
	if roster == null:
		return
	var imp := roster.entries[0].scene
	var only_imps := true
	for i in 100:
		only_imps = only_imps and roster.pick(1, i / 100.0) == imp
	_check("vague 1 : que des imps", only_imps)
	var oeil := roster.entries[4]
	_near("l'Œil absent à la vague 10", oeil.weight_at(10), 0.0)
	_near("l'Œil entre à la vague 11", oeil.weight_at(11), 14.0)
	# Poids de l'ancien tableau, recalculés à la vague 20.
	var old_weights := [22.0, 43.0, 47.5, 46.0, 26.6]
	for i in old_weights.size():
		_near("poids vague 20, type %d" % i, roster.entries[i].weight_at(20), old_weights[i])
	_near("l'imp ne descend pas sous zéro", roster.entries[0].weight_at(60), 0.0)

	var late := EnemySpawnEntry.new()
	late.scene = PackedScene.new()
	late.min_wave = 5
	var fallback := EnemyRoster.new()
	fallback.entries.append(late)
	_check("aucun type éligible : repli sur le premier", fallback.pick(1, 0.5) == late.scene)


func _test_leftover_harvest() -> void:
	_near("intact : rien", LeftoverHarvest.souls_owed(3.0, 100.0, 100.0, 0.5), 0.0)
	_near("à moitié, taux 0,5", LeftoverHarvest.souls_owed(3.0, 50.0, 100.0, 0.5), 0.75)
	_near("PV sous zéro bornés", LeftoverHarvest.souls_owed(3.0, -20.0, 100.0, 0.25), 0.75)
	_near("taux nul", LeftoverHarvest.souls_owed(3.0, 0.0, 100.0, 0.0), 0.0)

	# L'exemple du README : quarante imps à moitié entamés. Arrondis un par un,
	# ils rendraient zéro ; cumulés, trente âmes.
	var harvest := LeftoverHarvest.new()
	var dropped := 0
	for i in 40:
		dropped += harvest.add(0.75)
	_check("quarante imps : 30 âmes versées", dropped == 30 and harvest.souls == 30)
	_check("quarante survivants comptés", harvest.survivors == 40)
	_check("un ennemi intact n'est pas compté", LeftoverHarvest.new().add(0.0) == 0)


func _scene_health(path: String) -> float:
	var boss := (load(path) as PackedScene).instantiate() as Boss
	var health := boss.max_health
	boss.free()
	return health


func _near(label: String, actual: float, expected: float, tolerance: float = EPSILON) -> void:
	_check("%s (obtenu %.4f, attendu %.4f)" % [label, actual, expected],
		absf(actual - expected) <= tolerance)


func _check(label: String, ok: bool) -> void:
	if ok:
		_passed += 1
	else:
		_failed += 1
		print("ÉCHEC  ", label)
