class_name WorldView
extends Node3D
## Mirrors the simulation into the scene: one EntityView per SimEntity, a
## small mesh per projectile, and effects for sim events.

var world: SimWorld = null
var local_player: int = 0
var views: Dictionary[int, EntityView] = {}
var fog_enabled: bool = true
var _ghosts: Array[EntityView] = []  ## remembered enemy buildings that died unseen
var fx: FxLayer = null
var _proj_views: Dictionary[int, MeshInstance3D] = {}
var _proj_mesh: BoxMesh = null
var _proj_mats: Dictionary[String, StandardMaterial3D] = {}


func setup(sim_world: SimWorld, local_player_id: int) -> void:
	world = sim_world
	local_player = local_player_id
	fx = FxLayer.new()
	fx.name = "Fx"
	add_child(fx)
	_proj_mesh = BoxMesh.new()
	_proj_mesh.size = Vector3(0.16, 0.16, 0.6)
	sync(1.0)


func view_of(id: int) -> EntityView:
	return views.get(id, null)


## Whether the local player can currently see this entity's visual.
func is_shown(id: int) -> bool:
	var v: EntityView = views.get(id, null)
	return v != null and v.shown


## Fog-of-war rule for one entity: own things always; enemy units only while
## seen; enemy buildings and neutral objects stay once they have been seen.
func _should_show(e: SimEntity, v: EntityView) -> bool:
	if not fog_enabled or e.owner == local_player:
		return true
	if e.owner < 0:
		if e.kind == SimEntity.Kind.WRECK:
			return v.seen_once or SimVision.is_visible(world, local_player, e.pos)
		return SimVision.is_explored(world, local_player, e.pos)
	if SimVision.can_see(world, local_player, e):
		return true
	return e.kind == SimEntity.Kind.BUILDING and v.seen_once


## Brings every visual up to date. alpha is how far we are between the last
## two simulation ticks (0..1).
func sync(alpha: float) -> void:
	for e: SimEntity in world.entities:
		var v: EntityView = views.get(e.id, null)
		if v == null:
			v = EntityView.new()
			add_child(v)
			v.setup(e, world, local_player)
			v.shown = true
			views[e.id] = v
		v.set_shown(_should_show(e, v))
		if v.shown:
			if e.kind == SimEntity.Kind.UPLINK:
				v.refresh_owner(e, world)
			v.sync(e, world.map, alpha)
	if views.size() != world.entities.size():
		var gone: Array[int] = []
		for id: int in views.keys():
			if not world.by_id.has(id):
				gone.append(id)
		for id: int in gone:
			var v: EntityView = views[id]
			views.erase(id)
			var ground: Vector2 = Vector2(v.position.x, v.position.z)
			if fog_enabled and v.kind == SimEntity.Kind.BUILDING and v.owner_id != local_player and v.seen_once and not SimVision.is_visible(world, local_player, ground):
				# Destroyed out of sight: the player keeps seeing it until they look again.
				_ghosts.append(v)
			else:
				v.queue_free()
	if not _ghosts.is_empty():
		var kept: Array[EntityView] = []
		for g: EntityView in _ghosts:
			if SimVision.is_visible(world, local_player, Vector2(g.position.x, g.position.z)):
				g.queue_free()
			else:
				kept.append(g)
		_ghosts = kept
	_sync_projectiles(alpha)


func _sync_projectiles(alpha: float) -> void:
	var live: Dictionary[int, bool] = {}
	for p: SimProjectile in world.projectiles:
		live[p.id] = true
		var node: MeshInstance3D = _proj_views.get(p.id, null)
		if node == null:
			node = MeshInstance3D.new()
			node.mesh = _proj_mesh
			node.material_override = _proj_mat(p.weapon.fx)
			node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(node)
			_proj_views[p.id] = node
		var flat: Vector2 = p.prev_pos.lerp(p.pos, alpha)
		node.visible = not fog_enabled or SimVision.is_visible(world, local_player, flat)
		var total: float = maxf(p.start_pos.distance_to(p.target_pos), 0.01)
		var done: float = clampf(p.start_pos.distance_to(flat) / total, 0.0, 1.0)
		var arc: float = 1.6 if p.weapon.homing else 0.5
		var y: float = world.map.height_at(flat) + 1.0 + sin(done * PI) * arc
		var at: Vector3 = Vector3(flat.x, y, flat.y)
		var ahead: Vector2 = p.target_pos - flat
		if ahead.length() > 0.05:
			var to: Vector3 = Vector3(p.target_pos.x, y + cos(done * PI) * arc * 0.5, p.target_pos.y)
			node.look_at_from_position(at, to, Vector3.UP)
		else:
			node.position = at
	if _proj_views.size() != live.size():
		var gone: Array[int] = []
		for id: int in _proj_views.keys():
			if not live.has(id):
				gone.append(id)
		for id: int in gone:
			_proj_views[id].queue_free()
			_proj_views.erase(id)


