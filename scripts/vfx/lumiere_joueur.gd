class_name LumiereJoueur
extends PointLight2D
## LA LUMIÈRE DU JOUEUR : un halo chaud sur le sol autour de ses pieds.
##
## Avec le vignetage, c'est ce qui dit où regarder : le sol s'éclaire autour de
## lui et s'enfonce dans le noir vers les bords. Elle le suit partout — c'est un
## enfant du joueur, et le même nœud survit aux changements de personnage du
## combat contre Hélel.
##
## ELLE N'ÉCLAIRE QUE LE SOL ET LE DÉCOR (calque `Carte.MASQUE_DECOR`), comme la
## lave et le feu. Éclairer les créatures les ferait changer de teinte selon leur
## distance au joueur, et un ennemi qui s'éclaircit en approchant se lirait
## comme un ennemi qui charge.
##
## Blanc chaud, pas orange : l'orange est la couleur de la brûlure et de la
## lave, un halo orange sous les pieds dirait « tu es dans la lave ».

@export var rayon: float = 270.0
@export var energie: float = 0.65
@export var couleur: Color = Color(1.0, 0.9, 0.74)
## Respiration lente de la lumière, en part de l'énergie. Assez faible pour ne
## jamais se remarquer comme un clignotement ; elle empêche seulement le halo
## d'avoir l'air d'une tache peinte au sol.
@export_range(0.0, 0.2, 0.01) var respiration: float = 0.05

var _temps: float = 0.0


func _ready() -> void:
	var degrade := Gradient.new()
	degrade.offsets = PackedFloat32Array([0.0, 0.3, 1.0])
	degrade.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.55),
		Color(1, 1, 1, 0)])
	var tex := GradientTexture2D.new()
	tex.gradient = degrade
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 256
	tex.height = 256
	texture = tex
	texture_scale = rayon * 2.0 / 256.0
	# Ovale, comme le sol vu en perspective — et centré sur les PIEDS, pas sur
	# l'origine du nœud, qui tombe à mi-corps.
	scale = Vector2(1.0, 0.75)
	position = Vector2(0.0, Carte.PIED)
	color = couleur
	energy = energie
	blend_mode = Light2D.BLEND_MODE_ADD
	range_item_cull_mask = Carte.MASQUE_DECOR
	shadow_enabled = false


func _process(delta: float) -> void:
	_temps += delta
	energy = energie * (1.0 + respiration * sin(_temps * 1.7))
