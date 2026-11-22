// Devre elemanları için tek malzeme. Ağ (mesh) köşe renkleri hem rengi hem de malzeme türünü taşır:
// COLOR.a ≈ 1.0 dielektrik (epoksi, seramik, plastik), ≈ 0.66 parlak metal (pinler, bacaklar),
// ≈ 0.33 ışık veren işaret (ok, artı, şarj halkası), ≈ 0.0 bakır.
// Örnek başına "glow" (Robo bastığında pinlerden geçen enerji) ve "charge" (kondansatör boşalması) taşır.
shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_opaque;

instance uniform float glow = 0.0;
instance uniform float charge = 0.0;
uniform vec3 energy : source_color = vec3(1.0, 0.62, 0.22);

void fragment() {
	float id = COLOR.a;
	vec3 c = COLOR.rgb;
	ALBEDO = c;
	if (id > 0.83) {
		ROUGHNESS = 0.58;
		METALLIC = 0.0;
		SPECULAR = 0.45;
		EMISSION = energy * glow * 0.06;
	} else if (id > 0.5) {
		ROUGHNESS = 0.24;
		METALLIC = 0.92;
		EMISSION = energy * glow * 1.4;
	} else if (id > 0.17) {
		ROUGHNESS = 0.35;
		METALLIC = 0.0;
		EMISSION = c * (0.55 + glow * 1.4 + charge * 2.6);
	} else {
		ROUGHNESS = 0.32;
		METALLIC = 0.85;
		EMISSION = energy * glow * 0.9;
	}
}
