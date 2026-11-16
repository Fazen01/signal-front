class_name FxLayer
extends Node3D
## Short-lived combat effects: tracers, muzzle and impact flashes, blasts.
## Everything is a pooled primitive mesh animated in _process. Each effect
## owns its material and fades through the material's alpha: the per-object
## `transparency` property does nothing in the Compatibility renderer.

class Fx:
	var node: MeshInstance3D = null
	var mat: StandardMaterial3D = null
	var color: Color = Color.WHITE
	var additive: bool = false
	var age: float = 0.0
	var life: float = 0.1
	var grow: float = 0.0  ## scale added per second
	var base_scale: Vector3 = Vector3.ONE
	var rise: float = 0.0
	var grow_flat: float = 0.0  ## x/z scale added per second (ground rings)
	var grow_limit: float = 0.0
	var late_fade: bool = false  ## stay solid, fade only in the last 20%

const MAX_BURSTS: int = 56  ## live particle emitters; extra bursts are skipped
const MAX_LIGHTS: int = 6  ## flashes that light their surroundings at once
const MAX_SCORCH: int = 36  ## burn marks left on the ground; the oldest goes first
const SCORCH_LIFE: float = 22.0
const PLAIN: Color = Color(1.0, 0.72, 0.3)  ## the colour of fire, when no faction's colour is given

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
var _pool_mix: Array[Fx] = []  ## spent effects waiting to be reused
var _pool_add: Array[Fx] = []
var _lights: Array[OmniLight3D] = []
var _light_age: Array[float] = []
var _light_life: Array[float] = []
var _light_peak: Array[float] = []
var _scorch: Array[MeshInstance3D] = []
var _scorch_age: Array[float] = []
var _scorch_mesh: CylinderMesh = null
var _scorch_shader: Shader = null
var _flame_ramp: Gradient = null
var _blasts: int = 0  ## explosions so far; each leans a different way


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
	_flame_ramp = _ramp(Color(1.0, 0.72, 0.25, 0.95), Color(0.9, 0.2, 0.05, 0.0))
	_scorch_mesh = CylinderMesh.new()
	_scorch_mesh.top_radius = 1.0
	_scorch_mesh.bottom_radius = 1.0
	_scorch_mesh.height = 0.02
	_scorch_mesh.radial_segments = 14
	_scorch_mesh.rings = 1
	# A soft-edged burn: dark in the middle, fading out towards the rim.
	_scorch_shader = Shader.new()
	_scorch_shader.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform float fade = 1.0;
varying vec2 flat_pos;

void vertex() {
	flat_pos = VERTEX.xz;
}

