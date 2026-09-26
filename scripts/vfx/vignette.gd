class_name Vignette
extends CanvasLayer
## LE VIGNETAGE : les bords de l'écran s'assombrissent, le regard revient au
## centre — là où se tient le joueur.
##
## Posé entre le monde et l'interface : le HUD, la boutique et les menus restent
## à pleine lumière, seul le monde s'enfonce dans le noir vers les bords.
##
## IL EST FORT, et c'est un choix assumé contre la lisibilité des bords : monté
## trois fois à la demande, jusqu'à accepter d'en cacher un peu. Les ennemis
## entrent par les bords et les zones annoncées s'y dessinent : si le jeu devient
## injuste sur les côtés, `force` est la première valeur à redescendre. Mesuré en
## jeu, voir le README (« La lumière et les ombres ») : le milieu des bords perd
## un bon tiers de sa lumière, les coins près des trois quarts.
##
## Il suit l'écran, pas le joueur. La caméra anticipe le déplacement de 96 px au
## plus : le joueur ne sort jamais de la zone claire.

## Part de la lumière retirée au plus sombre, dans les coins.
@export_range(0.0, 1.0, 0.05) var force: float = 0.8
## Distance au centre (en part de l'écran, ellipse) où l'ombre commence, et où
## elle atteint `force`. L'ellipse suit la forme de l'écran : sur un écran très
## large, les côtés ne s'assombrissent pas plus que le haut et le bas.
@export var debut: float = 0.24
@export var fin: float = 0.74
## Un noir à peine violacé, celui du fond de l'enfer : un noir pur éteint la
## couleur au lieu de l'assombrir.
@export var teinte: Color = Color(0.03, 0.0, 0.03)

const SHADER := """
shader_type canvas_item;
uniform float force = 0.8;
uniform float debut = 0.24;
uniform float fin = 0.74;
uniform vec4 teinte : source_color = vec4(0.03, 0.0, 0.03, 1.0);
void fragment() {
	float d = length(UV - vec2(0.5));
	float a = smoothstep(debut, fin, d) * force;
	// Un grain d'un 255e casse les paliers qu'un dégradé sombre dessine sur un
	// écran 8 bits.
	a += (fract(sin(dot(FRAGCOORD.xy, vec2(12.9898, 78.233))) * 43758.5453) - 0.5) / 255.0;
	COLOR = vec4(teinte.rgb, clamp(a, 0.0, 1.0));
}
"""


func _ready() -> void:
	# Au-dessus du monde (0), sous le HUD (2) et tout ce qui s'ouvre par-dessus.
	layer = 1
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = SHADER
	var materiau := ShaderMaterial.new()
	materiau.shader = shader
	materiau.set_shader_parameter(&"force", force)
	materiau.set_shader_parameter(&"debut", debut)
	materiau.set_shader_parameter(&"fin", fin)
	materiau.set_shader_parameter(&"teinte", teinte)
	rect.material = materiau
	add_child(rect)
