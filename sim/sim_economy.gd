class_name SimEconomy
extends RefCounted
## Harvesting, construction, production, bandwidth and wreck decay.

enum Job { TO_RESOURCE, LOADING, TO_DEPOT, UNLOADING }

const RESOURCE_SEARCH: float = 30.0  ## how far a hauler looks for its next source
const SQUARE: float = 1.45  ## footprint half-size to corner distance, with slack


# ---------------------------------------------------------------- commands

static func apply_command(w: SimWorld, cmd: SimCommand) -> void:
	match cmd.type:
		SimCommand.Type.HARVEST:
			_cmd_harvest(w, cmd)
		SimCommand.Type.BUILD:
			_cmd_build(w, cmd)
		SimCommand.Type.REPAIR:
			_cmd_repair(w, cmd)
		SimCommand.Type.TRAIN:
			_cmd_train(w, cmd)
		SimCommand.Type.CANCEL_TRAIN:
			_cmd_cancel_train(w, cmd)
		SimCommand.Type.CANCEL_BUILDING:
			_cmd_cancel_building(w, cmd)
		SimCommand.Type.RALLY:
			var b: SimEntity = _own_building(w, cmd)
			if b != null:
				b.rally = w.map.clamp_to_map(cmd.pos)
				b.has_rally = true


static func _own_building(w: SimWorld, cmd: SimCommand) -> SimEntity:
	var b: SimEntity = w.get_entity(cmd.target_id)
	if b == null or b.owner != cmd.player or b.kind != SimEntity.Kind.BUILDING:
		return null
	return b


static func _cmd_harvest(w: SimWorld, cmd: SimCommand) -> void:
	var target: SimEntity = w.get_entity(cmd.target_id)
	if target == null:
		return
	var to_depot: bool = target.kind == SimEntity.Kind.BUILDING and target.owner == cmd.player and target.def.depot
	if not to_depot and not target.is_harvestable():
		return
	for e: SimEntity in SimOrders.own_units(w, cmd):
		if not e.def.harvester:
			continue
		SimOrders.give_order(e, SimOrder.make(SimOrder.Type.HARVEST, target.pos, target.id), cmd.queue)
		if not cmd.queue:
			start_harvest(e, target, to_depot)


## Points a hauler at a resource (or straight at a depot to unload).
static func start_harvest(e: SimEntity, target: SimEntity, to_depot: bool) -> void:
	e.work_ticks = 0
	if to_depot:
		e.harvest_target = 0
		e.job = Job.TO_DEPOT
	else:
		e.harvest_target = target.id
		e.job = Job.TO_DEPOT if e.cargo >= e.def.capacity else Job.TO_RESOURCE


## Why a building cannot go here, or "" when it can.
static func placement_error(w: SimWorld, player_id: int, def: EntityDef, cell: Vector2i) -> String:
	if def == null or not def.is_building or not def.buildable:
		return "Cannot build that"
	var p: SimPlayer = w.player(player_id)
	if p == null or def.faction != p.faction.id:
		return "Cannot build that"
	if not p.meets_requirements(def):
		return "Requires %s" % w.data.entity(def.requires[0]).name
	for y: int in range(cell.y, cell.y + def.footprint.y):
		for x: int in range(cell.x, cell.x + def.footprint.x):
			if not w.map.is_cell_buildable(Vector2i(x, y)):
				return "Ground is blocked"
	var centre: Vector2 = Vector2(
		(float(cell.x) + float(def.footprint.x) * 0.5) * SimMap.CELL,
		(float(cell.y) + float(def.footprint.y) * 0.5) * SimMap.CELL
	)
	for other: SimEntity in w.query_radius(centre, def.radius * SQUARE + 3.0):
		if other.kind == SimEntity.Kind.FIELD and other.pos.distance_to(centre) < other.radius + def.radius:
			return "Too close to a salvage field"
		if other.kind == SimEntity.Kind.UNIT and w.are_enemies(player_id, other.owner):
			if Rect2i(cell, def.footprint).has_point(w.map.cell_of(other.pos)):
				return "Enemy units in the way"
	return SimSignal.placement_error(w, player_id, def, centre)


static func can_place(w: SimWorld, player_id: int, def: EntityDef, cell: Vector2i) -> bool:
	return placement_error(w, player_id, def, cell) == ""


