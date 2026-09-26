class_name StoryDirector
extends Node
## L'histoire dans l'arène : ce qui se joue autour des boss.
##
## Monté par `main.gd`. Il ne fait qu'ORDONNER ce qui existe déjà — le lecteur de
## cinématiques, la boutique, le gestionnaire de vagues, l'écran de fin — dans
## le bon ordre :
##
## - Lucifer apparaît : son entrée, la première fois que CE damné l'atteint.
## - Un boss tombe : sa scène d'après-boss (Lilith), puis la boutique.
## - Lucifer tombe : le sceau de ce damné se brise — sa fin, puis Lucifer qui se
##   relève — et un CHOIX : l'enfer sans fin, ou le portail vers Hélel si les
##   trois sceaux sont brisés.
## - Hélel : les trois damnés se relaient dans un seul corps, au hasard, jusqu'à
##   sa chute. Puis la vraie fin.

const HELEL_SCENE := preload("res://scenes/bosses/helel.tscn")

## Intervalle entre deux changements de corps pendant le combat contre Hélel.
## Assez long pour qu'on ait le temps de JOUER chaque personnage — sa ruée, sa
## parade, sa Marque —, assez court pour qu'aucun ne s'installe.
const SWAP_MIN := 10.0
const SWAP_MAX := 16.0
## Dans l'Aurore, la dernière phase, les âmes se bousculent : le corps change
## deux fois plus souvent, au moment où tout part en même temps.
const SWAP_MIN_AURORE := 5.0
const SWAP_MAX_AURORE := 8.0
const GLITCH_TIME := 0.45

const COULEURS := {
	&"cain": Color(0.85, 0.22, 0.18),
	&"job": Color(0.55, 0.72, 0.85),
	&"loth": Color(0.95, 0.85, 0.5),
}

## Le glitch : le corps « saute » d'une âme à l'autre. L'image se dédouble en
## rouge et cyan et se tranche en bandes décalées, le temps d'un battement.
const GLITCH_SHADER := """
shader_type canvas_item;
uniform sampler2D screen : hint_screen_texture, filter_nearest;
uniform float force = 0.0;
uniform float graine = 0.0;
float hasard(float x) { return fract(sin(x * 91.3458 + graine) * 47453.5453); }
void fragment() {
	vec2 uv = SCREEN_UV;
	float bande = floor(uv.y * 28.0);
	float decalage = (hasard(bande) - 0.5) * 0.08 * force * step(0.55, hasard(bande + 3.0));
	uv.x += decalage;
	float split = 0.012 * force;
	float r = texture(screen, uv + vec2(split, 0.0)).r;
	float g = texture(screen, uv).g;
	float b = texture(screen, uv - vec2(split, 0.0)).b;
	vec3 c = vec3(r, g, b);
	c = mix(c, vec3(1.0, 0.95, 0.8), 0.25 * force * step(0.92, hasard(bande + graine)));
	COLOR = vec4(c, 1.0);
}
"""

var _boss_slain: StringName = &""
var _player: Player
var _waves: WaveManager
var _shop: CanvasLayer
var _game_over: CanvasLayer

var _in_final: bool = false
## Les changements de corps, distincts du combat lui-même : ils cessent dès
## qu'Hélel tombe, alors que le combat ne se CONCLUT qu'après le ramassage du
## butin. Un changement tombé dans cet intervalle restait figé à l'écran par la
## pause de la cinématique, jusque sur l'écran de victoire.
var _swapping: bool = false
var _origin: StringName = &""
var _swap_left: float = 0.0
var _rng := RandomNumberGenerator.new()
var _glitch_layer: CanvasLayer
var _glitch_rect: ColorRect


func setup(player: Player, waves: WaveManager, shop: CanvasLayer, game_over: CanvasLayer) -> void:
	_player = player
	_waves = waves
	_shop = shop
	_game_over = game_over


func _ready() -> void:
	add_to_group(&"story_director")
	_rng.randomize()
	GameEvents.boss_spawned.connect(_on_boss_spawned)
	GameEvents.boss_died.connect(_on_boss_died)
	GameEvents.player_died.connect(func(_p: Node2D) -> void: _stop_swaps())
	tree_exiting.connect(_restore_origin)


