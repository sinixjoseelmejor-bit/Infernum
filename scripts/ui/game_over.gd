extends CanvasLayer
## Fin de run : bilan, versement des clés, et panneau de déblocage permanent.
##
## Les âmes non dépensées sont perdues (elles ne doivent pas devenir une épargne
## inter-runs qui trivialise les premières vagues suivantes) ; les clés, elles,
## sont capitalisées et servent à élargir le pool d'objets.

@onready var title_label: Label = %GameOverTitle
@onready var summary_label: Label = %SummaryLabel
@onready var keys_label: Label = %BankedKeysLabel
@onready var unlock_list: VBoxContainer = %UnlockList
@onready var restart_button: Button = %RestartButton
@onready var forge_button: Button = %ForgeButton
@onready var menu_button: Button = %MenuButton

## Renseigné par main.gd : l'écran de fin ne connaît pas la Forge autrement.
var forge_screen: CanvasLayer

var _open: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	visible = false
	restart_button.pressed.connect(_on_restart_pressed)
	forge_button.pressed.connect(_on_forge_pressed)
	menu_button.pressed.connect(_on_menu_pressed)
	GameEvents.player_died.connect(_on_player_died)
	SaveGame.keys_changed.connect(func(_total: int) -> void: _refresh_unlocks())


func _on_player_died(_player: Node2D) -> void:
	if _open:
		return
	_open = true
	var summary := RunState.get_summary()
	RunState.end_run()
	# Petit délai : la mort du joueur doit rester lisible avant le bilan.
	await get_tree().create_timer(1.2).timeout
	_show(summary)


func _show(summary: Dictionary) -> void:
	visible = true
	get_tree().paused = true
	title_label.text = "VOUS ÊTES MORT"
	summary_label.text = "Vague %d  ·  %d éliminations  ·  %s\n%d objets  ·  %d clés récoltées" % [
		summary["wave"],
		summary["kills"],
		HUD._format_time(summary["time"]),
		summary["items"],
		summary["keys"],
	]
	_refresh_unlocks()
	restart_button.grab_focus()


func _refresh_unlocks() -> void:
	keys_label.text = "Clés disponibles : %d   ·   Meilleure vague : %d" % [
		SaveGame.banked_keys, SaveGame.best_wave
	]
	UIUtils.clear_children(unlock_list)

	var locked := ItemDB.get_locked()
	if locked.is_empty():
		var done := Label.new()
		done.text = "Tout le contenu est débloqué."
		unlock_list.add_child(done)
		return

	for item in locked:
		unlock_list.add_child(_build_unlock_row(item))


func _build_unlock_row(item: ItemData) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 12)

	var label := Label.new()
	label.text = "%s — %s" % [item.display_name, item.description]
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_color_override(&"font_color", item.get_rarity_color())
	label.add_theme_font_size_override(&"font_size", 14)
	row.add_child(label)

	var button := Button.new()
	button.text = "%d clés" % item.key_cost
	button.disabled = SaveGame.banked_keys < item.key_cost
	button.pressed.connect(func() -> void: SaveGame.unlock_item(item))
	row.add_child(button)
	return row


func _on_forge_pressed() -> void:
	if forge_screen != null:
		forge_screen.call(&"open")


func _on_menu_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")


func _on_restart_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()
