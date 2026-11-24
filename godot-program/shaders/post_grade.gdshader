// Ekran-uzayı son işlem (Mobile renderer uyumlu, tek tam ekran geçiş):
// renk derecelendirme (lift / gamma / gain + doygunluk + kontrast + sıcaklık), kenara doğru artan hafif kromatik
// sapma, sinematik vinyet ve hareketli ince film greni. Arayüz bu katmanın üstünde çizildiği için etkilenmez.
shader_type canvas_item;

// mipmap'siz örnekleme: ekran kopyası tam çözünürlükte okunur; filter_linear_mipmap her karede ekran
// kopyasının mip zincirini ürettiriyordu (mobilde boşa giden bir tam ekran geçişi), görüntü aynı kalır
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform vec3 lift = vec3(0.0);
uniform vec3 gamma = vec3(1.0);
uniform vec3 gain = vec3(1.0);
uniform float saturation = 1.08;
uniform float contrast = 1.06;
uniform float warmth = 0.0;          // -1 soğuk .. 1 sıcak
uniform float chroma = 0.0016;       // kenarda kromatik sapma (uv birimi)
uniform float vignette = 0.32;
uniform float grain = 0.035;
uniform float strength = 1.0;        // 0: kapalı
uniform int filter = 0;              // fotoğraf modu: 0 normal, 1 sepya, 2 noir, 3 neon, 4 blueprint

float hash(vec2 p) {
	p = fract(p * vec2(443.897, 441.423));
	p += dot(p, p.yx + 19.19);
	return fract((p.x + p.y) * p.x);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 d = uv - 0.5;
	float r2 = dot(d, d);
	vec2 off = d * chroma * (0.4 + r2 * 4.0);
	vec3 c;
	c.r = texture(screen_tex, uv + off).r;
	c.g = texture(screen_tex, uv).g;
	c.b = texture(screen_tex, uv - off).b;
	vec3 src = c;
	// lift / gamma / gain
	c = c * gain + lift * (1.0 - c);
	c = pow(max(c, vec3(0.0)), 1.0 / max(gamma, vec3(0.01)));
	// sıcaklık
	c *= vec3(1.0 + warmth * 0.06, 1.0, 1.0 - warmth * 0.06);
	// kontrast + doygunluk
	c = (c - 0.5) * contrast + 0.5;
	float l = dot(c, vec3(0.2126, 0.7152, 0.0722));
	c = mix(vec3(l), c, saturation);
	// fotoğraf modu filtreleri
	if (filter == 1) {
		c = clamp(vec3(dot(c, vec3(0.393, 0.769, 0.189)), dot(c, vec3(0.349, 0.686, 0.168)), dot(c, vec3(0.272, 0.534, 0.131))), 0.0, 1.0);
	} else if (filter == 2) {
		float n = dot(c, vec3(0.3, 0.59, 0.11));
		n = smoothstep(0.08, 0.85, n);
		c = vec3(n * n * (3.0 - 2.0 * n));
	} else if (filter == 3) {
		float n = dot(c, vec3(0.2126, 0.7152, 0.0722));
		vec3 neon = mix(vec3(0.05, 0.0, 0.18), mix(vec3(1.0, 0.15, 0.75), vec3(0.2, 1.0, 1.0), smoothstep(0.45, 0.9, n)), smoothstep(0.05, 0.6, n));
		c = mix(c, neon, 0.7) * 1.15;
	} else if (filter == 4) {
		float n = dot(c, vec3(0.2126, 0.7152, 0.0722));
		c = mix(vec3(0.03, 0.12, 0.3), vec3(0.78, 0.93, 1.0), smoothstep(0.1, 0.9, n));
		vec2 px = FRAGCOORD.xy;
		float gl = max(step(fract(px.x / 32.0), 0.04), step(fract(px.y / 32.0), 0.04));
		float gm = max(step(fract(px.x / 160.0), 0.008), step(fract(px.y / 160.0), 0.008));
		c += vec3(0.25, 0.45, 0.7) * (gl * 0.18 + gm * 0.35);
	}
	// vinyet
	c *= 1.0 - vignette * smoothstep(0.12, 0.55, r2);
	// film greni (zamanla değişen)
	float g = hash(uv * vec2(1920.0, 1080.0) + fract(TIME * 7.13) * 91.7) - 0.5;
	c += g * grain * (1.0 - l * 0.6);
	COLOR = vec4(mix(src, clamp(c, 0.0, 1.0), strength), 1.0);
}
