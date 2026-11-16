class_name SimOrders
extends RefCounted
## Applies player commands and runs each unit's order queue.

const LEASH: float = 18.0  ## idle units stop chasing this far from where they stood


static func apply_command(w: SimWorld, cmd: SimCommand) -> void:
	var p: SimPlayer = w.player(cmd.player)
	if p == null or p.defeated:
		return
	match cmd.type:
		SimCommand.Type.MOVE:
			_cmd_move(w, cmd, SimOrder.Type.MOVE)
		SimCommand.Type.ATTACK_MOVE:
			_cmd_move(w, cmd, SimOrder.Type.ATTACK_MOVE)
		SimCommand.Type.ATTACK:
			_cmd_attack(w, cmd)
		SimCommand.Type.STOP:
			for e: SimEntity in own_units(w, cmd):
				clear_orders(e)
				e.hold = false
		SimCommand.Type.HOLD:
			for e: SimEntity in own_units(w, cmd):
				clear_orders(e)
				e.hold = true
		SimCommand.Type.SURRENDER:
			w.defeat_player(cmd.player)
		SimCommand.Type.DIRECTIVE, SimCommand.Type.UNLOCK:
			SimDirectives.apply_command(w, cmd)
		_:
			SimEconomy.apply_command(w, cmd)


## The alive units in cmd.ids that belong to the commanding player.
static func own_units(w: SimWorld, cmd: SimCommand) -> Array[SimEntity]:
	var out: Array[SimEntity] = []
	for id: int in cmd.ids:
		var e: SimEntity = w.get_entity(id)
		if e != null and e.owner == cmd.player and e.kind == SimEntity.Kind.UNIT:
			out.append(e)
	return out


static func clear_orders(e: SimEntity) -> void:
	e.orders.clear()
	SimMovement.stop(e)
	e.target_id = 0
	e.chasing = false
	e.guard_pos = e.pos


static func give_order(e: SimEntity, order: SimOrder, queued: bool) -> void:
	if not queued:
		clear_orders(e)
	e.hold = false
	e.orders.append(order)


static func _cmd_move(w: SimWorld, cmd: SimCommand, order_type: int) -> void:
	var units: Array[SimEntity] = own_units(w, cmd)
	if units.is_empty():
		return
	var slots: Array[Vector2] = formation_slots(w, units, cmd.pos)
	for i: int in units.size():
		# Ground units cannot stand on blocked cells; aircraft can hover anywhere.
		var slot: Vector2 = slots[i] if units[i].def.is_air() else w.map.nearest_free_pos(slots[i])
		give_order(units[i], SimOrder.make(order_type, slot), cmd.queue)


static func _cmd_attack(w: SimWorld, cmd: SimCommand) -> void:
	var target: SimEntity = w.get_entity(cmd.target_id)
	if target == null or not target.is_combatant():
		return
	if not _attackable(w, cmd.player, target):
		# Cannot see it: go and look instead.
		cmd.pos = target.pos
		_cmd_move(w, cmd, SimOrder.Type.ATTACK_MOVE)
		return
	for e: SimEntity in own_units(w, cmd):
		if e.def.is_armed() and SimCombat.best_multiplier(w, e, target) > 0.0:
			give_order(e, SimOrder.make(SimOrder.Type.ATTACK, target.pos, target.id), cmd.queue)
		else:
			give_order(e, SimOrder.make(SimOrder.Type.MOVE, target.pos), cmd.queue)


## Units must be in sight to be attacked; buildings only need to have been
## seen once, since they do not move.
static func _attackable(w: SimWorld, player_id: int, target: SimEntity) -> bool:
	if SimVision.can_see(w, player_id, target):
		return true
	return target.kind == SimEntity.Kind.BUILDING and SimVision.is_explored(w, player_id, target.pos)


