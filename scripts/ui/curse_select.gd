extends CanvasLayer
## Sélection des malédictions, au démarrage d'une run.
##
## Écran volontairement « sautable » : le bouton par défaut est « Commencer sans
## malédiction » et il a le focus. Aucune malédiction n'est cochée par défaut, et
## la run de référence est justement celle-là.

signal confirmed()

@onready var list: VBoxContainer = %CurseList
@onready var danger_label: Label = %DangerLabel
@onready var start_button: Button = %StartRunButton

var _rows: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	start_button.pressed.connect(_on_start_pressed)
	Curses.curses_changed.connect(_refresh)


func open() -> void:
	Curses.clear_all()
	visible = true
	get_tree().paused = true
	_build()
	_refresh()
	UIUtils.chain_focus(self)
	start_button.grab_focus()


func _build() -> void:
	UIUtils.clear_children(list)
	_rows.clear()

	for curse in Curses.CURSES:
		var check := CheckBox.new()
		check.text = "%s  —  %s" % [curse["name"], curse["penalty"]]
		check.add_theme_font_size_override(&"font_size", 17)
		check.tooltip_text = curse["desc"]
		var id: StringName = curse["id"]
		check.toggled.connect(func(_pressed: bool) -> void: Curses.toggle(id))
		list.add_child(check)
		_rows[id] = check

		var reward := Label.new()
		reward.text = "        en échange : " + _format_rewards(curse)
		reward.add_theme_font_size_override(&"font_size", 13)
		reward.add_theme_color_override(&"font_color", Color(0.56, 0.94, 1))
		list.add_child(reward)


func _format_rewards(curse: Dictionary) -> String:
	var parts: Array[String] = []
	var rewards: Dictionary = curse.get("rewards", {})
	for key in rewards:
		var value := float(rewards[key])
		match String(key):
			"soul_gain_pct": parts.append("%+d %% d'âmes" % roundi(value * 100.0))
			"luck": parts.append("+%s chance (raretés)" % _num(value))
			"max_health_flat":
				# Un malus de PV est déjà affiché comme pénalité : ne pas le
				# répéter dans la ligne « en échange ».
				if value > 0.0:
					parts.append("%+d PV max" % roundi(value))
			_: parts.append("%s %+.2f" % [key, value])
	if float(curse.get("key_chance", 0.0)) > 0.0:
		parts.append("%+d %% de chance de clé" % roundi(float(curse["key_chance"]) * 100.0))
	return ", ".join(parts)


## 1.5 doit s'afficher « 1,5 » et non « 2 » : arrondir masquait la valeur réelle.
func _num(value: float) -> String:
	return str(roundi(value)) if is_equal_approx(value, roundf(value)) 		else String.num(value, 1).replace(".", ",")


func _refresh() -> void:
	var danger := Curses.get_danger()
	if danger == 0:
		danger_label.text = "Aucune malédiction — run de référence."
		start_button.text = "Commencer sans malédiction"
	else:
		danger_label.text = "Danger %d  ·  %d malédiction(s) active(s)" % [
			danger, Curses.active.size()]
		start_button.text = "Commencer (danger %d)" % danger


func _on_start_pressed() -> void:
	visible = false
	get_tree().paused = false
	RunState.recompute_stats()
	confirmed.emit()
