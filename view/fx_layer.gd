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
	var grow_flat: float = 0.0  ## x/z scale added per second (ground rings)
	var grow_limit: float = 0.0
	var late_fade: bool = false  ## stay solid, fade only in the last 20%

const MAX_BURSTS: int = 56  ## live particle emitters; extra bursts are skipped

var _active: Array[Fx] = []
var _bursts: Array[CPUParticles3D] = []
var _burst_left: Array[float] = []
var _debris_mesh: BoxMesh = null
var _puff_mesh: SphereMesh = null
var _spark_mesh: BoxMesh = null
var _particle_mat: StandardMaterial3D = null
var _smoke_ramp: Gradient = null
var _spark_ramp: Gradient = null
var _dust_ramp: Gradient = null
var _tracer_mesh: BoxMesh = null
var _blast_mesh: SphereMesh = null
var _ring_mesh: TorusMesh = null
var _disc_mesh: CylinderMesh = null
var _mats: Dictionary[String, StandardMaterial3D] = {}


func _ready() -> void:
	_tracer_mesh = BoxMesh.new()
	_tracer_mesh.size = Vector3(1.0, 1.0, 1.0)
	_blast_mesh = SphereMesh.new()
	_blast_mesh.radius = 0.5
	_blast_mesh.height = 1.0
	_blast_mesh.radial_segments = 8
	_blast_mesh.rings = 4
	_ring_mesh = TorusMesh.new()
	_ring_mesh.inner_radius = 0.965
	_ring_mesh.outer_radius = 1.0
	_ring_mesh.rings = 48
	_ring_mesh.ring_segments = 4
	_disc_mesh = CylinderMesh.new()
	_disc_mesh.top_radius = 1.0
	_disc_mesh.bottom_radius = 1.0
	_disc_mesh.height = 0.05
	_disc_mesh.radial_segments = 40
	_disc_mesh.rings = 1
	_debris_mesh = BoxMesh.new()
	_debris_mesh.size = Vector3(0.16, 0.12, 0.2)
	_spark_mesh = BoxMesh.new()
	_spark_mesh.size = Vector3(0.05, 0.05, 0.22)
	_puff_mesh = SphereMesh.new()
	_puff_mesh.radius = 0.32
	_puff_mesh.height = 0.64
	_puff_mesh.radial_segments = 6
	_puff_mesh.rings = 3
	_particle_mat = StandardMaterial3D.new()
	_particle_mat.vertex_color_use_as_albedo = true
	_particle_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_particle_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_smoke_ramp = _ramp(Color(0.32, 0.30, 0.28, 0.8), Color(0.12, 0.12, 0.12, 0.0))
	_spark_ramp = _ramp(Color(1.0, 0.95, 0.6, 1.0), Color(1.0, 0.45, 0.1, 0.0))
	_dust_ramp = _ramp(Color(0.62, 0.55, 0.42, 0.55), Color(0.5, 0.45, 0.35, 0.0))


func _ramp(from: Color, to: Color) -> Gradient:
	var g: Gradient = Gradient.new()
	g.set_color(0, from)
	g.set_color(1, to)
	return g


func _emitter(at: Vector3, amount: int, life: float, mesh: Mesh) -> CPUParticles3D:
	if _bursts.size() >= MAX_BURSTS:
		return null
	var p: CPUParticles3D = CPUParticles3D.new()
	p.mesh = mesh
	p.material_override = _particle_mat
	p.amount = amount
	p.lifetime = life
	p.one_shot = true
	p.explosiveness = 0.92
	p.direction = Vector3.UP
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.position = at
	add_child(p)
	p.emitting = true
	_bursts.append(p)
	_burst_left.append(life + 0.35)
	return p


## Chunks thrown up by an explosion; they fall back under gravity.
func debris(at: Vector3, size: float) -> void:
	var p: CPUParticles3D = _emitter(at, int(5.0 + size * 5.0), 1.0, _debris_mesh)
	if p == null:
		return
	p.spread = 55.0
	p.initial_velocity_min = 3.5 + size
	p.initial_velocity_max = 7.0 + size * 2.5
	p.gravity = Vector3(0.0, -17.0, 0.0)
	p.angular_velocity_min = -400.0
	p.angular_velocity_max = 400.0
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.2 + size * 0.5
	p.color = Color(0.2, 0.19, 0.18)


