shader_type canvas_item;
// The baked map (paper + ink) shown only where it has been charted. Outside the
// map area (the border, grid letters, title) is always shown. Where the mask is
// low the sprite turns transparent and the live paper underneath shows through,
// which is the same paper — so it reads as ink spreading across a blank sheet.

uniform sampler2D mask : filter_linear;
uniform vec2 sheet_pos;
uniform vec2 sheet_size;
uniform vec2 map_size;
uniform vec4 fresh_ink : source_color = vec4(0.12, 0.07, 0.04, 1.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
	           mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	vec4 col = texture(TEXTURE, UV);
	vec2 world = sheet_pos + UV * sheet_size;
	vec2 muv = world / map_size;
	float inside = step(0.0, muv.x) * step(muv.x, 1.0) * step(0.0, muv.y) * step(muv.y, 1.0);
	float m = texture(mask, muv).r;
	// a ragged, blotted edge: the ink soaks unevenly into the fibres
	float n = vnoise(world / 22.0) * 0.6 + vnoise(world / 7.0) * 0.4;
	float a = smoothstep(0.38, 0.62, m + (n - 0.5) * 0.45);
	// a darker tide-line where the ink has only just reached
	float rim = smoothstep(0.0, 0.25, a) * (1.0 - smoothstep(0.25, 0.8, a));
	col.rgb = mix(col.rgb, fresh_ink.rgb, rim * 0.35);
	col.a *= mix(1.0, a, inside);
	COLOR = col;
}
