shader_type canvas_item;
// Lente del cannocchiale (US-8B24b): fuori dal cerchio il buio del tubo, un anello d'ottone, dentro la nebbia che si
// dirada (nebbia 1 -> 0, la porta scripts/cannocchiale.gd coi tempi di data/world/cannocchiali.json). Tutto a quadretti
// della grana del gioco (640 x 360) e la nebbia a retino (alpha 0 o 1, come gli sprite): niente sfumature lisce.

uniform float raggio = 0.42;                    // raggio della lente, in altezze dello schermo
uniform float nebbia : hint_range(0.0, 1.0) = 1.0;
uniform float tempo = 0.0;
uniform vec2 grana = vec2(640.0, 360.0);
uniform vec4 colore_buio : source_color = vec4(0.094, 0.078, 0.145, 1.0);
uniform vec4 colore_anello : source_color = vec4(0.894, 0.651, 0.447, 1.0);
uniform vec4 colore_nebbia : source_color = vec4(0.753, 0.796, 0.863, 1.0);

float caso(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float rumore(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(caso(i), caso(i + vec2(1.0, 0.0)), u.x), mix(caso(i + vec2(0.0, 1.0)), caso(i + vec2(1.0, 1.0)), u.x), u.y);
}

float bayer4(vec2 p) {
	int x = int(mod(p.x, 4.0));
	int y = int(mod(p.y, 4.0));
	int m[16] = int[16](0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5);
	return (float(m[y * 4 + x]) + 0.5) / 16.0;
}

void fragment() {
	vec2 px = floor(UV * grana);
	vec2 c = (px + 0.5 - grana * 0.5) / grana.y;
	float d = length(c);
	float bordo = 1.5 / grana.y;
	if (d > raggio) {
		COLOR = colore_buio;
	} else if (d > raggio - bordo) {
		COLOR = colore_anello;
	} else {
		// due strati di nebbia che scorrono piano; verso il bordo della lente la nebbia resta di piu'
		float n = rumore(px * 0.035 + vec2(tempo * 0.45, tempo * 0.12)) * 0.6
				+ rumore(px * 0.08 - vec2(tempo * 0.25, 0.0)) * 0.4;
		float densita = nebbia * (0.55 + 0.6 * n) + 0.25 * nebbia * smoothstep(raggio * 0.6, raggio, d);
		COLOR = vec4(colore_nebbia.rgb, step(bayer4(px), densita));
	}
}
