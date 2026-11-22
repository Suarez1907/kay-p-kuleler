// Kulenin altındaki baskı devre kartı (PCB): zümrüt yeşili lehim maskesi, altından geçen bakır yollar
// (maskenin altında açık yeşil görünür), altın kaplı vialar ve pedler, beyaz serigrafi işaretleri.
// Desen dünya koordinatından üretilir; doku dosyası yoktur.
shader_type spatial;

uniform vec3 mask_color : source_color = vec3(0.03, 0.24, 0.16);
uniform vec3 trace_color : source_color = vec3(0.09, 0.42, 0.26);
uniform vec3 gold : source_color = vec3(0.86, 0.66, 0.28);
uniform vec3 silk : source_color = vec3(0.92, 0.94, 0.9);
uniform float cell = 0.5;
uniform float pulse = 0.0;
uniform vec3 pulse_pos = vec3(0.0);

varying vec3 wpos;

float h12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = wpos.xz / cell;
	vec2 id = floor(p);
	vec2 f = fract(p) - 0.5;
	float r = h12(id);
	float r2 = h12(id + 17.3);
	float w = 0.09;
	// her hücrede bir yol parçası: yatay, dikey ya da köşegen; komşularla birleşerek uzun hatlar oluşturur
	float tr = 0.0;
	if (r < 0.32) tr = step(abs(f.y), w);
	else if (r < 0.62) tr = step(abs(f.x), w);
	else if (r < 0.74) tr = step(abs(f.x - f.y) * 0.7071, w);
	else if (r < 0.82) tr = step(abs(f.x + f.y) * 0.7071, w);
	// paralel veri yolu demetleri
	float bus = step(0.86, h12(vec2(id.y, 3.0))) * step(abs(fract(p.y * 3.0) - 0.5), 0.12);
	tr = max(tr, bus * step(0.3, h12(vec2(id.x, id.y * 0.0 + 7.0))));
	vec3 col = mix(mask_color, trace_color, tr);
	// via: altın halka + delik
	float d = length(f - (vec2(r2, h12(id + 5.1)) - 0.5) * 0.5);
	float via = step(0.88, r2);
	col = mix(col, gold, via * smoothstep(0.13, 0.11, d) * smoothstep(0.04, 0.06, d));
	col = mix(col, vec3(0.02), via * smoothstep(0.05, 0.035, d));
	// SMD pedleri (küçük altın dikdörtgenler)
	vec2 pd = abs(f - vec2(0.18, -0.2));
	float pad = step(0.93, h12(id + 41.0)) * step(pd.x, 0.12) * step(pd.y, 0.06);
	col = mix(col, gold, pad);
	// serigrafi: ince beyaz çerçeveler ve kısa işaretler
	vec2 sp = abs(fract(wpos.xz / (cell * 6.0)) - 0.5);
	float frame = step(0.47, max(sp.x, sp.y)) * step(max(sp.x, sp.y), 0.485) * step(0.55, h12(floor(wpos.xz / (cell * 6.0))));
	float tick = step(0.97, h12(id + 91.0)) * step(abs(f.y + 0.32), 0.02) * step(abs(f.x), 0.3);
	col = mix(col, silk, max(frame * 0.35, tick * 0.8));
	ALBEDO = col;
	float metal = max(via, pad) + tr * 0.1;
	METALLIC = metal * 0.8;
	ROUGHNESS = mix(0.42, 0.22, metal);
	SPECULAR = 0.5;
	// Robo'nun adımıyla yollardan yayılan enerji halkası
	float rd = length(wpos.xz - pulse_pos.xz);
	float ring = smoothstep(0.35, 0.0, abs(rd - (1.0 - pulse) * 6.0)) * pulse;
	EMISSION = vec3(1.0, 0.6, 0.2) * ring * tr * 1.6 + gold * 0.02 * pad;
}
