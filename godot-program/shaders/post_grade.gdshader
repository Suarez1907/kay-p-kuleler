// Ekran-uzayı son işlem (Mobile renderer uyumlu, tek tam ekran geçiş):
// renk derecelendirme (lift / gamma / gain + doygunluk + kontrast + sıcaklık), kenara doğru artan hafif kromatik
// sapma, sinematik vinyet ve hareketli ince film greni. Arayüz bu katmanın üstünde çizildiği için etkilenmez.
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
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
	// vinyet
	c *= 1.0 - vignette * smoothstep(0.12, 0.55, r2);
	// film greni (zamanla değişen)
	float g = hash(uv * vec2(1920.0, 1080.0) + fract(TIME * 7.13) * 91.7) - 0.5;
	c += g * grain * (1.0 - l * 0.6);
	COLOR = vec4(mix(src, clamp(c, 0.0, 1.0), strength), 1.0);
}
