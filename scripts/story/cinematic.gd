class_name Cinematic
extends CanvasLayer
## Lecteur de cinématiques : joue une file de cinématiques écrites dans
## `StoryDB`, puis rend la main.
##
## ON PEUT TOUJOURS PASSER. B, Échap, Start ou le bouton « Passer » coupent
## TOUTE la file d'un coup : quelqu'un qui passe le Pari ne veut pas non plus
## subir le prologue qui suit. A, Entrée, Espace ou un clic font avancer : ils
## terminent la réplique en cours, puis passent à la suivante.
##
## Une cinématique est comptée comme VUE dès qu'elle commence : la passer, c'est
## avoir choisi de ne pas la regarder, pas l'avoir manquée.
##
## Tout est construit par code, comme les écrans de menu : un plan n'est qu'une
## entrée de `StoryDB.CINEMATIQUES`.

signal finished()

const LAYER := 90
## Hauteur des bandes noires : le format « cinéma » est ce qui dit, avant tout
## texte, qu'on ne joue plus.
const LETTERBOX := 150.0
const TYPE_SPEED := 45.0
const FADE := 0.4
const ANIM_FPS := 8.0
const WALK_SPEED := 300.0
## Silhouette éteinte, qu'une réplique allume.
const DIM := Color(0.1, 0.08, 0.1)
## Durée de caméra par réplique, pour étaler le glissement sur tout le plan.
const CAMERA_PER_LINE := 3.5

const FLOOR_TEXTURE := "res://assets/sprites/arena/floor/floor2.png"
const MENU_TEXTURE := "res://assets/sprites/menu/menu.jpg"
## La statue de sel : on garde la luminance du pixel art — donc son modelé — et on
## la reteinte d'un blanc cassé. Un simple `modulate` ne ferait que l'assombrir.
const SALT_SHADER := """
shader_type canvas_item;
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float l = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	COLOR = vec4(mix(vec3(0.55, 0.53, 0.52), vec3(1.0, 0.98, 0.94), l), c.a);
}
"""

var _queue: Array[StringName] = []
var _shots: Array = []
var _shot: Dictionary = {}
var _shot_index: int = -1
var _line_index: int = -1
var _typing: bool = false
var _busy: bool = false
var _done: bool = false
## Un plan sans réplique (carton, plan muet) avance seul à la fin de ce compte.
var _auto_left: float = -1.0
var _clock: float = 0.0
var _shake: float = 0.0
var _zoom: float = 1.0
var _actors: Dictionary = {}

var _world: Node2D
var _backdrop: Node2D
var _ui: Control
var _bar_top: ColorRect
var _bar_bottom: ColorRect
var _speaker: Label
var _text: Label
var _center_text: Label
var _title: Label
var _subtitle: Label
var _arrow: Label
var _fade: ColorRect
var _active_label: Label


## Joue `ids` par-dessus tout le reste, puis appelle `on_done`. La couche se
## détruit seule ensuite.
static func play(ids: Array[StringName], on_done: Callable = Callable()) -> Cinematic:
	var cinematic := Cinematic.new()
	cinematic._queue = ids.duplicate()
	if on_done.is_valid():
		cinematic.finished.connect(on_done)
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(cinematic)
	return cinematic


func _ready() -> void:
	# Joue aussi bien depuis le menu que depuis la pause, arbre figé.
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = LAYER
	MenuNav.suspend()
	get_viewport().gui_release_focus()
	_build()
	var bars := create_tween().set_parallel()
	bars.tween_property(_bar_top, ^"custom_minimum_size:y", LETTERBOX, 0.6)
	bars.tween_property(_bar_bottom, ^"custom_minimum_size:y", LETTERBOX, 0.6)
	_next_cinematic()


# --- Construction ------------------------------------------------------------

