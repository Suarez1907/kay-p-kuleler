## Bölüm dekoru: kulenin altında ya da dışında tek bir hafif prosedürel grup.
## Oynanış hücrelerinin üstüne çıkmaz, çarpışması yoktur, gölge düşürmez.
class_name ThemePropGenerator
extends RefCounted


static func spawn(parent: Node3D, theme: ChapterTheme, aabb: AABB) -> Node3D:
	var root := Node3D.new()
	root.name = "ThemeDecor"
	parent.add_child(root)
	var floor_y := aabb.position.y - 1.2
	var center := Vector3(aabb.get_center().x, floor_y, aabb.get_center().z)
	var reach := maxf(aabb.size.x, aabb.size.z) * 0.5
	# Blender dekor seti (assets/models/themes/theme_XX.glb): kulenin iki yanına birer küme; yoksa prosedürel
	if ComponentFactory.use_models and _glb_sets(root, theme, aabb):
		return root
	var S := ChapterTheme.VisualStyle
	match theme.visual_style:
		S.KINTSUGI:
			_bowl(root, center, theme.block_top_color, theme.accent_color)
		S.CLOCKWORK:
			_gears(root, center, reach, theme.accent_color)
		S.RETRO_SYNTH:
			_circuits(root, center, reach, theme.accent_color)
		S.PRISM_GLASS:
			_crystals(root, aabb, theme.accent_color, theme.robot_led_color)
		S.ORIGAMI:
			_paper(root, center, theme.block_top_color, theme.stair_color)
		S.TYPOGRAPHY:
			_typeblock(root, _beside(aabb), theme.block_base_color, theme.accent_color)
		S.BRUTALIST_MIRROR:
			_plinth(root, center, reach, theme.block_top_color, 0.55)
		S.TERRARIUM:
			_jar(root, _beside(aabb), theme.block_base_color, theme.block_top_color, theme.accent_color)
		S.CYBER_LOOM:
			_fibers(root, center, reach, theme.accent_color)
		S.SUNDIAL:
			_sundial(root, _beside(aabb), theme.block_top_color, theme.block_base_color)
		S.OBSERVATORY:
			_orbits(root, aabb, theme.accent_color, 2)
		S.KINETIC_SCULPTURE:
			_rotor(root, center, theme.block_base_color, theme.accent_color)
		S.BLUEPRINT:
			_grid(root, center, reach, theme.block_top_color)
		S.ZEN_GARDEN:
			_garden(root, center, reach, _beside(aabb), theme.block_top_color, theme.accent_color)
		S.COSMIC_PORCELAIN:
			_orbits(root, aabb, theme.accent_color, 2)
		_:
			_plinth(root, center, reach, theme.accent_color, 0.2)
	return root


static func _glb_sets(root: Node3D, theme: ChapterTheme, aabb: AABB) -> bool:
	var a := AssetLoader.theme_model(theme.chapter_id)
	if a == null:
		return false
	var y := aabb.position.y - 0.55
	a.position = Vector3(aabb.position.x - 1.7, y, aabb.get_center().z)
	root.add_child(a)
	var b := AssetLoader.theme_model(theme.chapter_id, Vector3(1.0, 1.9, 1.7))
	if b != null:
		b.position = Vector3(aabb.end.x + 1.7, y, aabb.position.z + 0.4)
		b.rotation.y = PI
		root.add_child(b)
	for mi in PartBuilder._meshes_in(root):
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return true


## Kulenin yanında, blokların altında kalan bir nokta (yolun ve kameranın dışında).
static func _beside(aabb: AABB) -> Vector3:
	return Vector3(aabb.position.x - 1.7, aabb.position.y - 0.55, aabb.get_center().z)


