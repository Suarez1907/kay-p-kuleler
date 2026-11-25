## Stüdyo aydınlatması: 2K HDRI gökyüzü (yalnızca ortam ışığı + yansıma kaynağı; görünen arka plan oyunun
## kendi gradyanı/rengi kalır), AgX ton eşleme, yalnızca gerçek LED/kıvılcımlarda parlama ve LightmapGI ayarları.
## Metaller (altın pin, bakır bobin, alüminyum kapasitör) HDRI'daki softbox'ları yansıtır.
class_name StudioLighting
extends RefCounted

const STUDIO := "res://assets/hdri/studio_softbox_2k.exr"
const WORKSHOP := "res://assets/hdri/workshop_warm_2k.exr"

## AgX koyu orta tonları doğrusal eşlemeden ~%20 daha karanlık gösterir; sahne bunu pozlamayla dengeler
const AGX_EXPOSURE := 1.0

static var _skies := {}

## HDRI'dan Sky (radyans haritası mobil için 256 px; panorama dokusu 2K)
static func sky(path: String, energy := 1.0) -> Sky:
	var key := "%s@%.2f" % [path, energy]
	if _skies.has(key):
		return _skies[key]
	if not ResourceLoader.exists(path):
		return null
	var pm := PanoramaSkyMaterial.new()
	pm.panorama = load(path)
	pm.energy_multiplier = energy
	pm.filter = true
	var s := Sky.new()
	s.sky_material = pm
	s.radiance_size = Sky.RADIANCE_SIZE_256
	s.process_mode = Sky.PROCESS_MODE_QUALITY
	_skies[key] = s
	return s

## Ortama HDRI ortam/yansıma ışığı, AgX ve parlama uygular. sky_mix: ortam ışığında HDRI payı
## (geri kalanı ortamın kendi ambient_light_color'ı: tema ve hava durumu renkleri korunur).
static func apply(env: Environment, path := STUDIO, energy := 1.0, sky_mix := 0.65, exposure := 1.0) -> void:
	if env == null:
		return
	var s := sky(path, energy)
	if s != null:
		env.sky = s
		env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
		env.ambient_light_sky_contribution = sky_mix
		env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = exposure
	env.tonemap_agx_contrast = 1.18
	env.glow_enabled = true
	env.glow_hdr_threshold = 1.55
	# ince temas gölgesi (SSAO yalnızca Forward+ renderer'da çalışır; Mobile renderer'da yok sayılır)
	env.ssao_enabled = true
	env.ssao_intensity = 0.8
	env.ssao_radius = 0.45

## Fırınlama ayarları ADIM 7 tablosundaki değerlerle
static func configure_lightmap(lm: LightmapGI, high := true, path := STUDIO) -> void:
	lm.directional = true
	lm.bounces = 3
	lm.bounce_indirect_energy = 1.15
	lm.use_denoiser = true
	lm.generate_probes_subdiv = LightmapGI.GENERATE_PROBES_SUBDIV_8
	lm.max_texture_size = 2048
	lm.texel_scale = 1.0
	lm.quality = LightmapGI.BAKE_QUALITY_HIGH if high else LightmapGI.BAKE_QUALITY_MEDIUM
	var s := sky(path, 1.0)
	if s != null:
		lm.environment_mode = LightmapGI.ENVIRONMENT_MODE_CUSTOM_SKY
		lm.environment_custom_sky = s
		lm.environment_custom_energy = 2.0   # fırınlanmış ortam ışığı gerçek zamanlıdaki kadar aydınlık kalsın
