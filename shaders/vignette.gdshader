shader_type canvas_item;
// Full-screen overlay: lamp-lit vignette that tightens as the dream sours.

uniform float dread : hint_range(0.0, 1.0) = 0.0;
uniform float strength : hint_range(0.0, 2.0) = 0.9;
uniform vec4 warm : source_color = vec4(0.22, 0.12, 0.04, 1.0);
uniform vec4 cold : source_color = vec4(0.03, 0.05, 0.10, 1.0);

float hash(float n) { return fract(sin(n) * 43758.5453); }

void fragment() {
	vec2 uv = SCREEN_UV - 0.5;
	uv.x *= SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	float d = length(uv);
	// candle flicker
	float t = TIME * 7.0;
	float flick = mix(hash(floor(t)), hash(floor(t) + 1.0), fract(t)) * 0.03;
	float inner = mix(0.42, 0.30, dread) + flick;
	float v = smoothstep(inner, inner + 0.55, d) * strength;
	vec3 tint = mix(warm.rgb, cold.rgb, dread);
	COLOR = vec4(tint, clamp(v, 0.0, 0.95));
}