func _proj_mat(fx_name: String) -> StandardMaterial3D:
	if _proj_mats.has(fx_name):
		return _proj_mats[fx_name]
	var color: Color = Color(1.0, 0.8, 0.4)
	if fx_name == "missile":
		color = Color(1.0, 0.55, 0.25)
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	_proj_mats[fx_name] = m
	return m


func _directive_fx(ev: SimEvent) -> void:
	var at: Vector3 = _ground(ev.pos, 0.35)
	var duration: float = ev.pos2.x
	match ev.text:
		"recon_sweep":
			fx.ground_ring(at, ev.value, Color(0.45, 0.9, 1.0, 0.9), 1.2, true)
			fx.ground_ring(at, ev.value, Color(0.45, 0.9, 1.0, 0.35), duration)
		"shell_barrage":
			fx.ground_ring(at, ev.value, Color(1.0, 0.3, 0.2, 0.9), duration + 1.5)
		"field_repair":
			fx.ground_ring(at, ev.value, Color(0.4, 1.0, 0.5, 0.9), 1.4, true)
			fx.flash(at + Vector3(0.0, 1.0, 0.0), 2.0, Color(0.4, 1.0, 0.5, 0.5), 0.5)
		"blackout":
			fx.ground_disc(at, ev.value, Color(0.12, 0.02, 0.2, 0.5), duration)
			fx.ground_ring(at, ev.value, Color(0.75, 0.3, 1.0, 0.9), duration)
		"reinforcement_drop":
			fx.ground_ring(at, ev.value, Color(0.5, 0.8, 1.0, 0.9), duration)
		"drop_arrived":
			fx.flash(at + Vector3(0.0, 0.8, 0.0), 2.5, Color(0.7, 0.9, 1.0, 0.8), 0.4)
			fx.ground_ring(at, ev.value, Color(0.7, 0.9, 1.0, 0.9), 0.8, true)
		_:
			pass


func _ground(p: Vector2, lift: float) -> Vector3:
	return Vector3(p.x, world.map.height_at(p) + lift, p.y)


## Called by the battle scene for every sim event after a tick.
func handle_event(ev: SimEvent) -> void:
	var own_power: bool = ev.type == SimEvent.Type.DIRECTIVE and ev.player == local_player
	if fog_enabled and not own_power and not SimVision.is_visible(world, local_player, ev.pos):
		if ev.type != SimEvent.Type.SHOT or not SimVision.is_visible(world, local_player, ev.pos2):
			return
	match ev.type:
		SimEvent.Type.DIRECTIVE:
			_directive_fx(ev)
		SimEvent.Type.RANK_UP:
			fx.ground_ring(_ground(ev.pos, 0.2), 1.6, Color(1.0, 0.85, 0.3, 0.9), 0.8, true)
		SimEvent.Type.SHOT:
			fx.tracer(_ground(ev.pos, 1.0), _ground(ev.pos2, 0.8), ev.text == "tracer_heavy")
		SimEvent.Type.PROJECTILE:
			fx.flash(_ground(ev.pos, 1.1), 0.4, Color(1.0, 0.8, 0.45, 0.9), 0.08)
		SimEvent.Type.IMPACT:
			fx.explosion(_ground(ev.pos, 0.6), 0.9 + ev.value)
		SimEvent.Type.DIED:
			fx.explosion(_ground(ev.pos, 0.7), 1.0 + ev.value * 1.4)