static func _cmd_build(w: SimWorld, cmd: SimCommand) -> void:
	var def: EntityDef = w.data.entity(cmd.def_id)
	var p: SimPlayer = w.players[cmd.player]
	var builders: Array[SimEntity] = []
	for e: SimEntity in SimOrders.own_units(w, cmd):
		if e.def.builder and e.def.builds.has(cmd.def_id):
			builders.append(e)
	if builders.is_empty():
		return
	var why: String = placement_error(w, cmd.player, def, cmd.cell)
	if why != "":
		w.alert(cmd.player, why, w.map.cell_center(cmd.cell))
		return
	if p.salvage < def.cost:
		w.alert(cmd.player, "Not enough salvage", w.map.cell_center(cmd.cell))
		return
	p.salvage -= def.cost
	p.stat_salvage_spent += def.cost
	var site: SimEntity = w.spawn_building(def.id, cmd.player, cmd.cell, false)
	_evict_units(w, Rect2i(cmd.cell, def.footprint))
	var ev: SimEvent = w.emit_event(SimEvent.Type.BUILDING_PLACED, site.id, cmd.player, site.pos)
	ev.text = def.id
	for e: SimEntity in builders:
		SimOrders.give_order(e, SimOrder.make(SimOrder.Type.REPAIR, site.pos, site.id), cmd.queue)


## Moves any unit standing on a new footprint to the nearest free ground.
static func _evict_units(w: SimWorld, rect: Rect2i) -> void:
	for e: SimEntity in w.entities:
		if e.alive and e.kind == SimEntity.Kind.UNIT and not e.def.is_air() and rect.has_point(w.map.cell_of(e.pos)):
			e.pos = w.map.nearest_free_pos(e.pos)
			if e.moving:
				SimMovement.start_move(w, e, e.move_goal)


static func _cmd_repair(w: SimWorld, cmd: SimCommand) -> void:
	var b: SimEntity = _own_building(w, cmd)
	if b == null:
		return
	for e: SimEntity in SimOrders.own_units(w, cmd):
		if e.def.builder:
			SimOrders.give_order(e, SimOrder.make(SimOrder.Type.REPAIR, b.pos, b.id), cmd.queue)


## Why a unit cannot be queued at this building, or "" when it can.
static func train_error(w: SimWorld, b: SimEntity, def: EntityDef) -> String:
	if b == null or def == null or not b.constructed or not b.def.produces.has(def.id):
		return "Cannot train that here"
	var p: SimPlayer = w.players[b.owner]
	if not p.meets_requirements(def):
		return "Requires %s" % w.data.entity(def.requires[0]).name
	if b.queue.size() >= w.data.queue_max:
		return "Queue is full"
	if p.salvage < def.cost:
		return "Not enough salvage"
	return ""


static func _cmd_train(w: SimWorld, cmd: SimCommand) -> void:
	var b: SimEntity = _own_building(w, cmd)
	if b == null:
		return
	var def: EntityDef = w.data.entity(cmd.def_id)
	var why: String = train_error(w, b, def)
	if why != "":
		w.alert(cmd.player, why, b.pos)
		return
	var p: SimPlayer = w.players[cmd.player]
	p.salvage -= def.cost
	p.stat_salvage_spent += def.cost
	b.queue.append(def.id)


static func _cmd_cancel_train(w: SimWorld, cmd: SimCommand) -> void:
	var b: SimEntity = _own_building(w, cmd)
	if b == null or cmd.index < 0 or cmd.index >= b.queue.size():
		return
	var def: EntityDef = w.data.entity(b.queue[cmd.index])
	var p: SimPlayer = w.players[cmd.player]
	p.salvage += def.cost
	p.stat_salvage_spent -= def.cost
	b.queue.remove_at(cmd.index)
	if cmd.index == 0:
		b.prod_progress = 0.0


static func _cmd_cancel_building(w: SimWorld, cmd: SimCommand) -> void:
	var b: SimEntity = _own_building(w, cmd)
	if b == null or b.constructed:
		return
	var p: SimPlayer = w.players[cmd.player]
	var refund: int = int(float(b.def.cost) * w.data.refund_fraction)
	p.salvage += refund
	p.stat_salvage_spent -= refund
	w.on_building_removed(b)
	w.remove_entity(b)
	var ev: SimEvent = w.emit_event(SimEvent.Type.DIED, b.id, b.owner, b.pos)
	ev.text = "cancelled"


