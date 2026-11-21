// Kayıp Kuleler — prosedürel gökyüzü ve hava durumu (canvas_item, tam ekran arka plan).
// Doku dosyası kullanmaz: her piksel ekran çözünürlüğünde hesaplanır, bu yüzden 4K'da da keskindir.
// Katmanlar (arkadan öne): gökyüzü gradyanı → yıldızlar / kuzey ışıkları → güneş / ay → sirrus →
// perspektifli kümülüs bulutları (güneşe göre kendi gölgesi + gümüş kenar) → yıldırım → uzak dağlar
// ve ufuk sisi → zemin → hortum → yağmur / kar → şimşek parlaması.
shader_type canvas_item;

uniform float aspect = 1.7778;
uniform float quality : hint_range(0.0, 2.0) = 2.0;   // 0 düşük, 1 orta, 2 yüksek
uniform float yaw = 0.0;                              // kamera açısı (radyan) → paralaks
uniform float seed = 0.0;
uniform float time_scale = 1.0;
uniform float horizon = 0.64;                          // ufuk çizgisi (ekranın üstünden oran)

uniform vec3 sky_top : source_color = vec3(0.32, 0.55, 0.85);
uniform vec3 sky_mid : source_color = vec3(0.55, 0.74, 0.92);
uniform vec3 sky_horizon : source_color = vec3(0.86, 0.9, 0.94);
uniform vec3 haze : source_color = vec3(0.82, 0.87, 0.92);
uniform vec3 mountain : source_color = vec3(0.45, 0.55, 0.66);
uniform vec3 ground : source_color = vec3(0.42, 0.5, 0.42);

uniform vec2 sun_pos = vec2(0.78, 0.16);
uniform vec3 sun_color : source_color = vec3(1.0, 0.95, 0.85);
uniform float sun_size = 0.028;
uniform float sun_glow = 0.6;
uniform float moon = 0.0;
uniform float stars = 0.0;
uniform float aurora = 0.0;

uniform float cloud_cover = 0.45;        // 0 açık … 1 tamamen kapalı
uniform float cloud_density = 1.0;
uniform vec3 cloud_lit : source_color = vec3(1.0, 1.0, 1.0);
uniform vec3 cloud_shade : source_color = vec3(0.55, 0.6, 0.7);
uniform float cloud_speed = 0.012;
uniform float cloud_scale = 1.0;
uniform float cirrus = 0.3;
uniform float scud = 0.0;                // alçak, hızlı fırtına bulutları

uniform float rain = 0.0;
uniform float snow = 0.0;
uniform float wind = 0.15;               // yağışın eğimi
uniform float flash = 0.0;               // şimşek parlaması 0..1
uniform vec4 bolt = vec4(0.5, 0.0, 9.0, 0.0);   // x, tohum, yaş (sn), yer=1 / bulut içi=0
uniform float tornado = 0.0;
uniform float tornado_x = 0.3;
uniform float snow_ground = 0.0;

// ---------- gürültü ----------
float h12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}
vec2 h22(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.xx + p3.yz) * p3.zy);
}
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
	float a = h12(i);
	float b = h12(i + vec2(1.0, 0.0));
	float c = h12(i + vec2(0.0, 1.0));
	float d = h12(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}
const mat2 ROT = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8));
float fbm(vec2 p, int oct) {
	float s = 0.0;
	float a = 0.5;
	for (int i = 0; i < 8; i++) {
		if (i >= oct) break;
		s += a * vnoise(p);
		p = ROT * p * 2.03 + vec2(1.7, 9.2);
		a *= 0.5;
	}
	return s;
}

// Kümülüs yoğunluğu: alan bükmeli fbm, kapsama eşiğiyle kesilir
float cloud_field(vec2 p, float t, int oct) {
	vec2 q = vec2(fbm(p * 0.6 + vec2(0.0, t * 0.3), 3), fbm(p * 0.6 + vec2(5.2, 1.3 - t * 0.2), 3));
	float n = fbm(p + 1.6 * q + vec2(t, 0.0), oct);
	float thr = mix(0.72, 0.2, cloud_cover);
	return clamp((n - thr) / (1.0 - thr) * 2.2 * cloud_density, 0.0, 1.0);
}

