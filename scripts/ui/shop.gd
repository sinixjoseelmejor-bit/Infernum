extends CanvasLayer
## Boutique d'entre-deux-vagues.
##
## Les objets s'ACHÈTENT avec des âmes au lieu d'être offerts : c'est le
## régulateur principal de la puissance. Le joueur ne peut pas tout prendre, il
## doit choisir un axe — et c'est ce choix forcé qui empêche l'accumulation
## simultanée de tous les stats multiplicatifs.

const OFFER_SIZE := 4
const REROLL_BASE_COST := 12
const REROLL_COST_GROWTH := 12
## Les prix suivent DEUX courbes, parce que le revenu en âmes croît beaucoup plus
## vite que la difficulté : le nombre d'ennemis par vague est multiplié par ~14
## entre les vagues 1 et 20, et la valeur unitaire monte encore avec les élites.
## Sans la seconde courbe, le joueur pouvait s'offrir une dizaine d'objets par
## vague en fin de partie, ce qui supprimait tout arbitrage.
const COST_WAVE_GROWTH := 0.15
## Renchérissement par objet déjà possédé : plus la build est avancée, plus
## chaque ajout coûte cher. Maintient ~2-3 achats par vague sur toute la run.
## La composante QUADRATIQUE est le frein de la boucle de rétroaction : plus de
## puissance = plus de kills = plus d'âmes = plus de puissance. Une courbe
## linéaire ne rattrape jamais cette boucle, et une run cumulant malédictions et
## pactes de densité finissait avec 3 fois la puissance d'une run normale.
const COST_PER_OWNED_ITEM := 0.06
const COST_PER_OWNED_ITEM_SQ := 0.0035

@onready var offer_row: HFlowContainer = %OfferRow
@onready var pact_row: HFlowContainer = %PactRow
@onready var pact_status: Label = %PactStatus
@onready var souls_label: Label = %ShopSoulsLabel
@onready var wave_label: Label = %ShopWaveLabel
@onready var reroll_button: Button = %RerollButton
@onready var continue_button: Button = %ContinueButton

var _cards: Array[ItemCard] = []
var _pact_buttons: Array[Button] = []
var _rerolls: int = 0
var _open: bool = false


func _ready() -> void:
	# La boutique doit rester interactive alors que le jeu est en pause.
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	visible = false
	reroll_button.pressed.connect(_on_reroll_pressed)
	continue_button.pressed.connect(close)
	GameEvents.wave_cleared.connect(_on_wave_cleared)
	RunState.souls_changed.connect(_on_souls_changed)


func _on_wave_cleared(_wave: int) -> void:
	if RunState.is_running:
		open()


func open() -> void:
	if _open:
		return
	_open = true
	_rerolls = 0
	visible = true
	get_tree().paused = true
	wave_label.text = "Vague %d terminée" % RunState.wave
	_roll_offer()
	_roll_pacts()
	_refresh()
	GameEvents.shop_opened.emit()
	continue_button.grab_focus()


func close() -> void:
	if not _open:
		return
	_open = false
	visible = false
	get_tree().paused = false
	GameEvents.shop_closed.emit()


## Bouton B de la manette / Échap : retour. Sans ça, un écran ouvert à la manette
## est un cul-de-sac — il n'y a aucun moyen d'en sortir sans souris.
func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


func get_item_cost(item: ItemData) -> int:
	var wave_factor := 1.0 + COST_WAVE_GROWTH * maxf(0.0, RunState.wave - 1.0)
	var owned := float(RunState.owned_items.size())
	var wealth_factor := 1.0 + COST_PER_OWNED_ITEM * owned + COST_PER_OWNED_ITEM_SQ * owned * owned
	return maxi(1, roundi(item.get_base_cost() * wave_factor * wealth_factor))


func get_reroll_cost() -> int:
	return REROLL_BASE_COST + REROLL_COST_GROWTH * _rerolls


func _roll_offer() -> void:
	UIUtils.clear_children(offer_row)
	_cards.clear()

	var offer := ItemDB.roll_offer(
		OFFER_SIZE, maxi(1, RunState.wave), RunState.owned_counts, RunState.stats.get_luck()
	)
	for item in offer:
		var card := ItemCard.new()
		card.buy_requested.connect(_on_buy_requested)
		offer_row.add_child(card)
		card.setup(item, get_item_cost(item))
		_cards.append(card)

	if offer.is_empty():
		var label := Label.new()
		label.text = "Plus rien à vendre : vous avez tout pris."
		offer_row.add_child(label)