func _build() -> void:
	var base := ColorRect.new()
	base.color = Color.BLACK
	base.set_anchors_preset(Control.PRESET_FULL_RECT)
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(base)

	_world = Node2D.new()
	add_child(_world)
	_backdrop = Node2D.new()
	_world.add_child(_backdrop)

	_ui = Control.new()
	_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Bloque les clics destinés à l'écran de dessous ; un clic fait avancer.
	_ui.mouse_filter = Control.MOUSE_FILTER_STOP
	_ui.gui_input.connect(_on_ui_input)
	add_child(_ui)

	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.add_theme_constant_override(&"separation", 0)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(column)

	_bar_top = _bar()
	column.add_child(_bar_top)
	var middle := Control.new()
	middle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	middle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(middle)
	_bar_bottom = _bar()
	column.add_child(_bar_bottom)

	# Dans la bande du bas : qui parle, puis ce qu'il dit.
	var talk := VBoxContainer.new()
	talk.set_anchors_preset(Control.PRESET_CENTER)
	talk.custom_minimum_size = Vector2(1400, 0)
	talk.position = Vector2(-700, -64)
	talk.add_theme_constant_override(&"separation", 2)
	talk.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar_bottom.add_child(talk)
	_speaker = _label(30, Color.WHITE)
	talk.add_child(_speaker)
	_text = _label(40, Color(0.92, 0.9, 0.88))
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	talk.add_child(_text)

	_arrow = _label(30, Color(1, 0.8, 0.4))
	_arrow.text = "▼"
	_arrow.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_arrow.position = Vector2(-90, -60)
	_bar_bottom.add_child(_arrow)

	# La narration sur fond noir se lit au milieu de l'écran, en grand.
	_center_text = _label(50, Color(0.86, 0.82, 0.8))
	_center_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_center_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_center_text.set_anchors_preset(Control.PRESET_CENTER)
	_center_text.custom_minimum_size = Vector2(1400, 0)
	_center_text.position = Vector2(-700, -40)
	_ui.add_child(_center_text)

	_title = _label(160, Color(0.9, 0.22, 0.14))
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.set_anchors_preset(Control.PRESET_CENTER)
	_title.custom_minimum_size = Vector2(1600, 0)
	_title.position = Vector2(-800, -150)
	_title.add_theme_color_override(&"font_outline_color", Color(0.1, 0.02, 0.02))
	_title.add_theme_constant_override(&"outline_size", 16)
	_ui.add_child(_title)
	_subtitle = _label(50, Color(0.86, 0.8, 0.74))
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle.set_anchors_preset(Control.PRESET_CENTER)
	_subtitle.custom_minimum_size = Vector2(1600, 0)
	_subtitle.position = Vector2(-800, 40)
	_ui.add_child(_subtitle)

	# « Passer » est TOUJOURS là, en haut à droite, et dit ses touches.
	var skip_box := HBoxContainer.new()
	skip_box.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	skip_box.position = Vector2(-560, 40)
	skip_box.custom_minimum_size = Vector2(520, 0)
	skip_box.alignment = BoxContainer.ALIGNMENT_END
	skip_box.add_theme_constant_override(&"separation", 16)
	_ui.add_child(skip_box)
	var hint := _label(20, Color(0.62, 0.58, 0.56))
	hint.text = "A · Entrée : suivant"
	hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	skip_box.add_child(hint)
	var skip := Button.new()
	skip.text = "Passer  ·  B / Échap"
	skip.theme_type_variation = &"SecondaryButton"
	skip.add_theme_font_size_override(&"font_size", 20)
	# Jamais de focus : A doit faire avancer, pas presser « Passer ».
	skip.focus_mode = Control.FOCUS_NONE
	skip.pressed.connect(_skip)
	skip_box.add_child(skip)

	_fade = ColorRect.new()
	_fade.color = Color.BLACK
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade)
	_clear_text()


func _bar() -> ColorRect:
	var bar := ColorRect.new()
	bar.color = Color.BLACK
	bar.custom_minimum_size = Vector2(0, 0)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return bar


