// Yürünebilir blok üst yüzü: yüksekliğe göre açık tonlu kapak + parlak kenar çerçevesi.
// Siyah epoksi bloklarda üst yüz yanlardan ayrışsın, katlar bir bakışta okunsun diye.
// Renk MultiMesh özel verisinden (INSTANCE_CUSTOM.rgb) gelir.
shader_type spatial;
render_mode cull_back;

uniform float edge = 0.07;
uniform float rim_boost = 0.45;
varying vec3 v_col;

void vertex() {
	v_col = INSTANCE_CUSTOM.rgb;
}

void fragment() {
	vec2 uv = UV;
	float d = min(min(uv.x, 1.0 - uv.x), min(uv.y, 1.0 - uv.y));
	float rim = 1.0 - smoothstep(edge * 0.55, edge, d);
	// ince iç çizgi: çip gövdesi hissi (çok hafif)
	float inner = (1.0 - smoothstep(0.0, 0.012, abs(d - 0.2))) * 0.06;
	vec3 c = v_col * (1.0 - inner);
	ALBEDO = mix(c, c + vec3(rim_boost) * (vec3(1.0) - c), rim);
	ROUGHNESS = 0.78;
	SPECULAR = 0.25;
}
