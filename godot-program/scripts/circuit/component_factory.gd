## Zemin blokları elektronik devre elemanlarıdır. Her tür için bir kez prosedürel mesh kurulur ve önbelleğe
## alınır; hepsi tek bir malzemeyi (shaders/component.gdshader) paylaşır. Robo bastığında örnek başına
## "glow" parametresiyle pinlerden enerji geçer. Röle kapağı saydam ayrı bir mesh, durum LED'i ayrı malzemedir.
class_name ComponentFactory
extends RefCounted

enum ComponentType { SMD_TRANSISTOR, DIODE, CAPACITOR, RESISTOR, RELAY }

const TYPE_BY_KEY := {"": ComponentType.SMD_TRANSISTOR, "diode": ComponentType.DIODE, "cap": ComponentType.CAPACITOR,
	"res": ComponentType.RESISTOR, "relay": ComponentType.RELAY}
const NAMES := ["SMD transistör", "Diyot", "Kondansatör", "Direnç", "Röle"]

const EPOXY := "#16161b"
const PCB := "#0b3b2a"
const PIN := "#d2d5dc"
const COPPER := "#c27a3e"

static var _meshes := {}
static var _mat: ShaderMaterial
static var _cover_mesh: ArrayMesh
static var _cover_mat: StandardMaterial3D

static func material() -> ShaderMaterial:
	if _mat == null:
		_mat = ShaderMaterial.new()
		_mat.shader = load("res://shaders/component.gdshader")
	return _mat

static func type_of(key: String) -> int:
	return TYPE_BY_KEY.get(key, ComponentType.SMD_TRANSISTOR)

## Hücre düğümü için bileşen: Node3D (ızgara hücresinin merkezinde), meta "body" = parlayan MeshInstance3D,
## röle için meta "led" = durum ışığı malzemesi.
static func build(type: int, dir := 0) -> Node3D:
	var n := Node3D.new()
	var mi := MeshInstance3D.new()
	mi.mesh = mesh_for(type)
	mi.material_override = material()
	n.add_child(mi)
	n.set_meta("body", mi)
	n.set_meta("type", type)
	if type == ComponentType.DIODE:
		mi.rotation.y = [0.0, -PI / 2, PI, PI / 2][dir % 4]
	if type == ComponentType.RELAY:
		var cv := MeshInstance3D.new()
		cv.mesh = _cover()
		cv.material_override = _cover_material()
		cv.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		n.add_child(cv)
		var led := StandardMaterial3D.new()
		led.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		led.albedo_color = Color("#ff4d5e")
		var lm := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.055
		sm.height = 0.11
		lm.mesh = sm
		lm.material_override = led
		lm.position = Vector3(0.32, 0.52, 0.32)
		n.add_child(lm)
		n.set_meta("led", led)
	return n

