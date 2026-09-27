shader_type canvas_item;
// Aged survey paper. Used for the map sheet and for menu backgrounds.

uniform vec4 paper_color : source_color = vec4(0.91, 0.85, 0.71, 1.0);
uniform vec4 stain_color : source_color = vec4(0.66, 0.52, 0.33, 1.0);
uniform vec2 rect_size = vec2(1280.0, 720.0);
uniform float stain_amount : hint_range(0.0, 1.0) = 0.55;
uniform float edge_burn : hint_range(0.0, 1.0) = 0.6;
uniform float grain : hint_range(0.0, 0.2) = 0.05;
uniform float seed = 3.0;

varying vec2 local_pos;

void vertex() {
	local_pos = VERTEX;
}

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21) + seed);
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
	           mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += a * vnoise(p);
		p *= 2.03;
		a *= 0.5;
	}
	return v;
}

void fragment() {
	vec2 p = local_pos;
	vec3 col = paper_color.rgb;

	// big soft blotches
	float blotch = fbm(p / 260.0);
	col = mix(col, stain_color.rgb, smoothstep(0.45, 0.85, blotch) * 0.45 * stain_amount);

	// a couple of tide-line rings (coffee / water stains)
	float ring = 0.0;
	for (int i = 0; i < 3; i++) {
		vec2 c = vec2(hash(vec2(float(i), 1.0)), hash(vec2(float(i), 7.0))) * rect_size;
		float r = 60.0 + hash(vec2(float(i), 3.0)) * 110.0;
		float d = length(p - c) + (fbm(p / 25.0) - 0.5) * 18.0;
		ring += smoothstep(4.0, 0.0, abs(d - r)) * 0.8 + smoothstep(r, r * 0.4, d) * 0.12;
	}
	col = mix(col, stain_color.rgb * 0.9, clamp(ring, 0.0, 1.0) * 0.35 * stain_amount);

	// fibres and grain
	float fib = vnoise(vec2(p.x / 2.0, p.y / 40.0)) * vnoise(vec2(p.x / 45.0, p.y / 2.5));
	col -= fib * 0.05;
	col += (hash(floor(p)) - 0.5) * grain;

	// darkened, burnt edges
	vec2 uv = p / rect_size;
	float edge = min(min(uv.x, 1.0 - uv.x), min(uv.y, 1.0 - uv.y));
	edge += (fbm(p / 40.0) - 0.5) * 0.04;
	col = mix(col, stain_color.rgb * 0.55, smoothstep(0.08, 0.0, edge) * edge_burn);

	COLOR = vec4(col, 1.0);
}
