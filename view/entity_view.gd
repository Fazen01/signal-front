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
var _selected: bool = false


func setup(e: SimEntity, world: SimWorld, local_player: int) -> void:
	entity_id = e.id
	kind = e.kind
	owner_id = e.owner
	name = "E%d" % e.id
	match e.kind:
		SimEntity.Kind.UNIT, SimEntity.Kind.BUILDING:
			var team: Color = world.players[e.owner].color if e.owner >= 0 else Color(0.7, 0.7, 0.7)
			model = ModelFactory.build(e.def.model, team)
		SimEntity.Kind.WRECK:
			model = ModelFactory.build_wreck(e.wreck_model, e.id)
			model.rotation.y = -e.facing
		SimEntity.Kind.FIELD:
			model = ModelFactory.build_field(e.id)
		_:
			model = ModelFactory.build_uplink()
	add_child(model)
	turret = model.get_node_or_null("Turret") as Node3D
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
	sync(e, world.map, 1.0)


func set_shown(on: bool) -> void:
	if on:
		seen_once = true
	if on != shown:
		shown = on
		visible = on


func set_selected(on: bool) -> void:
	if on != _selected:
		_selected = on
		select_ring.visible = on


func sync(e: SimEntity, map: SimMap, alpha: float) -> void:
	var p: Vector2 = e.prev_pos.lerp(e.pos, alpha)
	base_y = map.height_at(p)
	position = Vector3(p.x, base_y, p.y)
	match kind:
		SimEntity.Kind.UNIT:
			var f: float = lerp_angle(e.prev_facing, e.facing, alpha)
			model.rotation.y = -f
			if turret != null:
				turret.rotation.y = -(lerp_angle(e.prev_aim, e.aim, alpha) - f)
		SimEntity.Kind.BUILDING:
			if turret != null:
				turret.rotation.y = -lerp_angle(e.prev_aim, e.aim, alpha)
			var sy: float = 1.0 if e.constructed else lerpf(0.12, 1.0, e.build_progress)
			if absf(model.scale.y - sy) > 0.001:
				model.scale = Vector3(1.0, sy, 1.0)
		SimEntity.Kind.FIELD:
			var s: float = lerpf(0.45, 1.0, clampf(float(e.salvage) / e.max_hp, 0.0, 1.0))
			if absf(model.scale.x - s) > 0.005:
				model.scale = Vector3(s, s, s)