// Yıldırımın yatay sapması: kırıklı çizgi (iki ölçekte gürültü)
float bolt_x(float y, float sd) {
	return (vnoise(vec2(y * 9.0, sd)) - 0.5) * 0.09 + (vnoise(vec2(y * 38.0, sd + 7.0)) - 0.5) * 0.025;
}

void fragment() {
	vec2 uv = UV;
	float t = TIME * time_scale;
	int oct = quality >= 1.5 ? 7 : (quality >= 0.5 ? 5 : 4);
	float px = 1.0 / max(SCREEN_PIXEL_SIZE.y, 1e-4);     // ekran yüksekliği (piksel)
	float par = yaw * 0.08;                                 // paralaks kayması

	// ---------- gökyüzü gradyanı (ufukta daha açık, tepede daha doygun) ----------
	float e = clamp((horizon - uv.y) / horizon, 0.0, 1.0);   // yükseklik: 0 ufuk, 1 tepe
	vec3 col = mix(sky_horizon, sky_mid, smoothstep(0.0, 0.35, e));
	col = mix(col, sky_top, smoothstep(0.3, 1.0, e));

	vec2 sp = vec2(uv.x * aspect, uv.y);
	vec2 sun_sp = vec2(sun_pos.x * aspect, sun_pos.y);
	float sd = length(sp - sun_sp);

	// ---------- yıldızlar ----------
	if (stars > 0.0 && uv.y < horizon) {
		vec2 g = sp * 180.0;
		vec2 id = floor(g);
		vec2 o = h22(id + seed);
		float r = h12(id + 3.1);
		float d = length(fract(g) - o);
		float tw = 0.6 + 0.4 * sin(t * (1.5 + r * 3.0) + r * 40.0);
		float st = smoothstep(0.08, 0.0, d) * step(0.93, r) * tw;
		col += vec3(st) * stars * smoothstep(0.0, 0.3, e) * 1.4;
		// samanyolu tozu
		float mw = fbm(sp * 3.0 + vec2(seed), 4);
		col += vec3(0.25, 0.25, 0.35) * stars * pow(mw, 3.0) * smoothstep(0.1, 0.6, e) * 0.7;
	}
	// ---------- kuzey ışıkları ----------
	if (aurora > 0.0) {
		float ax = sp.x * 1.3 + par;
		float band = fbm(vec2(ax * 1.5, t * 0.05), 4);
		float yc = 0.18 + band * 0.22;
		// perde: alt kenarı keskin, yukarı doğru sönen ışınlar
		float dy = uv.y - yc;
		float curtain = smoothstep(0.012, 0.0, dy) * exp(dy * 9.0) * step(-0.35, dy);
		float rays = pow(vnoise(vec2(ax * 45.0, t * 0.4)), 2.0) * 0.8 + 0.2;
		float fold = smoothstep(0.25, 0.65, fbm(vec2(ax * 3.0 - t * 0.04, 2.0), 3));
		float a = curtain * rays * fold * aurora;
		vec3 ac = mix(vec3(0.2, 1.0, 0.6), vec3(0.65, 0.35, 1.0), smoothstep(0.0, -0.22, dy));
		col += ac * a * 0.5;
	}
	// ---------- güneş / ay ----------
	float glow = exp(-sd * 6.0) * sun_glow + exp(-sd * 1.6) * sun_glow * 0.35;
	col += sun_color * glow * (1.0 - cloud_cover * 0.6);
	float disc = smoothstep(sun_size, sun_size * 0.82, sd);
	if (moon > 0.0) {
		float cr = fbm((sp - sun_sp) * 40.0, 4);
		col = mix(col, vec3(0.92, 0.93, 0.98) * (0.78 + 0.3 * cr), disc * moon);
	} else {
		col = mix(col, sun_color * 1.6, disc);
	}

	// ---------- sirrus (yüksek, ince, rüzgârla uzamış) ----------
	if (cirrus > 0.0 && uv.y < horizon) {
		vec2 cp = vec2(sp.x * 0.7 + par * 0.5, uv.y * 3.5) + vec2(t * cloud_speed * 0.6, 0.0);
		float c = fbm(cp * vec2(2.0, 6.0) + fbm(cp * 3.0, 3), oct - 1);
		c = smoothstep(0.55, 0.85, c) * cirrus * smoothstep(0.05, 0.4, e);
		col = mix(col, mix(cloud_lit, sun_color, 0.2), c * 0.6);
	}

	// ---------- kümülüs: perspektifli bulut düzlemi ----------
	float cover_a = 0.0;
	if (uv.y < horizon + 0.01) {
		float z = 1.0 / (e + 0.06);                          // derinlik (ufka yaklaştıkça artar)
		vec2 cp = vec2((uv.x - 0.5) * aspect * z * 0.85 + par * 3.0, z * 0.8) * cloud_scale;
		cp += vec2(t * cloud_speed * 8.0, t * cloud_speed * 2.0) + seed;
		float d = cloud_field(cp, t * cloud_speed * 3.0, oct);
		// kendi gölgesi: güneşe doğru kaydırılmış ikinci örnek (yüksek kalitede iki örnek)
		vec2 to_sun = normalize(vec2((sun_pos.x - uv.x) * aspect, sun_pos.y - uv.y) + vec2(1e-4, 0.0));
		float sh = cloud_field(cp + to_sun * 0.18, t * cloud_speed * 3.0, oct - 2);
		if (quality >= 1.5) sh = 0.6 * sh + 0.4 * cloud_field(cp + to_sun * 0.42, t * cloud_speed * 3.0, 4);
		float light = exp(-sh * 2.4);
		// altta koyu taban, üstte aydınlık; ince kenarlar güneşe yakınken parlar (gümüş kenar)
		float base = smoothstep(0.0, 0.9, d);
		vec3 cc = mix(cloud_shade, cloud_lit, light);
		cc = mix(cc, cloud_shade * 0.8, base * 0.35 * (1.0 - light));
		float silver = (1.0 - d) * exp(-sd * 3.0) * 1.4 * (1.0 - moon) * clamp(sun_glow * 1.4, 0.0, 1.0);
		cc += sun_color * silver * smoothstep(0.0, 0.25, d);
		// şimşek bulutları içeriden aydınlatır
		cc += vec3(0.8, 0.84, 1.0) * flash * (0.12 + 0.45 * d) * (0.6 + 0.4 * vnoise(cp * 0.7 + bolt.y));
		// uzaktaki bulutlar sise karışır
		float far = smoothstep(4.0, 15.0, z);
		cc = mix(cc, mix(haze, cloud_shade, 0.35), far * 0.7);
		float a = smoothstep(0.0, 0.55, d) * (1.0 - smoothstep(0.0, 0.012, uv.y - horizon + 0.008));
		col = mix(col, cc, a);
		cover_a = a;

		// alçak, hızlı fırtına bulutları (scud)
		if (scud > 0.0) {
			vec2 sc = vec2((uv.x - 0.5) * aspect * z * 0.8 + par * 4.0, z * 1.4) + vec2(t * cloud_speed * 30.0, 0.0) + seed * 2.0;
			float s2 = smoothstep(0.5, 0.8, fbm(sc * 1.3, oct - 2)) * scud * smoothstep(0.0, 0.25, e) * (1.0 - far);
			col = mix(col, cloud_shade * 0.7 + flash * 0.5, s2 * 0.8);
		}
	}

	// ---------- yıldırım (bulut tabanından yere) ----------
	if (bolt.z < 0.35) {
		float age = bolt.z;
		float flick = step(0.5, fract(age * 18.0 + 0.3)) * 0.6 + 0.4;
		float life = 1.0 - smoothstep(0.08, 0.35, age);
		float top = horizon * 0.2;
		float bottom = bolt.w > 0.5 ? horizon + 0.015 : horizon * 0.55;
		if (uv.y > top && uv.y < bottom) {
			float yy = (uv.y - top) / (bottom - top);
			float bx = bolt.x + bolt_x(yy, bolt.y) * (0.4 + yy);
			float dx = abs(uv.x - bx) * aspect;
			// dal: orta yükseklikten ayrılan ikinci kırık çizgi
			float by = smoothstep(0.35, 0.4, yy);
			float bx2 = bolt.x + bolt_x(yy, bolt.y + 3.0) * 1.6 + (yy - 0.35) * 0.12 * sign(h12(vec2(bolt.y)) - 0.5);
			float dx2 = abs(uv.x - bx2) * aspect + (1.0 - by) * 10.0 + smoothstep(0.75, 0.95, yy) * 10.0;
			float w = 1.2 / px;
			float core = smoothstep(w * 2.0, 0.0, dx) + 0.6 * smoothstep(w * 1.5, 0.0, dx2);
			float halo = exp(-dx * 90.0) * 0.7 + exp(-dx2 * 120.0) * 0.35;
			col = mix(col, vec3(0.92, 0.95, 1.0), clamp(core, 0.0, 1.0) * life * flick);
			col += vec3(0.6, 0.7, 1.0) * halo * life * flick;
		}
	}

	// ---------- ufuk altı: uzak dağlar, sis ve zemin ----------
	if (uv.y > horizon - 0.12) {
		for (int k = 0; k < 3; k++) {
			float fk = float(k);
			float depth = 1.0 - fk * 0.3;                     // 1 en uzak
			float x = sp.x * (1.2 + fk * 0.8) + par * (1.0 + fk * 2.5) + seed * 0.3 + fk * 13.0;
			float hgt = (fbm(vec2(x, fk * 4.0), oct - 2) - 0.35) * (0.08 + fk * 0.03) + 0.01 * fk;
			float ridge = horizon - hgt;
			float m = smoothstep(ridge, ridge + 1.5 / px, uv.y);
			vec3 mc = mix(mountain, haze, depth * 0.75);
			mc = mix(mc, vec3(0.95, 0.97, 1.0), snow_ground * smoothstep(ridge + 0.02, ridge, uv.y) * 0.8);
			mc += sun_color * 0.08 * (1.0 - moon) * smoothstep(ridge + 0.03, ridge, uv.y);
			col = mix(col, mc, m);
		}
		// zemin: ufuktan aşağı doğru koyulaşan geniş ova, alçak sis
		float g = smoothstep(horizon + 0.005, horizon + 0.02, uv.y);
		float gz = (uv.y - horizon) / (1.0 - horizon);
		vec2 gp = vec2((uv.x - 0.5) * aspect / (gz + 0.05) * 0.3 + par * 6.0, 1.0 / (gz + 0.05));
		float tex = fbm(gp * 1.5, oct - 2);
		vec3 gc = mix(ground, ground * 0.7, tex);
		gc = mix(gc, vec3(0.93, 0.95, 0.98) * (0.85 + 0.15 * tex), snow_ground);
		gc = mix(haze, gc, smoothstep(0.0, 0.6, gz));
		col = mix(col, gc, g);
		col += vec3(0.85, 0.88, 1.0) * flash * 0.12 * g;
	}

	// ---------- hortum ----------
	if (tornado > 0.0) {
		float tx = tornado_x + sin(t * 0.13) * 0.06 + par * 0.4;
		float top = horizon * 0.3;
		float bottom = horizon + 0.012;
		if (uv.y > top - 0.06 && uv.y < bottom + 0.05) {
			float yy = clamp((uv.y - top) / (bottom - top), 0.0, 1.0);
			// gövde kıvrılır: aşağıya doğru salınım genliği artar
			float cx = tx + sin(yy * 3.2 + t * 0.9) * 0.018 * yy + sin(yy * 9.0 - t * 1.7) * 0.004;
			float w = mix(0.12, 0.022, pow(yy, 0.5)) * (1.0 + 0.15 * sin(yy * 20.0 - t * 4.0));
			float dx = (uv.x - cx) * aspect / w;
			float body = smoothstep(1.0, 0.55, abs(dx)) * step(uv.y, bottom) * step(top, uv.y);
			// dönen bantlar: silindir üzerinde açı ~ asin(dx)
			float ang = asin(clamp(dx, -1.0, 1.0));
			float swirl = fbm(vec2(ang * 1.5 + t * 6.0 + yy * 6.0, yy * 14.0 - t * 1.5), 4);
			float shade = sqrt(max(0.0, 1.0 - dx * dx));
			vec3 tc = mix(cloud_shade * 0.7, mix(haze, cloud_lit, 0.5) * 0.8 + flash * 0.4, shade * 0.45 + swirl * 0.45);
			col = mix(col, tc, clamp(body * (0.8 + 0.3 * swirl), 0.0, 1.0) * tornado);
			// duvar bulutu: tepede alçalan, dönen koyu kütle
			float wc = smoothstep(0.12, 0.0, length(vec2((uv.x - tx) * aspect * 0.35, (uv.y - top + 0.01) * 2.5)) - 0.05);
			col = mix(col, cloud_shade * 0.5, wc * 0.85 * tornado);
			// tabanda toz bulutu ve savrulan parçalar
			vec2 dp = vec2((uv.x - cx) * aspect, (uv.y - bottom) * 2.2);
			float dust = smoothstep(0.1, 0.0, length(dp) - 0.02 * fbm(dp * 30.0 + t, 3)) * fbm(vec2(atan(dp.y, dp.x) * 3.0 + t * 3.0, length(dp) * 40.0), 3);
			col = mix(col, mix(ground, haze, 0.4) * 0.9, clamp(dust * 1.6, 0.0, 1.0) * tornado);
			for (int k = 0; k < 10; k++) {
				float fk = float(k);
				float ph = t * (1.5 + h12(vec2(fk, 2.0)) * 1.5) + fk * 2.4;
				float rr = 0.02 + 0.05 * h12(vec2(fk, 5.0));
				float hy = bottom - 0.01 - fract(ph * 0.1 + h12(vec2(fk, 9.0))) * 0.25;
				vec2 dpos = vec2(cx + cos(ph) * rr / aspect, hy);
				float dd = length((uv - dpos) * vec2(aspect, 1.0));
				col = mix(col, vec3(0.2, 0.18, 0.16), smoothstep(2.4 / px, 0.0, dd) * tornado * step(0.0, sin(ph)));
			}
		}
	}

	// ---------- yağmur: üç derinlik katmanı, rüzgârla eğik çizgiler ----------
	if (rain > 0.0) {
		col = mix(col, mix(haze, cloud_shade, 0.4), rain * 0.18);      // yağmur perdesi
		for (int k = 0; k < 3; k++) {
			if (float(k) > quality + 0.5) break;
			float fk = float(k);
			float sc = 1.0 + fk * 0.9;
			vec2 rp = vec2(uv.x * aspect * 60.0 / sc, uv.y * 3.0 / sc);
			rp.x += rp.y * wind * 20.0;
			rp.y -= t * (2.6 + fk * 0.5) / sc * 2.0;
			vec2 id = floor(rp);
			vec2 f = fract(rp);
			float r = h12(id + fk * 17.0);
			float xo = 0.2 + 0.6 * h12(id + 5.0);
			float drop = step(1.0 - rain * (0.35 + fk * 0.1), r);
			float dx = abs(f.x - xo);
			float len = smoothstep(0.0, 0.25, f.y) * smoothstep(1.0, 0.55, f.y);
			float line = smoothstep(0.12 / sc, 0.0, dx) * len * drop;
			col = mix(col, vec3(0.82, 0.86, 0.92) + flash * 0.3, line * (0.22 + 0.1 * (2.0 - fk)));
		}
	}
	// ---------- kar: yalpalayan yumuşak taneler ----------
	if (snow > 0.0) {
		for (int k = 0; k < 4; k++) {
			if (float(k) > quality + 1.5) break;
			float fk = float(k);
			float sc = 6.0 + fk * 5.0;
			vec2 q = vec2(uv.x * aspect, uv.y) * sc;
			q.y -= t * (0.35 + fk * 0.08) * sc * 0.18;
			q.x += sin(q.y * 0.7 + t * 0.6 + fk) * 0.35 + t * wind * sc * 0.2;
			vec2 id = floor(q);
			vec2 f = fract(q) - 0.5;
			vec2 o = (h22(id + fk * 11.0) - 0.5) * 0.6;
			float on = step(1.0 - snow * 0.75, h12(id + 3.0 + fk));
			float rad = 0.07 + 0.08 * h12(id + 9.0);
			float dd = length(f - o);
			float flake = smoothstep(rad, rad * 0.35, dd) * on;
			col = mix(col, vec3(0.97, 0.98, 1.0), flake * (0.45 + 0.15 * (3.0 - fk)));
		}
	}
	// ---------- şimşek: tüm göğü bir an aydınlatır ----------
	col += vec3(0.75, 0.8, 0.95) * flash * 0.12;
	// hafif film greni (bantlaşmayı kırar)
	col += (h12(uv * px + fract(t) * 91.0) - 0.5) / 255.0 * 1.5;
	COLOR = vec4(col, 1.0);
}
