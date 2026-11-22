## Prosedürel mesh kurucu: kutu, silindir, halka parçalarını tek bir ArrayMesh'te birleştirir.
## Köşe rengi = parça rengi (doğrusal uzay), alfa = malzeme türü (bkz. shaders/component.gdshader):
## DIELECTRIC 1.0, METAL 0.66, GLOW 0.33, COPPER 0.0. Devre elemanları ve bilgisayar parçaları bunu kullanır.
class_name MeshKit
extends RefCounted

const DIELECTRIC := 1.0
const METAL := 0.66
const GLOW := 0.33
const COPPER := 0.0

var st := SurfaceTool.new()

func _init() -> void:
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

static func col(hex, id: float) -> Color:
	var c: Color = Color(hex) if hex is String else hex
	c = c.srgb_to_linear()
	c.a = id
	return c

func _quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3, color: Color) -> void:
	st.set_color(color)
	st.set_normal(n)
	for v in [a, b, c, a, c, d]:
		st.add_vertex(v)

## Kutu: merkez, boyut, renk (Color: col() ile), isteğe bağlı dönüş
func box(center: Vector3, size: Vector3, color: Color, basis := Basis()) -> MeshKit:
	var h := size / 2.0
	var P := func(x: float, y: float, z: float) -> Vector3: return center + basis * Vector3(x * h.x, y * h.y, z * h.z)
	var N := func(n: Vector3) -> Vector3: return (basis * n).normalized()
	_quad(P.call(-1, 1, -1), P.call(1, 1, -1), P.call(1, 1, 1), P.call(-1, 1, 1), N.call(Vector3.UP), color)
	_quad(P.call(-1, -1, 1), P.call(1, -1, 1), P.call(1, -1, -1), P.call(-1, -1, -1), N.call(Vector3.DOWN), color)
	_quad(P.call(-1, -1, 1), P.call(-1, 1, 1), P.call(1, 1, 1), P.call(1, -1, 1), N.call(Vector3.BACK), color)
	_quad(P.call(1, -1, -1), P.call(1, 1, -1), P.call(-1, 1, -1), P.call(-1, -1, -1), N.call(Vector3.FORWARD), color)
	_quad(P.call(1, -1, 1), P.call(1, 1, 1), P.call(1, 1, -1), P.call(1, -1, -1), N.call(Vector3.RIGHT), color)
	_quad(P.call(-1, -1, -1), P.call(-1, 1, -1), P.call(-1, 1, 1), P.call(-1, -1, 1), N.call(Vector3.LEFT), color)
	return self

## Silindir: varsayılan ekseni Y; basis ile döndürülür (ör. Basis(Vector3.FORWARD, PI/2) → X ekseni)
func cyl(center: Vector3, r: float, h: float, color: Color, seg := 20, basis := Basis(), caps := true) -> MeshKit:
	var hh := h / 2.0
	for i in seg:
		var a0 := TAU * i / seg
		var a1 := TAU * (i + 1) / seg
		var p0 := Vector3(cos(a0) * r, 0, sin(a0) * r)
		var p1 := Vector3(cos(a1) * r, 0, sin(a1) * r)
		var n := (basis * Vector3(cos((a0 + a1) / 2), 0, sin((a0 + a1) / 2))).normalized()
		_quad(center + basis * (p0 + Vector3(0, -hh, 0)), center + basis * (p0 + Vector3(0, hh, 0)),
			center + basis * (p1 + Vector3(0, hh, 0)), center + basis * (p1 + Vector3(0, -hh, 0)), n, color)
		if caps:
			st.set_color(color)
			st.set_normal((basis * Vector3.UP).normalized())
			for v in [Vector3(0, hh, 0), p1 + Vector3(0, hh, 0), p0 + Vector3(0, hh, 0)]:
				st.add_vertex(center + basis * v)
			st.set_normal((basis * Vector3.DOWN).normalized())
			for v in [Vector3(0, -hh, 0), p0 + Vector3(0, -hh, 0), p1 + Vector3(0, -hh, 0)]:
				st.add_vertex(center + basis * v)
	return self

## Halka: Y eksenli, ince kutu parçalarından
func ring(center: Vector3, r: float, thick: float, h: float, color: Color, seg := 24, basis := Basis()) -> MeshKit:
	for i in seg:
		var a := TAU * (i + 0.5) / seg
		var b := basis * Basis(Vector3.UP, -a)
		box(center + basis * Vector3(cos(a) * r, 0, sin(a) * r), Vector3(thick, h, TAU * r / seg * 1.08), color, b)
	return self

func commit() -> ArrayMesh:
	return st.commit()
