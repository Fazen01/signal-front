class_name SimSignal
extends RefCounted
## The Signal Grid: which emitters are chained back to an HQ, the coverage
## each player's linked emitters project, and who is Linked or Dark.

const MIN_INTERVAL_TICKS: int = 5  ## recompute at most 4 times a second


static func mark_dirty(w: SimWorld) -> void:
	w.signal_dirty = true


static func cell_index(w: SimWorld, pos: Vector2) -> int:
	var c: Vector2i = w.map.cell_of(pos)
	if not w.map.in_bounds(c):
		return -1
	return c.y * w.map.w + c.x


## True if `pos` is inside the player's signal coverage.
static func is_covered(w: SimWorld, player_id: int, pos: Vector2) -> bool:
	if player_id < 0 or player_id >= w.coverage.size():
		return false
	var i: int = cell_index(w, pos)
	return i >= 0 and w.coverage[player_id][i] != 0


static func is_emitter(e: SimEntity) -> bool:
	return e.def != null and e.def.signal_radius > 0.0 and e.kind == SimEntity.Kind.BUILDING and e.constructed


## Effective signal radius of an emitter for its owner right now.
static func emitter_radius(w: SimWorld, e: SimEntity) -> float:
	return e.def.signal_radius * w.players[e.owner].signal_radius_mult


## Distance from `pos` to the edge of the player's coverage: 0 inside it,
## otherwise how far outside the nearest linked emitter's disc it is.
static func distance_outside(w: SimWorld, player_id: int, pos: Vector2) -> float:
	if is_covered(w, player_id, pos):
		return 0.0
	var best: float = INF
	for e: SimEntity in w.entities:
		if e.alive and e.owner == player_id and is_emitter(e) and e.linked:
			best = minf(best, e.pos.distance_to(pos) - emitter_radius(w, e))
	return maxf(best, 0.0)


## Why a building cannot be placed at `centre` as far as signal goes, or "".
static func placement_error(w: SimWorld, player_id: int, def: EntityDef, centre: Vector2) -> String:
	if def.signal_radius > 0.0:
		for e: SimEntity in w.entities:
			if e.alive and e.owner == player_id and is_emitter(e) and e.linked:
				if e.pos.distance_to(centre) <= w.data.link_range:
					return ""
		return "Relay must be within link range of your network"
	if not is_covered(w, player_id, centre):
		return "Must be built inside your signal coverage"
	return ""


# -------------------------------------------------------------- per tick

static func update(w: SimWorld) -> void:
	if w.signal_dirty and w.tick_count >= w.signal_next_tick:
		recompute(w)
	# Mobile units check the cell they stand on every tick.
	var cells_w: int = w.map.w
	for e: SimEntity in w.entities:
		if e.kind != SimEntity.Kind.UNIT or e.owner < 0:
			continue
		var c: Vector2i = w.map.cell_of(e.pos)
		e.linked = w.map.in_bounds(c) and w.coverage[e.owner][c.y * cells_w + c.x] != 0


## Rebuilds the link graph and every player's coverage grid.
static func recompute(w: SimWorld) -> void:
	w.signal_dirty = false
	w.signal_next_tick = w.tick_count + MIN_INTERVAL_TICKS
	w.coverage_version += 1
	var cells: int = w.map.w * w.map.h
	for p: SimPlayer in w.players:
		var emitters: Array[SimEntity] = []
		for e: SimEntity in w.entities:
			if e.alive and e.owner == p.id and is_emitter(e):
				emitters.append(e)
		# Breadth-first from the roots: an emitter is linked when it is
		# within link range of an emitter that is already linked.
		var linked: Dictionary[int, bool] = {}
		var frontier: Array[SimEntity] = []
		var links: PackedInt32Array = PackedInt32Array()
		for e: SimEntity in emitters:
			if e.def.signal_root:
				linked[e.id] = true
				frontier.append(e)
		var head: int = 0
		while head < frontier.size():
			var a: SimEntity = frontier[head]
			head += 1
			for b: SimEntity in emitters:
				if linked.has(b.id):
					continue
				if a.pos.distance_to(b.pos) <= w.data.link_range:
					linked[b.id] = true
					frontier.append(b)
					links.append(a.id)
					links.append(b.id)
		var lost: int = 0
		var lost_at: Vector2 = Vector2.ZERO
		for e: SimEntity in emitters:
			var now_linked: bool = linked.has(e.id)
			if e.linked and not now_linked:
				lost += 1
				lost_at = e.pos
			e.linked = now_linked
		if lost > 0 and not p.defeated:
			w.alert(p.id, "Blackout! %d relay%s cut off from the HQ" % [lost, "" if lost == 1 else "s"], lost_at)
		w.signal_links[p.id] = links

		var grid: PackedByteArray = PackedByteArray()
		grid.resize(cells)
		for e: SimEntity in frontier:
			_stamp(w, grid, e.pos, emitter_radius(w, e))
		w.coverage[p.id] = grid

	# Everything that cannot move takes its state from the new grids.
	for e: SimEntity in w.entities:
		if e.alive and e.owner >= 0 and e.kind == SimEntity.Kind.BUILDING and not is_emitter(e):
			e.linked = is_covered(w, e.owner, e.pos)
	SimEconomy.recompute_bandwidth(w)


## Marks every cell whose centre lies within `radius` of `centre`.
static func _stamp(w: SimWorld, grid: PackedByteArray, centre: Vector2, radius: float) -> void:
	var cw: int = w.map.w
	var ch: int = w.map.h
	var x0: int = clampi(int(floorf((centre.x - radius) / SimMap.CELL)), 0, cw - 1)
	var x1: int = clampi(int(floorf((centre.x + radius) / SimMap.CELL)), 0, cw - 1)
	var y0: int = clampi(int(floorf((centre.y - radius) / SimMap.CELL)), 0, ch - 1)
	var y1: int = clampi(int(floorf((centre.y + radius) / SimMap.CELL)), 0, ch - 1)
	var r2: float = radius * radius
	for y: int in range(y0, y1 + 1):
		var cy: float = (float(y) + 0.5) * SimMap.CELL - centre.y
		for x: int in range(x0, x1 + 1):
			var cx: float = (float(x) + 0.5) * SimMap.CELL - centre.x
			if cx * cx + cy * cy <= r2:
				grid[y * cw + x] = 1
