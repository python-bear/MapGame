shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back;
// Ochre on stone: the pigment takes the grain of the rock it was rubbed onto.
// `glow` makes it smoulder (when the cave does something it shouldn't).

uniform sampler2D paint : source_color, filter_linear_mipmap;
uniform sampler2D rock_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D rock_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform vec2 size = vec2(2.0, 1.5);       // metres, to match the rock's scale
uniform float rock_scale = 0.33;
uniform float glow = 0.0;

void fragment() {
	vec4 p = texture(paint, UV);
	vec2 ruv = UV * size * rock_scale;
	float grain = dot(texture(rock_albedo, ruv).rgb, vec3(0.33));
	ALBEDO = p.rgb * mix(0.6, 1.25, grain * 2.2);
	ALPHA = p.a * smoothstep(0.08, 0.5, grain * 1.6 + 0.1);
	ROUGHNESS = 0.9;
	NORMAL_MAP = texture(rock_normal, ruv).rgb;
	EMISSION = p.rgb * glow * p.a;
}
