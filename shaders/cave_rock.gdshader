shader_type spatial;
// The cave: rough stone on the walls and ceiling, packed earth on the floor.
// World-space triplanar (the cave mesh has no UVs), with triplanar normal maps.
// `lump` pushes the surface in and out (the rock that grows over the mouth).

uniform sampler2D rock_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D rock_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D dirt_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D dirt_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform float rock_scale = 0.33;      // tiles per metre
uniform float dirt_scale = 0.5;
uniform float normal_strength = 1.0;
uniform vec4 tint : source_color = vec4(1.0);
uniform float lump = 0.0;

varying vec3 wpos;
varying vec3 wnrm;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float vnoise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i + vec3(0, 0, 0)), hash(i + vec3(1, 0, 0)), f.x),
				   mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
			   mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x),
				   mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

void vertex() {
	if (lump > 0.0) {
		float n = vnoise(VERTEX * 2.1) * 0.6 + vnoise(VERTEX * 5.3) * 0.4;
		VERTEX += NORMAL * (n - 0.45) * lump;
	}
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

vec3 tri_albedo(sampler2D t, vec3 p, vec3 w, float s) {
	return texture(t, p.zy * s).rgb * w.x + texture(t, p.xz * s).rgb * w.y + texture(t, p.xy * s).rgb * w.z;
}

// "Whiteout" triplanar normal blend, returns a world-space normal.
vec3 tri_normal(sampler2D t, vec3 p, vec3 n, vec3 w, float s) {
	vec3 tx = texture(t, p.zy * s).rgb * 2.0 - 1.0;
	vec3 ty = texture(t, p.xz * s).rgb * 2.0 - 1.0;
	vec3 tz = texture(t, p.xy * s).rgb * 2.0 - 1.0;
	tx.xy *= normal_strength;
	ty.xy *= normal_strength;
	tz.xy *= normal_strength;
	tx = vec3(tx.xy + n.zy, abs(tx.z) * n.x);
	ty = vec3(ty.xy + n.xz, abs(ty.z) * n.y);
	tz = vec3(tz.xy + n.xy, abs(tz.z) * n.z);
	return normalize(tx.zyx * w.x + ty.xzy * w.y + tz.xyz * w.z);
}

void fragment() {
	vec3 n = normalize(wnrm);
	vec3 w = pow(abs(n), vec3(4.0));
	w /= (w.x + w.y + w.z);
	// earth settles on anything that faces up
	float blotch = vnoise(wpos * 0.7) * 0.5 + vnoise(wpos * 2.3) * 0.25;
	float dirt = smoothstep(0.5, 0.85, n.y + (blotch - 0.35) * 0.5);
	vec3 rock = tri_albedo(rock_albedo, wpos, w, rock_scale);
	vec3 earth = tri_albedo(dirt_albedo, wpos, w, dirt_scale);
	vec3 col = mix(rock, earth, dirt);
	// damp, darker stains running down the walls
	col *= mix(0.75, 1.05, vnoise(vec3(wpos.x * 1.7, wpos.y * 0.25, wpos.z * 1.7)));
	ALBEDO = col * tint.rgb;
	ROUGHNESS = mix(0.82, 0.95, dirt);
	vec3 nw = normalize(mix(tri_normal(rock_normal, wpos, n, w, rock_scale), tri_normal(dirt_normal, wpos, n, w, dirt_scale), dirt));
	NORMAL = normalize((VIEW_MATRIX * vec4(nw, 0.0)).xyz);
}