static func mesh_for(type: int) -> ArrayMesh:
	if _meshes.has(type):
		return _meshes[type]
	var k := MeshKit.new()
	var D := MeshKit.DIELECTRIC
	var M := MeshKit.METAL
	var G := MeshKit.GLOW
	var C := MeshKit.COPPER
	# ortak: altta bakır pedli yeşil PCB dilimi
	k.box(Vector3(0, -0.46, 0), Vector3(1.0, 0.08, 1.0), MeshKit.col(PCB, D))
	match type:
		ComponentType.SMD_TRANSISTOR:
			k.box(Vector3(0, 0.04, 0), Vector3(0.8, 0.92, 0.8), MeshKit.col(EPOXY, D))
			# dört yanda martı kanadı pinler (QFP kılıf)
			for side in 4:
				var b := Basis(Vector3.UP, side * PI / 2)
				for zz in [-0.24, 0.0, 0.24]:
					k.box(b * Vector3(0.44, -0.16, zz), Vector3(0.09, 0.05, 0.1), MeshKit.col(PIN, M), b)
					k.box(b * Vector3(0.48, -0.3, zz), Vector3(0.04, 0.24, 0.1), MeshKit.col(PIN, M), b)
					k.box(b * Vector3(0.48, -0.415, zz), Vector3(0.1, 0.01, 0.14), MeshKit.col(COPPER, C), b)
			# üst yüz: pin-1 noktası, baskı yazısı ve ince devre işareti
			k.cyl(Vector3(-0.26, 0.503, -0.26), 0.05, 0.008, MeshKit.col("#9a9aa2", D), 14)
			k.box(Vector3(0.04, 0.503, 0.06), Vector3(0.42, 0.006, 0.05), MeshKit.col("#6e6e78", D))
			k.box(Vector3(-0.02, 0.503, 0.18), Vector3(0.3, 0.006, 0.04), MeshKit.col("#6e6e78", D))
			k.box(Vector3(0.0, 0.503, -0.06), Vector3(0.56, 0.005, 0.025), MeshKit.col("#7a4a12", G))
			k.box(Vector3(0.27, 0.503, -0.18), Vector3(0.025, 0.005, 0.25), MeshKit.col("#7a4a12", G))
		ComponentType.DIODE:
			k.box(Vector3(0, 0.04, 0), Vector3(0.84, 0.92, 0.82), MeshKit.col("#1b1310", D))
			# katot şeridi (+x ucunda) ve eksenel bacaklar
			k.box(Vector3(0.3, 0.045, 0), Vector3(0.12, 0.93, 0.84), MeshKit.col("#dfe3ea", M))
			for sx in [-1.0, 1.0]:
				k.cyl(Vector3(sx * 0.46, -0.2, 0), 0.04, 0.12, MeshKit.col(PIN, M), 10, Basis(Vector3.FORWARD, PI / 2))
			# akım yönü oku (üstte, +x)
			k.box(Vector3(-0.08, 0.505, 0), Vector3(0.42, 0.01, 0.09), MeshKit.col("#ff8a1f", G))
			k.box(Vector3(0.1, 0.505, -0.075), Vector3(0.26, 0.01, 0.08), MeshKit.col("#ff8a1f", G), Basis(Vector3.UP, -0.75))
			k.box(Vector3(0.1, 0.505, 0.075), Vector3(0.26, 0.01, 0.08), MeshKit.col("#ff8a1f", G), Basis(Vector3.UP, 0.75))
		ComponentType.CAPACITOR:
			k.box(Vector3(0, -0.4, 0), Vector3(0.9, 0.06, 0.9), MeshKit.col("#20242c", D))
			k.cyl(Vector3(0, 0.03, 0), 0.42, 0.86, MeshKit.col("#274b98", D), 28)
			# eksi şeridi
			k.box(Vector3(0.405, 0.03, 0), Vector3(0.04, 0.84, 0.26), MeshKit.col("#c8d0dc", D))
			# alüminyum kapak, artı işareti ve şarj halkası
			k.cyl(Vector3(0, 0.48, 0), 0.4, 0.04, MeshKit.col("#c6cbd3", M), 28)
			k.box(Vector3(0, 0.505, 0), Vector3(0.28, 0.012, 0.07), MeshKit.col("#ffd36e", G))
			k.box(Vector3(0, 0.505, 0), Vector3(0.07, 0.012, 0.28), MeshKit.col("#ffd36e", G))
			k.ring(Vector3(0, 0.503, 0), 0.33, 0.035, 0.012, MeshKit.col("#59e1ff", G), 28)
		ComponentType.RESISTOR:
			k.box(Vector3(0, 0.04, 0), Vector3(0.88, 0.92, 0.84), MeshKit.col("#d9c49c", D))
			var bands := [["#6b3a1e", -0.3, D], ["#151515", -0.13, D], ["#c0392b", 0.04, D], ["#d4af37", 0.3, M]]
			for bd in bands:
				k.box(Vector3(bd[1], 0.045, 0), Vector3(0.08, 0.93, 0.86), MeshKit.col(bd[0], bd[2]))
			for sx in [-1.0, 1.0]:
				k.cyl(Vector3(sx * 0.47, -0.2, 0), 0.04, 0.1, MeshKit.col(PIN, M), 10, Basis(Vector3.FORWARD, PI / 2))
		ComponentType.RELAY:
			k.box(Vector3(0, -0.3, 0), Vector3(0.9, 0.24, 0.9), MeshKit.col("#1d1f26", D))
			k.cyl(Vector3(-0.16, 0.0, 0), 0.19, 0.4, MeshKit.col(COPPER, C), 22)
			k.cyl(Vector3(-0.16, 0.22, 0), 0.08, 0.06, MeshKit.col(PIN, M), 12)
			k.box(Vector3(0.18, 0.2, 0), Vector3(0.36, 0.04, 0.12), MeshKit.col(PIN, M))
			k.box(Vector3(0.3, -0.02, 0), Vector3(0.05, 0.4, 0.1), MeshKit.col(PIN, M))
			k.box(Vector3(0.22, -0.1, 0.22), Vector3(0.12, 0.1, 0.08), MeshKit.col("#e8b949", M))
	var m := k.commit()
	_meshes[type] = m
	return m

static func _cover() -> ArrayMesh:
	if _cover_mesh == null:
		var k := MeshKit.new()
		k.box(Vector3(0, 0.12, 0), Vector3(0.92, 0.76, 0.92), MeshKit.col("#bfe4ff", MeshKit.DIELECTRIC))
		_cover_mesh = k.commit()
	return _cover_mesh

static func _cover_material() -> StandardMaterial3D:
	if _cover_mat == null:
		_cover_mat = StandardMaterial3D.new()
		_cover_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_cover_mat.albedo_color = Color(0.72, 0.86, 1.0, 0.3)
		_cover_mat.roughness = 0.08
		_cover_mat.metallic_specular = 0.9
		_cover_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return _cover_mat

## Röle durum ışığı
static func set_relay(n: Node3D, on: bool) -> void:
	if n != null and n.has_meta("led"):
		(n.get_meta("led") as StandardMaterial3D).albedo_color = Color("#3cf08a") if on else Color("#ff4d5e")