static func boss_id(boss: Node) -> StringName:
	return StringName(boss.scene_file_path.get_file().get_basename())


# --- Entrées -----------------------------------------------------------------

func _on_boss_spawned(boss: Node2D) -> void:
	if _in_final or boss_id(boss) != &"lucifer":
		return
	var id := StringName("lucifer_entree_%s" % Characters.selected_id)
	if not StoryDB.CINEMATIQUES.has(id) or SaveGame.has_seen_story(id):
		return
	# Le boss vient d'entrer dans l'arbre : on fige tout avant son premier coup.
	get_tree().paused = true
	Cinematic.play([id], func() -> void: get_tree().paused = false)


func _on_boss_died(boss: Node2D) -> void:
	_boss_slain = boss_id(boss)
	if _boss_slain == &"helel":
		_swapping = false
		_hide_glitch()


# --- Avant la boutique -------------------------------------------------------

## Appelé par la boutique à la fin d'une vague, à la place de s'ouvrir : c'est
## ici qu'on décide ce qui passe avant elle — ou à sa place.
func before_shop() -> void:
	var slain := _boss_slain
	_boss_slain = &""
	get_tree().paused = true

	if slain == &"helel" and _in_final:
		_victory()
		return

	if slain == &"lucifer":
		var file: Array[StringName] = []
		if SaveGame.break_seal(Characters.selected_id):
			var fin := StringName("lucifer_fin_%s" % Characters.selected_id)
			if StoryDB.CINEMATIQUES.has(fin):
				file.append(fin)
			file.append(StoryDB.LUCIFER_RELEVE)
		if file.is_empty():
			_show_choice()
		else:
			Cinematic.play(file, _show_choice)
		return

	var after := StoryDB.pending_after_boss(slain, Characters.selected_id)
	if after.is_empty():
		_open_shop()
	else:
		Cinematic.play(after, _open_shop)


func _open_shop() -> void:
	_shop.call(&"open")


# --- Le choix ----------------------------------------------------------------

## Après chaque mort de Lucifer : continuer l'enfer sans fin, toujours possible ;
## franchir le portail, seulement les trois sceaux brisés. L'écran dit lesquels
## manquent — un portail grisé sans explication ne se comprendrait pas.
func _show_choice() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 40
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)

	var veil := ColorRect.new()
	veil.color = Color(0, 0, 0, 0.8)
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(veil)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(900, 0)
	center.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override(StringName("margin_" + side), 36)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 18)
	margin.add_child(box)

	var title := Label.new()
	title.theme_type_variation = &"TitleLabel"
	title.text = "LUCIFER EST TOMBÉ… PAS TOUT À FAIT"
	title.add_theme_font_size_override(&"font_size", 50)
	title.add_theme_color_override(&"font_color", Color(1.0, 0.55, 0.3))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var seals := Label.new()
	seals.theme_type_variation = &"TitleLabel"
	seals.add_theme_font_size_override(&"font_size", 30)
	seals.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var parts: Array[String] = []
	for character in Characters.get_all():
		var brise := SaveGame.has_seal(character.id)
		parts.append("%s %s" % [character.display_name, "✓" if brise else "✗"])
	seals.text = "Sceaux brisés : %d / 3   ·   %s" % [SaveGame.seal_count(), "   ".join(parts)]
	box.add_child(seals)

	var open := SaveGame.seal_count() >= 3
	var help := Label.new()
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.add_theme_color_override(&"font_color", Color(0.78, 0.74, 0.72))
	help.text = "Les trois sceaux sont brisés : le portail vers Hélel est ouvert." if open \
		else "Chaque damné doit abattre Lucifer pour briser son propre sceau."
	box.add_child(help)

	var portal := Button.new()
	portal.text = "Franchir le portail — Hélel" if open else "Portail scellé"
	portal.disabled = not open
	portal.custom_minimum_size = Vector2(0, 60)
	box.add_child(portal)
	var endless := Button.new()
	endless.text = "Continuer — l'enfer sans fin"
	endless.custom_minimum_size = Vector2(0, 60)
	# Le bouton doré est l'action attendue : le portail quand il s'ouvre, la
	# suite sinon.
	if open:
		endless.theme_type_variation = &"SecondaryButton"
	box.add_child(endless)

	portal.pressed.connect(func() -> void:
		layer.queue_free()
		_enter_portal())
	endless.pressed.connect(func() -> void:
		layer.queue_free()
		_open_shop())
	(portal if open else endless).grab_focus()