# ------------------------------------------------------------ unit orders

static func update_order(w: SimWorld, e: SimEntity, o: SimOrder) -> void:
	match o.type:
		SimOrder.Type.HARVEST:
			_update_harvest(w, e, o)
		SimOrder.Type.REPAIR:
			_update_repair(w, e, o)
		_:
			SimOrders.finish_order(e)


static func find_resource(w: SimWorld, near: Vector2, max_dist: float) -> SimEntity:
	var best: SimEntity = null
	var best_d: float = max_dist
	for other: SimEntity in w.entities:
		if other.is_harvestable():
			var d: float = other.pos.distance_to(near)
			if d < best_d:
				best_d = d
				best = other
	return best


static func find_depot(w: SimWorld, owner: int, near: Vector2) -> SimEntity:
	var best: SimEntity = null
	var best_d: float = INF
	for other: SimEntity in w.entities:
		if other.alive and other.owner == owner and other.kind == SimEntity.Kind.BUILDING and other.constructed and other.def.depot:
			var d: float = other.pos.distance_to(near)
			if d < best_d:
				best_d = d
				best = other
	return best


## Walks e to within `reach` of target. Returns true once it is there (or as
## close as the terrain allows).
static func _approach(w: SimWorld, e: SimEntity, o: SimOrder, target: SimEntity, reach: float) -> bool:
	var d: float = e.pos.distance_to(target.pos)
	if d <= reach:
		if e.moving:
			SimMovement.stop(e)
		return true
	if o.started and not e.moving and d <= reach + 3.0:
		return true
	if not o.started or (not e.moving and w.tick_count >= e.repath_tick):
		var away: Vector2 = e.pos - target.pos
		if away.length() < 0.01:
			away = Vector2.RIGHT
		var edge: Vector2 = target.pos + away.normalized() * maxf(reach - e.radius - 0.4, 0.5)
		SimMovement.start_move(w, e, edge)
		o.started = true
		e.repath_tick = w.tick_count + 15
		if not e.moving:
			e.stuck_ticks += 15
	return false


static func _update_harvest(w: SimWorld, e: SimEntity, o: SimOrder) -> void:
	match e.job:
		Job.TO_RESOURCE:
			if e.cargo >= e.def.capacity:
				e.job = Job.TO_DEPOT
				o.started = false
				return
			var res: SimEntity = w.get_entity(e.harvest_target)
			if res == null or not res.is_harvestable():
				res = find_resource(w, o.pos, RESOURCE_SEARCH)
				if res == null:
					if e.cargo > 0:
						e.job = Job.TO_DEPOT
						o.started = false
					else:
						SimMovement.stop(e)
						SimOrders.finish_order(e)
					return
				e.harvest_target = res.id
				o.started = false
			if _approach(w, e, o, res, res.radius + e.radius + 0.5):
				e.job = Job.LOADING
				e.work_ticks = 0
		Job.LOADING:
			var res: SimEntity = w.get_entity(e.harvest_target)
			if res == null or not res.is_harvestable():
				e.job = Job.TO_RESOURCE
				o.started = false
				return
			e.work_ticks += 1
			if e.work_ticks >= int(w.data.harvest_seconds * float(SimWorld.TICK_RATE)):
				var take: int = mini(e.def.capacity - e.cargo, res.salvage)
				res.salvage -= take
				e.cargo += take
				if res.salvage <= 0:
					w.remove_entity(res)
				e.job = Job.TO_DEPOT
				o.started = false
		Job.TO_DEPOT:
			var depot: SimEntity = find_depot(w, e.owner, e.pos)
			if depot == null:
				SimMovement.stop(e)
				return
			if _approach(w, e, o, depot, depot.radius * SQUARE + e.radius + 0.6):
				e.job = Job.UNLOADING
				e.work_ticks = 0
		Job.UNLOADING:
			e.work_ticks += 1
			if e.work_ticks >= int(w.data.unload_seconds * float(SimWorld.TICK_RATE)):
				var p: SimPlayer = w.players[e.owner]
				p.salvage += e.cargo
				p.stat_salvage_collected += e.cargo
				var ev: SimEvent = w.emit_event(SimEvent.Type.DEPOSIT, e.id, e.owner, e.pos)
				ev.value = float(e.cargo)
				e.cargo = 0
				e.job = Job.TO_RESOURCE
				o.started = false


