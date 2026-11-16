class_name FxLayer
extends Node3D
## Short-lived combat effects: tracers, muzzle and impact flashes, blasts.
## Everything is a pooled primitive mesh animated in _process.

class Fx:
	var node: MeshInstance3D = null
	var age: float = 0.0
	var life: float = 0.1
	var grow: float = 0.0  ## scale added per second
	var base_scale: Vector3 = Vector3.ONE
	var rise: float = 0.0

var _active: Array[Fx] = []
var _tracer_mesh: BoxMesh = null
var _blast_mesh: SphereMesh = null
var _mats: Dictionary[String, StandardMaterial3D] = {}


func _ready() -> void:
	_tracer_mesh = BoxMesh.new()
	_tracer_mesh.size = Vector3(1.0, 1.0, 1.0)
	_blast_mesh = SphereMesh.new()
	_blast_mesh.radius = 0.5
	_blast_mesh.height = 1.0
	_blast_mesh.radial_segments = 8
	_blast_mesh.rings = 4


func _fx_mat(color: Color) -> StandardMaterial3D:
	var key: String = color.to_html()
	if _mats.has(key):
		return _mats[key]
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mats[key] = m
	return m


func _spawn(mesh: Mesh, color: Color, life: float) -> Fx:
	var fx: Fx = Fx.new()
	fx.node = MeshInstance3D.new()
	fx.node.mesh = mesh
	fx.node.material_override = _fx_mat(color)
	fx.node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	fx.life = life
	add_child(fx.node)
	_active.append(fx)
	return fx


## A bright streak from a to b.
func tracer(a: Vector3, b: Vector3, heavy: bool) -> void:
	var d: Vector3 = b - a
	var length: float = d.length()
	if length < 0.05:
		return
	var width: float = 0.09 if heavy else 0.05
	var fx: Fx = _spawn(_tracer_mesh, Color(1.0, 0.86, 0.45, 0.95) if heavy else Color(1.0, 0.93, 0.6, 0.85), 0.07)
	fx.node.position = (a + b) * 0.5
	var up: Vector3 = Vector3.UP if absf(d.normalized().y) < 0.95 else Vector3.RIGHT
	fx.node.look_at_from_position(fx.node.position, b, up)
	fx.base_scale = Vector3(width, width, length)
	fx.node.scale = fx.base_scale
	flash(a, 0.35 if heavy else 0.22, Color(1.0, 0.85, 0.5, 0.9), 0.06)


## An expanding, fading ball of light.
func flash(at: Vector3, size: float, color: Color, life: float = 0.2) -> void:
	var fx: Fx = _spawn(_blast_mesh, color, life)
	fx.node.position = at
	fx.base_scale = Vector3(size, size, size)
	fx.node.scale = fx.base_scale
	fx.grow = size * 2.5 / maxf(life, 0.01)


func explosion(at: Vector3, size: float) -> void:
	flash(at, size, Color(1.0, 0.75, 0.3, 0.95), 0.28)
	flash(at + Vector3(0.0, size * 0.3, 0.0), size * 0.6, Color(1.0, 0.95, 0.8, 0.95), 0.16)
	var smoke: Fx = _spawn(_blast_mesh, Color(0.16, 0.15, 0.14, 0.7), 0.9)
	smoke.node.position = at + Vector3(0.0, size * 0.4, 0.0)
	smoke.base_scale = Vector3(size, size, size) * 0.8
	smoke.node.scale = smoke.base_scale
	smoke.grow = size * 0.9
	smoke.rise = 1.4


func _process(delta: float) -> void:
	if _active.is_empty():
		return
	var kept: Array[Fx] = []
	for fx: Fx in _active:
		fx.age += delta
		if fx.age >= fx.life:
			fx.node.queue_free()
			continue
		if fx.grow != 0.0:
			var s: float = fx.grow * fx.age
			fx.node.scale = fx.base_scale + Vector3(s, s, s)
		if fx.rise != 0.0:
			fx.node.position.y += fx.rise * delta
		fx.node.transparency = clampf(fx.age / fx.life, 0.0, 1.0)
		kept.append(fx)
	_active = kept
