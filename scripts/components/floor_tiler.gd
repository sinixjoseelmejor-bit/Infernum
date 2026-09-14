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
