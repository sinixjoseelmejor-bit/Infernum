// LE FOND DES ÉCRANS PLEIN CADRE (0.9.4) : noir en haut, qui rougeoie vers le
// bas comme un feu sous l'écran. Il remplace le panneau brun-rouge uni du kit,
// trop terne, et se pose sur le voile `Dim` de chaque écran ; le cadre, lui,
// ne dessine plus que son liseré (`CadreEcran` dans le thème).
shader_type canvas_item;

uniform vec3 haut : source_color = vec3(0.025, 0.012, 0.012);
uniform vec3 bas : source_color = vec3(0.22, 0.05, 0.02);
// Plus il est grand, plus la lueur reste collée au bas de l'écran.
uniform float montee = 2.6;

void fragment() {
	float lueur = pow(UV.y, montee);
	// Les côtés un peu plus sombres : la lueur vient du centre.
	float bords = smoothstep(0.0, 0.5, 0.5 - abs(UV.x - 0.5)) * 0.35 + 0.65;
	COLOR = vec4(mix(haut, bas, lueur) * bords, COLOR.a);
}
