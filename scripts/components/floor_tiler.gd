class_name FloorTiler
extends Sprite2D
## Sol carrelé infini.
##
## L'arène n'a pas de bord : le sol ne peut donc pas être une image posée une
## fois. Un seul Sprite2D suffit pourtant — `texture_repeat` répète la texture
## sur toute la `region_rect`, il n'y a ni grille de nœuds ni TileMap à tenir.
##
## Le motif doit rester ACCROCHÉ AU MONDE. Si le sprite suivait la caméra au
## pixel près, le sol paraîtrait immobile et le joueur donnerait l'impression de
## courir sur place. On recale donc la position sur un multiple exact de la
## taille du carreau : le décalage est invisible (un carreau en vaut un autre),
## et le dallage ne bouge pas d'un pixel par rapport au monde.
##
## DEUX ÉTAGES. Passé `deep_from_wave`, le carreau change : on descend. C'est la
## seule récompense purement visuelle du jeu, et elle tombe là où la plupart des
## runs s'arrêtent — voir le commentaire de ce réglage.

@export_group("Profondeur")
## Le carreau du second étage. Vide = un seul sol, le premier.
@export var deep_texture: Texture2D
## Teinte appliquée au second carreau. La pierre bleue du second étage, passée
## sous la teinte chaude du premier, tournerait au mauve : elle a la sienne.
@export var deep_modulate: Color = Color(0.88, 0.68, 0.6)
## Vague à partir de laquelle on change d'étage. Onze, soit juste après Lilith :
## c'est le mur où s'arrêtent la plupart des premières runs, donc le passage se
## mérite et se remarque.
@export var deep_from_wave: int = 11

var _shallow_texture: Texture2D
var _shallow_modulate: Color
var _deep: bool = false


func _ready() -> void:
	_shallow_texture = texture
	_shallow_modulate = modulate
	GameEvents.wave_started.connect(_on_wave_started)


## Le sol suit la vague dans les deux sens : une nouvelle run repart en surface
## sans qu'on ait à le remettre à la main.
func _on_wave_started(wave: int) -> void:
	var profond := deep_texture != null and wave >= deep_from_wave
	texture = deep_texture if profond else _shallow_texture
	modulate = deep_modulate if profond else _shallow_modulate
	if profond != _deep:
		_deep = profond
		GameEvents.arena_depth_changed.emit(profond)


func _process(_delta: float) -> void:
	if texture == null:
		return
	var camera := get_viewport().get_camera_2d()
	if camera == null:
		return
	var tile := Vector2(texture.get_width(), texture.get_height()) * scale
	if tile.x <= 0.0 or tile.y <= 0.0:
		return
	global_position = (camera.get_screen_center_position() / tile).floor() * tile