## Destination points for a group ordered to `target`: a block facing the
## direction of travel. `units` is re-ordered in place so units[i] takes
## slot i with little path crossing.
static func formation_slots(w: SimWorld, units: Array[SimEntity], target: Vector2) -> Array[Vector2]:
	var slots: Array[Vector2] = []
	var n: int = units.size()
	if n == 1:
		slots.append(target)
		return slots
	var centroid: Vector2 = Vector2.ZERO
	var max_radius: float = 0.0
	for e: SimEntity in units:
		centroid += e.pos
		max_radius = maxf(max_radius, e.radius)
	centroid /= float(n)
	var dir: Vector2 = target - centroid
	if dir.length() < 0.01:
		dir = Vector2.RIGHT
	dir = dir.normalized()
	var side: Vector2 = Vector2(-dir.y, dir.x)
	var spacing: float = max_radius * 2.0 + 0.5
	var cols: int = int(ceilf(sqrt(float(n))))
	# Front rows go to the units already furthest along the direction of travel.
	units.sort_custom(func(a: SimEntity, b: SimEntity) -> bool:
		var da: float = a.pos.dot(dir)
		var db: float = b.pos.dot(dir)
		if da == db:
			return a.id < b.id
		return da > db
	)
	var row: int = 0
	var i: int = 0
	while i < n:
		var count: int = mini(cols, n - i)
		var row_units: Array[SimEntity] = units.slice(i, i + count)
		row_units.sort_custom(func(a: SimEntity, b: SimEntity) -> bool:
			var sa: float = a.pos.dot(side)
			var sb: float = b.pos.dot(side)
			if sa == sb:
				return a.id < b.id
			return sa < sb
		)
		for k: int in count:
			units[i + k] = row_units[k]
			var offset: float = (float(k) - float(count - 1) * 0.5) * spacing
			var slot: Vector2 = target + side * offset - dir * (float(row) * spacing)
			slots.append(w.map.clamp_to_map(slot))
		i += count
		row += 1
	return slots


static func finish_order(e: SimEntity) -> void:
	if not e.orders.is_empty():
		e.orders.remove_at(0)
	if e.orders.is_empty():
		e.guard_pos = e.pos
		e.chasing = false


static func update_unit(w: SimWorld, e: SimEntity) -> void:
	var o: SimOrder = e.current_order()
	if o == null:
		_idle(w, e)
		return
	match o.type:
		SimOrder.Type.MOVE:
			if not o.started:
				o.started = true
				SimMovement.start_move(w, e, o.pos)
				if not e.moving:
					finish_order(e)
			elif not e.moving:
				finish_order(e)
		SimOrder.Type.ATTACK_MOVE:
			var seen: SimEntity = w.get_entity(e.target_id)
			if seen != null and e.def.is_armed():
				engage(w, e, seen)
				o.started = false  # path again once the fight is over
			elif not o.started:
				o.started = true
				SimMovement.start_move(w, e, o.pos)
				if not e.moving:
					finish_order(e)
			elif not e.moving:
				finish_order(e)
		SimOrder.Type.ATTACK:
			var target: SimEntity = w.get_entity(o.target_id)
			if target != null and target.kind == SimEntity.Kind.UNIT and not SimVision.can_see(w, e.owner, target):
				target = null  # lost sight of it
			if target == null or not e.def.is_armed():
				SimMovement.stop(e)
				e.target_id = 0
				finish_order(e)
			else:
				e.target_id = target.id
				engage(w, e, target)
		_:
			SimEconomy.update_order(w, e, o)


static func _idle(w: SimWorld, e: SimEntity) -> void:
	if not e.def.is_armed():
		return
	var t: SimEntity = w.get_entity(e.target_id)
	if t == null or e.hold:
		if e.chasing:
			SimMovement.stop(e)
			e.chasing = false
		return
	if e.pos.distance_to(e.guard_pos) > LEASH:
		# Lured too far: give up and look again in a moment.
		e.target_id = 0
		e.scan_tick = w.tick_count + 30
		SimMovement.stop(e)
		e.chasing = false
		return
	engage(w, e, t)
	e.chasing = e.moving


## Stand and fire when the target is in range, otherwise close the distance.
static func engage(w: SimWorld, e: SimEntity, t: SimEntity) -> void:
	var reach: float = SimCombat.reach_against(w, e, t)
	var d: float = e.pos.distance_to(t.pos) - t.radius
	if d <= reach * 0.92:
		if e.moving:
			SimMovement.stop(e)
		return
	if e.hold:
		return
	if d > reach or e.moving:
		if not e.moving or w.tick_count >= e.repath_tick:
			SimMovement.start_move(w, e, t.pos)
			e.repath_tick = w.tick_count + 10 + e.id % 5
