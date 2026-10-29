shader_type canvas_item;
// Rampa del Pathway (US-8B72): le icone delle primitive sono disegnate a 4 toni di grigio
// (tools/art/build_primitive.py: 0 contorno, 85 scuro, 170 primario, 255 accento) e qui
// prendono i colori della palette del Pathway (data/vfx.json pathway_palette_visiva).
// La forma e' una, il colore cambia con il Pathway, come i VFX.

uniform vec4 inchiostro : source_color = vec4(0.04, 0.04, 0.06, 1.0);
uniform vec4 scuro : source_color = vec4(0.35, 0.35, 0.4, 1.0);
uniform vec4 primario : source_color = vec4(0.6, 0.6, 0.65, 1.0);
uniform vec4 accento : source_color = vec4(0.95, 0.95, 1.0, 1.0);
// US-8B40: il frame d'impatto dei VFX e' bianco (contorno escluso); 0 con riduci_flash.
uniform float lampo : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 t = texture(TEXTURE, UV);
	float l = t.r * 3.0;
	vec3 c = l < 0.5 ? inchiostro.rgb : (l < 1.5 ? scuro.rgb : (l < 2.5 ? primario.rgb : accento.rgb));
	c = mix(c, vec3(1.0), lampo * step(0.5, l));
	COLOR = vec4(c, t.a * COLOR.a);
}
