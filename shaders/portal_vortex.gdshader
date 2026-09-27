shader_type spatial;
// The swirl behind a portal door: spiral arms of violet and teal turning in
// towards a dark hole. Unshaded and bright enough to bloom.
render_mode unshaded, cull_disabled, fog_disabled;

uniform vec4 color_a : source_color = vec4(0.58, 0.28, 1.0, 1.0);
uniform vec4 color_b : source_color = vec4(0.12, 0.85, 0.8, 1.0);
uniform float aspect = 1.6;       // quad height / width
uniform float strength = 1.0;     // 0 = dark, 1 = full swirl

void fragment() {
	vec2 p = (UV - 0.5) * vec2(1.0, aspect);
	float r = length(p);
	float a = atan(p.y, p.x);
	float t = TIME;
	float arms = 0.5 + 0.5 * sin(a * 3.0 + r * 16.0 - t * 4.0);
	float fine = 0.5 + 0.5 * sin(a * 7.0 - r * 30.0 + t * 6.5);
	float v = arms * 0.75 + fine * 0.25;
	vec3 c = mix(color_a.rgb, color_b.rgb, arms * (0.5 + 0.5 * sin(t * 0.7 + r * 4.0)));
	float hole = smoothstep(0.04, 0.3, r);                 // the dark eye in the middle
	float rim = 1.0 + 0.8 * smoothstep(0.2, 0.55, r);
	ALBEDO = c * v * hole * rim * 0.95 * strength + vec3(0.02, 0.0, 0.05);
}
