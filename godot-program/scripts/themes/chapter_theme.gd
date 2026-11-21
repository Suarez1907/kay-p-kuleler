## Bir bölümün sanat yönelimi. Renkler ve materyal değerleri ThemeLibrary'de doldurulur.
class_name ChapterTheme
extends Resource

enum VisualStyle {
	KINTSUGI,
	CLOCKWORK,
	RETRO_SYNTH,
	PRISM_GLASS,
	ORIGAMI,
	TYPOGRAPHY,
	BRUTALIST_MIRROR,
	TERRARIUM,
	CYBER_LOOM,
	SUNDIAL,
	OBSERVATORY,
	KINETIC_SCULPTURE,
	BLUEPRINT,
	ZEN_GARDEN,
	COSMIC_PORCELAIN,
}

@export var chapter_id: int
@export var theme_name: String
@export var concept_name: String
@export var visual_style: VisualStyle
@export var bg_top_color: Color
@export var bg_bottom_color: Color
@export var light_color: Color
@export var light_energy: float
@export var light_rotation_deg: Vector3
@export var ambient_color: Color
@export var ambient_energy: float
@export var block_base_color: Color
@export var block_top_color: Color
@export var stair_color: Color
@export var accent_color: Color
@export var roughness: float
@export var metallic: float
@export var emission_strength: float
@export var robot_led_color: Color
@export var ui_panel_bg: Color
@export var ui_accent_color: Color
@export var ui_border_color: Color
