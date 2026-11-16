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
		SimCommand.Type.CAPTURE:
			var site: SimEntity = w.get_entity(cmd.target_id)
			if site != null and site.kind == SimEntity.Kind.UPLINK:
				for e: SimEntity in SimOrders.own_units(w, cmd):
					if e.def.builder:
						SimOrders.give_order(e, SimOrder.make(SimOrder.Type.CAPTURE, site.pos, site.id), cmd.queue)
			elif site != null and site.kind == SimEntity.Kind.UNIT:
				for e: SimEntity in SimOrders.own_units(w, cmd):
					if hijack_error(w, e, site) == "":
						SimOrders.give_order(e, SimOrder.make(SimOrder.Type.CAPTURE, site.pos, site.id), cmd.queue)
						e.work_ticks = 0
		SimCommand.Type.DEPLOY:
			_cmd_deploy(w, cmd)
		SimCommand.Type.PACK:
			_cmd_pack(w, cmd)
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
			var c: Vector2i = Vector2i(x, y)
			# Things that do not block (mines) only need walkable ground.
			if not (w.map.is_cell_buildable(c) if def.blocks else w.map.is_cell_passable(c)):
				return "Ground is blocked"
	var centre: Vector2 = Vector2(
		(float(cell.x) + float(def.footprint.x) * 0.5) * SimMap.CELL,
		(float(cell.y) + float(def.footprint.y) * 0.5) * SimMap.CELL
	)
	for other: SimEntity in w.query_radius(centre, def.radius * SQUARE + 3.0):
		if other.kind == SimEntity.Kind.FIELD and other.pos.distance_to(centre) < other.radius + def.radius:
			return "Too close to a salvage field"
		if other.kind == SimEntity.Kind.UPLINK and other.pos.distance_to(centre) < other.radius + def.radius * SQUARE:
			return "Too close to an uplink site"
		if other.kind == SimEntity.Kind.UNIT and w.are_enemies(player_id, other.owner) and not other.def.is_air():
			if Rect2i(cell, def.footprint).has_point(w.map.cell_of(other.pos)):
				return "Enemy units in the way"
	if not def.needs_coverage:
		return ""
	return SimSignal.placement_error(w, player_id, def, centre)


## Why a deployable unit cannot set up with its footprint at `cell`, or "".
static func deploy_error(w: SimWorld, player_id: int, unit_def: EntityDef, cell: Vector2i) -> String:
	var bdef: EntityDef = w.data.entity(unit_def.deploys_to)
	if bdef == null:
		return "Cannot deploy that"
	for y: int in range(cell.y, cell.y + bdef.footprint.y):
		for x: int in range(cell.x, cell.x + bdef.footprint.x):
			if not w.map.is_cell_buildable(Vector2i(x, y)):
				return "Ground is blocked"
	var centre: Vector2 = footprint_centre(cell, bdef)
	for other: SimEntity in w.query_radius(centre, bdef.radius * SQUARE + 3.0):
		if (other.kind == SimEntity.Kind.FIELD or other.kind == SimEntity.Kind.UPLINK) and other.pos.distance_to(centre) < other.radius + bdef.radius:
			return "Too close to a salvage field or uplink"
	if bdef.signal_root:
		return ""  # a headquarters brings its own signal
	return SimSignal.placement_error(w, player_id, bdef, centre)


static func footprint_centre(cell: Vector2i, def: EntityDef) -> Vector2:
	return Vector2(
		(float(cell.x) + float(def.footprint.x) * 0.5) * SimMap.CELL,
		(float(cell.y) + float(def.footprint.y) * 0.5) * SimMap.CELL
	)


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
	if def.blocks:
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


static func _cmd_deploy(w: SimWorld, cmd: SimCommand) -> void:
	for e: SimEntity in SimOrders.own_units(w, cmd):
		if e.def.deploys_to == "":
			continue
		var bdef: EntityDef = w.data.entity(e.def.deploys_to)
		var order: SimOrder = SimOrder.make(SimOrder.Type.DEPLOY, footprint_centre(cmd.cell, bdef))
		order.cell = cmd.cell
		SimOrders.give_order(e, order, cmd.queue)
		break  # one footprint, one unit


