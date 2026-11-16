class_name EntityView
extends Node3D
## The visual for one SimEntity. Reads sim state; never writes it.

const RING_OWN: Color = Color(0.35, 1.0, 0.45)
const RING_ENEMY: Color = Color(1.0, 0.3, 0.25)
const RING_NEUTRAL: Color = Color(1.0, 0.9, 0.4)

var entity_id: int = 0
var kind: int = SimEntity.Kind.UNIT
var model: Node3D = null
var turret: Node3D = null
var select_ring: MeshInstance3D = null
var base_y: float = 0.0
var shown: bool = true  ## false while hidden by fog of war
var seen_once: bool = false  ## the local player has seen this at least once
var owner_id: int = -1
var altitude: float = 0.0  ## aircraft are drawn this far above the ground
var _rotors: Array[Node3D] = []
var _spins: Array[Node3D] = []  ## radar dishes and the like, turning slowly
var _cargo: Node3D = null  ## a hauler's load, shown while it carries salvage
var _turret_home: Vector3 = Vector3.ZERO
var _kick: float = 0.0  ## turret recoil, 1 just after firing, decaying to 0
var _view_scale: float = 1.0
var _walks: bool = false  ## infantry bob as they move
var _stride: float = 0.0
var _scaffold: Node3D = null  ## stands around a building until it is finished
var _range_ring: MeshInstance3D = null  ## how far its weapons reach, while it is selected
var _fire: CPUParticles3D = null  ## flames on something close to destruction
var _smoke: CPUParticles3D = null  ## rises from badly damaged vehicles and buildings
var _selected: bool = false
var _wreck_since: int = 0  ## when this wreck started to burn (msec)

const WRECK_BURN: float = 12.0  ## seconds a fresh wreck is on fire
const WRECK_SMOKE: float = 26.0  ## and how long it goes on smoking


func setup(e: SimEntity, world: SimWorld, local_player: int) -> void:
	entity_id = e.id
	kind = e.kind
	owner_id = e.owner
	name = "E%d" % e.id
	set_process(false)
	match e.kind:
		SimEntity.Kind.UNIT, SimEntity.Kind.BUILDING:
			var team: Color = world.players[e.owner].color if e.owner >= 0 else Color(0.7, 0.7, 0.7)
			model = ModelFactory.build(e.def.model, team)
		SimEntity.Kind.WRECK:
			model = ModelFactory.build_wreck(e.wreck_model, e.id)
			model.rotation.y = -e.facing
			# A wreck made just now is on fire; one that was already lying
			# there when it came into view (or when a save was loaded) is not.
			var made: int = e.decay_tick - int(world.data.wreck_decay_seconds * float(SimWorld.TICK_RATE))
			if world.tick_count - made < SimWorld.TICK_RATE * 3:
				_wreck_since = Time.get_ticks_msec()
				_fire = _make_fire(e.radius)
				_smoke = _make_smoke(e.radius)
		SimEntity.Kind.FIELD:
			model = ModelFactory.build_field(e.id)
		_:
			model = ModelFactory.build_uplink()
	add_child(model)
	if e.def != null and e.kind == SimEntity.Kind.UNIT:
		altitude = e.def.altitude()
		model.position.y = altitude
		# Units are drawn a little larger than their footprint so they read
		# from the usual camera height; infantry most of all.
		_walks = e.def.is_infantry()
		_view_scale = 1.25 if _walks else 1.1
		model.scale = Vector3.ONE * _view_scale
	_find_parts()
	var ring_color: Color = RING_NEUTRAL
	if e.owner >= 0:
		ring_color = RING_OWN if e.owner == local_player else RING_ENEMY
	var ring_mat: StandardMaterial3D = ModelFactory.mat(ring_color, 1.0)
	var r: float = maxf(e.radius * 1.15, 0.55)
	if e.kind == SimEntity.Kind.BUILDING:
		r = e.radius * 1.42  # circumscribe the square footprint
	select_ring = ModelFactory.ring(self, r, r + maxf(0.08, r * 0.09), Vector3(0.0, 0.14, 0.0), ring_mat)
	select_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	select_ring.visible = false
	if e.def != null and e.def.jam_radius > 0.0:
		# Jammers show how far they reach.
		var jr: float = e.def.jam_radius
		var jam: MeshInstance3D = ModelFactory.ring(self, jr - 0.12, jr, Vector3(0.0, 0.3, 0.0), ModelFactory.mat(Color(0.75, 0.3, 1.0), 0.9))
		jam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sync(e, world.map, 1.0)


func set_shown(on: bool) -> void:
	if on:
		seen_once = true
	if on != shown:
		shown = on
		visible = on


## The longest reach among a definition's weapons, 0 if it has none.
static func weapon_reach(def: EntityDef) -> float:
	var reach: float = 0.0
	if def != null:
		for wd: WeaponDef in def.weapons:
			reach = maxf(reach, wd.max_range)
		# A unit with an aura shows how far that reaches instead.
		reach = maxf(reach, def.aura_radius)
	return reach