## Rising, fading smoke.
func smoke(at: Vector3, size: float, amount: int = 7) -> void:
	var p: CPUParticles3D = _emitter(at, amount, 1.7, _puff_mesh)
	if p == null:
		return
	p.explosiveness = 0.55
	p.spread = 30.0
	p.initial_velocity_min = 0.6
	p.initial_velocity_max = 2.0 + size * 0.4
	p.gravity = Vector3(0.0, 0.7, 0.0)
	p.scale_amount_min = 0.9 * size
	p.scale_amount_max = 2.0 * size
	p.color_ramp = _smoke_ramp


## A short spray of hot fragments where a round strikes.
func sparks(at: Vector3, amount: int = 6) -> void:
	var p: CPUParticles3D = _emitter(at, amount, 0.32, _spark_mesh)
	if p == null:
		return
	p.spread = 75.0
	p.initial_velocity_min = 4.0
	p.initial_velocity_max = 9.0
	p.gravity = Vector3(0.0, -12.0, 0.0)
	p.color_ramp = _spark_ramp


## Dust kicked up at ground level.
func dust(at: Vector3, size: float) -> void:
	var p: CPUParticles3D = _emitter(at, 6, 0.8, _puff_mesh)
	if p == null:
		return
	p.direction = Vector3(0.0, 0.3, 0.0)
	p.spread = 85.0
	p.initial_velocity_min = 1.0
	p.initial_velocity_max = 2.4 + size
	p.gravity = Vector3(0.0, 0.2, 0.0)
	p.scale_amount_min = 0.7 * size
	p.scale_amount_max = 1.5 * size
	p.color_ramp = _dust_ramp


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


## A ring on the ground marking an area for `life` seconds. With `pulse` it
## starts small and expands to its radius.
func ground_ring(at: Vector3, radius: float, color: Color, life: float, pulse: bool = false) -> void:
	var fx: Fx = _spawn(_ring_mesh, color, life)
	fx.node.position = at
	if pulse:
		fx.base_scale = Vector3(radius * 0.15, 1.0, radius * 0.15)
		fx.grow_flat = radius * 0.85 / maxf(life * 0.5, 0.01)
		fx.grow_limit = radius
	else:
		fx.base_scale = Vector3(radius, 1.0, radius)
	fx.node.scale = fx.base_scale
	fx.late_fade = true


## A translucent disc on the ground for `life` seconds (Blackout).
func ground_disc(at: Vector3, radius: float, color: Color, life: float) -> void:
	var fx: Fx = _spawn(_disc_mesh, color, life)
	fx.node.position = at
	fx.base_scale = Vector3(radius, 1.0, radius)
	fx.node.scale = fx.base_scale
	fx.late_fade = true


## Fireball, flying debris and a column of smoke.
func explosion(at: Vector3, size: float) -> void:
	flash(at, size, Color(1.0, 0.75, 0.3, 0.95), 0.28)
	flash(at + Vector3(0.0, size * 0.3, 0.0), size * 0.6, Color(1.0, 0.95, 0.8, 0.95), 0.16)
	debris(at, size)
	smoke(at + Vector3(0.0, size * 0.3, 0.0), maxf(0.7, size * 0.7))
	if size >= 1.8:
		dust(at, size * 0.6)


## A small trailing puff (missile exhaust).
func puff(at: Vector3) -> void:
	var fx: Fx = _spawn(_blast_mesh, Color(0.8, 0.78, 0.74, 0.5), 0.45)
	fx.node.position = at
	fx.base_scale = Vector3(0.22, 0.22, 0.22)
	fx.node.scale = fx.base_scale
	fx.grow = 0.7


func _process(delta: float) -> void:
	var b: int = _bursts.size() - 1
	while b >= 0:
		_burst_left[b] -= delta
		if _burst_left[b] <= 0.0:
			_bursts[b].queue_free()
			_bursts.remove_at(b)
			_burst_left.remove_at(b)
		b -= 1
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
		if fx.grow_flat != 0.0:
			var r: float = minf(fx.grow_limit, fx.base_scale.x + fx.grow_flat * fx.age)
			fx.node.scale = Vector3(r, 1.0, r)
		if fx.late_fade:
			fx.node.transparency = clampf((fx.age / fx.life - 0.8) * 5.0, 0.0, 1.0)
		else:
			fx.node.transparency = clampf(fx.age / fx.life, 0.0, 1.0)
		kept.append(fx)
	_active = kept