# --- Hélel -------------------------------------------------------------------

## Panneau de développement : le combat sans la cinématique ni le choix.
func dev_start_helel() -> void:
	if _in_final:
		return
	_start_final()


func _enter_portal() -> void:
	Cinematic.play([StoryDB.HELEL_ENTREE], _start_final)


func _start_final() -> void:
	_in_final = true
	_swapping = true
	_origin = Characters.selected_id
	_swap_left = _rng.randf_range(SWAP_MIN, SWAP_MAX)
	get_tree().paused = false
	_waves.start_final_fight(HELEL_SCENE)


func _process(delta: float) -> void:
	if not _swapping or get_tree().paused or not is_instance_valid(_player) \
			or _player.health.is_dead:
		return
	_swap_left -= delta
	if _swap_left <= 0.0:
		_swap_left = _next_swap_delay()
		_swap()


## UN AUTRE DAMNÉ PREND LE CORPS, au hasard parmi les deux autres — jamais le
## même, sinon le glitch ne changerait rien. Le joueur n'a pas le choix : c'est
## tout le sujet du combat.
func _next_swap_delay() -> float:
	var boss := get_tree().get_first_node_in_group(Groups.BOSSES) as Boss
	if boss != null and boss.current_phase >= boss.phase_thresholds.size():
		return _rng.randf_range(SWAP_MIN_AURORE, SWAP_MAX_AURORE)
	return _rng.randf_range(SWAP_MIN, SWAP_MAX)


func _swap() -> void:
	var others: Array[StringName] = []
	for character in Characters.get_all():
		if character.id != Characters.selected_id:
			others.append(character.id)
	if others.is_empty():
		return
	var next: StringName = others[_rng.randi() % others.size()]
	_glitch()
	Characters.swap_in_run(next)
	_player.swap_character(Characters.get_selected())
	var character := Characters.get_selected()
	GameEvents.announce.emit(character.display_name.to_upper(), character.title,
		COULEURS.get(next, Color.WHITE))
	GameEvents.request_shake(6.0)


func _glitch() -> void:
	if _glitch_layer == null:
		_glitch_layer = CanvasLayer.new()
		_glitch_layer.layer = 30
		# Le glitch se termine même si une pause tombe en plein milieu.
		_glitch_layer.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(_glitch_layer)
		_glitch_rect = ColorRect.new()
		_glitch_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		_glitch_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var material := ShaderMaterial.new()
		var shader := Shader.new()
		shader.code = GLITCH_SHADER
		material.shader = shader
		_glitch_rect.material = material
		_glitch_layer.add_child(_glitch_rect)
	var material := _glitch_rect.material as ShaderMaterial
	material.set_shader_parameter(&"graine", _rng.randf() * 100.0)
	_glitch_rect.visible = true
	Audio.play(StringName("glitch_%d" % _rng.randi_range(1, 4)))
	var tween := _glitch_layer.create_tween()
	tween.tween_method(func(v: float) -> void: material.set_shader_parameter(&"force", v),
		1.0, 0.0, GLITCH_TIME)
	tween.tween_callback(func() -> void: _glitch_rect.visible = false)


func _victory() -> void:
	_stop_swaps()
	_waves.end_final_fight()
	Cinematic.play([StoryDB.HELEL_FIN], func() -> void: _game_over.call(&"show_victory"))


func _stop_swaps() -> void:
	_in_final = false
	_swapping = false
	_hide_glitch()
	_restore_origin()


func _hide_glitch() -> void:
	if _glitch_rect != null:
		_glitch_rect.visible = false


## Le personnage d'origine revient dès que le combat s'arrête — mort, victoire,
## abandon : l'écran de fin, la Forge qu'il ouvre et le menu doivent parler de
## celui qu'on avait choisi, et la sauvegarde n'a jamais vu passer les autres.
func _restore_origin() -> void:
	if _origin != &"" and Characters.selected_id != _origin:
		Characters.selected_id = _origin
	_origin = &""
