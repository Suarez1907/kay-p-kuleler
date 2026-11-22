// Robo'nun vizör yüzü: iki ışıyan göz, ruh hâline göre şekil + otomatik göz kırpma.
// mood: 0 normal · 1 mutlu (^ ^) · 2 üzgün · 3 şaşkın (O O) · 4 uyuyor (— —) · 5 uykulu (yarı kapalı)
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back, shadows_disabled;

uniform vec4 eye_color : source_color = vec4(0.43, 0.96, 1.0, 1.0);
uniform int mood = 0;
uniform float blink_seed = 0.0;
uniform float energy = 3.2;

float box(vec2 p, vec2 b, float r) {
	vec2 q = abs(p) - b + r;
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

float eye(vec2 p, float side) {
	float d;
	if (mood == 1) {          // ^ biçimli yay
		float a = abs(p.x) * 1.2;
		d = abs(p.y + 0.05 - (0.12 - a * a * 2.4)) - 0.035;
		d = max(d, abs(p.x) - 0.13);
	} else if (mood == 3) {   // iri yuvarlak
		d = length(p) - 0.12;
	} else if (mood == 4) {   // kapalı çizgi
		d = box(p + vec2(0.0, 0.02), vec2(0.12, 0.018), 0.018);
	} else {
		float h = 0.11;
		if (mood == 5) h = 0.05;
		d = box(p, vec2(0.085, h), 0.06);
		if (mood == 2) {      // üzgün: dış köşeden aşağı eğik göz kapağı
			float lid = p.y - 0.06 + side * p.x * 0.6;
			d = max(d, lid);
		}
	}
	return d;
}

void fragment() {
	vec2 uv = (UV - 0.5) * vec2(1.5, 0.9);
	// göz kırpma: ~4 sn'de bir 0.12 sn
	float tb = fract((TIME + blink_seed) / 4.2);
	float blink = (mood == 0 || mood == 2 || mood == 5) ? smoothstep(0.0, 0.015, abs(tb - 0.97)) : 1.0;
	vec2 p = uv;
	p.y /= max(blink, 0.08);
	float d = min(eye(p - vec2(-0.36, 0.0), -1.0), eye(p - vec2(0.36, 0.0), 1.0));
	float core = 1.0 - smoothstep(0.0, 0.012, d);
	float glow = exp(-max(d, 0.0) * 28.0) * 0.45;
	float a = clamp(core + glow, 0.0, 1.0);
	ALBEDO = eye_color.rgb * energy * a;
	ALPHA = a;
}