static func _update_deploy(w: SimWorld, e: SimEntity, o: SimOrder) -> void:
	var d: float = e.pos.distance_to(o.pos)
	var there: bool = d <= 1.0 or (o.started and not e.moving and d <= 3.5)
	if not there:
		if not o.started or (not e.moving and w.tick_count >= e.repath_tick):
			SimMovement.start_move(w, e, o.pos)
			o.started = true
			e.repath_tick = w.tick_count + 20
			if not e.moving:
				e.stuck_ticks += 20
		if e.stuck_ticks > 80:
			SimOrders.finish_order(e)
		return
	SimMovement.stop(e)
	var why: String = deploy_error(w, e.owner, e.def, o.cell)
	if why != "":
		w.alert(e.owner, why, e.pos)
		SimOrders.finish_order(e)
		return
	# Swap the unit for its building, keeping its state of repair.
	var frac: float = e.hp / e.max_hp
	var owner: int = e.owner
	var bdef: EntityDef = w.data.entity(e.def.deploys_to)
	w.players[owner].bandwidth_used -= e.def.bandwidth
	w.remove_entity(e)
	var b: SimEntity = w.spawn_building(bdef.id, owner, o.cell, true)
	b.hp = maxf(1.0, b.max_hp * frac)
	_evict_units(w, Rect2i(o.cell, bdef.footprint))
	var ev: SimEvent = w.emit_event(SimEvent.Type.BUILDING_PLACED, b.id, owner, b.pos)
	ev.text = bdef.id


static func _cmd_pack(w: SimWorld, cmd: SimCommand) -> void:
	var b: SimEntity = _own_building(w, cmd)
	if b == null or not b.constructed or b.def.packs_to == "":
		return
	var p: SimPlayer = w.players[cmd.player]
	for q: String in b.queue:
		var refund: int = w.data.entity(q).cost
		p.salvage += refund
		p.stat_salvage_spent -= refund
	b.queue.clear()
	var frac: float = b.hp / b.max_hp
	w.on_building_removed(b)
	w.remove_entity(b)
	var u: SimEntity = w.spawn_unit(b.def.packs_to, cmd.player, b.pos, PI * 0.5)
	u.hp = maxf(1.0, u.max_hp * frac)
	var ev: SimEvent = w.emit_event(SimEvent.Type.UNIT_READY, u.id, cmd.player, u.pos)
	ev.text = u.def.id


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
		SimOrder.Type.CAPTURE:
			_update_capture(w, e, o)
		SimOrder.Type.DEPLOY:
			_update_deploy(w, e, o)
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
				# Some factions (the Nomad Circuit) strip wrecks more thoroughly.
				if res.kind == SimEntity.Kind.WRECK:
					e.cargo += int(float(take) * w.players[e.owner].faction.wreck_salvage_mult)
				else:
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


## Why `e` cannot hijack `t`, or "".
static func hijack_error(w: SimWorld, e: SimEntity, t: SimEntity) -> String:
	if e.def == null or not e.def.hijacker:
		return "Only Splicers can hijack"
	if t == null or t.kind != SimEntity.Kind.UNIT or t.def == null or not t.def.is_vehicle():
		return "Only vehicles can be hijacked"
	if not w.are_enemies(e.owner, t.owner):
		return "Not an enemy"
	if t.linked:
		return "The vehicle must be Dark (outside its owner's signal)"
	if not SimVision.can_see(w, e.owner, t):
		return "Cannot see the target"
	return ""


## A Splicer closing on a Dark enemy vehicle and taking it over.
static func _update_hijack(w: SimWorld, e: SimEntity, o: SimOrder, t: SimEntity) -> void:
	if hijack_error(w, e, t) != "":
		SimMovement.stop(e)
		SimOrders.finish_order(e)
		return
	var reach: float = t.radius + e.radius + 0.9
	if e.pos.distance_to(t.pos) > reach:
		e.work_ticks = 0
		if not e.moving or w.tick_count >= e.repath_tick:
			SimMovement.start_move(w, e, t.pos)
			e.repath_tick = w.tick_count + 10
			o.started = true
		return
	SimMovement.stop(e)
	e.work_ticks += 1
	if e.work_ticks < int(w.data.hijack_seconds * float(SimWorld.TICK_RATE)):
		return
	var old_owner: SimPlayer = w.players[t.owner]
	var new_owner: SimPlayer = w.players[e.owner]
	old_owner.bandwidth_used -= t.def.bandwidth
	old_owner.stat_units_lost += 1
	new_owner.bandwidth_used += t.def.bandwidth - e.def.bandwidth
	new_owner.stat_kills += 1
	w.alert(old_owner.id, "%s hijacked!" % t.def.name, t.pos)
	w.alert(new_owner.id, "%s hijacked" % t.def.name, t.pos)
	t.owner = e.owner
	SimOrders.clear_orders(t)
	t.hold = false
	t.cargo = 0
	# The Splicer stays inside its prize.
	w.remove_entity(e)