static func _update_repair(w: SimWorld, e: SimEntity, o: SimOrder) -> void:
	var b: SimEntity = w.get_entity(o.target_id)
	if b == null or b.owner != e.owner or (b.constructed and b.hp >= b.max_hp):
		SimMovement.stop(e)
		SimOrders.finish_order(e)
		return
	if _approach(w, e, o, b, b.radius * SQUARE + e.radius + 1.0):
		b.builders_now += 1
		e.facing = rotate_toward(e.facing, (b.pos - e.pos).angle(), e.def.turn_rate * SimWorld.DT)
		e.aim = e.facing
	elif e.stuck_ticks > 40:
		SimOrders.finish_order(e)


# -------------------------------------------------------------- per tick

static func update(w: SimWorld) -> void:
	var n: int = w.entities.size()
	for i: int in n:
		var e: SimEntity = w.entities[i]
		if not e.alive:
			continue
		if e.kind == SimEntity.Kind.BUILDING:
			_update_building(w, e)
		elif e.kind == SimEntity.Kind.WRECK and w.tick_count >= e.decay_tick:
			w.remove_entity(e)
	if w.tick_count % 10 == 0:
		recompute_bandwidth(w)


static func _update_building(w: SimWorld, b: SimEntity) -> void:
	var workers: int = b.builders_now
	b.builders_now = 0
	if not b.constructed:
		if workers > 0:
			# Extra builders help with diminishing returns.
			var rate: float = sqrt(float(workers)) * SimWorld.DT / b.def.build_time
			b.build_progress += rate
			b.hp = minf(b.max_hp, b.hp + rate * b.max_hp * 0.9)
			if b.build_progress >= 1.0:
				b.build_progress = 1.0
				b.constructed = true
				w.on_building_completed(b, true)
		return
	if workers > 0 and b.hp < b.max_hp and b.linked:
		b.hp = minf(b.max_hp, b.hp + b.max_hp * w.data.repair_rate * sqrt(float(workers)) * SimWorld.DT)
	if b.queue.is_empty() or b.owner < 0:
		return
	if not b.linked:
		return  # a Dark building pauses production
	var def: EntityDef = w.data.entity(b.queue[0])
	var p: SimPlayer = w.players[b.owner]
	if b.prod_progress < def.build_time:
		b.prod_progress += SimWorld.DT
		return
	if p.bandwidth_used + def.bandwidth > p.bandwidth_cap:
		if w.tick_count % 200 == 0:
			w.alert(b.owner, "Bandwidth limit reached - build Relays", b.pos)
		return
	b.queue.remove_at(0)
	b.prod_progress = 0.0
	_deliver_unit(w, b, def)


static func _deliver_unit(w: SimWorld, b: SimEntity, def: EntityDef) -> void:
	var out_dir: Vector2 = b.rally - b.pos
	if out_dir.length() < 0.01:
		out_dir = Vector2.DOWN
	out_dir = out_dir.normalized()
	var exit: Vector2 = w.map.nearest_free_pos(b.pos + out_dir * (b.radius * SQUARE + def.radius + 0.6))
	var u: SimEntity = w.spawn_unit(def.id, b.owner, exit, out_dir.angle())
	var p: SimPlayer = w.players[b.owner]
	p.stat_units_built += 1
	var ev: SimEvent = w.emit_event(SimEvent.Type.UNIT_READY, u.id, b.owner, u.pos)
	ev.other_id = b.id
	ev.text = def.id
	if def.harvester and not b.has_rally:
		var res: SimEntity = find_resource(w, b.pos, RESOURCE_SEARCH * 1.5)
		if res != null:
			u.orders.append(SimOrder.make(SimOrder.Type.HARVEST, res.pos, res.id))
			start_harvest(u, res, false)
			return
	u.orders.append(SimOrder.make(SimOrder.Type.MOVE, b.rally))


static func recompute_bandwidth(w: SimWorld) -> void:
	for p: SimPlayer in w.players:
		p.bandwidth_cap = 0
	for e: SimEntity in w.entities:
		if e.alive and e.owner >= 0 and e.kind == SimEntity.Kind.BUILDING and e.constructed and e.linked:
			w.players[e.owner].bandwidth_cap += e.def.bandwidth_provided
	for p: SimPlayer in w.players:
		p.bandwidth_cap = mini(p.bandwidth_cap, w.data.bandwidth_max)
