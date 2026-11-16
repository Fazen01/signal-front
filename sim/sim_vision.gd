class_name SimVision
extends RefCounted
## Fog of war. Each player sees the cells inside their own signal coverage
## (the network shares what it sees) plus a disc around every unit and
## building they own. Rebuilt four times a second.

const INTERVAL: int = 5
const STEALTH_REVEAL_TICKS: int = 50  ## how long firing keeps a stealth unit visible
const SITE_SIGHT: float = 4.0


static func update(w: SimWorld) -> void:
	if w.tick_count >= w.vision_next_tick:
		recompute(w)


static func recompute(w: SimWorld) -> void:
	w.vision_next_tick = w.tick_count + INTERVAL
	w.vision_version += 1
	var cells: int = w.map.w * w.map.h
	for p: SimPlayer in w.players:
		var vis: PackedByteArray = w.coverage[p.id].duplicate()
		for e: SimEntity in w.entities:
			if not e.alive or e.owner != p.id or e.def == null:
				continue
			var sight: float = SimCombat.sight_range(w, e) if e.constructed else SITE_SIGHT
			SimSignal.stamp_disc(w, vis, e.pos, sight)
		for r: Vector4 in w.reveals:
			if int(r.w) == p.id:
				SimSignal.stamp_disc(w, vis, Vector2(r.x, r.y), r.z)
		var seen: PackedByteArray = w.explored[p.id]
		for i: int in cells:
			if vis[i] != 0:
				seen[i] = 1
		w.explored[p.id] = seen
		w.visible[p.id] = vis


static func is_visible(w: SimWorld, player_id: int, pos: Vector2) -> bool:
	if player_id < 0 or player_id >= w.visible.size():
		return false
	var i: int = SimSignal.cell_index(w, pos)
	return i >= 0 and w.visible[player_id][i] != 0


static func is_explored(w: SimWorld, player_id: int, pos: Vector2) -> bool:
	if player_id < 0 or player_id >= w.explored.size():
		return false
	var i: int = SimSignal.cell_index(w, pos)
	return i >= 0 and w.explored[player_id][i] != 0


## True while an entity is actually hidden: it has stealth (or belongs to a
## forest-cloaking faction and stands in forest), is standing still and has
## not fired for a moment.
static func is_stealthed(w: SimWorld, e: SimEntity) -> bool:
	if e.def == null or e.moving or w.tick_count - e.last_fire_tick <= STEALTH_REVEAL_TICKS:
		return false
	if e.def.stealth:
		return true
	if e.kind != SimEntity.Kind.UNIT or e.owner < 0 or e.def.is_air():
		return false
	return w.players[e.owner].faction.forest_cloak and w.map.terrain_at(e.pos) == SimMap.Terrain.FOREST


## Can this player currently see this entity?
static func can_see(w: SimWorld, player_id: int, e: SimEntity) -> bool:
	if e.owner == player_id:
		return true
	if not is_visible(w, player_id, e.pos):
		return false
	if is_stealthed(w, e):
		for n: SimEntity in w.query_radius(e.pos, e.def.detect_range):
			if n.owner == player_id and n.def != null:
				return true
		return false
	return true
