shader_type canvas_item;
// Settings > Brightness: lifts the dark parts of the picture without washing
// out the light ones (a gamma curve), plus a touch of gain.

uniform sampler2D screen : hint_screen_texture, filter_linear;
uniform float brightness = 1.0;

void fragment() {
	vec3 c = texture(screen, SCREEN_UV).rgb;
	c = pow(max(c, vec3(0.0)), vec3(1.0 / brightness)) * mix(1.0, brightness, 0.12);
	COLOR = vec4(c, 1.0);
}