func _label(size: int, color: Color) -> Label:
	var label := Label.new()
	label.theme_type_variation = &"TitleLabel"
	label.add_theme_font_size_override(&"font_size", size)
	label.add_theme_color_override(&"font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Le retour à la ligne est calculé sur le texte ENTIER : sans ça, un mot qui
	# s'écrit lettre par lettre saute d'une ligne à l'autre en cours de frappe.
	label.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING
	return label


# --- Déroulé -----------------------------------------------------------------

func _next_cinematic() -> void:
	if _done:
		return
	if _queue.is_empty():
		_finish()
		return
	var id: StringName = _queue.pop_front()
	SaveGame.mark_story_seen(id)
	_shots = StoryDB.CINEMATIQUES.get(id, [])
	_shot_index = -1
	_next_shot()


func _next_shot() -> void:
	if _done:
		return
	_busy = true
	_auto_left = -1.0
	await _fade_to(1.0)
	if _done:
		return
	_shot_index += 1
	if _shot_index >= _shots.size():
		_busy = false
		_next_cinematic()
		return
	_shot = _shots[_shot_index]
	_stage_shot()
	await _fade_to(0.0)
	if _done:
		return
	_busy = false
	if _shot.has("titre") or (_shot.get("lignes", []) as Array).is_empty():
		_auto_left = float(_shot.get("duree", 2.5))
	else:
		_line_index = -1
		_next_line()


func _stage_shot() -> void:
	_clear_text()
	for child in _backdrop.get_children():
		child.queue_free()
	for id in _actors:
		(_actors[id] as Node).queue_free()
	_actors.clear()
	_build_backdrop(_shot.get("fond", &"noir"))
	for data: Dictionary in _shot.get("acteurs", []):
		_add_actor(data)

	# La caméra glisse d'un bout à l'autre du plan : même immobiles, les
	# personnages ne sont jamais un arrêt sur image.
	var zoom: Array = _shot.get("zoom", [1.0, 1.0])
	_zoom = float(zoom[0])
	var lines := (_shot.get("lignes", []) as Array).size()
	var length := maxf(4.0, lines * CAMERA_PER_LINE + float(_shot.get("duree", 0.0)))
	create_tween().tween_property(self, ^"_zoom", float(zoom[1]), length) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	if _shot.has("titre"):
		var titre: Array = _shot["titre"]
		_title.text = titre[0]
		_subtitle.text = titre[1] if titre.size() > 1 else ""
		_title.visible = true
		_subtitle.visible = true
		_title.modulate.a = 0.0
		_subtitle.modulate.a = 0.0
		var reveal := create_tween()
		reveal.tween_property(_title, ^"modulate:a", 1.0, 1.0)
		reveal.tween_property(_subtitle, ^"modulate:a", 1.0, 0.8)


func _next_line() -> void:
	var lines: Array = _shot.get("lignes", [])
	_line_index += 1
	# Les répliques conditionnées au nombre de sceaux qui ne s'appliquent pas
	# sont sautées, comme si elles n'étaient pas écrites.
	while _line_index < lines.size() and not _line_applies(lines[_line_index]):
		_line_index += 1
	if _line_index >= lines.size():
		_next_shot()
		return
	var line: Dictionary = lines[_line_index]
	_apply_actions(line)

	var who: StringName = line.get("qui", &"")
	var narration := who == &""
	# Narration sur fond noir : au centre, en grand. Sinon : dans la bande.
	var centered: bool = narration and _shot.get("fond", &"noir") == &"noir"
	_center_text.visible = centered
	_text.get_parent().visible = not centered
	_active_label = _center_text if centered else _text
	if narration:
		_speaker.text = ""
		_text.add_theme_color_override(&"font_color", Color(0.78, 0.74, 0.72))
	else:
		var locuteur: Array = StoryDB.LOCUTEURS.get(who, [String(who), Color.WHITE])
		_speaker.text = locuteur[0]
		_speaker.add_theme_color_override(&"font_color", locuteur[1])
		_text.add_theme_color_override(&"font_color", Color(0.94, 0.92, 0.9))
	var sceaux := SaveGame.seal_count()
	_active_label.text = String(line.get("texte", "")).format(
		{"sceaux": sceaux, "reste": maxi(0, 3 - sceaux)})
	_active_label.visible_characters = 0
	_typing = true
	Audio.play(&"texte_ligne")
	_arrow.visible = false


func _line_applies(line: Dictionary) -> bool:
	var sceaux := SaveGame.seal_count()
	if line.has("si_min") and sceaux < int(line["si_min"]):
		return false
	if line.has("si_moins") and sceaux >= int(line["si_moins"]):
		return false
	return true


func _apply_actions(line: Dictionary) -> void:
	if line.has("dessale") and _actors.has(line["dessale"]):
		# Le sel se fend : un éclair blanc, puis la couleur revient.
		var statue: Sprite2D = _actors[line["dessale"]]
		statue.material = null
		statue.remove_meta(&"fige")
		statue.modulate = Color(3, 3, 3)
		create_tween().tween_property(statue, ^"modulate", Color.WHITE, 1.2)
	if line.has("montre") and _actors.has(line["montre"]):
		var sprite: Sprite2D = _actors[line["montre"]]
		sprite.visible = true
		sprite.modulate = Color(3, 2.2, 2.0, 0.0)
		create_tween().tween_property(sprite, ^"modulate", _base_color(sprite), 0.7)
	if line.has("allume") and _actors.has(line["allume"]):
		var lit: Sprite2D = _actors[line["allume"]]
		create_tween().tween_property(lit, ^"modulate", _base_color(lit), 0.6)
	if line.has("entre") and _actors.has(line["entre"]):
		var sprite: Sprite2D = _actors[line["entre"]]
		_walk(sprite, sprite.get_meta(&"depuis", sprite.position), sprite.get_meta(&"pos"))
	if line.has("son"):
		Audio.play(line["son"])
	if line.has("secousse"):
		_shake = float(line["secousse"]) * 18.0
		create_tween().tween_property(self, ^"_shake", 0.0, 0.8)


## Avancer : finir la réplique en cours, sinon passer à la suivante.
func _advance() -> void:
	if _done or _busy:
		return
	if _auto_left >= 0.0:
		_auto_left = -1.0
		_next_shot()
		return
	if _typing:
		_active_label.visible_characters = -1
		_typing = false
		_arrow.visible = true
		return
	_next_line()


func _skip() -> void:
	if _done:
		return
	# Tout ce qui restait dans la file est compté comme vu : c'est un choix.
	for id in _queue:
		SaveGame.mark_story_seen(id)
	_queue.clear()
	_finish()


func _finish() -> void:
	if _done:
		return
	_done = true
	var out := create_tween()
	out.tween_property(_fade, ^"modulate:a", 1.0, 0.3).from_current()
	await out.finished
	finished.emit()
	# Le noir tient le temps que l'appelant change de scène, puis se lève sur
	# ce qui vient ensuite — l'arène, ou l'écran d'où l'on a relancé.
	await get_tree().process_frame
	await get_tree().process_frame
	_world.visible = false
	_ui.visible = false
	var lift := create_tween()
	lift.tween_property(_fade, ^"modulate:a", 0.0, 0.5)
	await lift.finished
	MenuNav.resume()
	queue_free()


func _fade_to(alpha: float) -> void:
	var tween := create_tween()
	tween.tween_property(_fade, ^"modulate:a", alpha, FADE)
	await tween.finished


func _clear_text() -> void:
	_speaker.text = ""
	_text.text = ""
	_center_text.text = ""
	_center_text.visible = false
	_title.visible = false
	_subtitle.visible = false
	_arrow.visible = false
	_typing = false
	_active_label = _text


# --- Décor et personnages ----------------------------------------------------

func _build_backdrop(kind: StringName) -> void:
	# Assez grand pour couvrir l'écran le plus large à tous les zooms.
	var cover := Vector2(4200, 2600)
	match kind:
		&"abime":
			var gradient := Gradient.new()
			gradient.set_color(0, Color(0.02, 0.0, 0.01))
			gradient.add_point(0.55, Color(0.14, 0.02, 0.02))
			gradient.set_color(gradient.get_point_count() - 1, Color(0.42, 0.08, 0.03))
			var texture := GradientTexture2D.new()
			texture.gradient = gradient
			texture.fill_from = Vector2(0.5, 0.0)
			texture.fill_to = Vector2(0.5, 1.0)
			var rect := TextureRect.new()
			rect.texture = texture
			rect.size = cover
			rect.position = -cover * 0.5
			rect.stretch_mode = TextureRect.STRETCH_SCALE
			rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			_backdrop.add_child(rect)
			_backdrop.add_child(_embers())
		&"arene":
			var floor_tex: Texture2D = load(FLOOR_TEXTURE) if ResourceLoader.exists(FLOOR_TEXTURE) else null
			if floor_tex != null:
				var rect := TextureRect.new()
				rect.texture = floor_tex
				rect.stretch_mode = TextureRect.STRETCH_TILE
				rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
				rect.scale = Vector2(2, 2)
				rect.size = cover * 0.5
				rect.position = -cover * 0.5
				_backdrop.add_child(rect)
			var veil := ColorRect.new()
			veil.color = Color(0.07, 0.01, 0.01, 0.72)
			veil.size = cover
			veil.position = -cover * 0.5
			_backdrop.add_child(veil)
			_backdrop.add_child(_embers())
		&"menu":
			if ResourceLoader.exists(MENU_TEXTURE):
				var rect := TextureRect.new()
				rect.texture = load(MENU_TEXTURE)
				rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
				rect.size = Vector2(2600, 1460)
				rect.position = -rect.size * 0.5
				_backdrop.add_child(rect)


## Les mêmes braises que l'écran titre : l'histoire se passe au même endroit.
func _embers() -> CPUParticles2D:
	var embers := CPUParticles2D.new()
	embers.amount = 80
	embers.lifetime = 6.0
	embers.preprocess = 6.0
	embers.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	embers.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	embers.emission_rect_extents = Vector2(1400, 4)
	embers.position = Vector2(0, 700)
	embers.direction = Vector2.UP
	embers.spread = 18.0
	embers.gravity = Vector2(0, -6)
	embers.initial_velocity_min = 40.0
	embers.initial_velocity_max = 90.0
	embers.scale_amount_min = 2.0
	embers.scale_amount_max = 5.0
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.72, 0.3, 0.0))
	ramp.add_point(0.12, Color(1.0, 0.6, 0.2, 0.9))
	ramp.add_point(0.7, Color(0.95, 0.3, 0.1, 0.55))
	ramp.set_color(ramp.get_point_count() - 1, Color(0.6, 0.1, 0.05, 0.0))
	embers.color_ramp = ramp
	return embers