## Shows or hides a ring at the reach of this entity's weapons.
func set_range_shown(on: bool, e: SimEntity) -> void:
	if on and _range_ring == null and e != null:
		var reach: float = weapon_reach(e.def)
		if reach <= 0.0:
			return
		_range_ring = ModelFactory.ring(self, reach - 0.06, reach + 0.06, Vector3(0.0, 0.25, 0.0), ModelFactory.mat(Color(1.0, 0.55, 0.3), 1.0))
		_range_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if _range_ring != null:
		_range_ring.visible = on


func has_range_ring() -> bool:
	return _range_ring != null and _range_ring.visible


func set_selected(on: bool) -> void:
	if on != _selected:
		_selected = on
		select_ring.visible = on


## Ownership changed (an uplink was captured, a vehicle was hijacked):
## rebuild the model and selection ring in the new owner's colours.
func refresh_owner(e: SimEntity, world: SimWorld, local_player: int) -> void:
	if e.owner == owner_id:
		return
	owner_id = e.owner
	var team: Color = world.players[e.owner].color if e.owner >= 0 else Color(0.9, 0.9, 0.95)
	model.queue_free()
	if kind == SimEntity.Kind.UPLINK:
		model = ModelFactory.build_uplink(team)
	else:
		model = ModelFactory.build(e.def.model, team)
		model.position.y = altitude
		if kind == SimEntity.Kind.UNIT:
			model.scale = Vector3.ONE * _view_scale
	add_child(model)
	_find_parts()
	var ring_color: Color = RING_NEUTRAL
	if e.owner >= 0:
		ring_color = RING_OWN if e.owner == local_player else RING_ENEMY
	select_ring.material_override = ModelFactory.mat(ring_color, 1.0)


## How tall the model stands, for sizing the scaffolding around it.
func _model_height() -> float:
	var body: MeshInstance3D = model.get_node_or_null("Body") as MeshInstance3D
	if body == null or body.mesh == null:
		return 2.0
	var box: AABB = body.mesh.get_aabb()
	return snappedf(clampf(box.position.y + box.size.y, 1.6, 4.6), 0.2)


## Looks up the moving groups of the current model.
func _find_parts() -> void:
	turret = model.get_node_or_null("Turret") as Node3D
	_turret_home = turret.position if turret != null else Vector3.ZERO
	_cargo = model.get_node_or_null("Cargo") as Node3D
	_rotors.clear()
	_spins.clear()
	for child: Node in model.find_children("*", "Node3D", true, false):
		var part: String = str(child.name)
		if part.begins_with("Rotor"):
			_rotors.append(child as Node3D)
		elif part.begins_with("Spin"):
			_spins.append(child as Node3D)


## The unit just fired: its turret jolts back.
func kick() -> void:
	if turret != null:
		_kick = 1.0
		set_process(true)


## Only runs while a recoil is playing out.
func _process(delta: float) -> void:
	_kick = maxf(0.0, _kick - delta * 5.0)
	if turret != null:
		# Back along the barrel, which points down the turret's own +X.
		turret.position = _turret_home + turret.transform.basis.x * (-0.22 * _kick * _kick)
	if _kick <= 0.0:
		set_process(false)


func _update_damage_smoke(e: SimEntity) -> void:
	var burning: bool = e.constructed and e.hp < e.max_hp * 0.45 and (e.kind == SimEntity.Kind.BUILDING or e.def.is_vehicle())
	if burning and _smoke == null:
		_smoke = _make_smoke(e.radius)
	if _smoke != null and _smoke.emitting != burning:
		_smoke.emitting = burning
	# Close to destruction, flames join the smoke.
	var ablaze: bool = burning and e.hp < e.max_hp * 0.25
	if ablaze and _fire == null:
		_fire = _make_fire(e.radius)
	if _fire != null and _fire.emitting != ablaze:
		_fire.emitting = ablaze


## A fresh wreck burns for a while and smokes for a while longer.
func _update_wreck_fire() -> void:
	if _fire == null and _smoke == null:
		return
	var age: float = float(Time.get_ticks_msec() - _wreck_since) * 0.001
	if _fire != null and _fire.emitting and age > WRECK_BURN:
		_fire.emitting = false
	if _smoke != null and _smoke.emitting and age > WRECK_SMOKE:
		_smoke.emitting = false


func _make_smoke(radius: float) -> CPUParticles3D:
	var smoke: CPUParticles3D = CPUParticles3D.new()
	var puff: SphereMesh = SphereMesh.new()
	puff.radius = 0.3
	puff.height = 0.6
	puff.radial_segments = 6
	puff.rings = 3
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var ramp: Gradient = Gradient.new()
	ramp.set_color(0, Color(0.18, 0.17, 0.16, 0.75))
	ramp.set_color(1, Color(0.1, 0.1, 0.1, 0.0))
	smoke.mesh = puff
	smoke.material_override = m
	smoke.amount = 10
	smoke.lifetime = 2.2
	smoke.direction = Vector3.UP
	smoke.spread = 18.0
	smoke.initial_velocity_min = 1.0
	smoke.initial_velocity_max = 2.2
	smoke.gravity = Vector3(0.6, 0.8, 0.0)
	smoke.scale_amount_min = 0.8 + radius * 0.25
	smoke.scale_amount_max = 1.6 + radius * 0.5
	smoke.color_ramp = ramp
	smoke.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	smoke.position = Vector3(0.0, 1.0 + radius * 0.5, 0.0)
	add_child(smoke)
	return smoke


