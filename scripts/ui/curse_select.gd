extends CanvasLayer
## Sélection des malédictions, au démarrage d'une run.
##
## Écran volontairement « sautable » : le bouton par défaut est « Commencer sans
## malédiction » et il a le focus. Aucune malédiction n'est cochée par défaut, et
## la run de référence est justement celle-là.

signal confirmed()

@onready var list: GridContainer = %CurseList
@onready var scroll: ScrollContainer = %Scroll
@onready var danger_label: Label = %DangerLabel
@onready var start_button: Button = %StartRunButton

const CURSE_COLOR := Color(0.83, 0.42, 0.92)
const PRICE_COLOR := Color(1.0, 0.52, 0.42)
const GAIN_COLOR := Color(0.56, 0.94, 1.0)
## Une carte : la hauteur loge la plus longue description sur deux lignes.
const CARD_MIN_SIZE := Vector2(380, 176)

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
		var card := _build_card(curse)
		list.add_child(card)
		_rows[curse["id"]] = card
	_fit_scroll.call_deferred()


## UNE CARTE PAR MALÉDICTION, et le prix en face du gain. L'ancienne liste
## empilait onze barres dorées identiques, avec la récompense en petit texte
## cyan dessous : on lisait mal ce qu'on gagnait, et plus mal encore ce qui était
## coché. La carte cochée s'allume comme celle du personnage choisi.
func _build_card(curse: Dictionary) -> Button:
	var id: StringName = curse["id"]
	var card := Button.new()
	card.name = "malediction_%s" % id
	card.theme_type_variation = &"CardButton"
	card.toggle_mode = true
	card.custom_minimum_size = CARD_MIN_SIZE
	card.tooltip_text = curse["desc"]
	card.toggled.connect(func(_pressed: bool) -> void: Curses.toggle(id))

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override(StringName("margin_" + side), 14)
	card.add_child(margin)

	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override(&"separation", 4)
	margin.add_child(box)

	var head := HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(head)
	var title := _label(curse["name"], 30, CURSE_COLOR)
	title.theme_type_variation = &"TitleLabel"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	head.add_child(_label("Danger %d" % int(curse.get("danger", 0)), 15, Color(0.72, 0.62, 0.7)))

	var desc := _label(curse["desc"], 14, Color(0.7, 0.67, 0.68))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(desc)
	var price := _label("Prix : %s" % curse["penalty"], 17, PRICE_COLOR)
	price.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(price)
	var gain := _label("Gain : %s" % _format_rewards(curse), 17, GAIN_COLOR)
	gain.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(gain)
	return card


func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override(&"font_size", size)
	label.add_theme_color_override(&"font_color", color)
	return label


## Même règle que la Forge : la zone prend la hauteur de ses cartes, au lieu
## d'une valeur écrite à la main qui coupe dès qu'un texte s'allonge.
##
## Mesurée après une image de mise en page, pour que les textes à retour à la
## ligne aient déjà leur largeur (voir `Shop._fit_body`).
func _fit_scroll() -> void:
	await get_tree().process_frame
	scroll.custom_minimum_size.y = list.get_combined_minimum_size().y


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
	for id in _rows:
		(_rows[id] as Button).set_pressed_no_signal(Curses.active.has(id))
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