void fragment() {
	float d = length(flat_pos);
	ALBEDO = vec3(0.035, 0.03, 0.025);
	ALPHA = (1.0 - smoothstep(0.35, 1.0, d)) * 0.72 * fade;
}
"""


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


func _spawn(mesh: Mesh, color: Color, life: float, additive: bool = false) -> Fx:
	var pool: Array[Fx] = _pool_add if additive else _pool_mix
	var fx: Fx = null
	if pool.is_empty():
		fx = Fx.new()
		fx.additive = additive
		fx.mat = StandardMaterial3D.new()
		fx.mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		fx.mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		fx.mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		if additive:
			fx.mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		fx.node = MeshInstance3D.new()
		fx.node.material_override = fx.mat
		fx.node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(fx.node)
	else:
		fx = pool.pop_back()
		fx.node.visible = true
		fx.node.transform = Transform3D.IDENTITY
	fx.node.mesh = mesh
	fx.color = color
	fx.mat.albedo_color = color
	fx.age = 0.0
	fx.life = life
	fx.grow = 0.0
	fx.rise = 0.0
	fx.grow_flat = 0.0
	fx.grow_limit = 0.0
	fx.late_fade = false
	fx.base_scale = Vector3.ONE
	_active.append(fx)
	return fx


## A bright streak from a to b.
func tracer(a: Vector3, b: Vector3, heavy: bool, tint: Color = PLAIN) -> void:
	var d: Vector3 = b - a
	var length: float = d.length()
	if length < 0.05:
		return
	var width: float = 0.09 if heavy else 0.05
	var up: Vector3 = Vector3.UP if absf(d.normalized().y) < 0.95 else Vector3.RIGHT
	# A hot core inside a wider, fainter glow.
	var hot: Color = tint.lerp(Color.WHITE, 0.55)
	var fx: Fx = _spawn(_tracer_mesh, Color(hot.r, hot.g, hot.b, 0.95), 0.07, true)
	fx.node.position = (a + b) * 0.5
	fx.node.look_at_from_position(fx.node.position, b, up)
	fx.base_scale = Vector3(width, width, length)
	fx.node.scale = fx.base_scale
	var halo: Fx = _spawn(_tracer_mesh, Color(tint.r, tint.g, tint.b, 0.42), 0.09, true)
	halo.node.position = fx.node.position
	halo.node.look_at_from_position(halo.node.position, b, up)
	halo.base_scale = Vector3(width * 3.0, width * 3.0, length)
	halo.node.scale = halo.base_scale
	muzzle(a, d / length, 0.5 if heavy else 0.3, tint)


## A muzzle flash: a short tongue of flame along `dir` and a burst of light.
func muzzle(at: Vector3, dir: Vector3, size: float, tint: Color = PLAIN) -> void:
	var up: Vector3 = Vector3.UP if absf(dir.y) < 0.95 else Vector3.RIGHT
	var warm: Color = tint.lerp(Color(1.0, 0.8, 0.4), 0.35)
	var tongue: Fx = _spawn(_tracer_mesh, Color(warm.r, warm.g, warm.b, 0.95), 0.06, true)
	tongue.node.position = at + dir * size * 0.9
	tongue.node.look_at_from_position(tongue.node.position, at + dir * 4.0, up)
	tongue.base_scale = Vector3(size * 0.45, size * 0.45, size * 1.8)
	tongue.node.scale = tongue.base_scale
	flash(at, size * 0.7, Color(warm.r, warm.g, warm.b, 0.9), 0.06)
	if size >= 0.45:
		light(at + Vector3(0.0, 0.4, 0.0), warm, 2.2, 5.0 + size * 4.0, 0.1)


## A brief light that falls on everything nearby. Skipped when too many are
## already burning.
func light(at: Vector3, color: Color, energy: float, reach: float, life: float) -> void:
	if _lights.size() >= MAX_LIGHTS:
		return
	var l: OmniLight3D = OmniLight3D.new()
	l.light_color = color
	l.light_energy = energy
	l.omni_range = reach
	l.omni_attenuation = 1.4
	l.shadow_enabled = false
	l.position = at
	add_child(l)
	_lights.append(l)
	_light_age.append(0.0)
	_light_life.append(life)
	_light_peak.append(energy)


## A burn mark on the ground that fades over the next twenty seconds or so.
func scorch(at: Vector3, radius: float) -> void:
	if _scorch.size() >= MAX_SCORCH:
		_scorch[0].queue_free()
		_scorch.remove_at(0)
		_scorch_age.remove_at(0)
	var mi: MeshInstance3D = MeshInstance3D.new()
	var burn: ShaderMaterial = ShaderMaterial.new()
	burn.shader = _scorch_shader
	mi.mesh = _scorch_mesh
	mi.material_override = burn
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = at
	mi.scale = Vector3(radius, 1.0, radius)
	mi.rotation.y = at.x * 1.7 + at.z
	add_child(mi)
	_scorch.append(mi)
	_scorch_age.append(0.0)


## Flames licking up from something burning.
func flames(at: Vector3, size: float) -> void:
	var p: CPUParticles3D = _emitter(at, 8, 0.7, _puff_mesh)
	if p == null:
		return
	p.explosiveness = 0.3
	p.spread = 25.0
	p.initial_velocity_min = 1.2
	p.initial_velocity_max = 2.6 + size
	p.gravity = Vector3(0.0, 2.5, 0.0)
	p.scale_amount_min = 0.5 * size
	p.scale_amount_max = 1.1 * size
	p.color_ramp = _flame_ramp


## An expanding, fading ball of light.
func flash(at: Vector3, size: float, color: Color, life: float = 0.2) -> void:
	var fx: Fx = _spawn(_blast_mesh, color, life, true)
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


## Fireball, flying debris and a column of smoke. `tint` colours the shock
## ring and the hot core (a faction's shells burst in its own colour). No
## two look quite alike: the fireball is lopsided, and the bigger the blast
## the more there is to it (a second, slower fireball; a ring of dust; a
## pillar of smoke that hangs for seconds).
func explosion(at: Vector3, size: float, tint: Color = PLAIN) -> void:
	_blasts += 1
	var lean: Vector3 = Vector3(sin(float(_blasts) * 2.4), 0.0, cos(float(_blasts) * 2.4)) * size * 0.28
	flash(at, size, Color(1.0, 0.6, 0.2, 0.9), 0.3)
	flash(at + lean + Vector3(0.0, size * 0.3, 0.0), size * 0.66, Color(1.0, 0.95, 0.8, 0.95), 0.16)
	flash(at - lean * 0.8 + Vector3(0.0, size * 0.15, 0.0), size * 0.5, Color(1.0, 0.45, 0.12, 0.85), 0.36)
	var core: Color = tint.lerp(Color(1.0, 0.85, 0.6), 0.4)
	# A shock ring racing out along the ground.
	ground_ring(Vector3(at.x, at.y - 0.3, at.z), size * 2.4, Color(core.r, core.g, core.b, 0.6), 0.32, true)
	light(at + Vector3(0.0, 0.8, 0.0), Color(1.0, 0.7, 0.35), 2.5 + size, 6.0 + size * 5.0, 0.3)
	scorch(Vector3(at.x, at.y - 0.45, at.z), 0.9 + size * 0.9)
	debris(at, size)
	sparks(at, 4 + int(size * 3.0))
	flames(at, maxf(0.6, size * 0.6))
	smoke(at + Vector3(0.0, size * 0.3, 0.0), maxf(0.7, size * 0.7))
	if size >= 1.4:
		# A second fireball rolls up after the first.
		flash(at + Vector3(0.0, size * 0.75, 0.0) + lean * 0.5, size * 0.8, Color(0.95, 0.4, 0.1, 0.7), 0.55)
	if size >= 1.8:
		dust(at, size * 0.6)
		ground_ring(Vector3(at.x, at.y - 0.3, at.z), size * 3.6, Color(0.7, 0.62, 0.5, 0.3), 0.6, true)
		smoke_pillar(at + Vector3(0.0, size * 0.5, 0.0), size)


## Smoke that keeps rising from where something big blew up, for a few
## seconds after the fire has gone. Skipped when the battle is already thick
## with effects, so that the short bursts still get their turn.
func smoke_pillar(at: Vector3, size: float) -> void:
	if _bursts.size() > MAX_BURSTS * 2 / 3:
		return
	var p: CPUParticles3D = _emitter(at, 9, 4.2, _puff_mesh)
	if p == null:
		return
	p.explosiveness = 0.1
	p.spread = 12.0
	p.initial_velocity_min = 0.8
	p.initial_velocity_max = 1.6
	p.gravity = Vector3(0.35, 0.5, 0.0)
	p.scale_amount_min = 1.0 * size
	p.scale_amount_max = 2.1 * size
	p.color_ramp = _smoke_ramp


## How many mesh effects are live; callers use it to thin out optional ones.
func active_count() -> int:
	return _active.size()


## A low puff of dust behind a moving vehicle.
func trail_dust(at: Vector3, size: float) -> void:
	var fx: Fx = _spawn(_blast_mesh, Color(0.56, 0.50, 0.40, 0.30), 0.75)
	fx.node.position = at
	fx.base_scale = Vector3(size, size * 0.6, size) * 0.6
	fx.node.scale = fx.base_scale
	fx.grow = size * 1.1
	fx.rise = 0.5


## A small trailing puff (missile exhaust).
func puff(at: Vector3) -> void:
	var fx: Fx = _spawn(_blast_mesh, Color(0.8, 0.78, 0.74, 0.5), 0.45)
	fx.node.position = at
	fx.base_scale = Vector3(0.22, 0.22, 0.22)
	fx.node.scale = fx.base_scale
	fx.grow = 0.7


func _process(delta: float) -> void:
	var li: int = _lights.size() - 1
	while li >= 0:
		_light_age[li] += delta
		var left: float = 1.0 - _light_age[li] / _light_life[li]
		if left <= 0.0:
			_lights[li].queue_free()
			_lights.remove_at(li)
			_light_age.remove_at(li)
			_light_life.remove_at(li)
			_light_peak.remove_at(li)
		else:
			_lights[li].light_energy = _light_peak[li] * left
		li -= 1
	var si: int = _scorch.size() - 1
	while si >= 0:
		_scorch_age[si] += delta
		if _scorch_age[si] >= SCORCH_LIFE:
			_scorch[si].queue_free()
			_scorch.remove_at(si)
			_scorch_age.remove_at(si)
		elif _scorch_age[si] > SCORCH_LIFE * 0.6:
			# Fades out over the last part of its life.
			var burn: ShaderMaterial = _scorch[si].material_override as ShaderMaterial
			burn.set_shader_parameter("fade", 1.0 - (_scorch_age[si] / SCORCH_LIFE - 0.6) / 0.4)
		si -= 1
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
			fx.node.visible = false
			if fx.additive:
				_pool_add.append(fx)
			else:
				_pool_mix.append(fx)
			continue
		if fx.grow != 0.0:
			var s: float = fx.grow * fx.age
			fx.node.scale = fx.base_scale + Vector3(s, s, s)
		if fx.rise != 0.0:
			fx.node.position.y += fx.rise * delta
		if fx.grow_flat != 0.0:
			var r: float = minf(fx.grow_limit, fx.base_scale.x + fx.grow_flat * fx.age)
			fx.node.scale = Vector3(r, 1.0, r)
		var gone: float = clampf(fx.age / fx.life, 0.0, 1.0)
		if fx.late_fade:
			gone = clampf((fx.age / fx.life - 0.8) * 5.0, 0.0, 1.0)
		fx.mat.albedo_color = Color(fx.color.r, fx.color.g, fx.color.b, fx.color.a * (1.0 - gone))
		kept.append(fx)
	_active = kept