func _make_fire(radius: float) -> CPUParticles3D:
	var fire: CPUParticles3D = CPUParticles3D.new()
	var lick: SphereMesh = SphereMesh.new()
	lick.radius = 0.22
	lick.height = 0.6
	lick.radial_segments = 5
	lick.rings = 3
	var fm: StandardMaterial3D = StandardMaterial3D.new()
	fm.vertex_color_use_as_albedo = true
	fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var heat: Gradient = Gradient.new()
	heat.set_color(0, Color(1.0, 0.75, 0.3, 0.9))
	heat.set_color(1, Color(0.9, 0.15, 0.03, 0.0))
	fire.mesh = lick
	fire.material_override = fm
	fire.amount = 9
	fire.lifetime = 0.7
	fire.direction = Vector3.UP
	fire.spread = 22.0
	fire.initial_velocity_min = 1.2
	fire.initial_velocity_max = 2.6
	fire.gravity = Vector3(0.0, 2.0, 0.0)
	fire.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	fire.emission_sphere_radius = maxf(0.3, radius * 0.45)
	fire.scale_amount_min = 0.7 + radius * 0.2
	fire.scale_amount_max = 1.3 + radius * 0.4
	fire.color_ramp = heat
	fire.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	fire.position = Vector3(0.0, 0.7 + radius * 0.35, 0.0)
	add_child(fire)
	return fire


func sync(e: SimEntity, map: SimMap, alpha: float) -> void:
	if e.def != null:
		_update_damage_smoke(e)
	elif kind == SimEntity.Kind.WRECK:
		_update_wreck_fire()
	var p: Vector2 = e.prev_pos.lerp(e.pos, alpha)
	base_y = map.height_at(p)
	position = Vector3(p.x, base_y, p.y)
	match kind:
		SimEntity.Kind.UNIT:
			var f: float = lerp_angle(e.prev_facing, e.facing, alpha)
			model.rotation.y = -f
			if turret != null:
				turret.rotation.y = -(lerp_angle(e.prev_aim, e.aim, alpha) - f)
			var t: float = float(Time.get_ticks_msec()) * 0.001
			if altitude > 0.0:
				model.position.y = altitude + sin(t * 1.7 + float(entity_id)) * 0.18
				for r: Node3D in _rotors:
					r.rotation.y = t * 38.0
			elif _walks:
				# A small bounce in step while on the move.
				var moving: bool = e.pos.distance_squared_to(e.prev_pos) > 0.000001
				_stride = lerpf(_stride, 1.0 if moving else 0.0, 0.2)
				model.position.y = absf(sin(t * 9.0 + float(entity_id))) * 0.09 * _stride
			if _cargo != null:
				var fill: float = clampf(float(e.cargo) / maxf(1.0, float(e.def.capacity)), 0.0, 1.0)
				_cargo.visible = fill > 0.02
				var heap: float = lerpf(0.35, 1.0, fill)
				if fill > 0.02 and absf(_cargo.scale.y - heap) > 0.02:
					_cargo.scale = Vector3(1.0, heap, 1.0)
			for sp: Node3D in _spins:
				sp.rotation.y = t * 1.4
		SimEntity.Kind.BUILDING:
			if turret != null:
				turret.rotation.y = -lerp_angle(e.prev_aim, e.aim, alpha)
			if e.constructed and not _spins.is_empty():
				var bt: float = float(Time.get_ticks_msec()) * 0.001
				for sp: Node3D in _spins:
					sp.rotation.y = bt * 1.1 + float(entity_id)
			var sy: float = 1.0 if e.constructed else lerpf(0.12, 1.0, e.build_progress)
			if absf(model.scale.y - sy) > 0.001:
				model.scale = Vector3(1.0, sy, 1.0)
			if not e.constructed and _scaffold == null and e.radius >= 1.4:
				_scaffold = ModelFactory.build_scaffold(snappedf(e.radius + 0.15, 0.1), _model_height())
				add_child(_scaffold)
			elif e.constructed and _scaffold != null:
				_scaffold.queue_free()
				_scaffold = null
		SimEntity.Kind.UPLINK:
			for sp: Node3D in _spins:
				sp.rotation.y = float(Time.get_ticks_msec()) * 0.0009
		SimEntity.Kind.FIELD:
			var s: float = lerpf(0.45, 1.0, clampf(float(e.salvage) / e.max_hp, 0.0, 1.0))
			if absf(model.scale.x - s) > 0.005:
				model.scale = Vector3(s, s, s)
