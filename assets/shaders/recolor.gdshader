shader_type canvas_item;
// Troca de cor da decoração da casa (piso, paredes, móveis): gira o matiz e ajusta saturação e brilho,
// mantendo o sombreado da arte. Variações em HouseWorld.COLORS.

uniform float hue_shift = 0.0;     // 0..1 (volta inteira do círculo de cores)
uniform float sat_mult = 1.0;
uniform float val_mult = 1.0;
uniform bool light_only = false;   // só pinta as partes claras (o reboco da parede), não a madeira

vec3 rgb2hsv(vec3 c) {
	vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	float e = 1.0e-10;
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

vec3 hsv2rgb(vec3 c) {
	vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
	vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
	return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec3 h = rgb2hsv(c.rgb);
	float keep = (light_only && (h.z < 0.62 || h.y > 0.5)) ? 1.0 : 0.0;
	vec3 n = h;
	n.x = fract(h.x + hue_shift);
	n.y = clamp(h.y * sat_mult, 0.0, 1.0);
	n.z = clamp(h.z * val_mult, 0.0, 1.0);
	COLOR = vec4(mix(hsv2rgb(n), c.rgb, keep), c.a) * COLOR;
}
