shader_type canvas_item;
// Visual do jogador: pinta pele, camisa e calção do corpo base com as cores escolhidas,
// mantendo as sombras. A máscara (mesmo tamanho da folha) diz a classe de cada pixel:
// vermelho 60 = pele, 120 = camisa, 180 = calção, 0 = manter (contorno, olhos, ferramentas).
// Gerada por tools/make_player_layers.py.

uniform sampler2D look_mask : filter_nearest;
uniform vec4 skin_color : source_color = vec4(0.88, 0.67, 0.52, 1.0);
uniform vec4 shirt_color : source_color = vec4(0.91, 0.86, 0.75, 1.0);
uniform vec4 pants_color : source_color = vec4(0.48, 0.42, 0.23, 1.0);

// brilho médio de cada classe no desenho original
const float REF_SKIN = 0.44;
const float REF_SHIRT = 0.696;
const float REF_PANTS = 0.375;

vec3 tint(vec3 target, float lum, float ref, float contrast, float top) {
	float f = mix(1.0, lum / ref, contrast);
	return clamp(target * min(f, top), 0.0, 1.0);
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float cls = texture(look_mask, UV).r * 255.0;
	float lum = (c.r + c.g + c.b) / 3.0;
	if (cls > 30.0 && cls < 90.0) {
		c.rgb = tint(skin_color.rgb, lum, REF_SKIN, 0.75, 1.12);
	} else if (cls >= 90.0 && cls < 150.0) {
		c.rgb = tint(shirt_color.rgb, lum, REF_SHIRT, 0.9, 1.25);
	} else if (cls >= 150.0 && cls < 210.0) {
		c.rgb = tint(pants_color.rgb, lum, REF_PANTS, 0.9, 1.35);
	}
	COLOR = c * COLOR;
}
