class_name HUD
extends CanvasLayer
## Affichage tête haute : vie, vague en cours, minuteur, monnaies, éliminations.

@onready var health_bar: ProgressBar = %HealthBar
@onready var health_label: Label = %HealthLabel
@onready var wave_label: Label = %WaveLabel
@onready var wave_timer_label: Label = %WaveTimerLabel
@onready var souls_label: Label = %SoulsLabel
@onready var keys_label: Label = %KeysLabel
@onready var kills_label: Label = %KillsLabel
@onready var boss_panel: Control = %BossPanel
@onready var boss_name_label: Label = %BossNameLabel
@onready var boss_bar: ProgressBar = %BossBar
@onready var boss_phase_label: Label = %BossPhaseLabel

var wave_manager: WaveManager


func _ready() -> void:
	GameEvents.player_health_changed.connect(_on_health_changed)
	GameEvents.enemy_died.connect(_on_enemy_died)
	GameEvents.wave_started.connect(_on_wave_started)
	GameEvents.wave_cleared.connect(_on_wave_cleared)
	RunState.souls_changed.connect(_on_souls_changed)
	RunState.keys_changed.connect(_on_keys_changed)

	boss_panel.visible = false
	GameEvents.boss_spawned.connect(_on_boss_spawned)
	GameEvents.boss_health_changed.connect(_on_boss_health_changed)
	GameEvents.boss_phase_changed.connect(_on_boss_phase_changed)
	GameEvents.boss_enraged.connect(_on_boss_enraged)
	GameEvents.boss_died.connect(_on_boss_died)

	_on_souls_changed(RunState.souls)
	_on_keys_changed(RunState.keys)
	kills_label.text = "0"


func bind_wave_manager(manager: WaveManager) -> void:
	wave_manager = manager


func _process(_delta: float) -> void:
	if wave_manager == null:
		return
	match wave_manager.state:
		WaveManager.State.RUNNING:
			# Une vague de boss n'a pas de compte à rebours : elle dure le combat.
			if wave_manager.is_boss_wave():
				wave_timer_label.text = "BOSS  ·  %s" % _format_time(wave_manager.time_left)
			else:
				wave_timer_label.text = _format_time(wave_manager.time_left)
		WaveManager.State.INTERMISSION:
			wave_timer_label.text = "PRÉPAREZ-VOUS"
		_:
			wave_timer_label.text = "--:--"


static func _format_time(seconds: float) -> String:
	var total := maxi(0, ceili(seconds))
	return "%d:%02d" % [total / 60, total % 60]


func _on_health_changed(current: float, maximum: float) -> void:
	health_bar.max_value = maximum
	health_bar.value = current
	health_label.text = "%d / %d" % [roundi(current), roundi(maximum)]


func _on_enemy_died(_enemy: Node2D, _position: Vector2) -> void:
	kills_label.text = str(RunState.kills)


func _on_wave_started(index: int) -> void:
	wave_label.text = "VAGUE %d" % index


func _on_wave_cleared(_index: int) -> void:
	wave_timer_label.text = "VAGUE TERMINÉE"


func _on_boss_spawned(boss: Node2D) -> void:
	boss_panel.visible = true
	var subtitle: String = str(boss.get(&"subtitle"))
	boss_name_label.text = str(boss.get(&"boss_name")).to_upper()
	if subtitle != "":
		boss_name_label.text += "  —  " + subtitle
	boss_name_label.add_theme_color_override(&"font_color", Color(1, 0.35, 0.25))
	_on_boss_health_changed(boss.health.current, boss.health.max_health)


func _on_boss_health_changed(current: float, maximum: float) -> void:
	boss_bar.max_value = maximum
	boss_bar.value = current


func _on_boss_phase_changed(phase: int, total: int) -> void:
	boss_phase_label.text = "PHASE %d / %d" % [phase + 1, total]


func _on_boss_enraged(_boss: Node2D) -> void:
	boss_phase_label.text += "  ·  ENRAGÉ"
	boss_phase_label.add_theme_color_override(&"font_color", Color(1, 0.3, 0.2))


func _on_boss_died(_boss: Node2D) -> void:
	boss_panel.visible = false
	boss_phase_label.add_theme_color_override(&"font_color", Color(0.85, 0.8, 0.8))


func _on_souls_changed(amount: int) -> void:
	souls_label.text = "%d âmes" % amount


func _on_keys_changed(amount: int) -> void:
	keys_label.text = "%d clés" % amount
