## Tek bir bilgisayar parçasının verisi (100 seviyenin her biri bir parça kazandırır).
## assembly_scale: parçanın montajdaki sınır kutusu boyutu (dünya birimi). Prosedürel model bu kutuya
## çizilir; optional_glb_path'te bir .glb varsa o yüklenir ve aynı kutuya sığdırılır.
class_name PCPartData
extends Resource

@export var part_id := 0
@export var part_name := ""
@export var phase_name := ""
@export var phase_index := 0
@export var assembly_position := Vector3.ZERO
@export var assembly_rotation := Vector3.ZERO
@export var assembly_scale := Vector3.ONE
@export var procedural_shape := "box"
@export var color := Color.WHITE
@export var optional_glb_path := ""
