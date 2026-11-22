// Harici (.glb) modellerin üstüne eklenen enerji parlaması katmanı: örnek başına "glow" ile toplanır (glow = 0 → görünmez).
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back;

instance uniform float glow = 0.0;
uniform vec3 energy : source_color = vec3(1.0, 0.62, 0.22);

void fragment() {
	float rim = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	ALBEDO = energy * glow * (0.35 + rim * 0.9);
}
