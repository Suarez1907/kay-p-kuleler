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

const GLB_NAMES := ["smd_transistor", "diode", "capacitor", "resistor", "relay"]

## Hücre düğümü için bileşen: Node3D (ızgara hücresinin merkezinde), meta "body" = parlayan MeshInstance3D,
## röle için meta "led" = durum ışığı malzemesi, "contact" = hareketli kontak çubuğu.
## res://assets/models/components/<ad>.glb varsa o yüklenir (1×1 hücreye sığdırılır, tabanı hücre tabanına
## oturur); res://assets/textures/pbr/<ad>/ doku seti varsa prosedürel modele PBR malzeme bağlanır.
## Harici modeller kullanılsın mı (Grafik: Düşük'te prosedürel modeller daha hafiftir)
static var use_models := true
const BAND_COLORS := {1: ["#6b3a1e", "#151515", "#c0392b", "#d4af37"], 2: ["#c0392b", "#c0392b", "#ff8a1f", "#d4af37"]}

static func build(type: int, dir := 0, delay := 1) -> Node3D:
	var n := Node3D.new()
	n.set_meta("type", type)
	var glb: Node3D = AssetLoader.component_model(GLB_NAMES[type]) if use_models else null
	if glb != null:
		glb.position.y -= 0.5
		if type == ComponentType.DIODE:
			# model akım yönü -Z; oyunda yön 0 = +X
			glb.rotation.y = [0.0, -PI / 2, PI, PI / 2][dir % 4] - PI / 2
		n.add_child(glb)
		_decorate_glb(n, glb, type, delay)
		return n
	return _procedural(n, type, dir, delay)

## Fırınlama sahnesi için yalnızca model (süsleme yok): generator kaydeder, oyun adopt() ile süsler
static func bare(type: int, dir := 0) -> Node3D:
	var n := Node3D.new()
	var glb: Node3D = AssetLoader.component_model(GLB_NAMES[type])
	if glb == null:
		return null
	glb.name = "model"
	glb.position.y -= 0.5
	if type == ComponentType.DIODE:
		glb.rotation.y = [0.0, -PI / 2, PI, PI / 2][dir % 4] - PI / 2
	n.add_child(glb)
	return n

## Fırınlanmış seviye sahnesindeki hazır hücreyi sahiplenir: modelin kendisi sahnede kalır (ışık haritası
## düğüm yoluna bağlıdır), üstüne parlayan pin malzemeleri, direnç bantları ve röle LED'i eklenir.
static func adopt(n: Node3D, type: int, delay := 1) -> void:
	n.set_meta("type", type)
	if n.get_child_count() == 0:
		return
	var glb: Node3D = n.get_child(0)
	AssetLoader.enhance_materials(glb)
	_decorate_glb(n, glb, type, delay)

static func _decorate_glb(n: Node3D, glb: Node3D, type: int, delay: int) -> void:
	if true:
		var ms := PartBuilder._meshes_in(glb)
		n.set_meta("body", ms[0] if not ms.is_empty() else MeshInstance3D.new())
		# bastıkça parlayan bacaklar ve kondansatör şarj halkası: örneğe özel malzeme kopyaları
		var pins := AssetLoader.unique_surfaces(glb, "Pins")
		for m in pins:
			if m is StandardMaterial3D:
				(m as StandardMaterial3D).emission_enabled = true
				(m as StandardMaterial3D).emission = Color(1.0, 0.62, 0.22)
				(m as StandardMaterial3D).emission_energy_multiplier = 0.0
		n.set_meta("glow_mats", pins)
		n.set_meta("charge_mats", AssetLoader.unique_surfaces(glb, "ChargeRing"))
		if type == ComponentType.RESISTOR:
			var cols: Array = BAND_COLORS[clampi(delay, 1, 2)]
			for k in 4:
				for m in AssetLoader.unique_surfaces(glb, "Band%d" % (k + 1)):
					if m is StandardMaterial3D:
						(m as StandardMaterial3D).albedo_color = Color(cols[k])
		if type == ComponentType.RELAY:
			_relay_extras(n, false)   # modelin kendi pirinç kontak kolu var; yalnızca durum LED'i

static func _procedural(n: Node3D, type: int, dir: int, delay: int) -> Node3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh_for(type, clampi(delay, 1, 2))
	var pbr := AssetLoader.pbr_material(GLB_NAMES[type])
	mi.material_override = pbr if pbr != null else material()
	n.add_child(mi)
	n.set_meta("body", mi)
	if type == ComponentType.DIODE:
		mi.rotation.y = [0.0, -PI / 2, PI, PI / 2][dir % 4]
	if type == ComponentType.RELAY:
		var cv := MeshInstance3D.new()
		cv.mesh = _cover()
		cv.material_override = _cover_material()
		cv.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		n.add_child(cv)
		_relay_extras(n)
	return n

## Röle durum LED'i ve hareketli kontak çubuğu (prosedürel ve harici modelde ortak)
static func _relay_extras(n: Node3D, contact := true) -> void:
	if true:
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
		if not contact:
			return
		# hareketli kontak çubuğu: röle basılınca bobine doğru çekilir
		var ck := MeshKit.new()
		ck.box(Vector3(0.17, 0, 0), Vector3(0.34, 0.035, 0.1), MeshKit.col(PIN, MeshKit.METAL))
		ck.box(Vector3(0.33, -0.05, 0), Vector3(0.04, 0.1, 0.1), MeshKit.col("#e8b949", MeshKit.METAL))
		var cm := MeshInstance3D.new()
		cm.mesh = ck.commit()
		cm.material_override = material()
		cm.position = Vector3(0.0, 0.2, 0)
		n.add_child(cm)
		n.set_meta("contact", cm)