func _refresh() -> void:
	souls_label.text = "%d âmes" % RunState.souls
	reroll_button.text = "Relancer (%d âmes)" % get_reroll_cost()
	reroll_button.disabled = RunState.souls < get_reroll_cost() or _cards.is_empty()
	for card in _cards:
		card.set_affordable(RunState.souls >= card.cost)


func _on_buy_requested(item: ItemData) -> void:
	var card := _find_card(item)
	if card == null or card.purchased:
		return
	if not RunState.can_take(item):
		card.mark_purchased()
		return
	if not RunState.spend_souls(card.cost):
		return
	RunState.add_item(item)
	card.mark_purchased()
	_refresh()


func _on_reroll_pressed() -> void:
	var cost := get_reroll_cost()
	if not RunState.spend_souls(cost):
		return
	_rerolls += 1
	_roll_offer()
	_refresh()


## Pactes de vague : proposition facultative, valable pour la prochaine vague.
## Un seul pacte à la fois ; « Aucun pacte » est toujours disponible et gratuit.
func _roll_pacts() -> void:
	UIUtils.clear_children(pact_row)
	_pact_buttons.clear()
	WaveMods.clear_current()

	for mod in WaveMods.roll_offer(RunState.wave + 1, 2):
		var button := Button.new()
		button.theme_type_variation = &"CardButton"
		button.custom_minimum_size = Vector2(300, 88)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.text = "%s
%s
→ %s" % [
			mod["name"], mod["desc"], _format_pact_rewards(mod)]
		button.toggle_mode = true
		var id: StringName = mod["id"]
		button.pressed.connect(func() -> void: _on_pact_pressed(id))
		pact_row.add_child(button)
		_pact_buttons.append(button)

	_refresh_pacts()


func _format_pact_rewards(mod: Dictionary) -> String:
	var parts: Array[String] = []
	for key in mod.get("rewards", {}):
		var value := float(mod["rewards"][key])
		match String(key):
			"soul_gain_pct": parts.append("%+d %% d'âmes" % roundi(value * 100.0))
			"luck": parts.append("+%s chance" % _num(value))
			"range_pct": parts.append("%+d %% de portée" % roundi(value * 100.0))
			_: parts.append("%s %+.2f" % [key, value])
	if float(mod.get("key_chance", 0.0)) > 0.0:
		parts.append("%+d %% de chance de clé" % roundi(float(mod["key_chance"]) * 100.0))
	return ", ".join(parts)


## Même règle que l'écran de malédictions : 0.5 reste « 0,5 ».
func _num(value: float) -> String:
	return str(roundi(value)) if is_equal_approx(value, roundf(value)) 		else String.num(value, 1).replace(".", ",")


func _on_pact_pressed(id: StringName) -> void:
	# Re-cliquer sur le pacte actif l'annule : le refus reste toujours accessible.
	if WaveMods.has_modifier() and WaveMods.current.get("id", &"") == id:
		WaveMods.decline()
	else:
		WaveMods.accept(id)
	_refresh_pacts()


func _refresh_pacts() -> void:
	var active: StringName = WaveMods.current.get("id", &"")
	for i in _pact_buttons.size():
		var mod: Dictionary = WaveMods.offer[i] if i < WaveMods.offer.size() else {}
		_pact_buttons[i].button_pressed = mod.get("id", &"") == active
	if active == &"":
		pact_status.text = "Aucun pacte — la vague suivante se joue normalement."
		pact_status.add_theme_color_override(&"font_color", Color(0.68, 0.64, 0.64))
	else:
		pact_status.text = "Pacte actif : %s (une vague)" % WaveMods.current["name"]
		pact_status.add_theme_color_override(&"font_color", Color(1, 0.55, 0.3))


func _on_souls_changed(_amount: int) -> void:
	if _open:
		_refresh()


func _find_card(item: ItemData) -> ItemCard:
	for card in _cards:
		if card.item == item:
			return card
	return null