static func _update_capture(w: SimWorld, e: SimEntity, o: SimOrder) -> void:
	var site: SimEntity = w.get_entity(o.target_id)
	if site != null and site.kind == SimEntity.Kind.UNIT:
		_update_hijack(w, e, o, site)
		return
	if site == null or site.kind != SimEntity.Kind.UPLINK or site.owner == e.owner:
		SimMovement.stop(e)
		SimOrders.finish_order(e)
		return
	if not _approach(w, e, o, site, site.radius + e.radius + 0.8):
		if e.stuck_ticks > 40:
			SimOrders.finish_order(e)
		return
	if site.capturer != e.owner:
		site.capturer = e.owner
		site.capture_progress = 0.0
	site.capture_progress += SimWorld.DT
	e.facing = rotate_toward(e.facing, (site.pos - e.pos).angle(), e.def.turn_rate * SimWorld.DT)
	e.aim = e.facing
	if site.capture_progress >= w.data.uplink_capture_seconds:
		var previous: int = site.owner
		site.owner = e.owner
		site.capture_progress = 0.0
		site.capturer = -1
		site.linked = SimSignal.is_covered(w, site.owner, site.pos)
		w.alert(e.owner, "Uplink Site captured", site.pos)
		if previous >= 0:
			w.alert(previous, "Uplink Site lost", site.pos)
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
	if w.tick_count % SimWorld.TICK_RATE == 0:
		_pay_uplinks(w)


## Once a second: every owned uplink inside its owner's coverage pays out.
static func _pay_uplinks(w: SimWorld) -> void:
	for e: SimEntity in w.entities:
		if e.kind != SimEntity.Kind.UPLINK or e.owner < 0:
			continue
		e.linked = SimSignal.is_covered(w, e.owner, e.pos)
		if e.linked:
			var p: SimPlayer = w.players[e.owner]
			p.salvage += w.data.uplink_income_per_second
			p.stat_salvage_collected += w.data.uplink_income_per_second


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
	if b.def.mine_trigger > 0.0:
		if (w.tick_count + b.id) % 2 == 0:
			_check_mine(w, b)
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


## A mine goes off when an enemy ground unit comes within its trigger radius.
static func _check_mine(w: SimWorld, mine: SimEntity) -> void:
	var tripped: bool = false
	for n: SimEntity in w.query_radius(mine.pos, mine.def.mine_trigger + 1.6):
		if n.kind != SimEntity.Kind.UNIT or n.def.is_air() or not w.are_enemies(mine.owner, n.owner):
			continue
		if n.pos.distance_to(mine.pos) <= mine.def.mine_trigger + n.radius * 0.5:
			tripped = true
			break
	if not tripped:
		return
	var ev: SimEvent = w.emit_event(SimEvent.Type.IMPACT, mine.id, mine.owner, mine.pos)
	ev.text = "mine"
	ev.value = mine.def.mine_splash
	var explosive: int = GameData.DAMAGE_TYPES.find("explosive")
	for n: SimEntity in w.query_radius(mine.pos, mine.def.mine_splash + SimCombat.BIG_RADIUS):
		if n.def == null or n == mine or not w.are_enemies(mine.owner, n.owner) or n.def.is_air():
			continue
		var d: float = mine.pos.distance_to(n.pos) - n.radius
		if d > mine.def.mine_splash:
			continue
		var falloff: float = 1.0 if d <= 0.0 else lerpf(1.0, 0.4, d / mine.def.mine_splash)
		SimCombat.apply_damage(w, n, mine.def.mine_damage * falloff, explosive, null, mine.owner)
	w.on_building_removed(mine)
	w.remove_entity(mine)


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
