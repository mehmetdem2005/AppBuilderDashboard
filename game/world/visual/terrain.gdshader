shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

// Height/slope terrain colouring. GL-compatibility safe (no derivatives-heavy
// or compute features). Uniforms fed live from the active BiomeProfile.

uniform float sea_level = 11.5;
uniform float relief = 230.0;
uniform vec3 c_sand  : source_color = vec3(0.36, 0.305, 0.185);
uniform vec3 c_grass : source_color = vec3(0.105, 0.155, 0.062);
uniform vec3 c_grass2: source_color = vec3(0.150, 0.180, 0.080);
uniform vec3 c_dry   : source_color = vec3(0.165, 0.158, 0.090);
uniform vec3 c_rock  : source_color = vec3(0.135, 0.122, 0.108);

varying vec3 v_wpos;
varying vec3 v_wnorm;

void vertex() {
	v_wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void fragment() {
	float y = v_wpos.y;
	float slope = 1.0 - clamp(v_wnorm.y, 0.0, 1.0);
	float hrel = clamp((y - sea_level) / max(relief - sea_level, 1.0), 0.0, 1.0);
	float n = vnoise(v_wpos.xz * 0.06) * 0.5 + vnoise(v_wpos.xz * 0.4) * 0.5;

	vec3 col = mix(c_grass, c_grass2, n);
	col = mix(col, c_dry, smoothstep(0.45, 0.72, hrel));
	col = mix(col, c_rock, smoothstep(0.72, 0.92, hrel));
	col = mix(c_sand, col, smoothstep(0.0, 0.045, hrel));
	col = mix(col, c_rock, smoothstep(0.42, 0.62, slope));
	col *= 0.92 + 0.16 * n;

	ALBEDO = col;
	ROUGHNESS = 0.93;
	SPECULAR = 0.18;
}