func _add_actor(data: Dictionary) -> void:
	var base: String = StoryDB.PLANCHES.get(data.get("planche", &""), "")
	var idle_path := base + "_idle.png"
	if base == "" or not ResourceLoader.exists(idle_path):
		return
	var sprite := Sprite2D.new()
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale = Vector2.ONE * float(data.get("echelle", 6.0))
	sprite.flip_h = bool(data.get("miroir", false))
	var idle: Texture2D = load(idle_path)
	var walk_path := base + "_walk.png"
	var walk: Texture2D = load(walk_path) if ResourceLoader.exists(walk_path) else idle
	sprite.set_meta(&"idle", idle)
	sprite.set_meta(&"walk", walk)
	sprite.set_meta(&"pos", data.get("pos", Vector2.ZERO))
	_set_sheet(sprite, idle)
	sprite.position = data.get("pos", Vector2.ZERO)
	if data.has("teinte"):
		sprite.modulate = data["teinte"]
		sprite.set_meta(&"teinte", data["teinte"])
	if data.get("sombre", false):
		sprite.modulate = DIM
	if data.get("cache", false):
		sprite.visible = false
	if data.get("lumiere", false):
		sprite.material = BossHelel.make_aurore_material()
	if data.get("sel", false):
		var material := ShaderMaterial.new()
		var shader := Shader.new()
		shader.code = SALT_SHADER
		material.shader = shader
		sprite.material = material
		# Une statue ne respire pas.
		sprite.set_meta(&"fige", true)
	_world.add_child(sprite)
	_actors[data["id"]] = sprite
	if data.has("depuis"):
		sprite.set_meta(&"depuis", data["depuis"])
		_walk(sprite, data["depuis"], data.get("pos", Vector2.ZERO))


