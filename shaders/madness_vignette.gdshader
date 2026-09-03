shader_type canvas_item;
// Vignetta d'inchiostro della follia (US-215): scurisce i bordi. L'intensita'
// e' guidata dal valore di follia (script); qui c'e' solo la forma.

uniform float intensita : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec2 d = (UV - 0.5) * vec2(1.7, 1.4);
	float bordo = smoothstep(0.35, 0.95, length(d));
	COLOR = vec4(0.02, 0.0, 0.03, bordo * intensita);
}
