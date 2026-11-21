// Kayıp Kuleler — bölüm bloğu. Tek spatial shader, doku yok.
// Üst yüzde (dünya normali y > 0.7) her temada okunur bir iç karo çerçevesi çizer.
// visual_style: ChapterTheme.VisualStyle ile aynı sıra (0 KINTSUGI … 14 COSMIC_PORCELAIN).
// role: 0 blok, 1 merdiven, 2 hedef kristal.
shader_type spatial;

uniform int visual_style = 0;
uniform int role = 0;
uniform vec3 base_color : source_color = vec3(0.62);
uniform vec3 top_color : source_color = vec3(0.82);
uniform vec3 accent_color : source_color = vec3(0.91, 0.73, 0.29);
uniform float roughness_amt : hint_range(0.0, 1.0) = 0.8;
uniform float metallic_amt : hint_range(0.0, 1.0) = 0.0;
uniform float emission_strength : hint_range(0.0, 4.0) = 0.0;
uniform float stepped_glow : hint_range(0.0, 1.0) = 0.0;

varying vec3 local_pos;
varying vec3 world_pos;
varying vec3 world_nrm;
varying vec4 v_color;
varying vec2 v_uv;

float h21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	local_pos = VERTEX;
	v_uv = UV;
	v_color = COLOR;
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_nrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 wn = normalize(world_nrm);
	float up = smoothstep(0.45, 0.85, wn.y);
	float ndv = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	float fres = pow(1.0 - ndv, 3.0);
	vec3 albedo = mix(base_color, top_color, up);
	vec3 emit = accent_color * emission_strength * 0.18;
	float rough = roughness_amt;
	float metal = metallic_amt;
	float ax = max(abs(local_pos.x), max(abs(local_pos.y), abs(local_pos.z)));

	if (role == 2) {
		albedo = accent_color;
		rough = min(rough, 0.28);
		metal = max(metal, 0.12);
		emit = accent_color * (1.5 + fres * 1.8 + emission_strength);
	} else {
	float bevel = smoothstep(0.40, 0.50, ax);
	albedo = mix(albedo, albedo * 0.78 + accent_color * 0.10, bevel * (1.0 - up * 0.35));

	// Okunur iç karo: yalnızca üst yüzde, UV yüzeyi 0..1 kabul edilir.
	if (wn.y > 0.7) {
		float fu = min(v_uv.x, 1.0 - v_uv.x);
		float fv = min(v_uv.y, 1.0 - v_uv.y);
		float inset = min(fu, fv);
		float inner = smoothstep(0.10, 0.18, inset);
		float line = smoothstep(0.10, 0.14, inset) * (1.0 - smoothstep(0.18, 0.24, inset));
		vec3 paper = mix(top_color, vec3(1.0), 0.22);
		albedo = mix(albedo, paper, inner * 0.72);
		albedo = mix(albedo, mix(paper, vec3(1.0), 0.45), line);
	}

	// Komşu bloklar bir tık ayrı dursun (oynanış ızgarası).
	float chk = h21(floor(world_pos.xz + vec2(0.5)));
	albedo *= mix(0.96, 1.03, chk);

	if (visual_style == 0) {
		vec2 p = world_pos.xz * 3.2;
		float veins = abs(sin(p.x * 1.7 + sin(p.y * 2.4) * 1.5));
		float crack = 1.0 - smoothstep(0.0, 0.10, veins);
		albedo = mix(albedo, accent_color, crack * 0.9);
		emit += accent_color * crack * (0.12 + stepped_glow * 1.8);
	} else if (visual_style == 1) {
		float r = length(local_pos.xz);
		float rings = 1.0 - smoothstep(0.0, 0.018, abs(r - 0.22));
		rings = max(rings, 1.0 - smoothstep(0.0, 0.018, abs(r - 0.34)));
		albedo = mix(albedo, accent_color, rings * up);
		metal = mix(metal, 0.55, rings * up);
	} else if (visual_style == 2 && wn.y > 0.65) {
		float e = max(abs(local_pos.x), abs(local_pos.z));
		float led = smoothstep(0.30, 0.38, e) * (1.0 - smoothstep(0.44, 0.50, e));
		float pulse = 0.75 + 0.25 * sin(TIME * 4.0);
		emit += accent_color * led * pulse * 1.6;
		albedo = mix(albedo, accent_color, led * 0.65);
	} else if (visual_style == 3 || visual_style == 7) {
		vec3 violet = vec3(0.482, 0.173, 0.749);
		float violet_mix = 0.0;
		if (visual_style == 3) {
			violet_mix = 0.45;
		}
		vec3 glow = mix(accent_color, violet, violet_mix);
		emit += glow * fres * 1.15;
		albedo = mix(albedo, glow, fres * 0.28);
		rough = mix(rough, 0.12, fres);
	} else if (visual_style == 4 && wn.y > 0.7) {
		float crease = 1.0 - smoothstep(0.0, 0.03, abs(abs(local_pos.x) - abs(local_pos.z)));
		albedo = mix(albedo, albedo * 0.72, crease);
	} else if (visual_style == 5 && wn.y > 0.55) {
		float hatch = abs(fract(local_pos.x * 9.0 + local_pos.z * 9.0) - 0.5);
		float ink = 1.0 - smoothstep(0.42, 0.48, hatch);
		albedo = mix(albedo, vec3(0.12, 0.12, 0.13), ink * 0.55);
	} else if (visual_style == 6) {
		albedo = mix(albedo, mix(albedo, accent_color, 0.35), bevel);
		metal = mix(metal, 0.75, bevel);
		rough = mix(rough, 0.18, bevel);
	} else if (visual_style == 8) {
		float thread = abs(fract(world_pos.x * 3.5 + sin(world_pos.z * 5.0)) - 0.5);
		float line = 1.0 - smoothstep(0.0, 0.04, thread);
		vec3 purple = vec3(0.62, 0.45, 0.98);
		albedo = mix(albedo, accent_color, line * 0.75);
		emit += mix(accent_color, purple, 0.55) * line * 0.7;
	} else if (visual_style == 9 && wn.y > 0.7) {
		float ang = atan(local_pos.z, local_pos.x);
		float ray = abs(fract(ang * 2.2) - 0.5);
		float spoke = 1.0 - smoothstep(0.0, 0.06, ray);
		albedo = mix(albedo, albedo * 0.78, spoke * 0.65);
	} else if (visual_style == 10 && wn.y > 0.7) {
		float star = step(0.985, h21(floor(world_pos.xz * 16.0)));
		albedo = mix(albedo, vec3(1.0), star);
		emit += vec3(0.85, 0.9, 1.0) * star * 0.4;
	} else if (visual_style == 11) {
		float stripe = step(0.55, fract((local_pos.x + local_pos.y) * 4.0));
		albedo = mix(albedo, accent_color, stripe * (1.0 - up) * 0.22);
	} else if (visual_style == 12) {
		vec2 g = abs(fract(world_pos.xz * 2.0) - 0.5);
		float grid = 1.0 - smoothstep(0.0, 0.025, min(g.x, g.y));
		float edge = smoothstep(0.46, 0.495, ax);
		float line = max(grid * step(0.5, wn.y), edge);
		albedo = mix(albedo, vec3(0.886, 0.945, 1.0), line);
		emit += vec3(0.75, 0.88, 1.0) * line * 0.45;
	} else if (visual_style == 13 && wn.y > 0.7) {
		float rake = abs(fract(local_pos.x * 16.0) - 0.5);
		float groove = 1.0 - smoothstep(0.38, 0.46, rake);
		albedo = mix(albedo, albedo * 0.80, groove * 0.85);
	} else if (visual_style == 14) {
		vec2 p2 = world_pos.xz * 5.5;
		float fil = abs(sin(p2.x * 2.2 + cos(p2.y * 1.8) * 2.0));
		float gold = 1.0 - smoothstep(0.0, 0.07, fil);
		albedo = mix(albedo, accent_color, gold * 0.8);
		emit += accent_color * gold * (0.25 + emission_strength);
	}
	}

	ALBEDO = albedo * v_color.rgb;
	ROUGHNESS = rough;
	METALLIC = metal;
	SPECULAR = mix(0.35, 0.7, metal);
	if (role == 2) {
		SPECULAR = 0.65;
	}
	EMISSION = emit;
}
