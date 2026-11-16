class_name WorldView
extends Node3D
## Mirrors the simulation into the scene: one EntityView per SimEntity, a
## small mesh per projectile, and effects for sim events.

var world: SimWorld = null
var local_player: int = 0
var views: Dictionary[int, EntityView] = {}
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


## Brings every visual up to date. alpha is how far we are between the last
## two simulation ticks (0..1).
func sync(alpha: float) -> void:
	for e: SimEntity in world.entities:
		var v: EntityView = views.get(e.id, null)
		if v == null:
			v = EntityView.new()
			add_child(v)
			v.setup(e, world, local_player)
			views[e.id] = v
		v.sync(e, world.map, alpha)
	if views.size() != world.entities.size():
		var gone: Array[int] = []
		for id: int in views.keys():
			if not world.by_id.has(id):
				gone.append(id)
		for id: int in gone:
			views[id].queue_free()
			views.erase(id)
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


func _ground(p: Vector2, lift: float) -> Vector3:
	return Vector3(p.x, world.map.height_at(p) + lift, p.y)


## Called by the battle scene for every sim event after a tick.
func handle_event(ev: SimEvent) -> void:
	match ev.type:
		SimEvent.Type.SHOT:
			fx.tracer(_ground(ev.pos, 1.0), _ground(ev.pos2, 0.8), ev.text == "tracer_heavy")
		SimEvent.Type.PROJECTILE:
			fx.flash(_ground(ev.pos, 1.1), 0.4, Color(1.0, 0.8, 0.45, 0.9), 0.08)
		SimEvent.Type.IMPACT:
			fx.explosion(_ground(ev.pos, 0.6), 0.9 + ev.value)
		SimEvent.Type.DIED:
			fx.explosion(_ground(ev.pos, 0.7), 1.0 + ev.value * 1.4)