static func _mi(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


static func _std(color: Color, rough: float, metal: float, emit: float, alpha := 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(color.r, color.g, color.b, alpha)
	m.roughness = rough
	m.metallic = metal
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emit
	if alpha < 0.99:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m


static func _spin(n: Node3D, speed: float) -> void:
	n.set_meta("spin", speed)


static func _bob(n: Node3D, amp: float, phase: float) -> void:
	n.set_meta("bob", amp)
	n.set_meta("base_y", n.position.y)
	n.set_meta("phase", phase)


static func _torus(inner: float, outer: float) -> TorusMesh:
	var t := TorusMesh.new()
	t.inner_radius = inner
	t.outer_radius = outer
	t.rings = 24
	t.ring_segments = 10
	return t


static func _disc(r: float, h: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r
	c.height = h
	c.radial_segments = 24
	return c


static func _bowl(root: Node3D, at: Vector3, clay: Color, gold: Color) -> void:
	_mi(root, _disc(1.15, 0.08), _std(clay, 0.9, 0.0, 0.0), at)
	var ring := _mi(root, _torus(0.95, 1.12), _std(gold, 0.35, 0.7, 0.15), at + Vector3(0, 0.05, 0))
	_spin(ring, 0.15)


static func _gears(root: Node3D, at: Vector3, reach: float, brass: Color) -> void:
	var mat := _std(brass, 0.4, 0.65, 0.05)
	for i in 2:
		var g := Node3D.new()
		g.position = at + Vector3(0.15 * float(i), 0.02 * float(i), 0)
		root.add_child(g)
		# Düz, blok tabanının altında: kulenin çevresinde hale gibi görünür, üst yüzü kapatmaz.
		var rad := maxf(reach, 1.15) * (0.78 + float(i) * 0.22)
		_mi(g, _torus(rad * 0.86, rad), mat, Vector3.ZERO)
		for k in 10:
			var tooth := _mi(g, _box(Vector3(rad * 0.1, 0.04, rad * 0.16)), mat, Vector3(cos(k * TAU / 10.0) * rad, 0, sin(k * TAU / 10.0) * rad))
			tooth.rotation.y = -k * TAU / 10.0
		_spin(g, 0.18 if i == 0 else -0.12)


static func _circuits(root: Node3D, at: Vector3, reach: float, led: Color) -> void:
	var mat := _std(led, 0.3, 0.2, 2.2)
	var span := maxf(reach, 1.2)
	_mi(root, _box(Vector3(span * 2.2, 0.015, 0.045)), mat, at)
	_mi(root, _box(Vector3(0.045, 0.015, span * 2.2)), mat, at)
	_mi(root, _box(Vector3(span * 1.4, 0.015, 0.03)), mat, at + Vector3(0, 0.02, span * 0.45))
	for k in 4:
		var node := _mi(root, _sphere(0.07), mat, at + Vector3(cos(k * TAU / 4.0) * span * 0.7, 0.04, sin(k * TAU / 4.0) * span * 0.7))
		_bob(node, 0.03, float(k))


static func _crystals(root: Node3D, aabb: AABB, violet: Color, cyan: Color) -> void:
	var back := Vector3(-0.72, 0.0, -0.7).normalized()
	var cols := [violet, cyan, violet.lerp(cyan, 0.5)]
	for i in 3:
		var p := aabb.get_center() + back * (maxf(aabb.size.x, aabb.size.z) * 0.35 + 1.3 + float(i) * 0.45)
		p.y = aabb.end.y + 1.35 + float(i) * 0.42
		var gem := _mi(root, _octa(), _std(cols[i], 0.12, 0.15, 1.4, 0.62), p)
		gem.scale = Vector3.ONE * (0.28 + float(i) * 0.06)
		_spin(gem, 0.35 + float(i) * 0.1)
		_bob(gem, 0.12, float(i) * 1.4)


static func _paper(root: Node3D, at: Vector3, coral: Color, sage: Color) -> void:
	var a := _mi(root, _box(Vector3(1.1, 0.02, 0.7)), _std(coral, 0.98, 0.0, 0.0), at + Vector3(-0.2, 0.02, 0))
	a.rotation.y = 0.4
	var b := _mi(root, _box(Vector3(0.9, 0.02, 0.55)), _std(sage, 0.98, 0.0, 0.0), at + Vector3(0.35, 0.05, 0.1))
	b.rotation.y = -0.6


static func _typeblock(root: Node3D, at: Vector3, lead: Color, red: Color) -> void:
	_mi(root, _box(Vector3(0.9, 0.28, 0.7)), _std(lead, 0.8, 0.1, 0.0), at)
	_mi(root, _box(Vector3(0.7, 0.04, 0.08)), _std(red, 0.5, 0.0, 0.3), at + Vector3(0, 0.16, 0))


static func _plinth(root: Node3D, at: Vector3, reach: float, color: Color, metal: float) -> void:
	var slab := _mi(root, _box(Vector3(maxf(reach, 1.0) * 2.2, 0.08, maxf(reach, 1.0) * 2.2)), _std(color, 0.35, metal, 0.0), at)
	slab.rotation.y = 0.2


static func _jar(root: Node3D, at: Vector3, copper: Color, glass: Color, liquid: Color) -> void:
	_mi(root, _disc(0.28, 0.06), _std(copper, 0.4, 0.6, 0.0), at)
	_mi(root, _cyl(0.22, 0.26, 0.55), _std(glass, 0.15, 0.05, 0.15, 0.4), at + Vector3(0, 0.32, 0))
	_mi(root, _torus(0.24, 0.3), _std(copper, 0.4, 0.65, 0.1), at + Vector3(0, 0.58, 0))
	var drop := _mi(root, _sphere(0.08), _std(liquid, 0.2, 0.3, 0.6), at + Vector3(0.45, 0.2, 0.1))
	_bob(drop, 0.06, 0.5)


static func _fibers(root: Node3D, at: Vector3, reach: float, cyan: Color) -> void:
	var mat := _std(cyan, 0.2, 0.3, 1.6)
	var span := maxf(reach, 1.1)
	for i in 3:
		var arc := _mi(root, _cyl(0.02, 0.02, span * 1.6), mat, at + Vector3(0, 0.04, (float(i) - 1.0) * 0.35))
		arc.rotation.z = PI / 2.0
		arc.rotation.y = float(i) * 0.35


static func _sundial(root: Node3D, at: Vector3, sand: Color, bronze: Color) -> void:
	_mi(root, _disc(0.55, 0.05), _std(sand, 0.9, 0.05, 0.0), at)
	var gnomon := _mi(root, _cyl(0.0, 0.06, 0.7), _std(bronze, 0.55, 0.4, 0.0), at + Vector3(0, 0.38, 0))
	gnomon.rotation.z = 0.35


static func _orbits(root: Node3D, aabb: AABB, metal_col: Color, count: int) -> void:
	# İnce halkalar kulenin arkasında, gökte: oynanış yüzeyinin ve kameranın önünden geçmez.
	var mat := _std(metal_col, 0.25, 0.8, 0.35)
	var back := Vector3(-0.62, 0.0, -0.78).normalized()
	for i in count:
		var rad := 0.7 + float(i) * 0.32
		var pivot := Node3D.new()
		pivot.position = aabb.get_center() + back * (maxf(aabb.size.x, aabb.size.z) * 0.42 + 1.6)
		pivot.position.y = aabb.end.y + 1.7 + float(i) * 0.5
		root.add_child(pivot)
		var ring := _mi(pivot, _torus(rad * 0.88, rad), mat, Vector3.ZERO)
		ring.rotation.x = deg_to_rad(64.0 + float(i) * 16.0)
		_spin(pivot, 0.16 + float(i) * 0.06)


static func _rotor(root: Node3D, at: Vector3, alum: Color, yellow: Color) -> void:
	var hub := Node3D.new()
	hub.position = at + Vector3(0, 0.06, 0)
	root.add_child(hub)
	_mi(hub, _box(Vector3(1.6, 0.05, 0.12)), _std(alum, 0.35, 0.7, 0.0), Vector3.ZERO)
	_mi(hub, _box(Vector3(0.12, 0.05, 1.6)), _std(alum, 0.35, 0.7, 0.0), Vector3.ZERO)
	_mi(hub, _sphere(0.1), _std(yellow, 0.4, 0.3, 0.8), Vector3.ZERO)
	_spin(hub, 0.4)


static func _grid(root: Node3D, at: Vector3, reach: float, ink: Color) -> void:
	var span := maxf(reach, 1.2) * 2.4
	var plane := _mi(root, _box(Vector3(span, 0.02, span)), _std(ink, 0.4, 0.0, 0.15, 0.22), at)
	plane.rotation.y = 0.0
	var line := _std(ink, 0.3, 0.0, 0.4, 0.55)
	for i in 5:
		var o := (float(i) - 2.0) * span / 5.0
		_mi(root, _box(Vector3(span, 0.012, 0.02)), line, at + Vector3(0, 0.02, o))
		_mi(root, _box(Vector3(0.02, 0.012, span)), line, at + Vector3(o, 0.02, 0))


static func _garden(root: Node3D, at: Vector3, reach: float, _side: Vector3, gravel: Color, maple: Color) -> void:
	var rad := maxf(reach, 1.0) + 0.35
	_mi(root, _disc(rad, 0.05), _std(gravel, 0.95, 0.0, 0.0), at)
	# Akçaağaç çakıl halesinin kenarında, blokların altında: robotun üstüne binmez.
	var tree := Node3D.new()
	tree.position = at + Vector3(rad * 0.82, 0.0, -rad * 0.35)
	root.add_child(tree)
	_mi(tree, _cyl(0.025, 0.035, 0.22), _std(Color("#2F3133"), 0.8, 0.0, 0.0), Vector3(0, 0.12, 0))
	_mi(tree, _sphere(0.1), _std(maple, 0.7, 0.0, 0.2), Vector3(0, 0.28, 0))


static func _octa() -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = 0.45
	s.height = 0.9
	s.radial_segments = 4
	s.rings = 1
	return s


static func _box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b


static func _cyl(top: float, bottom: float, h: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = h
	return c


static func _sphere(r: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	return s
