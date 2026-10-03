class_name MenuItem
extends Button
## UNE ENTRÉE DE MENU EN TEXTE SEUL (0.10.1) : le menu principal et la pause.
##
## Pas de cadre : le texte, en grand, sur l'illustration. L'entrée qui a le
## focus s'allume en braise, glisse vers la droite, et une flèche du kit se
## pose devant elle. Le focus suit déjà le survol (`MenuNav`) : souris et
## manette montrent la même chose.

const FLECHE := preload("res://assets/sprites/ui/enfer/fleche.png")
## Retrait du texte au repos, et glissement quand il a le focus.
const RETRAIT := 64.0
const GLISSEMENT := 18.0
const COTE_FLECHE := 42.0
const DUREE := 0.12

var _eclat: float = 0.0:
	set(v):
		_eclat = v
		_style.content_margin_left = RETRAIT + GLISSEMENT * v
		queue_redraw()
var _style := StyleBoxEmpty.new()
var _tween: Tween


func _ready() -> void:
	theme_type_variation = &"MenuItem"
	alignment = HORIZONTAL_ALIGNMENT_LEFT
	_style.content_margin_left = RETRAIT
	_style.content_margin_right = GLISSEMENT
	for etat in [&"normal", &"hover", &"pressed", &"hover_pressed", &"disabled"]:
		add_theme_stylebox_override(etat, _style)
	focus_entered.connect(_allumer.bind(1.0))
	focus_exited.connect(_allumer.bind(0.0))
	if has_focus():
		_eclat = 1.0


func _allumer(cible: float) -> void:
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, ^"_eclat", cible, DUREE).set_trans(Tween.TRANS_QUAD) \
		.set_ease(Tween.EASE_OUT)


func _draw() -> void:
	if _eclat <= 0.01:
		return
	var x := 4.0 + GLISSEMENT * _eclat
	var y := (size.y - COTE_FLECHE) * 0.5
	draw_texture_rect(FLECHE, Rect2(Vector2(x, y), Vector2.ONE * COTE_FLECHE), false,
		Color(1, 1, 1, _eclat))