## La couleur d'un personnage une fois allumé ou apparu : sa teinte s'il en a
## une (Lucifer dans sa lumière), du blanc sinon.
func _base_color(sprite: Sprite2D) -> Color:
	return sprite.get_meta(&"teinte", Color.WHITE)


func _walk(sprite: Sprite2D, from: Vector2, to: Vector2) -> void:
	sprite.position = from
	_set_sheet(sprite, sprite.get_meta(&"walk"))
	var duration := from.distance_to(to) / WALK_SPEED
	var tween := create_tween()
	tween.tween_property(sprite, ^"position", to, duration)
	tween.tween_callback(func() -> void: _set_sheet(sprite, sprite.get_meta(&"idle")))


## Bande d'images carrées, comme partout dans le jeu : la hauteur donne le côté.
func _set_sheet(sprite: Sprite2D, texture: Texture2D) -> void:
	sprite.texture = texture
	sprite.hframes = maxi(1, texture.get_width() / maxi(1, texture.get_height()))
	sprite.frame = 0


# --- Boucle et entrées -------------------------------------------------------

func _process(delta: float) -> void:
	_clock += delta
	var center := get_viewport().get_visible_rect().size * 0.5
	var jolt := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake
	_world.position = center + jolt
	_world.scale = Vector2.ONE * _zoom

	for id in _actors:
		var sprite: Sprite2D = _actors[id]
		if sprite.hframes > 1 and not sprite.has_meta(&"fige"):
			sprite.frame = int(_clock * ANIM_FPS) % sprite.hframes

	if _typing and _active_label != null:
		var total := _active_label.get_total_character_count()
		var shown := _active_label.visible_characters + maxi(1, roundi(TYPE_SPEED * delta))
		if shown >= total:
			_active_label.visible_characters = -1
			_typing = false
			_arrow.visible = true
		else:
			# Un petit « blip » toutes les deux lettres : le texte s'entend
			# s'écrire, sans devenir une mitraille (l'anti-spam borne le débit).
			if floori(shown / 2.0) != floori(_active_label.visible_characters / 2.0):
				Audio.play(&"texte")
			_active_label.visible_characters = shown
	if _arrow.visible:
		_arrow.modulate.a = 0.4 + 0.6 * absf(sin(_clock * 3.0))

	if _auto_left >= 0.0 and not _busy:
		_auto_left -= delta
		if _auto_left < 0.0:
			_next_shot()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton or event is InputEventMouseMotion:
		return
	# Rien ne traverse la cinématique : ni la pause, ni l'écran de dessous — et
	# ça JUSQU'À CE QU'ELLE DISPARAISSE, fondu de sortie compris. Pendant ce
	# fondu la boutique a déjà le focus sur « Vague suivante » : le A de trop
	# de qui fait défiler les répliques la fermait sans qu'on l'ait vue.
	get_viewport().set_input_as_handled()
	if _done or not event.is_pressed() or event.is_echo():
		return
	if event.is_action(&"ui_cancel") \
			or (event is InputEventJoypadButton and event.button_index == JOY_BUTTON_START):
		_skip()
	elif event.is_action(&"ui_accept"):
		_advance()


func _on_ui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		_advance()