## Röle kontak çubuğu: basılıyken bobine çekilir (aşağı eğilir)
static func set_contact(n: Node3D, pressed: bool) -> void:
	if n != null and n.has_meta("contact"):
		(n.get_meta("contact") as Node3D).rotation.z = -0.32 if pressed else 0.0

static func mesh_for(type: int, variant := 1) -> ArrayMesh:
	var key := type * 10 + (variant if type == ComponentType.RESISTOR else 0)
	if _meshes.has(key):
		return _meshes[key]
	var k := MeshKit.new()
	var D := MeshKit.DIELECTRIC
	var M := MeshKit.METAL
	var G := MeshKit.GLOW
	var C := MeshKit.COPPER
	# ortak: altta bakır pedli yeşil PCB dilimi
	k.box(Vector3(0, -0.46, 0), Vector3(1.0, 0.08, 1.0), MeshKit.col(PCB, D))
	match type:
		ComponentType.SMD_TRANSISTOR:
			# SOT-23 tipi BJT/MOSFET: mat siyah epoksi gövde, PCB'ye inen 3 parlak bacak (bir yanda 2, öbür yanda 1)
			k.box(Vector3(0, 0.04, 0), Vector3(0.8, 0.92, 0.8), MeshKit.col(EPOXY, D))
			var legs := [[-1.0, -0.22], [-1.0, 0.22], [1.0, 0.0]]
			for lg in legs:
				var sx: float = lg[0]
				var zz: float = lg[1]
				k.box(Vector3(sx * 0.44, -0.12, zz), Vector3(0.09, 0.06, 0.14), MeshKit.col(PIN, M))
				k.box(Vector3(sx * 0.48, -0.28, zz), Vector3(0.05, 0.3, 0.14), MeshKit.col(PIN, M))
				k.box(Vector3(sx * 0.48, -0.415, zz), Vector3(0.12, 0.012, 0.2), MeshKit.col(COPPER, C))
			# üst yüz: silik seri kodu, ince çerçeve, pin-1 noktası
			k.cyl(Vector3(-0.26, 0.503, -0.26), 0.05, 0.008, MeshKit.col("#9a9aa2", D), 14)
			k.box(Vector3(0.04, 0.503, 0.06), Vector3(0.42, 0.006, 0.05), MeshKit.col("#5a5a63", D))
			k.box(Vector3(-0.02, 0.503, 0.18), Vector3(0.3, 0.006, 0.04), MeshKit.col("#5a5a63", D))
			for e in 4:
				var eb := Basis(Vector3.UP, e * PI / 2)
				k.box(eb * Vector3(0, 0.503, 0.34), Vector3(0.68, 0.005, 0.02), MeshKit.col("#3a3a42", D), eb)
			k.box(Vector3(0.0, 0.504, -0.06), Vector3(0.56, 0.005, 0.025), MeshKit.col("#7a4a12", G))
		ComponentType.DIODE:
			# yatay silindirik gövde (cam/epoksi), +x ucunda gümüş katot bandı, eksenel bacaklar, üstte parlayan ok
			var ax := Basis(Vector3.FORWARD, PI / 2)
			k.box(Vector3(0, -0.3, 0), Vector3(0.86, 0.24, 0.86), MeshKit.col("#1b1d24", D))
			k.cyl(Vector3(0, 0.07, 0), 0.43, 0.8, MeshKit.col("#2a1a12", D), 24, ax)
			k.cyl(Vector3(0.29, 0.07, 0), 0.445, 0.14, MeshKit.col("#dfe3ea", M), 24, ax)
			for sx in [-1.0, 1.0]:
				k.cyl(Vector3(sx * 0.46, 0.07, 0), 0.05, 0.1, MeshKit.col(PIN, M), 10, ax)
			k.box(Vector3(0, 0.5, 0), Vector3(0.9, 0.012, 0.36), MeshKit.col("#2a1a12", D))
			k.box(Vector3(-0.12, 0.508, 0), Vector3(0.42, 0.01, 0.09), MeshKit.col("#ff8a1f", G))
			k.box(Vector3(0.06, 0.508, -0.075), Vector3(0.26, 0.01, 0.08), MeshKit.col("#ff8a1f", G), Basis(Vector3.UP, -0.75))
			k.box(Vector3(0.06, 0.508, 0.075), Vector3(0.26, 0.01, 0.08), MeshKit.col("#ff8a1f", G), Basis(Vector3.UP, 0.75))
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
			# bantlar gecikmeye göre: 1 tur = kahverengi-siyah-kırmızı-altın, 2 tur = kırmızı-kırmızı-turuncu-altın
			var bands := [["#6b3a1e", -0.3, D], ["#151515", -0.13, D], ["#c0392b", 0.04, D], ["#d4af37", 0.3, M]]
			if variant >= 2:
				bands = [["#c0392b", -0.3, D], ["#c0392b", -0.13, D], ["#ff8a1f", 0.04, D], ["#d4af37", 0.3, M]]
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
	_meshes[key] = m
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

## Röle durum ışığı (aç/kapa röleleri)
static func set_relay(n: Node3D, on: bool) -> void:
	if n != null and n.has_meta("led"):
		(n.get_meta("led") as StandardMaterial3D).albedo_color = Color("#3cf08a") if on else Color("#ff4d5e")

## AND/OR/XOR girişi: devre kapalıyken basılı giriş amber, boş giriş sönük, devre yeşil.
static func set_relay_state(n: Node3D, circuit_on: bool, input_on: bool) -> void:
	if n == null or not n.has_meta("led"):
		return
	var led := n.get_meta("led") as StandardMaterial3D
	if circuit_on:
		led.albedo_color = Color("#3cf08a")
	elif input_on:
		led.albedo_color = Color("#ffd36e")
	else:
		led.albedo_color = Color("#5c3038")
