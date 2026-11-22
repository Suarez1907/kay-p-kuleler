// Blueprint v2 arka planı: lacivert zemin, 24 px milimetrik ızgara, her 5 karede cyan ana çizgi,
// merkezde hafif spot ışığı ve kenarlarda yumuşak vinyet. "hole" > 0 ise merkezde elips bir pencere açılır
// (başlık ekranında 3D vitrin bu pencereden görünür).
shader_type canvas_item;

uniform vec4 bg : source_color = vec4(0.027, 0.071, 0.141, 1.0);
uniform vec4 minor_col : source_color = vec4(0.169, 0.298, 0.494, 0.14);
uniform vec4 major_col : source_color = vec4(0.0, 0.898, 1.0, 0.12);
uniform float cell = 24.0;
uniform float vignette = 0.45;
uniform float hole = 0.0;          // 0: tam opak; 0..1: merkez pencere yarıçapı (kısa kenara oranla)
uniform vec2 hole_center = vec2(0.5, 0.52);
uniform float opacity = 1.0;

float grid_line(vec2 p, float step_px, float width) {
	vec2 g = abs(fract(p / step_px - 0.5) - 0.5) * step_px;
	float d = min(g.x, g.y);
	return 1.0 - smoothstep(width * 0.5, width * 0.5 + 1.0, d);
}

void fragment() {
	vec2 px = FRAGCOORD.xy;
	vec2 res = 1.0 / SCREEN_PIXEL_SIZE;
	vec2 uv = px / res;
	vec3 c = bg.rgb;
	float minor = grid_line(px, cell, 1.0);
	float major = grid_line(px, cell * 5.0, 1.4);
	c = mix(c, minor_col.rgb, minor * minor_col.a);
	c = mix(c, major_col.rgb, major * major_col.a);
	// merkez spot + vinyet
	vec2 q = (uv - vec2(0.5, 0.45)) * vec2(res.x / max(res.y, 1.0), 1.0);
	float r = length(q);
	c += vec3(0.02, 0.05, 0.09) * (1.0 - smoothstep(0.0, 0.7, r));
	c *= 1.0 - vignette * smoothstep(0.35, 1.05, r);
	float a = opacity;
	if (hole > 0.0) {
		vec2 hq = (uv - hole_center) * vec2(res.x / min(res.x, res.y), res.y / min(res.x, res.y));
		float hr = length(hq * vec2(0.8, 1.0));
		a *= smoothstep(hole * 0.75, hole, hr);
	}
	COLOR = vec4(c, a);
}
